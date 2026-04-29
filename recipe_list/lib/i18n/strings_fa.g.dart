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
class TranslationsFa with BaseTranslations<AppLocale, Translations> implements Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsFa({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.fa,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <fa>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key);

	late final TranslationsFa _root = this; // ignore: unused_field

	@override 
	TranslationsFa $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsFa(meta: meta ?? this.$meta);

	// Translations
	@override String get appTitle => 'Otus Food';
	@override String get back => 'بازگشت';
	@override String get dismiss => 'بستن';
	@override String get tabRecipes => 'دستور پخت‌ها';
	@override String get tabFridge => 'یخچال';
	@override String get tabFavorites => 'مورد علاقه‌ها';
	@override String get tabProfile => 'پروفایل';
	@override String get tabComingSoon => 'این بخش به زودی فعال می‌شود';
	@override String get emptyList => 'دستور پختی یافت نشد';
	@override String loadError({required Object error}) => 'خطا در بارگذاری: ${error}';
	@override String get retry => 'تلاش مجدد';
	@override String get offlineNotice => 'بدون اتصال — نمایش دستور پخت‌های ذخیره شده.';
	@override String get loadingTitle => 'در حال آماده‌سازی مجموعه دستور پخت‌ها';
	@override String loadingStage({required Object category, required Object done, required Object total}) => 'در حال بارگذاری "${category}" (${done}/${total} دسته‌بندی)…';
	@override String loadingProgress({required Object loaded, required Object target}) => '${loaded} از ${target} دستور پخت بارگذاری شد';
	@override String get loadingFromCache => 'در حال باز کردن دستور پخت‌های ذخیره شده…';
	@override String get emptyHint => 'سرور هیچ دستور پختی برنگرداند. اتصال خود را بررسی کرده و روی "تلاش مجدد" ضربه بزنید.';
	@override String get recipeTitle => 'دستور پخت';
	@override String get ingredientsHeader => 'مواد لازم';
	@override String get instructionsHeader => 'دستورالعمل‌ها';
	@override String get youtube => 'YouTube';
	@override String get source => 'منبع';
	@override String get searchHint => 'جستجوی دستور پخت';
	@override String get searchClear => 'پاک کردن';
	@override String get searchNoMatches => 'موردی یافت نشد';
	@override String ingredientCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fa'))(n,
		one: '${n} ماده اولیه',
		other: '${n} ماده اولیه',
	);
	@override late final _TranslationsA11yFa a11y = _TranslationsA11yFa._(_root);
	@override String get addRecipeTitle => 'افزودن دستور';
	@override String get addRecipeName => 'نام دستور';
	@override String get addRecipePhoto => 'نشانی عکس';
	@override String get addRecipeCategory => 'دسته';
	@override String get addRecipeArea => 'آشپزی';
	@override String get addRecipeInstructions => 'دستور پخت';
	@override String get addRecipeIngredientsLabel => 'مواد';
	@override String get addRecipeIngredientsHelper => 'یکی در هر خط. قالب: نام | اندازه (با خط عمودی).';
	@override String get addRecipeSubmit => 'ذخیرهٔ دستور';
	@override String get addRecipeRequired => 'لازم';
	@override String get addRecipeEnglishHint => 'لطفاً به انگلیسی وارد کنید — ترجمه‌ها خودکار ساخته می‌شوند.';
	@override String get addRecipeSaving => 'در حال ذخیره…';
	@override String get addRecipeError => 'ذخیرهٔ دستور ممکن نشد. دوباره تلاش کنید.';
	@override String get addRecipeSuccess => 'دستور افزوده شد!';
}

