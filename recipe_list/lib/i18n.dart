import 'package:flutter/material.dart';

import 'i18n/strings.g.dart';

/// Поддерживаемые языки UI. Совпадают с языками платформы
/// mahallem_ist (см. `routes/post-job.js` — `phrase_<code>` в БД):
/// `ru, en, es, fr, de, it, tr, ar, fa, ku`. На каждый язык есть
/// SVG-флаг в `assets/flags/<flag>.svg` (10 файлов, скопированных
/// из `mahallem_flutter/assets/pictures/flags`).
enum AppLang {
  ru('RU', 'ru', AppLocale.ru),
  en('EN', 'us', AppLocale.en),
  es('ES', 'es', AppLocale.es),
  fr('FR', 'fr', AppLocale.fr),
  de('DE', 'de', AppLocale.de),
  it('IT', 'it', AppLocale.it),
  tr('TR', 'tr', AppLocale.tr),
  ar('AR', 'sa', AppLocale.ar),
  fa('FA', 'ir', AppLocale.fa),
  ku('KU', 'iq', AppLocale.ku);

  /// Подпись на круглой кнопке (двухбуквенный лейбл).
  final String label;

  /// Имя SVG-флага без расширения (`assets/flags/<flag>.svg`).
  final String flag;

  /// Соответствующий AppLocale из сгенерированного slang-каталога.
  final AppLocale locale;

  const AppLang(this.label, this.flag, this.locale);

  String get flagAsset => 'assets/flags/$flag.svg';

  /// RTL-направление текста для арабского, фарси и курдского.
  bool get isRtl =>
      this == AppLang.ar || this == AppLang.fa || this == AppLang.ku;
}

/// Глобальное хранилище текущего языка.
final ValueNotifier<AppLang> appLang = ValueNotifier<AppLang>(AppLang.ru);

/// Переключает текущий язык на следующий из [AppLang].
void cycleAppLang() {
  final next =
      AppLang.values[(appLang.value.index + 1) % AppLang.values.length];
  // ignore: avoid_print
  print('[lang] cycleAppLang ${appLang.value.name} -> ${next.name}');
  appLang.value = next;
}

/// Связывает [appLang] с slang's [LocaleSettings]. Вызывать один раз
/// в `main()` — после этого каждое изменение `appLang.value`
/// автоматически перенастраивает текущий локаль slang, и все
/// `Translations.of(context)` ниже `TranslationProvider` обновляются.
bool _listenerInstalled = false;
void initI18n() {
  if (_listenerInstalled) return;
  _listenerInstalled = true;
  LocaleSettings.setLocaleSync(appLang.value.locale);
  appLang.addListener(() {
    // ignore: avoid_print
    print('[lang] initI18n listener -> ${appLang.value.name}');
    LocaleSettings.setLocaleSync(appLang.value.locale);
  });
}

/// Подписывает поддерево на изменение `appLang` — после каждого тапа
/// языковой кнопки весь UI ниже [AppLangScope] перестроится и при
/// необходимости получит RTL-направление.
class AppLangScope extends StatelessWidget {
  final Widget child;

  const AppLangScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: appLang,
      builder: (context, value, _) {
        if (value.isRtl) {
          return Directionality(textDirection: TextDirection.rtl, child: child);
        }
        return child;
      },
    );
  }
}

/// Тонкая обёртка над сгенерированными slang-переводами. Сохраняет
/// прежний API `S.of(context).foo`, чтобы не менять call sites.
@immutable
class S {
  const S._(this._t);

  final Translations _t;

  static S of(BuildContext context) {
    initI18n(); // идемпотентно; гарантирует синхронизацию appLang→slang
    try {
      return S._(Translations.of(context));
    } catch (_) {
      return S._(t);
    }
  }

  // App chrome.
  String get appTitle => _t.appTitle;
  String get back => _t.back;
  String get dismiss => _t.dismiss;

  // Bottom navbar.
  String get tabRecipes => _t.tabRecipes;
  String get tabFridge => _t.tabFridge;
  String get tabFavorites => _t.tabFavorites;
  String get tabProfile => _t.tabProfile;
  String get tabComingSoon => _t.tabComingSoon;

