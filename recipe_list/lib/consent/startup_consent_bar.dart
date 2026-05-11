import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n.dart';
import '../i18n/strings.g.dart';
import '../ui/app_theme.dart';
import 'startup_consent.dart';

/// Глобальный флаг «ждём согласия пользователя со стартовыми
/// документами». Раньше согласие собиралось full-screen модалкой
/// поверх splash, блокируя загрузку ленты. По правке от 2026-05-11
/// мы переехали на persistent bottom-bar (стилизованный как
/// floating SnackBar), который не мешает рецептам грузиться:
///
/// * `SplashAndRecipes` после splash-задержки сразу показывает ленту.
/// * Если пользователь ещё не дал согласие — выставляет
///   `startupConsentPendingNotifier.value = true`.
/// * [AppShell] подписан на этот флаг и рисует
///   [StartupConsentBottomBar] поверх `body`, прямо над
///   `bottomNavigationBar`.
/// * После нажатия «Agree» бар вызывает [acceptStartupConsent]
///   и сбрасывает флаг в `false` — бар уезжает, лента остаётся.
final ValueNotifier<bool> startupConsentPendingNotifier = ValueNotifier<bool>(
  false,
);

/// Persistent bottom-bar with required legal consents. Сидит
/// над нижним навбаром (рендерится внутри `Scaffold.body` Stack-ом
/// в [AppShell]), не блокирует ленту, переезжает за пользователем
/// по табам, пока он не подтвердит все галочки.
///
/// Перерисовывается при смене `appLang` — лейблы/документы
/// тянутся через [startupConsentSpecFor] от текущего языка,
/// при этом состояние чекбоксов сохраняется по `StartupConsentKind`
/// (если пользователь уже отметил «Terms», смена языка не
/// сбросит галочку).
class StartupConsentBottomBar extends StatefulWidget {
  const StartupConsentBottomBar({super.key});

  @override
  State<StartupConsentBottomBar> createState() =>
      _StartupConsentBottomBarState();
}

class _StartupConsentBottomBarState extends State<StartupConsentBottomBar> {
  final Map<StartupConsentKind, bool> _checksByKind = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    appLang.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    appLang.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() {
    if (!mounted) return;
    setState(() {
      // Перерисуемся под новый язык. _checksByKind переживает —
      // чекбоксы сохраняются между языками.
    });
  }

  Future<void> _openDoc(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final t = Translations.of(context);
    if (uri == null) {
      messenger?.showSnackBar(SnackBar(content: Text(t.consentDocUrlInvalid)));
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      messenger?.showSnackBar(SnackBar(content: Text(t.consentDocOpenFailed)));
    }
  }

  Future<void> _agree(StartupConsentSpec spec) async {
    final allChecked = spec.requiredItems.every(
      (item) => _checksByKind[item.kind] == true,
    );
    if (!allChecked) {
      final t = Translations.of(context);
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(t.consentCheckAll)));
      return;
    }
    setState(() => _saving = true);
    try {
      await acceptStartupConsent(lang: appLang.value, isWeb: kIsWeb);
      if (!mounted) return;
      startupConsentPendingNotifier.value = false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = startupConsentSpecFor(appLang.value, isWeb: kIsWeb);
    final s = S.of(context);
    final theme = Theme.of(context);
    // Стилизуем под floating SnackBar: тёмный фон Material 3
    // `inverseSurface`, скруглённые углы, тень. Лежит внутри
    // SafeArea, чтобы не наехать на жестовую полосу iOS.
    // 14% прозрачности по запросу — фон сквозит, чтобы лента
    // под баром оставалась читаемой.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Material(
          color: theme.colorScheme.inverseSurface.withValues(alpha: 0.86),
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // На широких экранах (>= 720px) кладём чекбоксы
                // в одну строку через Wrap, чтобы бар не съедал
                // вертикальное пространство ленты.
                final wide = constraints.maxWidth >= 720;
                final rows = [
                  for (final item in spec.requiredItems)
                    _ConsentRow(
                      checked: _checksByKind[item.kind] ?? false,
                      label: startupConsentLabel(item, s),
                      onChanged: (v) => setState(() {
                        _checksByKind[item.kind] = v ?? false;
                      }),
                      onOpen: () => _openDoc(item.docUrl),
                      inline: wide,
                    ),
                ];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      s.consentTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onInverseSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (wide)
                      Wrap(
                        spacing: AppSpacing.lg,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: rows,
                      )
                    else
                      for (final r in rows) r,
                    const SizedBox(height: AppSpacing.xs),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: _saving ? null : () => _agree(spec),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          _saving ? s.consentSaving : s.consentAgree,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.checked,
    required this.label,
    required this.onChanged,
    required this.onOpen,
    this.inline = false,
  });

  final bool checked;
  final String label;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onOpen;

  /// When true, the row sizes to its content (no `Expanded`) so it
  /// can sit inside a horizontal `Wrap` on wide layouts.
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkedText = _capitalizeWords(_extractLinkedText(label));
    final labelWidget = GestureDetector(
      onTap: onOpen,
      child: Text(
        linkedText,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onInverseSurface,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
    return InkWell(
      onTap: () => onChanged(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: inline ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(
                value: checked,
                onChanged: onChanged,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return theme.colorScheme.secondary;
                  }
                  return theme.colorScheme.onInverseSurface.withValues(
                    alpha: 0.6,
                  );
                }),
                checkColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            if (inline) labelWidget else Expanded(child: labelWidget),
          ],
        ),
      ),
    );
  }

  String _extractLinkedText(String value) {
    final normalized = value.trim();
    final lowered = normalized.toLowerCase();
    const prefixes = ['i accept the ', 'i accept '];
    for (final prefix in prefixes) {
      if (lowered.startsWith(prefix)) {
        return normalized.substring(prefix.length).trim();
      }
    }
    return normalized;
  }

  String _capitalizeWords(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          if (part.length == 1) return part.toUpperCase();
          return '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join(' ');
  }
}
