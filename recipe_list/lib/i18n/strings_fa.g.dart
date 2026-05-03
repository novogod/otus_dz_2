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
	@override String get loginUsername => 'نام کاربری';
	@override String get loginPassword => 'رمز عبور';
	@override String get loginButton => 'ورود';
	@override String get logoutButton => 'خروج';
	@override String get signUp => 'ثبت‌نام';
	@override String get signUpName => 'نام';
	@override String get signUpEmail => 'ایمیل';
	@override String get signUpPassword => 'رمز عبور';
	@override String get signUpButton => 'ایجاد حساب';
	@override String get signUpInvalidEmail => 'یک ایمیل معتبر وارد کنید';
	@override String get signUpPasswordTooShort => 'رمز عبور باید حداقل 4 کاراکتر باشد';
	@override String get signUpDuplicateUser => 'کاربر از قبل وجود دارد';
	@override String get signUpSenderError => 'حساب ساخته شد اما ارسال ایمیل ناموفق بود';
	@override String get signUpError => 'ایجاد حساب ممکن نشد. دوباره تلاش کنید.';
	@override String get signUpSuccess => 'حساب ایجاد شد. اطلاعات ورود به ایمیل شما ارسال شد.';
	@override String get loginInvalidCredentials => 'نام کاربری یا رمز عبور نادرست است';
	@override String get loginSuccessAdmin => 'حالت مدیر فعال شد';
	@override String get loginSuccessUser => 'ورود با موفقیت انجام شد';
	@override String get favoritesRegistrationRequired => 'برای این قابلیت ثبت‌نام لازم است، لطفاً روی دکمه Sign Up بزنید';
	@override String get forgotPassword => 'رمز عبورم را فراموش کرده‌ام';
	@override String get passwordRecoveryTitle => 'بازیابی رمز عبور';
	@override String get passwordRecoveryInstruction => 'کد بازیابی ۴ رقمی ارسال‌شده به ایمیل را وارد کنید';
	@override String get passwordRecoveryCodeLabel => 'کد بازیابی';
	@override String get passwordRecoveryCodeHint => '1234';
	@override String get passwordRecoveryNewPassword => 'رمز عبور جدید';
	@override String get passwordRecoverySubmit => 'ارسال';
	@override String get passwordRecoveryEnterEmail => 'ابتدا ایمیل خود را وارد کنید';
	@override String get passwordRecoveryInvalidEmail => 'یک ایمیل معتبر وارد کنید';
	@override String get passwordRecoveryRequestFailed => 'شروع بازیابی رمز عبور ممکن نشد. دوباره تلاش کنید.';
	@override String get passwordRecoveryInvalidCode => 'یک کد ۴ رقمی معتبر وارد کنید';
	@override String get passwordRecoveryPasswordTooShort => 'رمز عبور باید حداقل ۶ کاراکتر باشد';
	@override String get passwordRecoverySessionExpired => 'نشست بازیابی منقضی شده است. دوباره شروع کنید.';
	@override String get passwordRecoverySaveFailed => 'ذخیره رمز عبور جدید ممکن نشد. دوباره تلاش کنید.';
	@override String get passwordRecoverySaved => 'رمز عبور جدید شما ذخیره شد';
	@override String get adminDeleteTitle => 'حذف دستور؟';
	@override String get adminDeleteMessage => 'این کار دستور را برای همه حذف می‌کند.';
	@override String get adminDeleteAction => 'حذف';
	@override String get adminEditAction => 'ویرایش';
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
	@override String get favoritesEmpty => 'هنوز موردی به علاقه‌مندی‌ها افزوده نشده';
	@override String ingredientCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fa'))(n,
		one: '${n} ماده اولیه',
		other: '${n} ماده اولیه',
	);
	@override late final _TranslationsA11yFa a11y = _TranslationsA11yFa._(_root);
	@override String get addRecipeTitle => 'افزودن دستور';
	@override String get editRecipeTitle => 'ویرایش دستور';
	@override String get addRecipeName => 'نام دستور';
	@override String get addRecipePhoto => 'نشانی عکس';
	@override String get addRecipeCategory => 'دسته';
	@override String get addRecipeArea => 'آشپزی (کشور مبدأ)';
	@override String get addRecipeInstructions => 'دستور پخت';
	@override String get addRecipeIngredientsLabel => 'مواد';
	@override String get addRecipeIngredientName => 'نام';
	@override String get addRecipeIngredientNameHint => 'شکر';
	@override String get addRecipeIngredientQty => 'مقدار';
	@override String get addRecipeIngredientQtyShort => 'مقد.';
	@override String get addRecipeIngredientQtyHint => '100';
	@override String get addRecipeIngredientMeasure => 'واحد';
	@override String get addRecipeIngredientMeasureHint => 'گ';
	@override String get addRecipeIngredientAdd => 'افزودن ماده';
	@override String get addRecipeIngredientRemove => 'حذف ماده';
	@override String get addRecipeSubmit => 'ذخیرهٔ دستور';
	@override String get addRecipeRequired => 'لازم';
	@override String get addRecipeSaving => 'در حال ذخیره…';
	@override String get addRecipeError => 'ذخیرهٔ دستور ممکن نشد. دوباره تلاش کنید.';
	@override String get addRecipeSuccess => 'دستور افزوده شد!';
	@override String get addRecipePhotoFromGallery => 'انتخاب از گالری';
	@override String get addRecipePhotoFromCamera => 'گرفتن عکس';
	@override String get addRecipePhotoRequired => 'عکس الزامی است';
	@override String get addRecipePhotoRemove => 'حذف عکس';
	@override String get addRecipePhotoSourceTitle => 'افزودن عکس';
	@override String get addRecipePhotoErrorAccessDenied => 'دسترسی به عکس‌ها رد شد. در تنظیمات اجازه دهید.';
	@override String get addRecipePhotoErrorTooLarge => 'عکس حتی پس از فشرده‌سازی هم خیلی بزرگ است. یکی دیگر را امتحان کنید.';
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
	@override String get reloadServerBusy => 'سرور شلوغ است. دستور های قبلی نمایش داده می‌شوند.';
	@override String get scrollToTop => 'حرکت به بالا';
	@override String get addRecipe => 'افزودن دستور';
	@override String get addRecipePhotoPicker => 'انتخاب عکس دستور';
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
			'loginUsername' => 'نام کاربری',
			'loginPassword' => 'رمز عبور',
			'loginButton' => 'ورود',
			'logoutButton' => 'خروج',
			'signUp' => 'ثبت‌نام',
			'signUpName' => 'نام',
			'signUpEmail' => 'ایمیل',
			'signUpPassword' => 'رمز عبور',
			'signUpButton' => 'ایجاد حساب',
			'signUpInvalidEmail' => 'یک ایمیل معتبر وارد کنید',
			'signUpPasswordTooShort' => 'رمز عبور باید حداقل 4 کاراکتر باشد',
			'signUpDuplicateUser' => 'کاربر از قبل وجود دارد',
			'signUpSenderError' => 'حساب ساخته شد اما ارسال ایمیل ناموفق بود',
			'signUpError' => 'ایجاد حساب ممکن نشد. دوباره تلاش کنید.',
			'signUpSuccess' => 'حساب ایجاد شد. اطلاعات ورود به ایمیل شما ارسال شد.',
			'loginInvalidCredentials' => 'نام کاربری یا رمز عبور نادرست است',
			'loginSuccessAdmin' => 'حالت مدیر فعال شد',
			'loginSuccessUser' => 'ورود با موفقیت انجام شد',
			'favoritesRegistrationRequired' => 'برای این قابلیت ثبت‌نام لازم است، لطفاً روی دکمه Sign Up بزنید',
			'forgotPassword' => 'رمز عبورم را فراموش کرده‌ام',
			'passwordRecoveryTitle' => 'بازیابی رمز عبور',
			'passwordRecoveryInstruction' => 'کد بازیابی ۴ رقمی ارسال‌شده به ایمیل را وارد کنید',
			'passwordRecoveryCodeLabel' => 'کد بازیابی',
			'passwordRecoveryCodeHint' => '1234',
			'passwordRecoveryNewPassword' => 'رمز عبور جدید',
			'passwordRecoverySubmit' => 'ارسال',
			'passwordRecoveryEnterEmail' => 'ابتدا ایمیل خود را وارد کنید',
			'passwordRecoveryInvalidEmail' => 'یک ایمیل معتبر وارد کنید',
			'passwordRecoveryRequestFailed' => 'شروع بازیابی رمز عبور ممکن نشد. دوباره تلاش کنید.',
			'passwordRecoveryInvalidCode' => 'یک کد ۴ رقمی معتبر وارد کنید',
			'passwordRecoveryPasswordTooShort' => 'رمز عبور باید حداقل ۶ کاراکتر باشد',
			'passwordRecoverySessionExpired' => 'نشست بازیابی منقضی شده است. دوباره شروع کنید.',
			'passwordRecoverySaveFailed' => 'ذخیره رمز عبور جدید ممکن نشد. دوباره تلاش کنید.',
			'passwordRecoverySaved' => 'رمز عبور جدید شما ذخیره شد',
			'adminDeleteTitle' => 'حذف دستور؟',
			'adminDeleteMessage' => 'این کار دستور را برای همه حذف می‌کند.',
			'adminDeleteAction' => 'حذف',
			'adminEditAction' => 'ویرایش',
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
			'favoritesEmpty' => 'هنوز موردی به علاقه‌مندی‌ها افزوده نشده',
			'ingredientCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fa'))(n, one: '${n} ماده اولیه', other: '${n} ماده اولیه', ), 
			'a11y.switchLanguageTo' => ({required Object label}) => 'تغییر زبان به ${label}',
			'a11y.reloadFeed' => 'بارگذاری مجدد فهرست',
			'a11y.flagOf' => ({required Object label}) => 'پرچم ${label}',
			'a11y.offlineReloadUnavailable' => 'آفلاین هستید. دستور های قبلی نمایش داده می‌شوند.',
			'a11y.reloadServerBusy' => 'سرور شلوغ است. دستور های قبلی نمایش داده می‌شوند.',
			'a11y.scrollToTop' => 'حرکت به بالا',
			'a11y.addRecipe' => 'افزودن دستور',
			'a11y.addRecipePhotoPicker' => 'انتخاب عکس دستور',
			'addRecipeTitle' => 'افزودن دستور',
			'editRecipeTitle' => 'ویرایش دستور',
			'addRecipeName' => 'نام دستور',
			'addRecipePhoto' => 'نشانی عکس',
			'addRecipeCategory' => 'دسته',
			'addRecipeArea' => 'آشپزی (کشور مبدأ)',
			'addRecipeInstructions' => 'دستور پخت',
			'addRecipeIngredientsLabel' => 'مواد',
			'addRecipeIngredientName' => 'نام',
			'addRecipeIngredientNameHint' => 'شکر',
			'addRecipeIngredientQty' => 'مقدار',
			'addRecipeIngredientQtyShort' => 'مقد.',
			'addRecipeIngredientQtyHint' => '100',
			'addRecipeIngredientMeasure' => 'واحد',
			'addRecipeIngredientMeasureHint' => 'گ',
			'addRecipeIngredientAdd' => 'افزودن ماده',
			'addRecipeIngredientRemove' => 'حذف ماده',
			'addRecipeSubmit' => 'ذخیرهٔ دستور',
			'addRecipeRequired' => 'لازم',
			'addRecipeSaving' => 'در حال ذخیره…',
			'addRecipeError' => 'ذخیرهٔ دستور ممکن نشد. دوباره تلاش کنید.',
			'addRecipeSuccess' => 'دستور افزوده شد!',
			'addRecipePhotoFromGallery' => 'انتخاب از گالری',
			'addRecipePhotoFromCamera' => 'گرفتن عکس',
			'addRecipePhotoRequired' => 'عکس الزامی است',
			'addRecipePhotoRemove' => 'حذف عکس',
			'addRecipePhotoSourceTitle' => 'افزودن عکس',
			'addRecipePhotoErrorAccessDenied' => 'دسترسی به عکس‌ها رد شد. در تنظیمات اجازه دهید.',
			'addRecipePhotoErrorTooLarge' => 'عکس حتی پس از فشرده‌سازی هم خیلی بزرگ است. یکی دیگر را امتحان کنید.',
			_ => null,
		};
	}
}
