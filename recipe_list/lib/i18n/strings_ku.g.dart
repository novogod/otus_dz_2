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
class TranslationsKu with BaseTranslations<AppLocale, Translations> implements Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsKu({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ku,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ku>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key);

	late final TranslationsKu _root = this; // ignore: unused_field

	@override 
	TranslationsKu $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsKu(meta: meta ?? this.$meta);

	// Translations
	@override String get appTitle => 'Otus Food';
	@override String get back => 'گەڕانەوە';
	@override String get dismiss => 'ڕەتکردنەوە';
	@override String get tabRecipes => 'ڕێچەتەکان';
	@override String get tabFridge => 'بەفرگر';
	@override String get tabFavorites => 'دڵخوازەکان';
	@override String get tabProfile => 'پڕۆفایل';
	@override String get tabComingSoon => 'ئەم بەشە بەم زووانە بەردەست دەبێت';
	@override String get emptyList => 'هیچ ڕێچەتەیەک نییە';
	@override String loadError({required Object error}) => 'شکستی هێنا لە بارکردن: ${error}';
	@override String get retry => 'دووبارە هەوڵبدەوە';
	@override String get offlineNotice => 'هیچ پەیوەندییەک نییە — ڕێچەتە پاشەکەوتکراوەکان نیشان دەدرێن.';
	@override String get loadingTitle => 'ئامادەکردنی کۆمەڵەی ڕێچەتەکان';
	@override String loadingStage({required Object category, required Object done, required Object total}) => 'بارکردنی "${category}" (${done}/${total} پۆل)…';
	@override String loadingProgress({required Object loaded, required Object target}) => '${loaded} لە ${target} ڕێچەتە بارکرا';
	@override String get loadingFromCache => 'کردنەوەی ڕێچەتە پاشەکەوتکراوەکان…';
	@override String get emptyHint => 'سێرڤەر هیچ ڕێچەتەیەکی نەگەڕاندەوە. پەیوەندییەکەت بپشکنە و کرتە لەسەر "دووبارە هەوڵبدەوە" بکە.';
	@override String get recipeTitle => 'ڕێچەتە';
	@override String get ingredientsHeader => 'پێکهاتەکان';
	@override String get instructionsHeader => 'ڕێنماییەکان';
	@override String get youtube => 'YouTube';
	@override String get source => 'سەرچاوە';
	@override String get searchHint => 'گەڕان بەدوای ڕێچەتە';
	@override String get searchClear => 'پاککردنەوە';
	@override String get searchNoMatches => 'هیچ گونجاوێک نییە';
	@override String ingredientCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ku'))(n,
		one: '${n} پێکهاتە',
		other: '${n} پێکهاتە',
	);
	@override late final _TranslationsA11yKu a11y = _TranslationsA11yKu._(_root);
}

// Path: a11y
class _TranslationsA11yKu implements TranslationsA11yEn {
	_TranslationsA11yKu._(this._root);

	final TranslationsKu _root; // ignore: unused_field

	// Translations
	@override String switchLanguageTo({required Object label}) => 'گۆڕینی زمان بۆ ${label}';
	@override String flagOf({required Object label}) => 'ئاڵای ${label}';
}

/// The flat map containing all translations for locale <ku>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsKu {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'appTitle' => 'Otus Food',
			'back' => 'گەڕانەوە',
			'dismiss' => 'ڕەتکردنەوە',
			'tabRecipes' => 'ڕێچەتەکان',
			'tabFridge' => 'بەفرگر',
			'tabFavorites' => 'دڵخوازەکان',
			'tabProfile' => 'پڕۆفایل',
			'tabComingSoon' => 'ئەم بەشە بەم زووانە بەردەست دەبێت',
			'emptyList' => 'هیچ ڕێچەتەیەک نییە',
			'loadError' => ({required Object error}) => 'شکستی هێنا لە بارکردن: ${error}',
			'retry' => 'دووبارە هەوڵبدەوە',
			'offlineNotice' => 'هیچ پەیوەندییەک نییە — ڕێچەتە پاشەکەوتکراوەکان نیشان دەدرێن.',
			'loadingTitle' => 'ئامادەکردنی کۆمەڵەی ڕێچەتەکان',
			'loadingStage' => ({required Object category, required Object done, required Object total}) => 'بارکردنی "${category}" (${done}/${total} پۆل)…',
			'loadingProgress' => ({required Object loaded, required Object target}) => '${loaded} لە ${target} ڕێچەتە بارکرا',
			'loadingFromCache' => 'کردنەوەی ڕێچەتە پاشەکەوتکراوەکان…',
			'emptyHint' => 'سێرڤەر هیچ ڕێچەتەیەکی نەگەڕاندەوە. پەیوەندییەکەت بپشکنە و کرتە لەسەر "دووبارە هەوڵبدەوە" بکە.',
			'recipeTitle' => 'ڕێچەتە',
			'ingredientsHeader' => 'پێکهاتەکان',
			'instructionsHeader' => 'ڕێنماییەکان',
			'youtube' => 'YouTube',
			'source' => 'سەرچاوە',
			'searchHint' => 'گەڕان بەدوای ڕێچەتە',
			'searchClear' => 'پاککردنەوە',
			'searchNoMatches' => 'هیچ گونجاوێک نییە',
			'ingredientCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ku'))(n, one: '${n} پێکهاتە', other: '${n} پێکهاتە', ), 
			'a11y.switchLanguageTo' => ({required Object label}) => 'گۆڕینی زمان بۆ ${label}',
			'a11y.flagOf' => ({required Object label}) => 'ئاڵای ${label}',
			_ => null,
		};
	}
}