  // List page.
  String get emptyList => _t.emptyList;
  String loadError(Object error) => _t.loadError(error: error);
  String get retry => _t.retry;
  String get offlineNotice => _t.offlineNotice;

  // Preload / loading screen.
  String get loadingTitle => _t.loadingTitle;
  String loadingStage(String category, int done, int total) =>
      _t.loadingStage(category: category, done: done, total: total);
  String loadingProgress(int loaded, int target) =>
      _t.loadingProgress(loaded: loaded, target: target);
  String get loadingFromCache => _t.loadingFromCache;
  String get emptyHint => _t.emptyHint;

  // Details page.
  String get recipeTitle => _t.recipeTitle;
  String get ingredientsHeader => _t.ingredientsHeader;
  String get instructionsHeader => _t.instructionsHeader;
  String get youtube => _t.youtube;
  String get source => _t.source;

  // Search bar.
  String get searchHint => _t.searchHint;
  String get searchClear => _t.searchClear;
  String get searchNoMatches => _t.searchNoMatches;

  // Card ingredient count (CLDR plural).
  String ingredientCount(int n) => _t.ingredientCount(n: n);

  // Accessibility labels.
  String switchLanguageTo(String label) =>
      _t.a11y.switchLanguageTo(label: label);
  String flagOf(String label) => _t.a11y.flagOf(label: label);

  // FAB label — derives from current AppLang, not from translations.
  String get langLabel => appLang.value.label;

  /// Локализованное имя категории TheMealDB. Бэкенд `mahallem_ist`
  /// присылает категории по-русски через `lang=ru`, но прогресс-бар
  /// в `RecipeListLoader` показывает английский ключ (`'Lamb'`,
  /// `'Pasta'`, …) — потому что итерируемся по локальному списку.
  /// Маппим вручную, чтобы не делать сетевой запрос ради подписи.
  String localizedCategory(String englishKey) =>
      _categoryNames[appLang.value]?[englishKey] ?? englishKey;
}

