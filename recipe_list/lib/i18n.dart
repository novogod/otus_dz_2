import 'package:flutter/material.dart';

import 'i18n/strings.g.dart';

/// Поддерживаемые языки UI. Совпадают с языками платформы
/// mahallem_ist (см. `routes/post-job.js` — `phrase_<code>` в БД):
/// `ru, en, es, fr, de, it, tr, ar, fa, ku`. На каждый язык есть
/// SVG-флаг в `assets/flags/<flag>.svg` (10 файлов, скопированных
/// из `mahallem_flutter/assets/pictures/flags`).
enum AppLang {
  en('EN', 'us', AppLocale.en),
  ru('RU', 'ru', AppLocale.ru),
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
final ValueNotifier<AppLang> appLang = ValueNotifier<AppLang>(AppLang.en);

/// Возвращает [AppLang], соответствующий локали устройства/браузера.
/// На Flutter Web это берётся из `navigator.language`, на iOS/Android —
/// из системной локали. Если локаль не входит в [AppLang.values],
/// возвращает [AppLang.en].
AppLang detectDeviceAppLang() {
  try {
    final deviceLocale = AppLocaleUtils.findDeviceLocale();
    for (final lang in AppLang.values) {
      if (lang.locale == deviceLocale) return lang;
    }
  } catch (_) {
    // Some test environments throw when probing platform locale.
  }
  return AppLang.en;
}

/// Глобальный «тикер» принудительной перезагрузки ленты. Кнопка
/// «обновить» в [AppPageBar] инкрементирует значение; слушатель в
/// [RecipeListLoader] отбрасывает локальный sqflite-кэш и заново
/// перебирает случайные категории через mahallem-API, чтобы лента
/// действительно обновилась (а не отдала те же 200 закэшированных
/// строк). Сам кэш не чистим — он переиспользуется внутри
/// `_seedFromCategories` для категорий, у которых уже >= порога.
final ValueNotifier<int> reloadFeedTicker = ValueNotifier<int>(0);

/// Сигнал «лента сейчас перезагружается» для `ReloadIconButton`
/// (анимация вращения иконки) и `AppPageBar` (тонкий
/// `LinearProgressIndicator` под шапкой). Управляется
/// `RecipeListLoader._onReloadRequested`. См. todo/03.
final ValueNotifier<bool> reloadingFeed = ValueNotifier<bool>(false);

/// Запрашивает повторный seed ленты: новый случайный набор
/// категорий и попытку дотянуть свежие рецепты из сети.
void requestFeedReload() {
  reloadFeedTicker.value = reloadFeedTicker.value + 1;
}

/// Глобальный «обновить всё» (todo/13) — ленту, избранное, страницу
/// источника. По умолчанию никем не используется: обычная кнопка
/// reload по-прежнему дёргает только ленту через
/// [requestFeedReload]. Подписаться можно через `[ValueListenableBuilder]`
/// или `addListener`/`removeListener` в `initState`/`dispose`.
final ValueNotifier<int> appReloadTicker = ValueNotifier<int>(0);

/// Поднимает [appReloadTicker]; листы, подписанные на него, должны
/// перезапросить свои данные. Феед тоже инвалидируется через
/// [requestFeedReload], чтобы единая кнопка двигала всё сразу.
void requestAppReload() {
  appReloadTicker.value = appReloadTicker.value + 1;
  requestFeedReload();
}

/// Переключает текущий язык на следующий из [AppLang].
void cycleAppLang() {
  final next =
      AppLang.values[(appLang.value.index + 1) % AppLang.values.length];
  // ignore: avoid_print
  print('[lang] cycleAppLang ${appLang.value.name} -> ${next.name}');
  appLang.value = next;
}

/// Устанавливает язык приложения в конкретное значение [lang].
void cycleAppLangTo(AppLang lang) {
  if (appLang.value == lang) return;
  // ignore: avoid_print
  print('[lang] cycleAppLangTo ${appLang.value.name} -> ${lang.name}');
  appLang.value = lang;
}

/// Связывает [appLang] с slang's [LocaleSettings]. Вызывать один раз
/// в `main()` — после этого каждое изменение `appLang.value`
/// автоматически перенастраивает текущий локаль slang, и все
/// `Translations.of(context)` ниже `TranslationProvider` обновляются.
bool _listenerInstalled = false;
void initI18n() {
  if (_listenerInstalled) return;
  _listenerInstalled = true;
  _registerPluralResolvers();
  LocaleSettings.setLocaleSync(appLang.value.locale);
  appLang.addListener(() {
    // ignore: avoid_print
    print('[lang] initI18n listener -> ${appLang.value.name}');
    LocaleSettings.setLocaleSync(appLang.value.locale);
  });
}

/// Регистрирует cardinal-резолверы для языков, у slang которых нет
/// встроенного правила (tr/ar/fa/ku). Без этого slang выводит
/// `Resolver for <lang = …> not specified!` и использует случайный
/// фолбэк. Правила минимальные — наши строки имеют только формы
/// `one`/`other`, поэтому достаточно классической бинарной логики.
void _registerPluralResolvers() {
  String oneOrOther(
    num n, {
    String? zero,
    String? one,
    String? two,
    String? few,
    String? many,
    String? other,
  }) {
    final form = (n == 1 ? one : other) ?? other ?? one ?? '';
    return form;
  }

  // Турецкий: CLDR определяет только `other`, но наши строки имеют
  // отдельную форму `one` — отдаём её при n==1 для лучшей подачи.
  LocaleSettings.setPluralResolverSync(
    language: 'tr',
    cardinalResolver: oneOrOther,
  );
  // Курдский (sorani/iq): n==1 -> one, иначе other.
  LocaleSettings.setPluralResolverSync(
    language: 'ku',
    cardinalResolver: oneOrOther,
  );
  // Фарси: n<=1 -> one, иначе other (CLDR).
  LocaleSettings.setPluralResolverSync(
    language: 'fa',
    cardinalResolver: (n, {zero, one, two, few, many, other}) =>
        (n <= 1 ? one : other) ?? other ?? one ?? '',
  );
  // Арабский: полный CLDR — zero/one/two/few/many/other.
  LocaleSettings.setPluralResolverSync(
    language: 'ar',
    cardinalResolver: (n, {zero, one, two, few, many, other}) {
      if (n == 0) return zero ?? other ?? one ?? '';
      if (n == 1) return one ?? other ?? '';
      if (n == 2) return two ?? other ?? one ?? '';
      final mod100 = n.toInt() % 100;
      if (mod100 >= 3 && mod100 <= 10) return few ?? other ?? '';
      if (mod100 >= 11 && mod100 <= 99) return many ?? other ?? '';
      return other ?? one ?? '';
    },
  );
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

  // PWA install (iOS instructions modal — see web_action_buttons.dart).
  String get pwaInstallTooltip => _t.pwaInstallTooltip;
  String get pwaInstallTitle => _t.pwaInstallTitle;
  String get pwaInstallSafariTitle => _t.pwaInstallSafariTitle;
  String get pwaInstallSafariStep1 => _t.pwaInstallSafariStep1;
  String get pwaInstallSafariStep2 => _t.pwaInstallSafariStep2;
  String get pwaInstallSafariStep3 => _t.pwaInstallSafariStep3;
  String get pwaInstallChromeTitle => _t.pwaInstallChromeTitle;
  String get pwaInstallChromeStep1 => _t.pwaInstallChromeStep1;
  String get pwaInstallChromeStep2 => _t.pwaInstallChromeStep2;
  String get pwaInstallChromeStep3 => _t.pwaInstallChromeStep3;
  String get pwaInstallGotIt => _t.pwaInstallGotIt;
  String get shareTooltip => _t.shareTooltip;
  String get shareEmail => _t.shareEmail;
  String get shareCopyLink => _t.shareCopyLink;
  String get shareLinkCopied => _t.shareLinkCopied;

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

  // Favorites page (todo/15, chunk D).
  String get favoritesEmpty => _t.favoritesEmpty;

  // Card ingredient count (CLDR plural).
  String ingredientCount(int n) => _t.ingredientCount(n: n);

  // Accessibility labels.
  String switchLanguageTo(String label) =>
      _t.a11y.switchLanguageTo(label: label);
  String flagOf(String label) => _t.a11y.flagOf(label: label);
  String get reloadFeed => _t.a11y.reloadFeed;
  String get offlineReloadUnavailable => _t.a11y.offlineReloadUnavailable;
  String get reloadServerBusy => _t.a11y.reloadServerBusy;
  String get scrollToTop => _t.a11y.scrollToTop;
  String get addRecipe => _t.a11y.addRecipe;

  // Add-recipe page.
  String get addRecipeTitle => _t.addRecipeTitle;
  String get editRecipeTitle => _t.editRecipeTitle;
  String get addRecipeName => _t.addRecipeName;
  String get addRecipePhoto => _t.addRecipePhoto;
  String get addRecipeCategory => _t.addRecipeCategory;
  String get addRecipeArea => _t.addRecipeArea;
  String get addRecipeInstructions => _t.addRecipeInstructions;
  String get addRecipeIngredientsLabel => _t.addRecipeIngredientsLabel;
  String get addRecipeIngredientName => _t.addRecipeIngredientName;
  String get addRecipeIngredientNameHint => _t.addRecipeIngredientNameHint;
  String get addRecipeIngredientQty => _t.addRecipeIngredientQty;
  String get addRecipeIngredientQtyShort => _t.addRecipeIngredientQtyShort;
  String get addRecipeIngredientQtyHint => _t.addRecipeIngredientQtyHint;
  String get addRecipeIngredientMeasure => _t.addRecipeIngredientMeasure;
  String get addRecipeIngredientMeasureHint =>
      _t.addRecipeIngredientMeasureHint;
  String get addRecipeIngredientAdd => _t.addRecipeIngredientAdd;
  String get addRecipeIngredientRemove => _t.addRecipeIngredientRemove;
  String get addRecipeSubmit => _t.addRecipeSubmit;
  String get addRecipeRequired => _t.addRecipeRequired;
  String get addRecipeSaving => _t.addRecipeSaving;
  String get addRecipeError => _t.addRecipeError;
  String get addRecipeSuccess => _t.addRecipeSuccess;

  // Photo picker (chunk 11 + 13 of recipe_photo_upload.md).
  String get addRecipePhotoFromGallery => _t.addRecipePhotoFromGallery;
  String get addRecipePhotoFromCamera => _t.addRecipePhotoFromCamera;
  String get addRecipePhotoRequired => _t.addRecipePhotoRequired;
  String get addRecipePhotoRemove => _t.addRecipePhotoRemove;
  String get addRecipePhotoSourceTitle => _t.addRecipePhotoSourceTitle;
  String get addRecipePhotoErrorAccessDenied =>
      _t.addRecipePhotoErrorAccessDenied;
  String get addRecipePhotoErrorTooLarge => _t.addRecipePhotoErrorTooLarge;
  String get addRecipePhotoPicker => _t.a11y.addRecipePhotoPicker;

  // Login / admin mode.
  String get loginUsername => _t.loginUsername;
  String get loginPassword => _t.loginPassword;
  String get loginButton => _t.loginButton;
  String get logoutButton => _t.logoutButton;
  String get signUp => _t.signUp;
  String get signUpName => _t.signUpName;
  String get signUpEmail => _t.signUpEmail;
  String get signUpPassword => _t.signUpPassword;
  String get signUpButton => _t.signUpButton;
  String get signUpInvalidEmail => _t.signUpInvalidEmail;
  String get signUpPasswordTooShort => _t.signUpPasswordTooShort;
  String get signUpDuplicateUser => _t.signUpDuplicateUser;
  String get signUpSenderError => _t.signUpSenderError;
  String get signUpError => _t.signUpError;
  String get signUpSuccess => _t.signUpSuccess;
  String get signUpChooseLanguage => _t.signUpChooseLanguage;
  String get loginInvalidCredentials => _t.loginInvalidCredentials;
  String get loginSuccessAdmin => _t.loginSuccessAdmin;
  String get loginSuccessUser => _t.loginSuccessUser;
  String favoritesRegistrationRequired({required Object button}) =>
      _t.favoritesRegistrationRequired(button: button);
  String get forgotPassword => _t.forgotPassword;
  String get passwordRecoveryTitle => _t.passwordRecoveryTitle;
  String get passwordRecoveryInstruction => _t.passwordRecoveryInstruction;
  String get passwordRecoveryCodeLabel => _t.passwordRecoveryCodeLabel;
  String get passwordRecoveryCodeHint => _t.passwordRecoveryCodeHint;
  String get passwordRecoveryNewPassword => _t.passwordRecoveryNewPassword;
  String get passwordRecoverySubmit => _t.passwordRecoverySubmit;
  String get passwordRecoveryEnterEmail => _t.passwordRecoveryEnterEmail;
  String get passwordRecoveryInvalidEmail => _t.passwordRecoveryInvalidEmail;
  String get passwordRecoveryRequestFailed => _t.passwordRecoveryRequestFailed;
  String get passwordRecoveryInvalidCode => _t.passwordRecoveryInvalidCode;
  String get passwordRecoveryPasswordTooShort =>
      _t.passwordRecoveryPasswordTooShort;
  String get passwordRecoverySessionExpired =>
      _t.passwordRecoverySessionExpired;
  String get passwordRecoverySaveFailed => _t.passwordRecoverySaveFailed;
  String get passwordRecoverySaved => _t.passwordRecoverySaved;
  String get adminDeleteTitle => _t.adminDeleteTitle;
  String get adminDeleteMessage => _t.adminDeleteMessage;
  String get adminDeleteAction => _t.adminDeleteAction;
  String get adminEditAction => _t.adminEditAction;

  // Admin users management (manual mapping to avoid regenerating slang files).
  String get adminPanelTitle => _byLang({
    AppLang.en: 'Admin panel',
    AppLang.ru: 'Панель администратора',
    AppLang.tr: 'Yönetici paneli',
  });
  String get adminEditUsersList => _byLang({
    AppLang.en: 'Edit users list',
    AppLang.ru: 'Редактировать список пользователей',
    AppLang.tr: 'Kullanıcı listesini düzenle',
  });
  String get adminEditCards => _byLang({
    AppLang.en: 'Edit recipes',
    AppLang.ru: 'Редактировать рецепты',
    AppLang.tr: 'Tarifleri düzenle',
  });
  String get adminUsersTitle => _byLang({
    AppLang.en: 'Users list',
    AppLang.ru: 'Список пользователей',
    AppLang.tr: 'Kullanıcı listesi',
  });
  String get adminSelectAll => _byLang({
    AppLang.en: 'Select all',
    AppLang.ru: 'Выбрать все',
    AppLang.tr: 'Tümünü seç',
  });
  String get adminNoUsersFound => _byLang({
    AppLang.en: 'No users found',
    AppLang.ru: 'Пользователи не найдены',
    AppLang.tr: 'Kullanıcı bulunamadı',
  });
  String get adminDeleteUserTitle => _byLang({
    AppLang.en: 'Delete user',
    AppLang.ru: 'Удалить пользователя',
    AppLang.tr: 'Kullanıcıyı sil',
  });
  String get adminDeleteSelectedUsersTitle => _byLang({
    AppLang.en: 'Delete selected users',
    AppLang.ru: 'Удалить выбранных пользователей',
    AppLang.tr: 'Seçili kullanıcıları sil',
  });
  String adminDeleteUserPrompt(String email) => _byLang({
    AppLang.en: 'Delete $email?',
    AppLang.ru: 'Удалить $email?',
    AppLang.tr: '$email silinsin mi?',
  });
  String adminDeleteSelectedUsersPrompt(int count) => _byLang({
    AppLang.en: 'Delete $count selected users?',
    AppLang.ru: 'Удалить $count выбранных пользователей?',
    AppLang.tr: '$count seçili kullanıcı silinsin mi?',
  });
  String get adminEditUserTitle => _byLang({
    AppLang.en: 'Edit user',
    AppLang.ru: 'Редактировать пользователя',
    AppLang.tr: 'Kullanıcıyı düzenle',
  });
  String get adminEditAccountFields => _byLang({
    AppLang.en: 'Edit account fields',
    AppLang.ru: 'Редактируйте поля аккаунта',
    AppLang.tr: 'Hesap alanlarını düzenle',
  });
  String get adminFullName => _byLang({
    AppLang.en: 'Full name',
    AppLang.ru: 'Полное имя',
    AppLang.tr: 'Ad Soyad',
  });
  String get adminPreferredLanguage => _byLang({
    AppLang.en: 'Preferred language',
    AppLang.ru: 'Предпочитаемый язык',
    AppLang.tr: 'Tercih edilen dil',
  });
  String get adminActive => _byLang({
    AppLang.en: 'Active',
    AppLang.ru: 'Активен',
    AppLang.tr: 'Aktif',
  });
  String adminDeleteSelectedButton(int count) => '$adminDeleteAction ($count)';
  String adminLangAndStatus(String preferredLanguage, String status) =>
      _byLang({
        AppLang.en: 'Lang: ${preferredLanguage.toUpperCase()} • $status',
        AppLang.ru: 'Язык: ${preferredLanguage.toUpperCase()} • $status',
        AppLang.tr: 'Dil: ${preferredLanguage.toUpperCase()} • $status',
      });

  String _byLang(Map<AppLang, String> values) {
    return values[appLang.value] ?? values[AppLang.en] ?? values.values.first;
  }

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
