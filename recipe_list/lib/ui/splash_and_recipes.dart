import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../auth/admin_session.dart';
import '../consent/startup_consent.dart';
import '../consent/startup_consent_bar.dart';
import '../i18n.dart';
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
  bool _checkingConsent = true;
  bool _showSplash = true;
  bool _showRecipes = false;
  int _flowTicket = 0;
  bool _lastHasSavedSession = false;

  /// Ключ для `RecipeListLoader`, чтобы при перезапуске
  /// последовательности (см. [restart]) Flutter создал новый
  /// State и заново прогнал весь load-pipeline.
  Key _loaderKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _lastHasSavedSession = _hasSavedSession;
    userLoggedInNotifier.addListener(_onSessionStateChanged);
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
        if (mounted && _showSplash) {
          setState(() => _showSplash = false);
        }
      }
    });
    _bootstrapConsentAndStart();
  }

  bool get _hasSavedSession => userLoggedInNotifier.value;

  void _onSessionStateChanged() {
    final hasSavedSession = _hasSavedSession;
    if (hasSavedSession == _lastHasSavedSession) return;
    _lastHasSavedSession = hasSavedSession;
    // User explicitly logged out (or session was dropped): rerun
    // startup flow so consent appears again per product policy.
    if (!hasSavedSession && mounted) {
      restart();
    }
  }

  /// Стартовый pipeline после переезда консента в bottom-bar
  /// (см. consent/startup_consent_bar.dart, todo/21):
  ///
  /// 1. Показываем splash на `AppDurations.splash`.
  /// 2. Сразу запускаем slide-up рецептов — лента грузится
  ///    параллельно, ничего не блокируем.
  /// 3. Параллельно проверяем, дал ли пользователь согласие.
  ///    Если ещё нет — поднимаем `startupConsentPendingNotifier`,
  ///    [AppShell] нарисует persistent-бар над навбаром.
  Future<void> _bootstrapConsentAndStart() async {
    if (!mounted) return;
    final int flowTicket = ++_flowTicket;
    setState(() {
      _checkingConsent = true;
      _showRecipes = false;
      _showSplash = true;
    });

    _controller.reset();
    bottomNavVisibleNotifier.value = false;

    // Запускаем splash-задержку и проверку согласия параллельно.
    final consentFuture = _hasSavedSession
        ? Future.value(true)
        : hasAcceptedStartupConsent(lang: appLang.value, isWeb: kIsWeb);
    await Future.delayed(AppDurations.splash);
    if (!mounted || flowTicket != _flowTicket) return;

    final accepted = await consentFuture;
    if (!mounted || flowTicket != _flowTicket) return;

    startupConsentPendingNotifier.value = !accepted;

    setState(() {
      _checkingConsent = false;
      _showRecipes = true;
    });
    _controller
      ..reset()
      ..forward();
  }

  void _onSplashLanguageSelected(AppLang lang) {
    cycleAppLangTo(lang);
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
      _checkingConsent = true;
      _showSplash = true;
      _showRecipes = false;
    });
    _flowTicket++;
    _bootstrapConsentAndStart();
  }

  @override
  void dispose() {
    userLoggedInNotifier.removeListener(_onSessionStateChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                topRightOverlay: SafeArea(
                  child: _LanguageSwitcherCircles(
                    onLanguageSelected: _onSplashLanguageSelected,
                  ),
                ),
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
        ],
      ),
    );
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