// Path: a11y
class _TranslationsA11yFa implements TranslationsA11yEn {
	_TranslationsA11yFa._(this._root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String switchLanguageTo({required Object label}) => 'تغییر زبان به ${label}';
	@override String get reloadFeed => 'بارگذاری مجدد فهرست';
	@override String flagOf({required Object label}) => 'پرچم ${label}';
	@override String get offlineReloadUnavailable => 'آفلاین هستید. دستور های قبلی نمایش داده می‌شوند.';
	@override String get scrollToTop => 'حرکت به بالا';
	@override String get addRecipe => 'افزودن دستور';
}

/// The flat map containing all translations for locale <fa>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsFa {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'appTitle' => 'Otus Food',
			'back' => 'بازگشت',
			'dismiss' => 'بستن',
			'tabRecipes' => 'دستور پخت‌ها',
			'tabFridge' => 'یخچال',
			'tabFavorites' => 'مورد علاقه‌ها',
			'tabProfile' => 'پروفایل',
			'tabComingSoon' => 'این بخش به زودی فعال می‌شود',
			'emptyList' => 'دستور پختی یافت نشد',
			'loadError' => ({required Object error}) => 'خطا در بارگذاری: ${error}',
			'retry' => 'تلاش مجدد',
			'offlineNotice' => 'بدون اتصال — نمایش دستور پخت‌های ذخیره شده.',
			'loadingTitle' => 'در حال آماده‌سازی مجموعه دستور پخت‌ها',
			'loadingStage' => ({required Object category, required Object done, required Object total}) => 'در حال بارگذاری "${category}" (${done}/${total} دسته‌بندی)…',
			'loadingProgress' => ({required Object loaded, required Object target}) => '${loaded} از ${target} دستور پخت بارگذاری شد',
			'loadingFromCache' => 'در حال باز کردن دستور پخت‌های ذخیره شده…',
			'emptyHint' => 'سرور هیچ دستور پختی برنگرداند. اتصال خود را بررسی کرده و روی "تلاش مجدد" ضربه بزنید.',
			'recipeTitle' => 'دستور پخت',
			'ingredientsHeader' => 'مواد لازم',
			'instructionsHeader' => 'دستورالعمل‌ها',
			'youtube' => 'YouTube',
			'source' => 'منبع',
			'searchHint' => 'جستجوی دستور پخت',
			'searchClear' => 'پاک کردن',
			'searchNoMatches' => 'موردی یافت نشد',
			'ingredientCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fa'))(n, one: '${n} ماده اولیه', other: '${n} ماده اولیه', ), 
			'a11y.switchLanguageTo' => ({required Object label}) => 'تغییر زبان به ${label}',
			'a11y.reloadFeed' => 'بارگذاری مجدد فهرست',
			'a11y.flagOf' => ({required Object label}) => 'پرچم ${label}',
			'a11y.offlineReloadUnavailable' => 'آفلاین هستید. دستور های قبلی نمایش داده می‌شوند.',
			'a11y.scrollToTop' => 'حرکت به بالا',
			'a11y.addRecipe' => 'افزودن دستور',
			'addRecipeTitle' => 'افزودن دستور',
			'addRecipeName' => 'نام دستور',
			'addRecipePhoto' => 'نشانی عکس',
			'addRecipeCategory' => 'دسته',
			'addRecipeArea' => 'آشپزی',
			'addRecipeInstructions' => 'دستور پخت',
			'addRecipeIngredientsLabel' => 'مواد',
			'addRecipeIngredientsHelper' => 'یکی در هر خط. قالب: نام | اندازه (با خط عمودی).',
			'addRecipeSubmit' => 'ذخیرهٔ دستور',
			'addRecipeRequired' => 'لازم',
			'addRecipeEnglishHint' => 'لطفاً به انگلیسی وارد کنید — ترجمه‌ها خودکار ساخته می‌شوند.',
			'addRecipeSaving' => 'در حال ذخیره…',
			'addRecipeError' => 'ذخیرهٔ دستور ممکن نشد. دوباره تلاش کنید.',
			'addRecipeSuccess' => 'دستور افزوده شد!',
			_ => null,
		};
	}
}
