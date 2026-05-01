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
class TranslationsAr with BaseTranslations<AppLocale, Translations> implements Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsAr({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ar,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ar>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key);

	late final TranslationsAr _root = this; // ignore: unused_field

	@override 
	TranslationsAr $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsAr(meta: meta ?? this.$meta);

	// Translations
	@override String get appTitle => 'Otus Food';
	@override String get back => 'رجوع';
	@override String get dismiss => 'إغلاق';
	@override String get tabRecipes => 'وصفات';
	@override String get tabFridge => 'ثلاجة';
	@override String get tabFavorites => 'المفضلة';
	@override String get tabProfile => 'الملف الشخصي';
	@override String get tabComingSoon => 'هذا القسم قادم قريباً';
	@override String get emptyList => 'لا توجد وصفات';
	@override String loadError({required Object error}) => 'فشل التحميل: ${error}';
	@override String get retry => 'إعادة المحاولة';
	@override String get offlineNotice => 'لا يوجد اتصال — يتم عرض الوصفات المخزنة مؤقتاً.';
	@override String get loadingTitle => 'جارٍ إعداد مجموعة الوصفات';
	@override String loadingStage({required Object category, required Object done, required Object total}) => 'جارٍ تحميل "${category}" (${done}/${total} فئات)…';
	@override String loadingProgress({required Object loaded, required Object target}) => 'تم تحميل ${loaded} من أصل ${target} وصفة';
	@override String get loadingFromCache => 'جارٍ فتح الوصفات المخزنة مؤقتاً…';
	@override String get emptyHint => 'لم يُرجع الخادم أي وصفات. تحقق من اتصالك وانقر على "إعادة المحاولة".';
	@override String get recipeTitle => 'وصفة';
	@override String get ingredientsHeader => 'المكونات';
	@override String get instructionsHeader => 'طريقة التحضير';
	@override String get youtube => 'YouTube';
	@override String get source => 'المصدر';
	@override String get searchHint => 'ابحث عن وصفة';
	@override String get searchClear => 'مسح';
	@override String get searchNoMatches => 'لا توجد نتائج مطابقة';
	@override String get favoritesEmpty => 'لا توجد مفضلات بعد';
	@override String ingredientCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		zero: '${n} مكون',
		one: '${n} مكون',
		two: '${n} مكونان',
		few: '${n} مكونات',
		many: '${n} مكوناً',
		other: '${n} مكون',
	);
	@override late final _TranslationsA11yAr a11y = _TranslationsA11yAr._(_root);
	@override String get addRecipeTitle => 'إضافة وصفة';
	@override String get editRecipeTitle => 'تعديل الوصفة';
	@override String get addRecipeName => 'اسم الوصفة';
	@override String get addRecipePhoto => 'رابط الصورة';
	@override String get addRecipeCategory => 'التصنيف';
	@override String get addRecipeArea => 'المطبخ (بلد المنشأ)';
	@override String get addRecipeInstructions => 'التعليمات';
	@override String get addRecipeIngredientsLabel => 'المكوّنات';
	@override String get addRecipeIngredientName => 'الاسم';
	@override String get addRecipeIngredientNameHint => 'سكر';
	@override String get addRecipeIngredientQty => 'الكمية';
	@override String get addRecipeIngredientQtyShort => 'كم.';
	@override String get addRecipeIngredientQtyHint => '100';
	@override String get addRecipeIngredientMeasure => 'الوحدة';
	@override String get addRecipeIngredientMeasureHint => 'غ';
	@override String get addRecipeIngredientAdd => 'إضافة مكوّن';
	@override String get addRecipeIngredientRemove => 'حذف المكوّن';
	@override String get addRecipeSubmit => 'حفظ الوصفة';
	@override String get addRecipeRequired => 'مطلوب';
	@override String get addRecipeSaving => 'جارٍ الحفظ…';
	@override String get addRecipeError => 'تعذّر حفظ الوصفة. حاول مرة أخرى.';
	@override String get addRecipeSuccess => 'تمت إضافة الوصفة!';
	@override String get addRecipePhotoFromGallery => 'اختر من المعرض';
	@override String get addRecipePhotoFromCamera => 'التقاط صورة';
	@override String get addRecipePhotoRequired => 'الصورة مطلوبة';
	@override String get addRecipePhotoRemove => 'إزالة الصورة';
	@override String get addRecipePhotoSourceTitle => 'أضف صورة';
	@override String get addRecipePhotoErrorAccessDenied => 'تم رفض الوصول إلى الصور. اسمح بالوصول من الإعدادات.';
	@override String get addRecipePhotoErrorTooLarge => 'الصورة كبيرة جدًا حتى بعد الضغط. جرّب صورة أخرى.';
}

