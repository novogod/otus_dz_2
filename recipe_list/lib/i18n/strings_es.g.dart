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
class TranslationsEs with BaseTranslations<AppLocale, Translations> implements Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsEs({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.es,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <es>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key);

	late final TranslationsEs _root = this; // ignore: unused_field

	@override 
	TranslationsEs $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsEs(meta: meta ?? this.$meta);

	// Translations
	@override String get appTitle => 'Otus Food';
	@override String get pwaInstallTooltip => 'Instalar como aplicación';
	@override String get pwaInstallTitle => 'Instala Otus Food en tu iPhone o iPad';
	@override String get pwaInstallSafariTitle => 'Safari';
	@override String get pwaInstallSafariStep1 => 'Pulsa el botón Compartir en la parte inferior de la pantalla';
	@override String get pwaInstallSafariStep2 => 'Desplázate y pulsa «Añadir a pantalla de inicio»';
	@override String get pwaInstallSafariStep3 => 'Pulsa «Añadir» en la esquina superior derecha';
	@override String get pwaInstallChromeTitle => 'Chrome';
	@override String get pwaInstallChromeStep1 => 'Pulsa el icono Compartir en la barra de direcciones';
	@override String get pwaInstallChromeStep2 => 'Pulsa «Añadir a pantalla de inicio»';
	@override String get pwaInstallChromeStep3 => 'Pulsa «Añadir» para confirmar';
	@override String get pwaInstallGotIt => 'Entendido';
	@override String get shareTooltip => 'Compartir';
	@override String get shareEmail => 'Correo';
	@override String get shareCopyLink => 'Copiar enlace';
	@override String get shareLinkCopied => 'Enlace copiado al portapapeles';
	@override String get back => 'Atrás';
	@override String get dismiss => 'Descartar';
	@override String get tabRecipes => 'Recetas';
	@override String get tabFridge => 'Nevera';
	@override String get tabFavorites => 'Favoritos';
	@override String get tabProfile => 'Perfil';
	@override String get tabComingSoon => 'Esta sección estará disponible pronto';
	@override String get loginUsername => 'Usuario';
	@override String get loginPassword => 'Contraseña';
	@override String get loginButton => 'Iniciar sesión';
	@override String get logoutButton => 'Cerrar sesión';
	@override String get signUp => 'Registrarse';
	@override String get signUpName => 'Nombre';
	@override String get signUpEmail => 'Correo';
	@override String get signUpPassword => 'Contraseña';
	@override String get signUpButton => 'Crear cuenta';
	@override String get signUpInvalidEmail => 'Introduce un correo válido';
	@override String get signUpPasswordTooShort => 'La contraseña debe tener al menos 4 caracteres';
	@override String get signUpDuplicateUser => 'El usuario ya existe';
	@override String get signUpSenderError => 'Cuenta creada, pero no se pudo enviar el correo';
	@override String get signUpError => 'No se pudo crear la cuenta. Inténtalo de nuevo.';
	@override String get signUpSuccess => 'Cuenta creada. Las credenciales se enviaron a tu correo.';
	@override String get signUpChooseLanguage => 'Elige tu idioma';
	@override String get loginInvalidCredentials => 'Usuario o contraseña incorrectos';
	@override String get loginSuccessAdmin => 'Modo administrador activado';
	@override String get loginSuccessUser => 'Sesión iniciada correctamente';
	@override String favoritesRegistrationRequired({required Object button}) => 'Se requiere registro para esta función; por favor, pulse el botón ${button}';
	@override String get forgotPassword => 'Olvidé mi contraseña';
	@override String get passwordRecoveryTitle => 'Recuperación de contraseña';
	@override String get passwordRecoveryInstruction => 'Introduce el código de recuperación de 4 dígitos enviado a tu correo';
	@override String get passwordRecoveryCodeLabel => 'Código de recuperación';
	@override String get passwordRecoveryCodeHint => '1234';
	@override String get passwordRecoveryNewPassword => 'Nueva contraseña';
	@override String get passwordRecoverySubmit => 'Enviar';
	@override String get passwordRecoveryEnterEmail => 'Primero introduce tu correo';
	@override String get passwordRecoveryInvalidEmail => 'Introduce un correo válido';
	@override String get passwordRecoveryRequestFailed => 'No se pudo iniciar la recuperación de contraseña. Inténtalo de nuevo.';
	@override String get passwordRecoveryInvalidCode => 'Introduce un código válido de 4 dígitos';
	@override String get passwordRecoveryPasswordTooShort => 'La contraseña debe tener al menos 6 caracteres';
	@override String get passwordRecoverySessionExpired => 'La sesión de recuperación expiró. Inicia el proceso de nuevo.';
	@override String get passwordRecoverySaveFailed => 'No se pudo guardar la nueva contraseña. Inténtalo de nuevo.';
	@override String get passwordRecoverySaved => 'Tu nueva contraseña se ha guardado';
	@override String get adminDeleteTitle => '¿Eliminar receta?';
	@override String get adminDeleteMessage => 'Esto eliminará la receta para todos.';
	@override String get adminDeleteAction => 'Eliminar';
	@override String get adminEditAction => 'Editar';
	@override String get emptyList => 'No hay recetas';
	@override String loadError({required Object error}) => 'Error al cargar: ${error}';
	@override String get retry => 'Reintentar';
	@override String get offlineNotice => 'Sin conexión — mostrando recetas en caché.';
	@override String get loadingTitle => 'Preparando colección de recetas';
	@override String loadingStage({required Object category, required Object done, required Object total}) => 'Cargando "${category}" (${done}/${total} categorías)…';
	@override String loadingProgress({required Object loaded, required Object target}) => 'Cargadas ${loaded} de ${target} recetas';
	@override String get loadingFromCache => 'Abriendo recetas en caché…';
	@override String get emptyHint => 'El servidor no devolvió recetas. Comprueba tu conexión y pulsa "Reintentar".';
	@override String get recipeTitle => 'Receta';
	@override String get ingredientsHeader => 'Ingredientes';
	@override String get instructionsHeader => 'Instrucciones';
	@override String get youtube => 'YouTube';
	@override String get source => 'Fuente';
	@override String get searchHint => 'Buscar receta';
	@override String get searchClear => 'Limpiar';
	@override String get searchNoMatches => 'No hay coincidencias';
	@override String get favoritesEmpty => 'Aún no hay favoritos';
	@override String get recipeAddedByPrefix => 'por';
	@override String get recipeRateTooltip => 'Toca una estrella para calificar';
	@override String recipeRatingAvg({required Object avg}) => '${avg} / 5';
	@override String recipeVotesCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} voto',
		other: '${n} votos',
	);
	@override String get recipeRatedToast => '¡Gracias por tu calificación!';
	@override String recipeAuthorRecipes({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} receta',
		other: '${n} recetas',
	);
	@override String get profileDisplayName => 'Nombre visible';
	@override String get profileLanguage => 'Idioma';
	@override String profileRecipesAdded({required Object n}) => 'Recetas añadidas: ${n}';
	@override String profileMemberSince({required Object date}) => 'Miembro desde: ${date}';
	@override String get profileEdit => 'Editar';
	@override String get profileSave => 'Guardar';
	@override String get profilePhotoFromCamera => 'Tomar foto';
	@override String get profilePhotoFromGallery => 'Elegir de la galería';
	@override String get profilePhotoRemove => 'Eliminar foto';
	@override String get profileFinishSetup => 'Finalizar configuración';
	@override String get profileAdd => 'Añadir';
	@override String get profileSkip => 'Omitir';
	@override String get profileSavedToast => 'Perfil guardado';
	@override String get profileLogout => 'Cerrar sesión';
	@override String ingredientCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} ingrediente',
		other: '${n} ingredientes',
	);
	@override late final _TranslationsA11yEs a11y = _TranslationsA11yEs._(_root);
	@override String get addRecipeTitle => 'Añadir receta';
	@override String get editRecipeTitle => 'Editar receta';
	@override String get addRecipeName => 'Nombre de la receta';
	@override String get addRecipePhoto => 'URL de la foto';
	@override String get addRecipeCategory => 'Categoría';
	@override String get addRecipeArea => 'Cocina (país de origen)';
	@override String get addRecipeYoutube => 'Enlace de YouTube';
	@override String get addRecipeInstructions => 'Instrucciones';
	@override String get addRecipeIngredientsLabel => 'Ingredientes';
	@override String get addRecipeIngredientName => 'Nombre';
	@override String get addRecipeIngredientNameHint => 'Azúcar';
	@override String get addRecipeIngredientQty => 'Cant.';
	@override String get addRecipeIngredientQtyShort => 'Cant.';
	@override String get addRecipeIngredientQtyHint => '100';
	@override String get addRecipeIngredientMeasure => 'Unidad';
	@override String get addRecipeIngredientMeasureHint => 'g';
	@override String get addRecipeIngredientAdd => 'Añadir ingrediente';
	@override String get addRecipeIngredientRemove => 'Eliminar ingrediente';
	@override String get addRecipeSubmit => 'Guardar receta';
	@override String get addRecipeRequired => 'Obligatorio';
	@override String get addRecipeSaving => 'Guardando…';
	@override String get addRecipeError => 'No se pudo guardar la receta. Inténtalo de nuevo.';
	@override String get addRecipeSuccess => '¡Receta añadida!';
	@override String get addRecipePhotoFromGallery => 'Elegir de la galería';
	@override String get addRecipePhotoFromCamera => 'Hacer foto';
	@override String get addRecipePhotoRequired => 'La foto es obligatoria';
	@override String get addRecipePhotoRemove => 'Quitar foto';
	@override String get addRecipePhotoSourceTitle => 'Añadir una foto';
	@override String get addRecipePhotoErrorAccessDenied => 'Acceso a fotos denegado. Permítelo en Ajustes.';
	@override String get addRecipePhotoErrorTooLarge => 'La foto es demasiado grande incluso tras comprimirla. Prueba otra.';
}

