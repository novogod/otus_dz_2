import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../consent/startup_consent.dart';
import '../i18n.dart';
import '../i18n/strings.g.dart';
import '../main.dart' show bottomNavVisibleNotifier;
import 'app_theme.dart';
import 'recipe_list_loader.dart';
import 'splash_page.dart';

/// Связка «splash → лента рецептов» (бывший `_AppRoot` из `main.dart`).
///
/// Показывает [SplashPage] на `AppDurations.splash` (Figma
/// `AFTER_TIMEOUT` 1.5с), затем выполняет переход на список с
/// `MOVE_IN`/`BOTTOM`, `EASE_IN_AND_OUT`, `0.7с` (Figma frame
/// `135:691` → `102:3`).
///
/// Splash при этом остаётся на месте — список «въезжает» сверху
/// и заслоняет его.
///
/// На чанке A рефакторинга (`docs/go-router-shell-refactor.md`)
/// этот виджет стал телом единственной реальной ветки `recipes`
/// внутри `StatefulShellRoute.indexedStack`. Глобальный ключ
/// [splashAndRecipesKey] остаётся механизмом перезапуска
/// splash-последовательности (см. `restartApp` в `main.dart`).
class SplashAndRecipes extends StatefulWidget {
  const SplashAndRecipes({super.key});

  @override
  State<SplashAndRecipes> createState() => SplashAndRecipesState();
}

class SplashAndRecipesState extends State<SplashAndRecipes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  StartupConsentSpec? _consentSpec;
  List<bool> _consentChecks = const [];
  bool _checkingConsent = true;
  bool _consentAccepted = false;
  bool _savingConsent = false;

  /// Ключ для `RecipeListLoader`, чтобы при перезапуске
  /// последовательности (см. [restart]) Flutter создал новый
  /// State и заново прогнал весь load-pipeline.
  Key _loaderKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.splashTransition,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 1), // въезд снизу (Figma MOVE_IN/BOTTOM)
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    // Навбар скрыт во время splash — иначе он перекрывал бы
    // нижний край «въезжающего» списка. Открываем его, как
    // только slide-up закончился.
    bottomNavVisibleNotifier.value = false;
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        bottomNavVisibleNotifier.value = true;
      }
    });
    _bootstrapConsentAndStart();
  }

  Future<void> _bootstrapConsentAndStart() async {
    final spec = startupConsentSpecFor(appLang.value, isWeb: kIsWeb);
    bool accepted = false;
    try {
      accepted = await hasAcceptedStartupConsent(
        lang: appLang.value,
        isWeb: kIsWeb,
      );
    } catch (_) {
      accepted = false;
    }
    if (!mounted) return;
    setState(() {
      _consentSpec = spec;
      _consentChecks = List<bool>.filled(spec.requiredItems.length, false);
      _checkingConsent = false;
      _consentAccepted = accepted;
    });
    if (accepted && mounted) {
      _controller.forward();
    }
  }

  Future<void> _openDoc(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      if (!mounted) return;
      final t = Translations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.consentDocUrlInvalid)));
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      final t = Translations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.consentDocOpenFailed)));
    }
  }

  Future<void> _agreeAndContinue() async {
    if (_consentSpec == null) return;
    final allChecked =
        _consentChecks.isNotEmpty && _consentChecks.every((checked) => checked);
    if (!allChecked) {
      final t = Translations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.consentCheckAll)));
      return;
    }
    setState(() => _savingConsent = true);
    try {
      await acceptStartupConsent(lang: appLang.value, isWeb: kIsWeb);
      if (!mounted) return;
      setState(() {
        _consentAccepted = true;
      });
      _controller.forward();
    } finally {
      if (mounted) setState(() => _savingConsent = false);
    }
  }

  /// Перезапускает splash-последовательность. Сбрасывает
  /// SlideTransition в начало, пересоздаёт [RecipeListLoader]
  /// через новый ключ и снова ждёт `AppDurations.splash`,
  /// после чего «въезжает» поверх splash. Используется
  /// «back»-кнопкой на списке (см. `SearchAppBar.onBack`).
  void restart() {
    if (!mounted) return;
    _controller.reset();
    bottomNavVisibleNotifier.value = false;
    setState(() {
      _loaderKey = UniqueKey();
      _consentAccepted = false;
      _checkingConsent = true;
    });
    _bootstrapConsentAndStart();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showConsent = !_checkingConsent && !_consentAccepted;
    // Material нужен, чтобы Text внутри splash/list получил
    // DefaultTextStyle темы вместо debug-fallback (жёлтое
    // подчёркивание, неверный вес).
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Сплеш всегда внизу стека — он не двигается во время
          // перехода MOVE_IN, его лишь перекрывает поверх список.
          const Positioned.fill(child: SplashPage()),
          // Список «въезжает» снизу, заслоняя splash. Переключатель
          // языка живёт в его AppBar — пока splash, кнопки нет.
          if (_consentAccepted)
            Positioned.fill(
              child: SlideTransition(
                position: _slide,
                child: RecipeListLoader(key: _loaderKey),
              ),
            ),
          if (_checkingConsent)
            const Positioned.fill(
              child: Center(child: CircularProgressIndicator()),
            ),
          if (showConsent)
            Positioned.fill(
              child: _StartupConsentPanel(
                spec: _consentSpec!,
                checks: _consentChecks,
                saving: _savingConsent,
                onToggle: (index, value) {
                  setState(() {
                    _consentChecks[index] = value;
                  });
                },
                onOpenDoc: _openDoc,
                onAgree: _agreeAndContinue,
              ),
            ),
        ],
      ),
    );
  }
}

class _StartupConsentPanel extends StatelessWidget {
  const _StartupConsentPanel({
    required this.spec,
    required this.checks,
    required this.saving,
    required this.onToggle,
    required this.onOpenDoc,
    required this.onAgree,
  });

  final StartupConsentSpec spec;
  final List<bool> checks;
  final bool saving;
  final void Function(int index, bool value) onToggle;
  final void Function(String url) onOpenDoc;
  final VoidCallback onAgree;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.2),
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Card(
              color: theme.colorScheme.surface.withValues(alpha: 0.9),
              elevation: theme.cardTheme.elevation,
              shadowColor: theme.cardTheme.shadowColor,
              shape: theme.cardTheme.shape,
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.consentTitle, style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      for (var i = 0; i < spec.requiredItems.length; i++)
                        _ConsentRow(
                          checked: checks[i],
                          label: startupConsentLabel(spec.requiredItems[i], s),
                          onChanged: (v) => onToggle(i, v ?? false),
                          onOpen: () => onOpenDoc(spec.requiredItems[i].docUrl),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: saving ? null : onAgree,
                              style: FilledButton.styleFrom(
                                elevation: theme.cardTheme.elevation,
                              ),
                              child: Text(
                                saving ? s.consentSaving : s.consentAgree,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
  });

  final bool checked;
  final String label;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(value: checked, onChanged: onChanged),
          Expanded(
            child: GestureDetector(
              onTap: onOpen,
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
