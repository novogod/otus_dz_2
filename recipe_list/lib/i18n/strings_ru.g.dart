///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsRu with BaseTranslations<AppLocale, Translations> implements Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsRu({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ru,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ru>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key);

	late final TranslationsRu _root = this; // ignore: unused_field

	@override 
	TranslationsRu $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsRu(meta: meta ?? this.$meta);

	// Translations
	@override String get appTitle => 'Otus Food';
	@override String get back => 'Назад';
	@override String get dismiss => 'Скрыть';
	@override String get pwaInstallTooltip => 'Установить как приложение';
	@override String get pwaInstallTitle => 'Установите Otus Food на iPhone или iPad';
	@override String get pwaInstallSafariTitle => 'Safari';
	@override String get pwaInstallSafariStep1 => 'Нажмите кнопку «Поделиться» внизу экрана';
	@override String get pwaInstallSafariStep2 => 'Прокрутите и выберите «На экран Домой»';
	@override String get pwaInstallSafariStep3 => 'Нажмите «Добавить» в правом верхнем углу';
	@override String get pwaInstallChromeTitle => 'Chrome';
	@override String get pwaInstallChromeStep1 => 'Нажмите значок «Поделиться» в адресной строке';
	@override String get pwaInstallChromeStep2 => 'Выберите «На экран Домой»';
	@override String get pwaInstallChromeStep3 => 'Нажмите «Добавить» для подтверждения';
	@override String get pwaInstallGotIt => 'Понятно';
	@override String get shareTooltip => 'Поделиться';
	@override String get shareEmail => 'Эл. почта';
	@override String get shareCopyLink => 'Копировать ссылку';
	@override String get shareLinkCopied => 'Ссылка скопирована';
	@override String get tabRecipes => 'Рецепты';
	@override String get tabFridge => 'Холодильник';
	@override String get tabFavorites => 'Избранное';
	@override String get tabProfile => 'Профиль';
	@override String get tabComingSoon => 'Этот раздел пока в разработке';
	@override String get loginUsername => 'Логин';
	@override String get loginPassword => 'Пароль';
	@override String get loginButton => 'Войти';
	@override String get logoutButton => 'Выйти';
	@override String get signUp => 'Зарегистрироваться';
	@override String get signUpName => 'Имя';
	@override String get signUpEmail => 'Email';
	@override String get signUpPassword => 'Пароль';
	@override String get signUpButton => 'Создать аккаунт';
	@override String get signUpInvalidEmail => 'Введите корректный email';
	@override String get signUpPasswordTooShort => 'Пароль должен быть не короче 4 символов';
	@override String get signUpDuplicateUser => 'Пользователь уже существует';
	@override String get signUpSenderError => 'Аккаунт создан, но письмо не отправлено';
	@override String get signUpError => 'Не удалось создать аккаунт. Попробуйте ещё раз.';
	@override String get signUpSuccess => 'Аккаунт создан. Данные отправлены на ваш email.';
	@override String get signUpChooseLanguage => 'Выберите язык';
	@override String get loginInvalidCredentials => 'Неверный логин или пароль';
	@override String get loginSuccessAdmin => 'Режим администратора включён';
	@override String get loginSuccessUser => 'Вход выполнен';
	@override String favoritesRegistrationRequired({required Object button}) => 'Для этой функции нужна регистрация, пожалуйста нажмите кнопку ${button}';
	@override String get forgotPassword => 'Я забыл пароль';
	@override String get passwordRecoveryTitle => 'Восстановление пароля';
	@override String get passwordRecoveryInstruction => 'Введите 4-значный код восстановления из вашего email';
	@override String get passwordRecoveryCodeLabel => 'Код восстановления';
	@override String get passwordRecoveryCodeHint => '1234';
	@override String get passwordRecoveryNewPassword => 'Новый пароль';
	@override String get passwordRecoverySubmit => 'Подтвердить';
	@override String get passwordRecoveryEnterEmail => 'Сначала введите ваш email';
	@override String get passwordRecoveryInvalidEmail => 'Введите корректный email';
	@override String get passwordRecoveryRequestFailed => 'Не удалось начать восстановление пароля. Попробуйте снова.';
	@override String get passwordRecoveryInvalidCode => 'Введите корректный 4-значный код';
	@override String get passwordRecoveryPasswordTooShort => 'Пароль должен быть не короче 6 символов';
	@override String get passwordRecoverySessionExpired => 'Сессия восстановления истекла. Начните заново.';
	@override String get passwordRecoverySaveFailed => 'Не удалось сохранить новый пароль. Попробуйте снова.';
	@override String get passwordRecoverySaved => 'Ваш новый пароль сохранён';
	@override String get adminDeleteTitle => 'Удалить рецепт?';
	@override String get adminDeleteMessage => 'Это удалит рецепт для всех.';
	@override String get adminDeleteAction => 'Удалить';
	@override String get adminEditAction => 'Редактировать';
	@override String get emptyList => 'Нет рецептов';
	@override String loadError({required Object error}) => 'Ошибка загрузки: ${error}';
	@override String get retry => 'Повторить';
	@override String get offlineNotice => 'Нет связи с сервером — показываем сохранённое.';
	@override String get loadingTitle => 'Готовим коллекцию рецептов';
	@override String loadingStage({required Object category, required Object done, required Object total}) => 'Загружаем «${category}» (${done}/${total} категорий)…';
	@override String loadingProgress({required Object loaded, required Object target}) => 'Получено ${loaded} из ${target} рецептов';
	@override String get loadingFromCache => 'Открываем сохранённые рецепты…';
	@override String get emptyHint => 'Сервер не вернул рецептов. Проверьте подключение и нажмите «Повторить».';
	@override String get recipeTitle => 'Рецепт';
	@override String get ingredientsHeader => 'Ингредиенты';
	@override String get instructionsHeader => 'Инструкция';
	@override String get youtube => 'YouTube';
	@override String get source => 'Источник';
	@override String get searchHint => 'Поиск рецепта';
	@override String get searchClear => 'Очистить';
	@override String get searchNoMatches => 'Совпадений не найдено';
	@override String get favoritesEmpty => 'Пока ничего не добавлено';
	@override String ingredientCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} ингредиент',
		few: '${n} ингредиента',
		many: '${n} ингредиентов',
		other: '${n} ингредиента',
	);
	@override late final _TranslationsA11yRu a11y = _TranslationsA11yRu._(_root);
	@override String get addRecipeTitle => 'Добавить рецепт';
	@override String get editRecipeTitle => 'Редактировать рецепт';
	@override String get addRecipeName => 'Название рецепта';
	@override String get addRecipePhoto => 'URL фотографии';
	@override String get addRecipeCategory => 'Категория';
	@override String get addRecipeArea => 'Кухня (страна происхождения)';
	@override String get addRecipeInstructions => 'Инструкция';
	@override String get addRecipeIngredientsLabel => 'Ингредиенты';
	@override String get addRecipeIngredientName => 'Название';
	@override String get addRecipeIngredientNameHint => 'Сахар';
	@override String get addRecipeIngredientQty => 'Кол-во';
	@override String get addRecipeIngredientQtyShort => 'Кол.';
	@override String get addRecipeIngredientQtyHint => '100';
	@override String get addRecipeIngredientMeasure => 'Ед. изм.';
	@override String get addRecipeIngredientMeasureHint => 'г';
	@override String get addRecipeIngredientAdd => 'Добавить ингредиент';
	@override String get addRecipeIngredientRemove => 'Удалить ингредиент';
	@override String get addRecipeSubmit => 'Сохранить рецепт';
	@override String get addRecipeRequired => 'Обязательно';
	@override String get addRecipeSaving => 'Сохраняем…';
	@override String get addRecipeError => 'Не удалось сохранить рецепт. Попробуйте ещё раз.';
	@override String get addRecipeSuccess => 'Рецепт добавлен!';
	@override String get addRecipePhotoFromGallery => 'Выбрать из галереи';
	@override String get addRecipePhotoFromCamera => 'Сделать фото';
	@override String get addRecipePhotoRequired => 'Фото обязательно';
	@override String get addRecipePhotoRemove => 'Удалить фото';
	@override String get addRecipePhotoSourceTitle => 'Добавить фото';
	@override String get addRecipePhotoErrorAccessDenied => 'Доступ к фото запрещён. Разрешите доступ в настройках.';
	@override String get addRecipePhotoErrorTooLarge => 'Фото слишком большое даже после сжатия. Выберите другое.';
}

