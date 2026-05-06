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
	@override String get pwaInstallTooltip => 'تثبيت كتطبيق';
	@override String get pwaInstallTitle => 'ثبّت Otus Food على iPhone أو iPad';
	@override String get pwaInstallSafariTitle => 'Safari';
	@override String get pwaInstallSafariStep1 => 'اضغط على زر المشاركة في أسفل الشاشة';
	@override String get pwaInstallSafariStep2 => 'مرّر واضغط «إضافة إلى الشاشة الرئيسية»';
	@override String get pwaInstallSafariStep3 => 'اضغط «إضافة» في الزاوية العلوية اليمنى';
	@override String get pwaInstallChromeTitle => 'Chrome';
	@override String get pwaInstallChromeStep1 => 'اضغط على رمز المشاركة في شريط العنوان';
	@override String get pwaInstallChromeStep2 => 'اضغط «إضافة إلى الشاشة الرئيسية»';
	@override String get pwaInstallChromeStep3 => 'اضغط «إضافة» للتأكيد';
	@override String get pwaInstallGotIt => 'فهمت';
	@override String get shareTooltip => 'مشاركة';
	@override String get shareEmail => 'بريد إلكتروني';
	@override String get shareCopyLink => 'نسخ الرابط';
	@override String get shareLinkCopied => 'تم نسخ الرابط';
	@override String get back => 'رجوع';
	@override String get dismiss => 'إغلاق';
	@override String get tabRecipes => 'وصفات';
	@override String get tabFridge => 'ثلاجة';
	@override String get tabFavorites => 'المفضلة';
	@override String get tabProfile => 'الملف الشخصي';
	@override String get tabComingSoon => 'هذا القسم قادم قريباً';
	@override String get loginUsername => 'اسم المستخدم';
	@override String get loginPassword => 'كلمة المرور';
	@override String get loginButton => 'تسجيل الدخول';
	@override String get logoutButton => 'تسجيل الخروج';
	@override String get signUp => 'إنشاء حساب';
	@override String get signUpName => 'الاسم';
	@override String get signUpEmail => 'البريد الإلكتروني';
	@override String get signUpPassword => 'كلمة المرور';
	@override String get signUpButton => 'إنشاء الحساب';
	@override String get signUpInvalidEmail => 'أدخل بريدًا إلكترونيًا صالحًا';
	@override String get signUpPasswordTooShort => 'يجب أن تكون كلمة المرور 4 أحرف على الأقل';
	@override String get signUpDuplicateUser => 'المستخدم موجود بالفعل';
	@override String get signUpSenderError => 'تم إنشاء الحساب لكن تعذر إرسال البريد';
	@override String get signUpError => 'تعذر إنشاء الحساب. حاول مرة أخرى.';
	@override String get signUpSuccess => 'تم إنشاء الحساب. تم إرسال بيانات الدخول إلى بريدك.';
	@override String get signUpChooseLanguage => 'اختر لغتك';
	@override String get loginInvalidCredentials => 'اسم المستخدم أو كلمة المرور غير صحيحة';
	@override String get loginSuccessAdmin => 'تم تفعيل وضع المسؤول';
	@override String get loginSuccessUser => 'تم تسجيل الدخول بنجاح';
	@override String favoritesRegistrationRequired({required Object button}) => 'التسجيل مطلوب لهذه الميزة، يرجى الضغط على زر ${button}';
	@override String get forgotPassword => 'نسيت كلمة المرور';
	@override String get passwordRecoveryTitle => 'استعادة كلمة المرور';
	@override String get passwordRecoveryInstruction => 'أدخل رمز الاستعادة المكوّن من 4 أرقام من بريدك الإلكتروني';
	@override String get passwordRecoveryCodeLabel => 'رمز الاستعادة';
	@override String get passwordRecoveryCodeHint => '1234';
	@override String get passwordRecoveryNewPassword => 'كلمة مرور جديدة';
	@override String get passwordRecoverySubmit => 'إرسال';
	@override String get passwordRecoveryEnterEmail => 'أدخل بريدك الإلكتروني أولاً';
	@override String get passwordRecoveryInvalidEmail => 'أدخل بريدًا إلكترونيًا صالحًا';
	@override String get passwordRecoveryRequestFailed => 'تعذر بدء استعادة كلمة المرور. حاول مرة أخرى.';
	@override String get passwordRecoveryInvalidCode => 'أدخل رمزًا صالحًا مكوّنًا من 4 أرقام';
	@override String get passwordRecoveryPasswordTooShort => 'يجب أن تكون كلمة المرور 6 أحرف على الأقل';
	@override String get passwordRecoverySessionExpired => 'انتهت جلسة الاستعادة. ابدأ من جديد.';
	@override String get passwordRecoverySaveFailed => 'تعذر حفظ كلمة المرور الجديدة. حاول مرة أخرى.';
	@override String get passwordRecoverySaved => 'تم حفظ كلمة المرور الجديدة';
	@override String get adminDeleteTitle => 'حذف الوصفة؟';
	@override String get adminDeleteMessage => 'سيؤدي هذا إلى حذف الوصفة للجميع.';
	@override String get adminDeleteAction => 'حذف';
	@override String get adminEditAction => 'تعديل';
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
	@override String get recipeAddedByPrefix => 'بواسطة';
	@override String get recipeRateTooltip => 'اضغط نجمة للتقييم';
	@override String recipeRatingAvg({required Object avg}) => '${avg} / 5';
	@override String recipeVotesCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		zero: '${n} أصوات',
		one: '${n} صوت',
		two: '${n} صوتان',
		few: '${n} أصوات',
		many: '${n} صوتًا',
		other: '${n} صوت',
	);
	@override String get recipeRatedToast => 'شكرًا على تقييمك!';
	@override String recipeAuthorRecipes({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		one: '${n} وصفة',
		other: '${n} وصفات',
	);
	@override String get profileDisplayName => 'الاسم المعروض';
	@override String get profileLanguage => 'اللغة';
	@override String profileRecipesAdded({required Object n}) => 'وصفات مضافة: ${n}';
	@override String profileMemberSince({required Object date}) => 'عضو منذ: ${date}';
	@override String get profileEdit => 'تعديل';
	@override String get profileSave => 'حفظ';
	@override String get profilePhotoFromCamera => 'التقط صورة';
	@override String get profilePhotoFromGallery => 'اختر من المعرض';
	@override String get profilePhotoRemove => 'إزالة الصورة';
	@override String get profileFinishSetup => 'إكمال الإعداد';
	@override String get profileAdd => 'إضافة';
	@override String get profileSkip => 'تخطي';
	@override String get profileSavedToast => 'تم حفظ الملف الشخصي';
	@override String get profileLogout => 'تسجيل الخروج';
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
			'pwaInstallTooltip' => 'تثبيت كتطبيق',
			'pwaInstallTitle' => 'ثبّت Otus Food على iPhone أو iPad',
			'pwaInstallSafariTitle' => 'Safari',
			'pwaInstallSafariStep1' => 'اضغط على زر المشاركة في أسفل الشاشة',
			'pwaInstallSafariStep2' => 'مرّر واضغط «إضافة إلى الشاشة الرئيسية»',
			'pwaInstallSafariStep3' => 'اضغط «إضافة» في الزاوية العلوية اليمنى',
			'pwaInstallChromeTitle' => 'Chrome',
			'pwaInstallChromeStep1' => 'اضغط على رمز المشاركة في شريط العنوان',
			'pwaInstallChromeStep2' => 'اضغط «إضافة إلى الشاشة الرئيسية»',
			'pwaInstallChromeStep3' => 'اضغط «إضافة» للتأكيد',
			'pwaInstallGotIt' => 'فهمت',
			'shareTooltip' => 'مشاركة',
			'shareEmail' => 'بريد إلكتروني',
			'shareCopyLink' => 'نسخ الرابط',
			'shareLinkCopied' => 'تم نسخ الرابط',
			'back' => 'رجوع',
			'dismiss' => 'إغلاق',
			'tabRecipes' => 'وصفات',
			'tabFridge' => 'ثلاجة',
			'tabFavorites' => 'المفضلة',
			'tabProfile' => 'الملف الشخصي',
			'tabComingSoon' => 'هذا القسم قادم قريباً',
			'loginUsername' => 'اسم المستخدم',
			'loginPassword' => 'كلمة المرور',
			'loginButton' => 'تسجيل الدخول',
			'logoutButton' => 'تسجيل الخروج',
			'signUp' => 'إنشاء حساب',
			'signUpName' => 'الاسم',
			'signUpEmail' => 'البريد الإلكتروني',
			'signUpPassword' => 'كلمة المرور',
			'signUpButton' => 'إنشاء الحساب',
			'signUpInvalidEmail' => 'أدخل بريدًا إلكترونيًا صالحًا',
			'signUpPasswordTooShort' => 'يجب أن تكون كلمة المرور 4 أحرف على الأقل',
			'signUpDuplicateUser' => 'المستخدم موجود بالفعل',
			'signUpSenderError' => 'تم إنشاء الحساب لكن تعذر إرسال البريد',
			'signUpError' => 'تعذر إنشاء الحساب. حاول مرة أخرى.',
			'signUpSuccess' => 'تم إنشاء الحساب. تم إرسال بيانات الدخول إلى بريدك.',
			'signUpChooseLanguage' => 'اختر لغتك',
			'loginInvalidCredentials' => 'اسم المستخدم أو كلمة المرور غير صحيحة',
			'loginSuccessAdmin' => 'تم تفعيل وضع المسؤول',
			'loginSuccessUser' => 'تم تسجيل الدخول بنجاح',
			'favoritesRegistrationRequired' => ({required Object button}) => 'التسجيل مطلوب لهذه الميزة، يرجى الضغط على زر ${button}',
			'forgotPassword' => 'نسيت كلمة المرور',
			'passwordRecoveryTitle' => 'استعادة كلمة المرور',
			'passwordRecoveryInstruction' => 'أدخل رمز الاستعادة المكوّن من 4 أرقام من بريدك الإلكتروني',
			'passwordRecoveryCodeLabel' => 'رمز الاستعادة',
			'passwordRecoveryCodeHint' => '1234',
			'passwordRecoveryNewPassword' => 'كلمة مرور جديدة',
			'passwordRecoverySubmit' => 'إرسال',
			'passwordRecoveryEnterEmail' => 'أدخل بريدك الإلكتروني أولاً',
			'passwordRecoveryInvalidEmail' => 'أدخل بريدًا إلكترونيًا صالحًا',
			'passwordRecoveryRequestFailed' => 'تعذر بدء استعادة كلمة المرور. حاول مرة أخرى.',
			'passwordRecoveryInvalidCode' => 'أدخل رمزًا صالحًا مكوّنًا من 4 أرقام',
			'passwordRecoveryPasswordTooShort' => 'يجب أن تكون كلمة المرور 6 أحرف على الأقل',
			'passwordRecoverySessionExpired' => 'انتهت جلسة الاستعادة. ابدأ من جديد.',
			'passwordRecoverySaveFailed' => 'تعذر حفظ كلمة المرور الجديدة. حاول مرة أخرى.',
			'passwordRecoverySaved' => 'تم حفظ كلمة المرور الجديدة',
			'adminDeleteTitle' => 'حذف الوصفة؟',
			'adminDeleteMessage' => 'سيؤدي هذا إلى حذف الوصفة للجميع.',
			'adminDeleteAction' => 'حذف',
			'adminEditAction' => 'تعديل',
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
			'recipeAddedByPrefix' => 'بواسطة',
			'recipeRateTooltip' => 'اضغط نجمة للتقييم',
			'recipeRatingAvg' => ({required Object avg}) => '${avg} / 5',
			'recipeVotesCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, zero: '${n} أصوات', one: '${n} صوت', two: '${n} صوتان', few: '${n} أصوات', many: '${n} صوتًا', other: '${n} صوت', ), 
			'recipeRatedToast' => 'شكرًا على تقييمك!',
			'recipeAuthorRecipes' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, one: '${n} وصفة', other: '${n} وصفات', ), 
			'profileDisplayName' => 'الاسم المعروض',
			'profileLanguage' => 'اللغة',
			'profileRecipesAdded' => ({required Object n}) => 'وصفات مضافة: ${n}',
			'profileMemberSince' => ({required Object date}) => 'عضو منذ: ${date}',
			'profileEdit' => 'تعديل',
			'profileSave' => 'حفظ',
			'profilePhotoFromCamera' => 'التقط صورة',
			'profilePhotoFromGallery' => 'اختر من المعرض',
			'profilePhotoRemove' => 'إزالة الصورة',
			'profileFinishSetup' => 'إكمال الإعداد',
			'profileAdd' => 'إضافة',
			'profileSkip' => 'تخطي',
			'profileSavedToast' => 'تم حفظ الملف الشخصي',
			'profileLogout' => 'تسجيل الخروج',
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
