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
	@override String get loginUsername => 'Kullanıcı adı';
	@override String get loginPassword => 'Şifre';
	@override String get loginButton => 'Giriş yap';
	@override String get logoutButton => 'Çıkış yap';
	@override String get signUp => 'Kayıt ol';
	@override String get signUpName => 'İsim';
	@override String get signUpEmail => 'E-posta';
	@override String get signUpPassword => 'Şifre';
	@override String get signUpButton => 'Hesap oluştur';
	@override String get signUpInvalidEmail => 'Geçerli bir e-posta girin';
	@override String get signUpPasswordTooShort => 'Şifre en az 4 karakter olmalı';
	@override String get signUpDuplicateUser => 'Kullanıcı zaten mevcut';
	@override String get signUpSenderError => 'Hesap oluşturuldu fakat e-posta gönderilemedi';
	@override String get signUpError => 'Hesap oluşturulamadı. Tekrar deneyin.';
	@override String get signUpSuccess => 'Hesap oluşturuldu. Bilgiler e-postanıza gönderildi.';
	@override String get loginInvalidCredentials => 'Kullanıcı adı veya şifre hatalı';
	@override String get loginSuccessAdmin => 'Yönetici modu etkin';
	@override String get loginSuccessUser => 'Başarıyla giriş yapıldı';
	@override String get favoritesRegistrationRequired => 'Bu özellik için kayıt gerekiyor, lütfen Sign Up düğmesine dokunun';
	@override String get forgotPassword => 'Şifremi unuttum';
	@override String get passwordRecoveryTitle => 'Şifre kurtarma';
	@override String get passwordRecoveryInstruction => 'E-postanızdaki 4 haneli kurtarma kodunu girin';
	@override String get passwordRecoveryCodeLabel => 'Kurtarma kodu';
	@override String get passwordRecoveryCodeHint => '1234';
	@override String get passwordRecoveryNewPassword => 'Yeni şifre';
	@override String get passwordRecoverySubmit => 'Gönder';
	@override String get passwordRecoveryEnterEmail => 'Önce e-posta adresinizi girin';
	@override String get passwordRecoveryInvalidEmail => 'Geçerli bir e-posta girin';
	@override String get passwordRecoveryRequestFailed => 'Şifre kurtarma başlatılamadı. Tekrar deneyin.';
	@override String get passwordRecoveryInvalidCode => 'Geçerli 4 haneli bir kod girin';
	@override String get passwordRecoveryPasswordTooShort => 'Şifre en az 6 karakter olmalı';
	@override String get passwordRecoverySessionExpired => 'Kurtarma oturumu süresi doldu. Yeniden başlatın.';
	@override String get passwordRecoverySaveFailed => 'Yeni şifre kaydedilemedi. Tekrar deneyin.';
	@override String get passwordRecoverySaved => 'Yeni şifreniz kaydedildi';
	@override String get adminDeleteTitle => 'Tarif silinsin mi?';
	@override String get adminDeleteMessage => 'Bu işlem tarifi herkes için kaldırır.';
	@override String get adminDeleteAction => 'Sil';
	@override String get adminEditAction => 'Düzenle';
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
	@override String get favoritesEmpty => 'Henüz favori yok';
	@override String ingredientCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		one: '${n} malzeme',
		other: '${n} malzeme',
	);
	@override late final _TranslationsA11yTr a11y = _TranslationsA11yTr._(_root);
	@override String get addRecipeTitle => 'Tarif ekle';
	@override String get editRecipeTitle => 'Tarifi düzenle';
	@override String get addRecipeName => 'Tarif adı';
	@override String get addRecipePhoto => 'Fotoğraf URL’si';
	@override String get addRecipeCategory => 'Kategori';
	@override String get addRecipeArea => 'Mutfak (köken ülke)';
	@override String get addRecipeInstructions => 'Talimatlar';
	@override String get addRecipeIngredientsLabel => 'Malzemeler';
	@override String get addRecipeIngredientName => 'Ad';
	@override String get addRecipeIngredientNameHint => 'Şeker';
	@override String get addRecipeIngredientQty => 'Miktar';
	@override String get addRecipeIngredientQtyShort => 'Mik.';
	@override String get addRecipeIngredientQtyHint => '100';
	@override String get addRecipeIngredientMeasure => 'Birim';
	@override String get addRecipeIngredientMeasureHint => 'g';
	@override String get addRecipeIngredientAdd => 'Malzeme ekle';
	@override String get addRecipeIngredientRemove => 'Malzemeyi sil';
	@override String get addRecipeSubmit => 'Tarifi kaydet';
	@override String get addRecipeRequired => 'Zorunlu';
	@override String get addRecipeSaving => 'Kaydediliyor…';
	@override String get addRecipeError => 'Tarif kaydedilemedi. Tekrar deneyin.';
	@override String get addRecipeSuccess => 'Tarif eklendi!';
	@override String get addRecipePhotoFromGallery => 'Galeriden seç';
	@override String get addRecipePhotoFromCamera => 'Fotoğraf çek';
	@override String get addRecipePhotoRequired => 'Fotoğraf zorunludur';
	@override String get addRecipePhotoRemove => 'Fotoğrafı kaldır';
	@override String get addRecipePhotoSourceTitle => 'Fotoğraf ekle';
	@override String get addRecipePhotoErrorAccessDenied => 'Fotoğraflara erişim reddedildi. Ayarlardan izin verin.';
	@override String get addRecipePhotoErrorTooLarge => 'Fotoğraf sıkıştırmadan sonra bile çok büyük. Başkasını deneyin.';
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
	@override String get reloadServerBusy => 'Sunucu meşgul. Önceki tarifler gösteriliyor.';
	@override String get scrollToTop => 'Yukarı kaydır';
	@override String get addRecipe => 'Tarif ekle';
	@override String get addRecipePhotoPicker => 'Tarif fotoğraf seçici';
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
			'loginUsername' => 'Kullanıcı adı',
			'loginPassword' => 'Şifre',
			'loginButton' => 'Giriş yap',
			'logoutButton' => 'Çıkış yap',
			'signUp' => 'Kayıt ol',
			'signUpName' => 'İsim',
			'signUpEmail' => 'E-posta',
			'signUpPassword' => 'Şifre',
			'signUpButton' => 'Hesap oluştur',
			'signUpInvalidEmail' => 'Geçerli bir e-posta girin',
			'signUpPasswordTooShort' => 'Şifre en az 4 karakter olmalı',
			'signUpDuplicateUser' => 'Kullanıcı zaten mevcut',
			'signUpSenderError' => 'Hesap oluşturuldu fakat e-posta gönderilemedi',
			'signUpError' => 'Hesap oluşturulamadı. Tekrar deneyin.',
			'signUpSuccess' => 'Hesap oluşturuldu. Bilgiler e-postanıza gönderildi.',
			'loginInvalidCredentials' => 'Kullanıcı adı veya şifre hatalı',
			'loginSuccessAdmin' => 'Yönetici modu etkin',
			'loginSuccessUser' => 'Başarıyla giriş yapıldı',
			'favoritesRegistrationRequired' => 'Bu özellik için kayıt gerekiyor, lütfen Sign Up düğmesine dokunun',
			'forgotPassword' => 'Şifremi unuttum',
			'passwordRecoveryTitle' => 'Şifre kurtarma',
			'passwordRecoveryInstruction' => 'E-postanızdaki 4 haneli kurtarma kodunu girin',
			'passwordRecoveryCodeLabel' => 'Kurtarma kodu',
			'passwordRecoveryCodeHint' => '1234',
			'passwordRecoveryNewPassword' => 'Yeni şifre',
			'passwordRecoverySubmit' => 'Gönder',
			'passwordRecoveryEnterEmail' => 'Önce e-posta adresinizi girin',
			'passwordRecoveryInvalidEmail' => 'Geçerli bir e-posta girin',
			'passwordRecoveryRequestFailed' => 'Şifre kurtarma başlatılamadı. Tekrar deneyin.',
			'passwordRecoveryInvalidCode' => 'Geçerli 4 haneli bir kod girin',
			'passwordRecoveryPasswordTooShort' => 'Şifre en az 6 karakter olmalı',
			'passwordRecoverySessionExpired' => 'Kurtarma oturumu süresi doldu. Yeniden başlatın.',
			'passwordRecoverySaveFailed' => 'Yeni şifre kaydedilemedi. Tekrar deneyin.',
			'passwordRecoverySaved' => 'Yeni şifreniz kaydedildi',
			'adminDeleteTitle' => 'Tarif silinsin mi?',
			'adminDeleteMessage' => 'Bu işlem tarifi herkes için kaldırır.',
			'adminDeleteAction' => 'Sil',
			'adminEditAction' => 'Düzenle',
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
			'favoritesEmpty' => 'Henüz favori yok',
			'ingredientCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, one: '${n} malzeme', other: '${n} malzeme', ), 
			'a11y.switchLanguageTo' => ({required Object label}) => 'Dili ${label} olarak değiştir',
			'a11y.reloadFeed' => 'Listeyi yenile',
			'a11y.flagOf' => ({required Object label}) => '${label} bayrağı',
			'a11y.offlineReloadUnavailable' => 'Çevrimdışısınız. Önceki tarifler gösteriliyor.',
			'a11y.reloadServerBusy' => 'Sunucu meşgul. Önceki tarifler gösteriliyor.',
			'a11y.scrollToTop' => 'Yukarı kaydır',
			'a11y.addRecipe' => 'Tarif ekle',
			'a11y.addRecipePhotoPicker' => 'Tarif fotoğraf seçici',
			'addRecipeTitle' => 'Tarif ekle',
			'editRecipeTitle' => 'Tarifi düzenle',
			'addRecipeName' => 'Tarif adı',
			'addRecipePhoto' => 'Fotoğraf URL’si',
			'addRecipeCategory' => 'Kategori',
			'addRecipeArea' => 'Mutfak (köken ülke)',
			'addRecipeInstructions' => 'Talimatlar',
			'addRecipeIngredientsLabel' => 'Malzemeler',
			'addRecipeIngredientName' => 'Ad',
			'addRecipeIngredientNameHint' => 'Şeker',
			'addRecipeIngredientQty' => 'Miktar',
			'addRecipeIngredientQtyShort' => 'Mik.',
			'addRecipeIngredientQtyHint' => '100',
			'addRecipeIngredientMeasure' => 'Birim',
			'addRecipeIngredientMeasureHint' => 'g',
			'addRecipeIngredientAdd' => 'Malzeme ekle',
			'addRecipeIngredientRemove' => 'Malzemeyi sil',
			'addRecipeSubmit' => 'Tarifi kaydet',
			'addRecipeRequired' => 'Zorunlu',
			'addRecipeSaving' => 'Kaydediliyor…',
			'addRecipeError' => 'Tarif kaydedilemedi. Tekrar deneyin.',
			'addRecipeSuccess' => 'Tarif eklendi!',
			'addRecipePhotoFromGallery' => 'Galeriden seç',
			'addRecipePhotoFromCamera' => 'Fotoğraf çek',
			'addRecipePhotoRequired' => 'Fotoğraf zorunludur',
			'addRecipePhotoRemove' => 'Fotoğrafı kaldır',
			'addRecipePhotoSourceTitle' => 'Fotoğraf ekle',
			'addRecipePhotoErrorAccessDenied' => 'Fotoğraflara erişim reddedildi. Ayarlardan izin verin.',
			'addRecipePhotoErrorTooLarge' => 'Fotoğraf sıkıştırmadan sonra bile çok büyük. Başkasını deneyin.',
			_ => null,
		};
	}
}
