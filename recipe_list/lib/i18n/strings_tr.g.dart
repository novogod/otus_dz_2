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
class TranslationsTr with BaseTranslations<AppLocale, Translations> implements Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsTr({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.tr,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <tr>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key);

	late final TranslationsTr _root = this; // ignore: unused_field

	@override 
	TranslationsTr $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsTr(meta: meta ?? this.$meta);

	// Translations
	@override String get appTitle => 'Otus Food';
	@override String get back => 'Geri';
	@override String get dismiss => 'Kapat';
	@override String get tabRecipes => 'Tarifler';
	@override String get tabFridge => 'Buzdolabı';
	@override String get tabFavorites => 'Favoriler';
	@override String get tabProfile => 'Profil';
	@override String get tabComingSoon => 'Bu bölüm yakında geliyor';
	@override String get emptyList => 'Tarif yok';
	@override String loadError({required Object error}) => 'Yüklenemedi: ${error}';
	@override String get retry => 'Tekrar Dene';
	@override String get offlineNotice => 'Bağlantı yok — önbelleğe alınmış tarifler gösteriliyor.';
	@override String get loadingTitle => 'Tarif koleksiyonu hazırlanıyor';
	@override String loadingStage({required Object category, required Object done, required Object total}) => '"${category}" yükleniyor (${done}/${total} kategori)…';
	@override String loadingProgress({required Object target, required Object loaded}) => '${target} tariften ${loaded} tanesi yüklendi';
	@override String get loadingFromCache => 'Önbelleğe alınmış tarifler açılıyor…';
	@override String get emptyHint => 'Sunucu tarif döndürmedi. Bağlantınızı kontrol edin ve "Tekrar Dene"ye dokunun.';
	@override String get recipeTitle => 'Tarif';
	@override String get ingredientsHeader => 'Malzemeler';
	@override String get instructionsHeader => 'Talimatlar';
	@override String get youtube => 'YouTube';
	@override String get source => 'Kaynak';
	@override String get searchHint => 'Tarif ara';
	@override String get searchClear => 'Temizle';
	@override String get searchNoMatches => 'Eşleşme yok';
	@override String ingredientCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		one: '${n} malzeme',
		other: '${n} malzeme',
	);
	@override late final _TranslationsA11yTr a11y = _TranslationsA11yTr._(_root);
	@override String get addRecipeTitle => 'Tarif ekle';
	@override String get addRecipeName => 'Tarif adı';
	@override String get addRecipePhoto => 'Fotoğraf URL’si';
	@override String get addRecipeCategory => 'Kategori';
	@override String get addRecipeArea => 'Mutfak (köken ülke)';
	@override String get addRecipeInstructions => 'Talimatlar';
	@override String get addRecipeIngredientsLabel => 'Malzemeler';
	@override String get addRecipeIngredientName => 'Ad';
	@override String get addRecipeIngredientQty => 'Miktar';
	@override String get addRecipeIngredientMeasure => 'Birim';
	@override String get addRecipeIngredientAdd => 'Malzeme ekle';
	@override String get addRecipeIngredientRemove => 'Malzemeyi sil';
	@override String get addRecipeSubmit => 'Tarifi kaydet';
	@override String get addRecipeRequired => 'Zorunlu';
	@override String get addRecipeEnglishHint => 'Lütfen İngilizce girin — çeviriler otomatik oluşturulur.';
	@override String get addRecipeSaving => 'Kaydediliyor…';
	@override String get addRecipeError => 'Tarif kaydedilemedi. Tekrar deneyin.';
	@override String get addRecipeSuccess => 'Tarif eklendi!';
}

// Path: a11y
class _TranslationsA11yTr implements TranslationsA11yEn {
	_TranslationsA11yTr._(this._root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String switchLanguageTo({required Object label}) => 'Dili ${label} olarak değiştir';
	@override String get reloadFeed => 'Listeyi yenile';
	@override String flagOf({required Object label}) => '${label} bayrağı';
	@override String get offlineReloadUnavailable => 'Çevrimdışısınız. Önceki tarifler gösteriliyor.';
	@override String get scrollToTop => 'Yukarı kaydır';
	@override String get addRecipe => 'Tarif ekle';
}

/// The flat map containing all translations for locale <tr>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsTr {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'appTitle' => 'Otus Food',
			'back' => 'Geri',
			'dismiss' => 'Kapat',
			'tabRecipes' => 'Tarifler',
			'tabFridge' => 'Buzdolabı',
			'tabFavorites' => 'Favoriler',
			'tabProfile' => 'Profil',
			'tabComingSoon' => 'Bu bölüm yakında geliyor',
			'emptyList' => 'Tarif yok',
			'loadError' => ({required Object error}) => 'Yüklenemedi: ${error}',
			'retry' => 'Tekrar Dene',
			'offlineNotice' => 'Bağlantı yok — önbelleğe alınmış tarifler gösteriliyor.',
			'loadingTitle' => 'Tarif koleksiyonu hazırlanıyor',
			'loadingStage' => ({required Object category, required Object done, required Object total}) => '"${category}" yükleniyor (${done}/${total} kategori)…',
			'loadingProgress' => ({required Object target, required Object loaded}) => '${target} tariften ${loaded} tanesi yüklendi',
			'loadingFromCache' => 'Önbelleğe alınmış tarifler açılıyor…',
			'emptyHint' => 'Sunucu tarif döndürmedi. Bağlantınızı kontrol edin ve "Tekrar Dene"ye dokunun.',
			'recipeTitle' => 'Tarif',
			'ingredientsHeader' => 'Malzemeler',
			'instructionsHeader' => 'Talimatlar',
			'youtube' => 'YouTube',
			'source' => 'Kaynak',
			'searchHint' => 'Tarif ara',
			'searchClear' => 'Temizle',
			'searchNoMatches' => 'Eşleşme yok',
			'ingredientCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, one: '${n} malzeme', other: '${n} malzeme', ), 
			'a11y.switchLanguageTo' => ({required Object label}) => 'Dili ${label} olarak değiştir',
			'a11y.reloadFeed' => 'Listeyi yenile',
			'a11y.flagOf' => ({required Object label}) => '${label} bayrağı',
			'a11y.offlineReloadUnavailable' => 'Çevrimdışısınız. Önceki tarifler gösteriliyor.',
			'a11y.scrollToTop' => 'Yukarı kaydır',
			'a11y.addRecipe' => 'Tarif ekle',
			'addRecipeTitle' => 'Tarif ekle',
			'addRecipeName' => 'Tarif adı',
			'addRecipePhoto' => 'Fotoğraf URL’si',
			'addRecipeCategory' => 'Kategori',
			'addRecipeArea' => 'Mutfak (köken ülke)',
			'addRecipeInstructions' => 'Talimatlar',
			'addRecipeIngredientsLabel' => 'Malzemeler',
			'addRecipeIngredientName' => 'Ad',
			'addRecipeIngredientQty' => 'Miktar',
			'addRecipeIngredientMeasure' => 'Birim',
			'addRecipeIngredientAdd' => 'Malzeme ekle',
			'addRecipeIngredientRemove' => 'Malzemeyi sil',
			'addRecipeSubmit' => 'Tarifi kaydet',
			'addRecipeRequired' => 'Zorunlu',
			'addRecipeEnglishHint' => 'Lütfen İngilizce girin — çeviriler otomatik oluşturulur.',
			'addRecipeSaving' => 'Kaydediliyor…',
			'addRecipeError' => 'Tarif kaydedilemedi. Tekrar deneyin.',
			'addRecipeSuccess' => 'Tarif eklendi!',
			_ => null,
		};
	}
}
