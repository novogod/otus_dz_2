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
	@override String get tabRecipes => 'Рецепты';
	@override String get tabFridge => 'Холодильник';
	@override String get tabFavorites => 'Избранное';
	@override String get tabProfile => 'Профиль';
	@override String get tabComingSoon => 'Этот раздел пока в разработке';
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
	@override String ingredientCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} ингредиент',
		few: '${n} ингредиента',
		many: '${n} ингредиентов',
		other: '${n} ингредиента',
	);
	@override late final _TranslationsA11yRu a11y = _TranslationsA11yRu._(_root);
}

// Path: a11y
class _TranslationsA11yRu implements TranslationsA11yEn {
	_TranslationsA11yRu._(this._root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String switchLanguageTo({required Object label}) => 'Переключить язык на ${label}';
	@override String flagOf({required Object label}) => 'Флаг ${label}';
	@override String get reloadFeed => 'Обновить ленту';
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
			'tabRecipes' => 'Рецепты',
			'tabFridge' => 'Холодильник',
			'tabFavorites' => 'Избранное',
			'tabProfile' => 'Профиль',
			'tabComingSoon' => 'Этот раздел пока в разработке',
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
			'ingredientCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} ингредиент', few: '${n} ингредиента', many: '${n} ингредиентов', other: '${n} ингредиента', ), 
			'a11y.switchLanguageTo' => ({required Object label}) => 'Переключить язык на ${label}',
			'a11y.flagOf' => ({required Object label}) => 'Флаг ${label}',
			'a11y.reloadFeed' => 'Обновить ленту',
			_ => null,
		};
	}
}
