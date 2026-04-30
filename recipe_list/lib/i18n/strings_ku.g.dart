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
	@override String get favoritesEmpty => 'هێشتا هیچ بەدڵبووەکێک نییە';
	@override String ingredientCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ku'))(n,
		one: '${n} پێکهاتە',
		other: '${n} پێکهاتە',
	);
	@override late final _TranslationsA11yKu a11y = _TranslationsA11yKu._(_root);
	@override String get addRecipeTitle => 'Resipe zêde bike';
	@override String get editRecipeTitle => 'Resipê biguherîne';
	@override String get addRecipeName => 'Navê resipê';
	@override String get addRecipePhoto => 'URLa wêneyê';
	@override String get addRecipeCategory => 'Kategorî';
	@override String get addRecipeArea => 'Pêjgeh (welatê ji kî tê)';
	@override String get addRecipeInstructions => 'Talîmat';
	@override String get addRecipeIngredientsLabel => 'Madde';
	@override String get addRecipeIngredientName => 'Nav';
	@override String get addRecipeIngredientNameHint => 'Şekir';
	@override String get addRecipeIngredientQty => 'În.';
	@override String get addRecipeIngredientQtyShort => 'În.';
	@override String get addRecipeIngredientQtyHint => '100';
	@override String get addRecipeIngredientMeasure => 'Pîvane';
	@override String get addRecipeIngredientMeasureHint => 'g';
	@override String get addRecipeIngredientAdd => 'Madde zêde bike';
	@override String get addRecipeIngredientRemove => 'Madde rake';
	@override String get addRecipeSubmit => 'Resipê tomar bike';
	@override String get addRecipeRequired => 'Pêwîst';
	@override String get addRecipeSaving => 'Tê tomarkirin…';
	@override String get addRecipeError => 'Resipe nehate tomarkirin. Dîsa biceribîne.';
	@override String get addRecipeSuccess => 'Resipe hate zêdekirin!';
	@override String get addRecipePhotoFromGallery => 'Hilbijêre ji galeriyê';
	@override String get addRecipePhotoFromCamera => 'Wêneyê bikişîne';
	@override String get addRecipePhotoRequired => 'Wêne pêwîst e';
	@override String get addRecipePhotoRemove => 'Wêneyê rake';
	@override String get addRecipePhotoSourceTitle => 'Wêneyek lê zêde bike';
	@override String get addRecipePhotoErrorAccessDenied => 'Gihîştina wêneyan hat redkirin. Ji Mîhengan destûr bide.';
	@override String get addRecipePhotoErrorTooLarge => 'Wêne piştî perçiqandinê jî pir mezin e. Yekê din biceribîne.';
}

// Path: a11y
class _TranslationsA11yKu implements TranslationsA11yEn {
	_TranslationsA11yKu._(this._root);

	final TranslationsKu _root; // ignore: unused_field

	// Translations
	@override String switchLanguageTo({required Object label}) => 'گۆڕینی زمان بۆ ${label}';
	@override String get reloadFeed => 'نوێکردنەوەی لیست';
	@override String flagOf({required Object label}) => 'ئاڵای ${label}';
	@override String get offlineReloadUnavailable => 'دڵبوونی ئینتەرنێت نییە. رێسێپاکانی پێشوو پیشاندەدرێن.';
	@override String get scrollToTop => 'گەڕانەوە بۆ سەرەوە';
	@override String get addRecipe => 'Resipe zêde bike';
	@override String get addRecipePhotoPicker => 'Hilbijêrê wêneyê reçeteyê';
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
			'favoritesEmpty' => 'هێشتا هیچ بەدڵبووەکێک نییە',
			'ingredientCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ku'))(n, one: '${n} پێکهاتە', other: '${n} پێکهاتە', ), 
			'a11y.switchLanguageTo' => ({required Object label}) => 'گۆڕینی زمان بۆ ${label}',
			'a11y.reloadFeed' => 'نوێکردنەوەی لیست',
			'a11y.flagOf' => ({required Object label}) => 'ئاڵای ${label}',
			'a11y.offlineReloadUnavailable' => 'دڵبوونی ئینتەرنێت نییە. رێسێپاکانی پێشوو پیشاندەدرێن.',
			'a11y.scrollToTop' => 'گەڕانەوە بۆ سەرەوە',
			'a11y.addRecipe' => 'Resipe zêde bike',
			'a11y.addRecipePhotoPicker' => 'Hilbijêrê wêneyê reçeteyê',
			'addRecipeTitle' => 'Resipe zêde bike',
			'editRecipeTitle' => 'Resipê biguherîne',
			'addRecipeName' => 'Navê resipê',
			'addRecipePhoto' => 'URLa wêneyê',
			'addRecipeCategory' => 'Kategorî',
			'addRecipeArea' => 'Pêjgeh (welatê ji kî tê)',
			'addRecipeInstructions' => 'Talîmat',
			'addRecipeIngredientsLabel' => 'Madde',
			'addRecipeIngredientName' => 'Nav',
			'addRecipeIngredientNameHint' => 'Şekir',
			'addRecipeIngredientQty' => 'În.',
			'addRecipeIngredientQtyShort' => 'În.',
			'addRecipeIngredientQtyHint' => '100',
			'addRecipeIngredientMeasure' => 'Pîvane',
			'addRecipeIngredientMeasureHint' => 'g',
			'addRecipeIngredientAdd' => 'Madde zêde bike',
			'addRecipeIngredientRemove' => 'Madde rake',
			'addRecipeSubmit' => 'Resipê tomar bike',
			'addRecipeRequired' => 'Pêwîst',
			'addRecipeSaving' => 'Tê tomarkirin…',
			'addRecipeError' => 'Resipe nehate tomarkirin. Dîsa biceribîne.',
			'addRecipeSuccess' => 'Resipe hate zêdekirin!',
			'addRecipePhotoFromGallery' => 'Hilbijêre ji galeriyê',
			'addRecipePhotoFromCamera' => 'Wêneyê bikişîne',
			'addRecipePhotoRequired' => 'Wêne pêwîst e',
			'addRecipePhotoRemove' => 'Wêneyê rake',
			'addRecipePhotoSourceTitle' => 'Wêneyek lê zêde bike',
			'addRecipePhotoErrorAccessDenied' => 'Gihîştina wêneyan hat redkirin. Ji Mîhengan destûr bide.',
			'addRecipePhotoErrorTooLarge' => 'Wêne piştî perçiqandinê jî pir mezin e. Yekê din biceribîne.',
			_ => null,
		};
	}
}
