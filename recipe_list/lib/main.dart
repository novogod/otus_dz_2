import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'i18n.dart';
import 'i18n/strings.g.dart';
import 'ui/app_theme.dart';
import 'ui/recipe_list_loader.dart';
import 'ui/splash_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initI18n();
  runApp(TranslationProvider(child: const RecipeApp()));
}

/// Глобальный ключ корневого виджета приложения. Используется
/// единственным публичным API файла — [restartApp] — чтобы
/// перезапустить splash-последовательность из любого места UI
/// (например, по тапу на «назад» в [SearchAppBar]).
final GlobalKey<_AppRootState> _appRootKey = GlobalKey<_AppRootState>();

/// Перезапускает связку «splash → список рецептов» с самого начала:
/// сбрасывает SlideTransition, пересоздаёт [RecipeListLoader] (что
/// заново триггерит весь load-pipeline) и снова ждёт `AppDurations.splash`
/// перед переходом. Безопасно вызывать до монтирования —
/// тогда вызов будет no-op.
void restartApp() => _appRootKey.currentState?._restart();

/// Корневой виджет приложения. Точка входа максимально короткая —
/// тема, splash и загрузка данных вынесены в отдельные виджеты.
class RecipeApp extends StatelessWidget {
  const RecipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    // slang знает все 10 локалей, но GlobalMaterialLocalizations
    // покрывает только те, что есть во flutter_localizations.
    // Курдский (`ku`) там не поддерживается — без подмены
    // MaterialApp выбрасывает «No MaterialLocalizations found»
    // при показе любого AppBar. Подменяем такие локали на
    // ближайшую Material-совместимую (Translations всё равно
    // отдельно ведутся через TranslationProvider).
    final flutterLocale = TranslationProvider.of(context).flutterLocale;
    final materialLocale = _materialLocaleFor(flutterLocale);
    return MaterialApp(
      title: t.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: materialLocale,
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('ru'),
        Locale('es'),
        Locale('fr'),
        Locale('de'),
        Locale('it'),
        Locale('tr'),
        Locale('ar'),
        Locale('fa'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: AppLangScope(child: _AppRoot(key: _appRootKey)),
    );
  }
}

/// Маппинг локалей slang → ближайшая локаль, которую умеет
/// `GlobalMaterialLocalizations`. Для всего, чего там нет
/// (например, `ku`), отдаём `en` — это влияет только на
/// служебные Material-строки (tooltip Back, semantics scrollbar
/// и т.п.); содержимое UI всё равно идёт из slang.
Locale _materialLocaleFor(Locale loc) {
  const supported = <String>{
    'en',
    'ru',
    'es',
    'fr',
    'de',
    'it',
    'tr',
    'ar',
    'fa',
  };
  return supported.contains(loc.languageCode) ? loc : const Locale('en');
}

/// Показывает splash на `AppDurations.splash` (Figma `AFTER_TIMEOUT` 1.5с),
/// затем выполняет переход на список рецептов с `MOVE_IN`/`TOP`,
/// `EASE_IN_AND_OUT`, `0.7с` (Figma frame `135:691` → `102:3`).
///
/// MOVE_IN / TOP в Figma — это «новый экран въезжает сверху, наплывая
/// поверх предыдущего». Splash при этом остаётся на месте.
class _AppRoot extends StatefulWidget {
  const _AppRoot({super.key});

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  /// Ключ для `RecipeListLoader`, чтобы при перезапуске
  /// последовательности (см. [_restart]) Flutter создал новый
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

    Future<void>.delayed(AppDurations.splash, () {
      if (mounted) _controller.forward();
    });
  }

  /// Перезапускает splash-последовательность. Сбрасывает
  /// SlideTransition в начало, пересоздаёт [RecipeListLoader]
  /// через новый ключ и снова ждёт `AppDurations.splash`,
  /// после чего «въезжает» поверх splash. Используется для
  /// «back»-кнопки на списке (см. `SearchAppBar.onBack`).
  void _restart() {
    if (!mounted) return;
    _controller.reset();
    setState(() {
      _loaderKey = UniqueKey();
    });
    Future<void>.delayed(AppDurations.splash, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
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
          const Positioned.fill(child: SplashPage()),
          // Список «въезжает» снизу, заслоняя splash. Переключатель
          // языка живёт в его AppBar — пока splash, кнопки нет.
          Positioned.fill(
            child: SlideTransition(
              position: _slide,
              child: RecipeListLoader(key: _loaderKey),
            ),
          ),
        ],
      ),
    );
  }
}
