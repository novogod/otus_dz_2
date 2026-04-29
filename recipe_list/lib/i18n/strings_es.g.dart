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
	@override String get back => 'Atrás';
	@override String get dismiss => 'Descartar';
	@override String get tabRecipes => 'Recetas';
	@override String get tabFridge => 'Nevera';
	@override String get tabFavorites => 'Favoritos';
	@override String get tabProfile => 'Perfil';
	@override String get tabComingSoon => 'Esta sección estará disponible pronto';
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
	@override String ingredientCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} ingrediente',
		other: '${n} ingredientes',
	);
	@override late final _TranslationsA11yEs a11y = _TranslationsA11yEs._(_root);
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
			'back' => 'Atrás',
			'dismiss' => 'Descartar',
			'tabRecipes' => 'Recetas',
			'tabFridge' => 'Nevera',
			'tabFavorites' => 'Favoritos',
			'tabProfile' => 'Perfil',
			'tabComingSoon' => 'Esta sección estará disponible pronto',
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
			'ingredientCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} ingrediente', other: '${n} ingredientes', ), 
			'a11y.switchLanguageTo' => ({required Object label}) => 'Cambiar idioma a ${label}',
			'a11y.reloadFeed' => 'Recargar lista',
			'a11y.flagOf' => ({required Object label}) => 'Bandera de ${label}',
			'a11y.offlineReloadUnavailable' => 'Sin conexión. Mostrando recetas anteriores.',
			_ => null,
		};
	}
}