// Path: a11y
class _TranslationsA11yAr implements TranslationsA11yEn {
	_TranslationsA11yAr._(this._root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String switchLanguageTo({required Object label}) => 'تغيير اللغة إلى ${label}';
	@override String get reloadFeed => 'إعادة تحميل القائمة';
	@override String flagOf({required Object label}) => 'علم ${label}';
	@override String get offlineReloadUnavailable => 'أنت غير متصل بالإنترنت. عرض الوصفات السابقة.';
	@override String get reloadServerBusy => 'الخادم مشغول. عرض الوصفات السابقة.';
	@override String get scrollToTop => 'التمرير إلى الأعلى';
	@override String get addRecipe => 'إضافة وصفة';
	@override String get addRecipePhotoPicker => 'اختيار صورة الوصفة';
}

/// The flat map containing all translations for locale <ar>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsAr {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'appTitle' => 'Otus Food',
			'back' => 'رجوع',
			'dismiss' => 'إغلاق',
			'tabRecipes' => 'وصفات',
			'tabFridge' => 'ثلاجة',
			'tabFavorites' => 'المفضلة',
			'tabProfile' => 'الملف الشخصي',
			'tabComingSoon' => 'هذا القسم قادم قريباً',
			'emptyList' => 'لا توجد وصفات',
			'loadError' => ({required Object error}) => 'فشل التحميل: ${error}',
			'retry' => 'إعادة المحاولة',
			'offlineNotice' => 'لا يوجد اتصال — يتم عرض الوصفات المخزنة مؤقتاً.',
			'loadingTitle' => 'جارٍ إعداد مجموعة الوصفات',
			'loadingStage' => ({required Object category, required Object done, required Object total}) => 'جارٍ تحميل "${category}" (${done}/${total} فئات)…',
			'loadingProgress' => ({required Object loaded, required Object target}) => 'تم تحميل ${loaded} من أصل ${target} وصفة',
			'loadingFromCache' => 'جارٍ فتح الوصفات المخزنة مؤقتاً…',
			'emptyHint' => 'لم يُرجع الخادم أي وصفات. تحقق من اتصالك وانقر على "إعادة المحاولة".',
			'recipeTitle' => 'وصفة',
			'ingredientsHeader' => 'المكونات',
			'instructionsHeader' => 'طريقة التحضير',
			'youtube' => 'YouTube',
			'source' => 'المصدر',
			'searchHint' => 'ابحث عن وصفة',
			'searchClear' => 'مسح',
			'searchNoMatches' => 'لا توجد نتائج مطابقة',
			'favoritesEmpty' => 'لا توجد مفضلات بعد',
			'ingredientCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, zero: '${n} مكون', one: '${n} مكون', two: '${n} مكونان', few: '${n} مكونات', many: '${n} مكوناً', other: '${n} مكون', ), 
			'a11y.switchLanguageTo' => ({required Object label}) => 'تغيير اللغة إلى ${label}',
			'a11y.reloadFeed' => 'إعادة تحميل القائمة',
			'a11y.flagOf' => ({required Object label}) => 'علم ${label}',
			'a11y.offlineReloadUnavailable' => 'أنت غير متصل بالإنترنت. عرض الوصفات السابقة.',
			'a11y.reloadServerBusy' => 'الخادم مشغول. عرض الوصفات السابقة.',
			'a11y.scrollToTop' => 'التمرير إلى الأعلى',
			'a11y.addRecipe' => 'إضافة وصفة',
			'a11y.addRecipePhotoPicker' => 'اختيار صورة الوصفة',
			'addRecipeTitle' => 'إضافة وصفة',
			'editRecipeTitle' => 'تعديل الوصفة',
			'addRecipeName' => 'اسم الوصفة',
			'addRecipePhoto' => 'رابط الصورة',
			'addRecipeCategory' => 'التصنيف',
			'addRecipeArea' => 'المطبخ (بلد المنشأ)',
			'addRecipeInstructions' => 'التعليمات',
			'addRecipeIngredientsLabel' => 'المكوّنات',
			'addRecipeIngredientName' => 'الاسم',
			'addRecipeIngredientNameHint' => 'سكر',
			'addRecipeIngredientQty' => 'الكمية',
			'addRecipeIngredientQtyShort' => 'كم.',
			'addRecipeIngredientQtyHint' => '100',
			'addRecipeIngredientMeasure' => 'الوحدة',
			'addRecipeIngredientMeasureHint' => 'غ',
			'addRecipeIngredientAdd' => 'إضافة مكوّن',
			'addRecipeIngredientRemove' => 'حذف المكوّن',
			'addRecipeSubmit' => 'حفظ الوصفة',
			'addRecipeRequired' => 'مطلوب',
			'addRecipeSaving' => 'جارٍ الحفظ…',
			'addRecipeError' => 'تعذّر حفظ الوصفة. حاول مرة أخرى.',
			'addRecipeSuccess' => 'تمت إضافة الوصفة!',
			'addRecipePhotoFromGallery' => 'اختر من المعرض',
			'addRecipePhotoFromCamera' => 'التقاط صورة',
			'addRecipePhotoRequired' => 'الصورة مطلوبة',
			'addRecipePhotoRemove' => 'إزالة الصورة',
			'addRecipePhotoSourceTitle' => 'أضف صورة',
			'addRecipePhotoErrorAccessDenied' => 'تم رفض الوصول إلى الصور. اسمح بالوصول من الإعدادات.',
			'addRecipePhotoErrorTooLarge' => 'الصورة كبيرة جدًا حتى بعد الضغط. جرّب صورة أخرى.',
			_ => null,
		};
	}
}