const Map<AppLang, Map<String, String>> _categoryNames = {
  AppLang.en: {
    'recipes': 'recipes',
    'Beef': 'Beef',
    'Breakfast': 'Breakfast',
    'Chicken': 'Chicken',
    'Dessert': 'Dessert',
    'Goat': 'Goat',
    'Lamb': 'Lamb',
    'Miscellaneous': 'Miscellaneous',
    'Pasta': 'Pasta',
    'Pork': 'Pork',
    'Seafood': 'Seafood',
    'Side': 'Side',
    'Starter': 'Starter',
    'Vegan': 'Vegan',
    'Vegetarian': 'Vegetarian',
  },
  AppLang.ru: {
    'recipes': 'рецепты',
    'Beef': 'Говядина',
    'Breakfast': 'Завтрак',
    'Chicken': 'Курица',
    'Dessert': 'Десерт',
    'Goat': 'Козлятина',
    'Lamb': 'Баранина',
    'Miscellaneous': 'Разное',
    'Pasta': 'Паста',
    'Pork': 'Свинина',
    'Seafood': 'Морепродукты',
    'Side': 'Гарнир',
    'Starter': 'Закуска',
    'Vegan': 'Веганское',
    'Vegetarian': 'Вегетарианское',
  },
  AppLang.es: {
    'recipes': 'recetas',
    'Beef': 'Ternera',
    'Breakfast': 'Desayuno',
    'Chicken': 'Pollo',
    'Dessert': 'Postre',
    'Goat': 'Cabra',
    'Lamb': 'Cordero',
    'Miscellaneous': 'Variado',
    'Pasta': 'Pasta',
    'Pork': 'Cerdo',
    'Seafood': 'Mariscos',
    'Side': 'Guarnición',
    'Starter': 'Entrante',
    'Vegan': 'Vegano',
    'Vegetarian': 'Vegetariano',
  },
  AppLang.fr: {
    'recipes': 'recettes',
    'Beef': 'Bœuf',
    'Breakfast': 'Petit-déjeuner',
    'Chicken': 'Poulet',
    'Dessert': 'Dessert',
    'Goat': 'Chèvre',
    'Lamb': 'Agneau',
    'Miscellaneous': 'Divers',
    'Pasta': 'Pâtes',
    'Pork': 'Porc',
    'Seafood': 'Fruits de mer',
    'Side': 'Accompagnement',
    'Starter': 'Entrée',
    'Vegan': 'Végétalien',
    'Vegetarian': 'Végétarien',
  },
  AppLang.de: {
    'recipes': 'Rezepte',
    'Beef': 'Rindfleisch',
    'Breakfast': 'Frühstück',
    'Chicken': 'Hähnchen',
    'Dessert': 'Dessert',
    'Goat': 'Ziege',
    'Lamb': 'Lamm',
    'Miscellaneous': 'Verschiedenes',
    'Pasta': 'Pasta',
    'Pork': 'Schweinefleisch',
    'Seafood': 'Meeresfrüchte',
    'Side': 'Beilage',
    'Starter': 'Vorspeise',
    'Vegan': 'Vegan',
    'Vegetarian': 'Vegetarisch',
  },
  AppLang.it: {
    'recipes': 'ricette',
    'Beef': 'Manzo',
    'Breakfast': 'Colazione',
    'Chicken': 'Pollo',
    'Dessert': 'Dolce',
    'Goat': 'Capra',
    'Lamb': 'Agnello',
    'Miscellaneous': 'Varie',
    'Pasta': 'Pasta',
    'Pork': 'Maiale',
    'Seafood': 'Frutti di mare',
    'Side': 'Contorno',
    'Starter': 'Antipasto',
    'Vegan': 'Vegano',
    'Vegetarian': 'Vegetariano',
  },
  AppLang.tr: {
    'recipes': 'tarifler',
    'Beef': 'Dana eti',
    'Breakfast': 'Kahvaltı',
    'Chicken': 'Tavuk',
    'Dessert': 'Tatlı',
    'Goat': 'Keçi',
    'Lamb': 'Kuzu',
    'Miscellaneous': 'Çeşitli',
    'Pasta': 'Makarna',
    'Pork': 'Domuz eti',
    'Seafood': 'Deniz ürünleri',
    'Side': 'Garnitür',
    'Starter': 'Başlangıç',
    'Vegan': 'Vegan',
    'Vegetarian': 'Vejetaryen',
  },
  AppLang.ar: {
    'recipes': 'وصفات',
    'Beef': 'لحم بقري',
    'Breakfast': 'فطور',
    'Chicken': 'دجاج',
    'Dessert': 'حلوى',
    'Goat': 'لحم ماعز',
    'Lamb': 'لحم ضأن',
    'Miscellaneous': 'متنوع',
    'Pasta': 'معكرونة',
    'Pork': 'لحم خنزير',
    'Seafood': 'مأكولات بحرية',
    'Side': 'طبق جانبي',
    'Starter': 'مقبلات',
    'Vegan': 'نباتي صرف',
    'Vegetarian': 'نباتي',
  },
  AppLang.fa: {
    'recipes': 'دستورها',
    'Beef': 'گوشت گاو',
    'Breakfast': 'صبحانه',
    'Chicken': 'مرغ',
    'Dessert': 'دسر',
    'Goat': 'گوشت بز',
    'Lamb': 'گوشت بره',
    'Miscellaneous': 'متفرقه',
    'Pasta': 'پاستا',
    'Pork': 'گوشت خوک',
    'Seafood': 'غذای دریایی',
    'Side': 'مخلفات',
    'Starter': 'پیش‌غذا',
    'Vegan': 'وگان',
    'Vegetarian': 'گیاهی',
  },
  AppLang.ku: {
    'recipes': 'ڕێسەکان',
    'Beef': 'گۆشتی گا',
    'Breakfast': 'نانی بەیانی',
    'Chicken': 'مریشک',
    'Dessert': 'شیرینی',
    'Goat': 'گۆشتی بزن',
    'Lamb': 'گۆشتی بەرخ',
    'Miscellaneous': 'هەمەجۆر',
    'Pasta': 'پاستا',
    'Pork': 'گۆشتی بەراز',
    'Seafood': 'خواردنی دەریایی',
    'Side': 'لاکێش',
    'Starter': 'خواردنی سەرەتایی',
    'Vegan': 'ڤیگان',
    'Vegetarian': 'ڕووەکی',
  },
};
