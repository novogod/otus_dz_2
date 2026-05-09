import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:glow_effects/glow_effects.dart';
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
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final AnimationController _consentController;
  late final Animation<Offset> _consentSlide;
  late final AnimationController _dissolveController;
  late final Animation<double> _dissolveOpacity;
  StartupConsentSpec? _consentSpec;
  List<bool> _consentChecks = const [];
  bool _checkingConsent = true;
  bool _consentAccepted = false;
  bool _consentVisible = false;
  bool _savingConsent = false;
  bool _isDissolving = false;
  bool _showSplash = true;
  bool _showRecipes = false;
  int _flowTicket = 0;

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
    _consentController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _consentSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _consentController, curve: Curves.easeInOut),
        );
    // Dissolve animation: fade consent modal to transparent over 2 seconds
    _dissolveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _dissolveOpacity = Tween<double>(begin: 0.95, end: 0.0).animate(
      CurvedAnimation(parent: _dissolveController, curve: Curves.easeInOut),
    );
    // Навбар скрыт во время splash — иначе он перекрывал бы
    // нижний край «въезжающего» списка. Открываем его, как
    // только slide-up закончился.
    bottomNavVisibleNotifier.value = false;
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        bottomNavVisibleNotifier.value = true;
        if (_consentAccepted && mounted && _showSplash) {
          setState(() => _showSplash = false);
        }
      }
    });
    _bootstrapConsentAndStart();
  }

  Future<void> _bootstrapConsentAndStart() async {
    final spec = startupConsentSpecFor(appLang.value, isWeb: kIsWeb);
    if (!mounted) return;
    final int flowTicket = ++_flowTicket;
    setState(() {
      _consentSpec = spec;
      _consentChecks = List<bool>.filled(spec.requiredItems.length, false);
      _checkingConsent = false;
      _consentAccepted = false;
      _consentVisible = false;
      _isDissolving = false;
      _showRecipes = false;
      _showSplash = true;
    });
    _controller.reset();
    _consentController.reset();
    _dissolveController.reset();
    bottomNavVisibleNotifier.value = false;
    await Future.delayed(AppDurations.splash);
    if (!mounted || flowTicket != _flowTicket) return;
    setState(() {
      _consentVisible = true;
    });
    _consentController
      ..reset()
      ..forward();
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
      setState(() => _isDissolving = true);
      _dissolveController.reset();
      await _dissolveController.forward();
      if (!mounted) return;
      setState(() {
        _consentAccepted = true;
        _consentVisible = false;
        _showRecipes = true;
      });
      _controller
        ..reset()
        ..forward();
    } finally {
      if (mounted) setState(() => _savingConsent = false);
    }
  }

  void _onSplashLanguageSelected(AppLang lang) {
    cycleAppLangTo(lang);
    if (!mounted || _consentAccepted) return;

    final nextSpec = startupConsentSpecFor(appLang.value, isWeb: kIsWeb);
    final previousSpec = _consentSpec;
    final previousChecks = _consentChecks;
    final checksByKind = <StartupConsentKind, bool>{
      if (previousSpec != null)
        for (
          var i = 0;
          i < previousSpec.requiredItems.length && i < previousChecks.length;
          i++
        )
          previousSpec.requiredItems[i].kind: previousChecks[i],
    };

    setState(() {
      _consentSpec = nextSpec;
      _consentChecks = List<bool>.generate(
        nextSpec.requiredItems.length,
        (i) => checksByKind[nextSpec.requiredItems[i].kind] ?? false,
      );
    });
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
      _consentVisible = false;
      _checkingConsent = true;
      _isDissolving = false;
      _showSplash = true;
      _showRecipes = false;
    });
    _consentController.reset();
    _dissolveController.reset();
    _flowTicket++;
    _bootstrapConsentAndStart();
  }

  @override
  void dispose() {
    _controller.dispose();
    _consentController.dispose();
    _dissolveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showConsent =
        !_checkingConsent && _consentVisible && !_consentAccepted;
    // Material нужен, чтобы Text внутри splash/list получил
    // DefaultTextStyle темы вместо debug-fallback (жёлтое
    // подчёркивание, неверный вес).
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Сплеш всегда внизу стека — он не двигается во время
          // перехода MOVE_IN, его лишь перекрывает поверх список.
          if (_showSplash)
            Positioned.fill(
              child: SplashPage(
                topRightOverlay: !_consentAccepted
                    ? SafeArea(
                        child: _LanguageSwitcherCircles(
                          onLanguageSelected: _onSplashLanguageSelected,
                        ),
                      )
                    : null,
              ),
            ),
          // Список «въезжает» снизу, заслоняя splash. Переключатель
          // языка живёт в его AppBar — пока splash, кнопки нет.
          if (_showRecipes)
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
              child: SlideTransition(
                position: _consentSlide,
                child: AnimatedBuilder(
                  animation: _dissolveOpacity,
                  builder: (context, child) {
                    final dissolveProgress = _isDissolving
                        ? Curves.easeInOutCubic.transform(
                            (1.0 - _dissolveOpacity.value).clamp(0.0, 1.0),
                          )
                        : 0.0;
                    return _isDissolving
                        ? GKWidget(
                            effect: DissolveEffect(
                              progress: dissolveProgress,
                              noiseScale: kIsWeb ? 3.2 : 4.2,
                              edgeSoftness: 0.14,
                            ),
                            child: child!,
                          )
                        : child!;
                  },
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
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            color: Colors.white.withValues(alpha: 0.95),
            elevation: 12,
            shadowColor: theme.cardTheme.shadowColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            margin: const EdgeInsets.all(AppSpacing.lg),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.consentTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const SizedBox(height: AppSpacing.md),
                    for (var i = 0; i < spec.requiredItems.length; i++)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: _ConsentRow(
                              checked: checks[i],
                              label: startupConsentLabel(
                                spec.requiredItems[i],
                                s,
                              ),
                              onChanged: (v) => onToggle(i, v ?? false),
                              onOpen: () =>
                                  onOpenDoc(spec.requiredItems[i].docUrl),
                            ),
                          ),
                          if (i < spec.requiredItems.length - 1)
                            const SizedBox(height: AppSpacing.sm),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.sm),
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
                              backgroundColor: theme.colorScheme.secondary,
                              foregroundColor: Colors.white,
                              minimumSize: Size.fromHeight(
                                kMinInteractiveDimension * 1.2,
                              ),
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
    final linkedText = _capitalizeWords(_extractLinkedText(label));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(value: checked, onChanged: onChanged),
          Expanded(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black,
                ),
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: onOpen,
                      child: Text(
                        linkedText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF2D2D2D),
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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

/// Language switcher for splash screen: shows 2 circles like in the app bar.
/// Circle 1 (left): SVG flag of current language.
/// Circle 2 (right): Label button showing next language.
///
/// Диаметр обоих кругов равен высоте кнопки согласия в модалке:
/// `kMinInteractiveDimension * 1.2`.
class _LanguageSwitcherCircles extends StatelessWidget {
  const _LanguageSwitcherCircles({required this.onLanguageSelected});

  static const double _kDiameter = kMinInteractiveDimension * 1.2;

  final void Function(AppLang lang) onLanguageSelected;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: appLang,
      builder: (context, current, _) {
        final next =
            AppLang.values[(current.index + 1) % AppLang.values.length];
        return Semantics(
          button: true,
          label: 'Switch language to ${next.label}',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Current language flag circle (same diameter as consent button)
              Container(
                width: _kDiameter,
                height: _kDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(width: 1, color: Colors.black),
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: _kDiameter,
                    height: _kDiameter,
                    child: SvgPicture.asset(
                      current.flagAsset,
                      fit: BoxFit.cover,
                      semanticsLabel: '${current.label} flag',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Next language cycle button (same diameter as consent button)
              Material(
                color: Theme.of(context).colorScheme.primary,
                shape: const CircleBorder(
                  side: BorderSide(width: 1, color: Colors.black),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(
                    side: BorderSide(width: 1, color: Colors.black),
                  ),
                  onTap: () {
                    onLanguageSelected(next);
                  },
                  child: SizedBox(
                    width: _kDiameter,
                    height: _kDiameter,
                    child: Center(
                      child: Text(
                        next.label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
