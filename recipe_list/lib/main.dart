import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'i18n.dart';
import 'i18n/strings.g.dart';
import 'router/app_router.dart';
import 'ui/app_theme.dart';
import 'ui/splash_and_recipes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initI18n();
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
