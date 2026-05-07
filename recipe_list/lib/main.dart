import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'i18n.dart';
import 'i18n/strings.g.dart';
import 'router/app_router.dart';
import 'ui/app_theme.dart';
import 'ui/splash_and_recipes.dart';
import 'ui/web_share/pwa_install.dart';
import 'web/url_strategy_stub.dart'
    if (dart.library.js_interop) 'web/url_strategy_web.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Web-only: switch from the default hash-URL strategy (`/#/foo`) to
  // path-URL strategy (`/foo`). Without this, share-links that point
  // at canonical paths like `https://recipies.mahallem.ist/en/recipes/
  // <id>` open the SPA shell, GoRouter sees no hash, and the recipes
  // tab — `initialLocation: Routes.recipes` — wins. Calling
  // `usePathUrlStrategy()` makes go_router read the real `pathname`,
  // so the `/:lang/recipes/:id` redirect fires and the receiver lands
  // on the recipe details page.
  // No-op on iOS/Android/desktop — the helper is web-only, so we
  // gate it behind `kIsWeb` and resolve the import at runtime via
  // a deferred import to keep iOS/Android binaries from referencing
  // `dart:html` symbols at all.
  if (kIsWeb) {
    enablePathUrlStrategy();
  }
  // Pick up the device / browser locale before initI18n wires the
  // ValueNotifier into slang. If the user has a stored session,
  // admin_session.dart will overwrite this with their preferred
  // language during the splash sequence.
  appLang.value = detectDeviceAppLang();
  initI18n();
  // Web-only: start polling the JS shim that captured
  // `beforeinstallprompt` so the Install-PWA button knows when to
  // surface itself. No-op on iOS/Android/desktop (stub).
  initPwaInstallWatcher();
  runApp(TranslationProvider(child: const RecipeApp()));
}

/// Глобальный ключ виджета [SplashAndRecipes]. Используется
/// единственным публичным API файла — [restartApp] — чтобы
/// перезапустить splash-последовательность из любого места UI
/// (например, по тапу на «назад» в [SearchAppBar]).
///
/// Ключ публичный, потому что после перехода на `go_router`
/// (см. `docs/go-router-shell-refactor.md`, чанк A)
/// [SplashAndRecipes] инстанцируется внутри роутера, а не
/// напрямую в [RecipeApp]. Ключ передаётся в роутере как
/// `key:` для соответствующей ветки.
final GlobalKey<SplashAndRecipesState> splashAndRecipesKey =
    GlobalKey<SplashAndRecipesState>();

/// Видна ли нижняя навигационная панель.
///
/// Дефолт `true` — навбар виден всегда, кроме явных override-ов.
/// `SplashAndRecipesState` сбрасывает в `false` на старте
/// splash-последовательности и снова в `true`, когда
/// `SlideTransition` доехал до конца. Тесты, которые
/// собирают приложение без splash, ничего об этом флаге
/// знать не должны.
///
/// Login/admin/signup/recovery живут на root-навигаторе
/// (`parentNavigatorKey: rootNavigatorKey` в `appRouter`) и
/// сами по себе не видят навбар — этот флаг управляет только
/// splash → recipes-сценарием.
final ValueNotifier<bool> bottomNavVisibleNotifier = ValueNotifier<bool>(true);

/// Перезапускает связку «splash → список рецептов» с самого начала:
/// сбрасывает SlideTransition, пересоздаёт `RecipeListLoader` (что
/// заново триггерит весь load-pipeline) и снова ждёт `AppDurations.splash`
/// перед переходом. Безопасно вызывать до монтирования —
/// тогда вызов будет no-op.
void restartApp() => splashAndRecipesKey.currentState?.restart();

/// Корневой виджет приложения. Точка входа максимально короткая —
/// тема, splash и загрузка данных вынесены в отдельные виджеты,
/// маршрутизация — в [appRouter] (`lib/router/app_router.dart`).
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
    return MaterialApp.router(
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
      routerConfig: appRouter,
      // AppLangScope раньше оборачивал `home:`. С `MaterialApp.router`
      // home недоступен — оборачиваем выдачу роутера через builder.
      //
      // ВАЖНО: НЕ оборачивать в GestureDetector с onTap unfocus — на
      // iPadOS 26 такой глобальный TapGestureRecognizer выигрывает в
      // gesture arena у TextField и блокирует появление клавиатуры
      // во ВСЁМ приложении. Дефолтный TextField.onTapOutside на
      // мобильных платформах сам прячет клавиатуру при тапе вне поля.
      builder: (context, child) =>
          AppLangScope(child: child ?? const SizedBox.shrink()),
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