// Path: a11y
class _TranslationsA11yEs implements TranslationsA11yEn {
	_TranslationsA11yEs._(this._root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String switchLanguageTo({required Object label}) => 'Cambiar idioma a ${label}';
	@override String get reloadFeed => 'Recargar lista';
	@override String flagOf({required Object label}) => 'Bandera de ${label}';
	@override String get offlineReloadUnavailable => 'Sin conexión. Mostrando recetas anteriores.';
	@override String get reloadServerBusy => 'Servidor ocupado. Mostrando recetas anteriores.';
	@override String get scrollToTop => 'Desplazar al inicio';
	@override String get addRecipe => 'Añadir receta';
	@override String get addRecipePhotoPicker => 'Selector de foto de receta';
}

/// The flat map containing all translations for locale <es>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsEs {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'appTitle' => 'Otus Food',
			'pwaInstallTooltip' => 'Instalar como aplicación',
			'pwaInstallTitle' => 'Instala Otus Food en tu iPhone o iPad',
			'pwaInstallSafariTitle' => 'Safari',
			'pwaInstallSafariStep1' => 'Pulsa el botón Compartir en la parte inferior de la pantalla',
			'pwaInstallSafariStep2' => 'Desplázate y pulsa «Añadir a pantalla de inicio»',
			'pwaInstallSafariStep3' => 'Pulsa «Añadir» en la esquina superior derecha',
			'pwaInstallChromeTitle' => 'Chrome',
			'pwaInstallChromeStep1' => 'Pulsa el icono Compartir en la barra de direcciones',
			'pwaInstallChromeStep2' => 'Pulsa «Añadir a pantalla de inicio»',
			'pwaInstallChromeStep3' => 'Pulsa «Añadir» para confirmar',
			'pwaInstallGotIt' => 'Entendido',
			'shareTooltip' => 'Compartir',
			'shareEmail' => 'Correo',
			'shareCopyLink' => 'Copiar enlace',
			'shareLinkCopied' => 'Enlace copiado al portapapeles',
			'back' => 'Atrás',
			'dismiss' => 'Descartar',
			'tabRecipes' => 'Recetas',
			'tabFridge' => 'Nevera',
			'tabFavorites' => 'Favoritos',
			'tabProfile' => 'Perfil',
			'tabComingSoon' => 'Esta sección estará disponible pronto',
			'loginUsername' => 'Usuario',
			'loginPassword' => 'Contraseña',
			'loginButton' => 'Iniciar sesión',
			'logoutButton' => 'Cerrar sesión',
			'signUp' => 'Registrarse',
			'signUpName' => 'Nombre',
			'signUpEmail' => 'Correo',
			'signUpPassword' => 'Contraseña',
			'signUpButton' => 'Crear cuenta',
			'signUpInvalidEmail' => 'Introduce un correo válido',
			'signUpPasswordTooShort' => 'La contraseña debe tener al menos 4 caracteres',
			'signUpDuplicateUser' => 'El usuario ya existe',
			'signUpSenderError' => 'Cuenta creada, pero no se pudo enviar el correo',
			'signUpError' => 'No se pudo crear la cuenta. Inténtalo de nuevo.',
			'signUpSuccess' => 'Cuenta creada. Las credenciales se enviaron a tu correo.',
			'signUpChooseLanguage' => 'Elige tu idioma',
			'loginInvalidCredentials' => 'Usuario o contraseña incorrectos',
			'loginSuccessAdmin' => 'Modo administrador activado',
			'loginSuccessUser' => 'Sesión iniciada correctamente',
			'favoritesRegistrationRequired' => ({required Object button}) => 'Se requiere registro para esta función; por favor, pulse el botón ${button}',
			'forgotPassword' => 'Olvidé mi contraseña',
			'passwordRecoveryTitle' => 'Recuperación de contraseña',
			'passwordRecoveryInstruction' => 'Introduce el código de recuperación de 4 dígitos enviado a tu correo',
			'passwordRecoveryCodeLabel' => 'Código de recuperación',
			'passwordRecoveryCodeHint' => '1234',
			'passwordRecoveryNewPassword' => 'Nueva contraseña',
			'passwordRecoverySubmit' => 'Enviar',
			'passwordRecoveryEnterEmail' => 'Primero introduce tu correo',
			'passwordRecoveryInvalidEmail' => 'Introduce un correo válido',
			'passwordRecoveryRequestFailed' => 'No se pudo iniciar la recuperación de contraseña. Inténtalo de nuevo.',
			'passwordRecoveryInvalidCode' => 'Introduce un código válido de 4 dígitos',
			'passwordRecoveryPasswordTooShort' => 'La contraseña debe tener al menos 6 caracteres',
			'passwordRecoverySessionExpired' => 'La sesión de recuperación expiró. Inicia el proceso de nuevo.',
			'passwordRecoverySaveFailed' => 'No se pudo guardar la nueva contraseña. Inténtalo de nuevo.',
			'passwordRecoverySaved' => 'Tu nueva contraseña se ha guardado',
			'adminDeleteTitle' => '¿Eliminar receta?',
			'adminDeleteMessage' => 'Esto eliminará la receta para todos.',
			'adminDeleteAction' => 'Eliminar',
			'adminEditAction' => 'Editar',
			'emptyList' => 'No hay recetas',
			'loadError' => ({required Object error}) => 'Error al cargar: ${error}',
			'retry' => 'Reintentar',
			'offlineNotice' => 'Sin conexión — mostrando recetas en caché.',
			'loadingTitle' => 'Preparando colección de recetas',
			'loadingStage' => ({required Object category, required Object done, required Object total}) => 'Cargando "${category}" (${done}/${total} categorías)…',
			'loadingProgress' => ({required Object loaded, required Object target}) => 'Cargadas ${loaded} de ${target} recetas',
			'loadingFromCache' => 'Abriendo recetas en caché…',
			'emptyHint' => 'El servidor no devolvió recetas. Comprueba tu conexión y pulsa "Reintentar".',
			'recipeTitle' => 'Receta',
			'ingredientsHeader' => 'Ingredientes',
			'instructionsHeader' => 'Instrucciones',
			'youtube' => 'YouTube',
			'source' => 'Fuente',
			'searchHint' => 'Buscar receta',
			'searchClear' => 'Limpiar',
			'searchNoMatches' => 'No hay coincidencias',
			'favoritesEmpty' => 'Aún no hay favoritos',
			'recipeAddedByPrefix' => 'por',
			'recipeRateTooltip' => 'Toca una estrella para calificar',
			'recipeRatingAvg' => ({required Object avg}) => '${avg} / 5',
			'recipeVotesCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} voto', other: '${n} votos', ), 
			'recipeRatedToast' => '¡Gracias por tu calificación!',
			'recipeAuthorRecipes' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} receta', other: '${n} recetas', ), 
			'profileDisplayName' => 'Nombre visible',
			'profileLanguage' => 'Idioma',
			'profileRecipesAdded' => ({required Object n}) => 'Recetas añadidas: ${n}',
			'profileMemberSince' => ({required Object date}) => 'Miembro desde: ${date}',
			'profileEdit' => 'Editar',
			'profileSave' => 'Guardar',
			'profilePhotoFromCamera' => 'Tomar foto',
			'profilePhotoFromGallery' => 'Elegir de la galería',
			'profilePhotoRemove' => 'Eliminar foto',
			'profileFinishSetup' => 'Finalizar configuración',
			'profileAdd' => 'Añadir',
			'profileSkip' => 'Omitir',
			'profileSavedToast' => 'Perfil guardado',
			'profileLogout' => 'Cerrar sesión',
			'ingredientCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} ingrediente', other: '${n} ingredientes', ), 
			'a11y.switchLanguageTo' => ({required Object label}) => 'Cambiar idioma a ${label}',
			'a11y.reloadFeed' => 'Recargar lista',
			'a11y.flagOf' => ({required Object label}) => 'Bandera de ${label}',
			'a11y.offlineReloadUnavailable' => 'Sin conexión. Mostrando recetas anteriores.',
			'a11y.reloadServerBusy' => 'Servidor ocupado. Mostrando recetas anteriores.',
			'a11y.scrollToTop' => 'Desplazar al inicio',
			'a11y.addRecipe' => 'Añadir receta',
			'a11y.addRecipePhotoPicker' => 'Selector de foto de receta',
			'addRecipeTitle' => 'Añadir receta',
			'editRecipeTitle' => 'Editar receta',
			'addRecipeName' => 'Nombre de la receta',
			'addRecipePhoto' => 'URL de la foto',
			'addRecipeCategory' => 'Categoría',
			'addRecipeArea' => 'Cocina (país de origen)',
			'addRecipeYoutube' => 'Enlace de YouTube',
			'addRecipeInstructions' => 'Instrucciones',
			'addRecipeIngredientsLabel' => 'Ingredientes',
			'addRecipeIngredientName' => 'Nombre',
			'addRecipeIngredientNameHint' => 'Azúcar',
			'addRecipeIngredientQty' => 'Cant.',
			'addRecipeIngredientQtyShort' => 'Cant.',
			'addRecipeIngredientQtyHint' => '100',
			'addRecipeIngredientMeasure' => 'Unidad',
			'addRecipeIngredientMeasureHint' => 'g',
			'addRecipeIngredientAdd' => 'Añadir ingrediente',
			'addRecipeIngredientRemove' => 'Eliminar ingrediente',
			'addRecipeSubmit' => 'Guardar receta',
			'addRecipeRequired' => 'Obligatorio',
			'addRecipeSaving' => 'Guardando…',
			'addRecipeError' => 'No se pudo guardar la receta. Inténtalo de nuevo.',
			'addRecipeSuccess' => '¡Receta añadida!',
			'addRecipePhotoFromGallery' => 'Elegir de la galería',
			'addRecipePhotoFromCamera' => 'Hacer foto',
			'addRecipePhotoRequired' => 'La foto es obligatoria',
			'addRecipePhotoRemove' => 'Quitar foto',
			'addRecipePhotoSourceTitle' => 'Añadir una foto',
			'addRecipePhotoErrorAccessDenied' => 'Acceso a fotos denegado. Permítelo en Ajustes.',
			'addRecipePhotoErrorTooLarge' => 'La foto es demasiado grande incluso tras comprimirla. Prueba otra.',
			_ => null,
		};
	}
}