// Path: a11y
class _TranslationsA11yRu implements TranslationsA11yEn {
	_TranslationsA11yRu._(this._root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String switchLanguageTo({required Object label}) => 'Переключить язык на ${label}';
	@override String flagOf({required Object label}) => 'Флаг ${label}';
	@override String get reloadFeed => 'Обновить ленту';
	@override String get offlineReloadUnavailable => 'Нет сети. Показываем прежние рецепты.';
	@override String get reloadServerBusy => 'Сервер занят. Показываем прежние рецепты.';
	@override String get scrollToTop => 'Наверх';
	@override String get addRecipe => 'Добавить рецепт';
	@override String get addRecipePhotoPicker => 'Выбор фото рецепта';
}

/// The flat map containing all translations for locale <ru>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsRu {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'appTitle' => 'Otus Food',
			'back' => 'Назад',
			'dismiss' => 'Скрыть',
			'pwaInstallTooltip' => 'Установить как приложение',
			'pwaInstallTitle' => 'Установите Otus Food на iPhone или iPad',
			'pwaInstallSafariTitle' => 'Safari',
			'pwaInstallSafariStep1' => 'Нажмите кнопку «Поделиться» внизу экрана',
			'pwaInstallSafariStep2' => 'Прокрутите и выберите «На экран Домой»',
			'pwaInstallSafariStep3' => 'Нажмите «Добавить» в правом верхнем углу',
			'pwaInstallChromeTitle' => 'Chrome',
			'pwaInstallChromeStep1' => 'Нажмите значок «Поделиться» в адресной строке',
			'pwaInstallChromeStep2' => 'Выберите «На экран Домой»',
			'pwaInstallChromeStep3' => 'Нажмите «Добавить» для подтверждения',
			'pwaInstallGotIt' => 'Понятно',
			'shareTooltip' => 'Поделиться',
			'shareEmail' => 'Эл. почта',
			'shareCopyLink' => 'Копировать ссылку',
			'shareLinkCopied' => 'Ссылка скопирована',
			'tabRecipes' => 'Рецепты',
			'tabFridge' => 'Холодильник',
			'tabFavorites' => 'Избранное',
			'tabProfile' => 'Профиль',
			'tabComingSoon' => 'Этот раздел пока в разработке',
			'loginUsername' => 'Логин',
			'loginPassword' => 'Пароль',
			'loginButton' => 'Войти',
			'logoutButton' => 'Выйти',
			'signUp' => 'Зарегистрироваться',
			'signUpName' => 'Имя',
			'signUpEmail' => 'Email',
			'signUpPassword' => 'Пароль',
			'signUpButton' => 'Создать аккаунт',
			'signUpInvalidEmail' => 'Введите корректный email',
			'signUpPasswordTooShort' => 'Пароль должен быть не короче 4 символов',
			'signUpDuplicateUser' => 'Пользователь уже существует',
			'signUpSenderError' => 'Аккаунт создан, но письмо не отправлено',
			'signUpError' => 'Не удалось создать аккаунт. Попробуйте ещё раз.',
			'signUpSuccess' => 'Аккаунт создан. Данные отправлены на ваш email.',
			'signUpChooseLanguage' => 'Выберите язык',
			'loginInvalidCredentials' => 'Неверный логин или пароль',
			'loginSuccessAdmin' => 'Режим администратора включён',
			'loginSuccessUser' => 'Вход выполнен',
			'favoritesRegistrationRequired' => ({required Object button}) => 'Для этой функции нужна регистрация, пожалуйста нажмите кнопку ${button}',
			'forgotPassword' => 'Я забыл пароль',
			'passwordRecoveryTitle' => 'Восстановление пароля',
			'passwordRecoveryInstruction' => 'Введите 4-значный код восстановления из вашего email',
			'passwordRecoveryCodeLabel' => 'Код восстановления',
			'passwordRecoveryCodeHint' => '1234',
			'passwordRecoveryNewPassword' => 'Новый пароль',
			'passwordRecoverySubmit' => 'Подтвердить',
			'passwordRecoveryEnterEmail' => 'Сначала введите ваш email',
			'passwordRecoveryInvalidEmail' => 'Введите корректный email',
			'passwordRecoveryRequestFailed' => 'Не удалось начать восстановление пароля. Попробуйте снова.',
			'passwordRecoveryInvalidCode' => 'Введите корректный 4-значный код',
			'passwordRecoveryPasswordTooShort' => 'Пароль должен быть не короче 6 символов',
			'passwordRecoverySessionExpired' => 'Сессия восстановления истекла. Начните заново.',
			'passwordRecoverySaveFailed' => 'Не удалось сохранить новый пароль. Попробуйте снова.',
			'passwordRecoverySaved' => 'Ваш новый пароль сохранён',
			'adminDeleteTitle' => 'Удалить рецепт?',
			'adminDeleteMessage' => 'Это удалит рецепт для всех.',
			'adminDeleteAction' => 'Удалить',
			'adminEditAction' => 'Редактировать',
			'emptyList' => 'Нет рецептов',
			'loadError' => ({required Object error}) => 'Ошибка загрузки: ${error}',
			'retry' => 'Повторить',
			'offlineNotice' => 'Нет связи с сервером — показываем сохранённое.',
			'loadingTitle' => 'Готовим коллекцию рецептов',
			'loadingStage' => ({required Object category, required Object done, required Object total}) => 'Загружаем «${category}» (${done}/${total} категорий)…',
			'loadingProgress' => ({required Object loaded, required Object target}) => 'Получено ${loaded} из ${target} рецептов',
			'loadingFromCache' => 'Открываем сохранённые рецепты…',
			'emptyHint' => 'Сервер не вернул рецептов. Проверьте подключение и нажмите «Повторить».',
			'recipeTitle' => 'Рецепт',
			'ingredientsHeader' => 'Ингредиенты',
			'instructionsHeader' => 'Инструкция',
			'youtube' => 'YouTube',
			'source' => 'Источник',
			'searchHint' => 'Поиск рецепта',
			'searchClear' => 'Очистить',
			'searchNoMatches' => 'Совпадений не найдено',
			'favoritesEmpty' => 'Пока ничего не добавлено',
			'ingredientCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} ингредиент', few: '${n} ингредиента', many: '${n} ингредиентов', other: '${n} ингредиента', ), 
			'a11y.switchLanguageTo' => ({required Object label}) => 'Переключить язык на ${label}',
			'a11y.flagOf' => ({required Object label}) => 'Флаг ${label}',
			'a11y.reloadFeed' => 'Обновить ленту',
			'a11y.offlineReloadUnavailable' => 'Нет сети. Показываем прежние рецепты.',
			'a11y.reloadServerBusy' => 'Сервер занят. Показываем прежние рецепты.',
			'a11y.scrollToTop' => 'Наверх',
			'a11y.addRecipe' => 'Добавить рецепт',
			'a11y.addRecipePhotoPicker' => 'Выбор фото рецепта',
			'addRecipeTitle' => 'Добавить рецепт',
			'editRecipeTitle' => 'Редактировать рецепт',
			'addRecipeName' => 'Название рецепта',
			'addRecipePhoto' => 'URL фотографии',
			'addRecipeCategory' => 'Категория',
			'addRecipeArea' => 'Кухня (страна происхождения)',
			'addRecipeInstructions' => 'Инструкция',
			'addRecipeIngredientsLabel' => 'Ингредиенты',
			'addRecipeIngredientName' => 'Название',
			'addRecipeIngredientNameHint' => 'Сахар',
			'addRecipeIngredientQty' => 'Кол-во',
			'addRecipeIngredientQtyShort' => 'Кол.',
			'addRecipeIngredientQtyHint' => '100',
			'addRecipeIngredientMeasure' => 'Ед. изм.',
			'addRecipeIngredientMeasureHint' => 'г',
			'addRecipeIngredientAdd' => 'Добавить ингредиент',
			'addRecipeIngredientRemove' => 'Удалить ингредиент',
			'addRecipeSubmit' => 'Сохранить рецепт',
			'addRecipeRequired' => 'Обязательно',
			'addRecipeSaving' => 'Сохраняем…',
			'addRecipeError' => 'Не удалось сохранить рецепт. Попробуйте ещё раз.',
			'addRecipeSuccess' => 'Рецепт добавлен!',
			'addRecipePhotoFromGallery' => 'Выбрать из галереи',
			'addRecipePhotoFromCamera' => 'Сделать фото',
			'addRecipePhotoRequired' => 'Фото обязательно',
			'addRecipePhotoRemove' => 'Удалить фото',
			'addRecipePhotoSourceTitle' => 'Добавить фото',
			'addRecipePhotoErrorAccessDenied' => 'Доступ к фото запрещён. Разрешите доступ в настройках.',
			'addRecipePhotoErrorTooLarge' => 'Фото слишком большое даже после сжатия. Выберите другое.',
			_ => null,
		};
	}
}
