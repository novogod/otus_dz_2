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
class TranslationsFr with BaseTranslations<AppLocale, Translations> implements Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsFr({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.fr,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <fr>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key);

	late final TranslationsFr _root = this; // ignore: unused_field

	@override 
	TranslationsFr $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsFr(meta: meta ?? this.$meta);

	// Translations
	@override String get appTitle => 'Otus Food';
	@override String get back => 'Retour';
	@override String get dismiss => 'Ignorer';
	@override String get tabRecipes => 'Recettes';
	@override String get tabFridge => 'Réfrigérateur';
	@override String get tabFavorites => 'Favoris';
	@override String get tabProfile => 'Profil';
	@override String get tabComingSoon => 'Cette section sera bientôt disponible';
	@override String get emptyList => 'Aucune recette';
	@override String loadError({required Object error}) => 'Échec du chargement : ${error}';
	@override String get retry => 'Réessayer';
	@override String get offlineNotice => 'Pas de connexion — affichage des recettes en cache.';
	@override String get loadingTitle => 'Préparation de la collection de recettes';
	@override String loadingStage({required Object category, required Object done, required Object total}) => 'Chargement de "${category}" (${done}/${total} catégories)…';
	@override String loadingProgress({required Object loaded, required Object target}) => '${loaded} recettes chargées sur ${target}';
	@override String get loadingFromCache => 'Ouverture des recettes en cache…';
	@override String get emptyHint => 'Le serveur n\'a renvoyé aucune recette. Vérifiez votre connexion et appuyez sur "Réessayer".';
	@override String get recipeTitle => 'Recette';
	@override String get ingredientsHeader => 'Ingrédients';
	@override String get instructionsHeader => 'Instructions';
	@override String get youtube => 'YouTube';
	@override String get source => 'Source';
	@override String get searchHint => 'Rechercher une recette';
	@override String get searchClear => 'Effacer';
	@override String get searchNoMatches => 'Aucun résultat';
	@override String ingredientCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(n,
		one: '${n} ingrédient',
		other: '${n} ingrédients',
	);
	@override late final _TranslationsA11yFr a11y = _TranslationsA11yFr._(_root);
	@override String get addRecipeTitle => 'Ajouter une recette';
	@override String get addRecipeName => 'Nom de la recette';
	@override String get addRecipePhoto => 'URL de la photo';
	@override String get addRecipeCategory => 'Catégorie';
	@override String get addRecipeArea => 'Cuisine (pays d’origine)';
	@override String get addRecipeInstructions => 'Instructions';
	@override String get addRecipeIngredientsLabel => 'Ingrédients';
	@override String get addRecipeIngredientName => 'Nom';
	@override String get addRecipeIngredientQty => 'Qté';
	@override String get addRecipeIngredientMeasure => 'Unité';
	@override String get addRecipeIngredientAdd => 'Ajouter un ingrédient';
	@override String get addRecipeIngredientRemove => 'Supprimer l’ingrédient';
	@override String get addRecipeSubmit => 'Enregistrer la recette';
	@override String get addRecipeRequired => 'Obligatoire';
	@override String get addRecipeEnglishHint => 'Saisissez en anglais — les traductions sont générées automatiquement.';
	@override String get addRecipeSaving => 'Enregistrement…';
	@override String get addRecipeError => 'Impossible d\'enregistrer la recette. Réessayez.';
	@override String get addRecipeSuccess => 'Recette ajoutée !';
	@override String get addRecipePhotoFromGallery => 'Choisir depuis la galerie';
	@override String get addRecipePhotoFromCamera => 'Prendre une photo';
	@override String get addRecipePhotoRequired => 'La photo est obligatoire';
	@override String get addRecipePhotoRemove => 'Supprimer la photo';
	@override String get addRecipePhotoSourceTitle => 'Ajouter une photo';
	@override String get addRecipePhotoErrorAccessDenied => 'Accès aux photos refusé. Autorisez-le dans les Réglages.';
	@override String get addRecipePhotoErrorTooLarge => 'Photo trop volumineuse même après compression. Essayez-en une autre.';
}

// Path: a11y
class _TranslationsA11yFr implements TranslationsA11yEn {
	_TranslationsA11yFr._(this._root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String switchLanguageTo({required Object label}) => 'Changer la langue pour ${label}';
	@override String get reloadFeed => 'Actualiser la liste';
	@override String flagOf({required Object label}) => 'Drapeau de ${label}';
	@override String get offlineReloadUnavailable => 'Hors ligne. Les recettes précédentes sont affichées.';
	@override String get scrollToTop => 'Revenir en haut';
	@override String get addRecipe => 'Ajouter une recette';
	@override String get addRecipePhotoPicker => 'Sélecteur de photo de recette';
}

/// The flat map containing all translations for locale <fr>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsFr {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'appTitle' => 'Otus Food',
			'back' => 'Retour',
			'dismiss' => 'Ignorer',
			'tabRecipes' => 'Recettes',
			'tabFridge' => 'Réfrigérateur',
			'tabFavorites' => 'Favoris',
			'tabProfile' => 'Profil',
			'tabComingSoon' => 'Cette section sera bientôt disponible',
			'emptyList' => 'Aucune recette',
			'loadError' => ({required Object error}) => 'Échec du chargement : ${error}',
			'retry' => 'Réessayer',
			'offlineNotice' => 'Pas de connexion — affichage des recettes en cache.',
			'loadingTitle' => 'Préparation de la collection de recettes',
			'loadingStage' => ({required Object category, required Object done, required Object total}) => 'Chargement de "${category}" (${done}/${total} catégories)…',
			'loadingProgress' => ({required Object loaded, required Object target}) => '${loaded} recettes chargées sur ${target}',
			'loadingFromCache' => 'Ouverture des recettes en cache…',
			'emptyHint' => 'Le serveur n\'a renvoyé aucune recette. Vérifiez votre connexion et appuyez sur "Réessayer".',
			'recipeTitle' => 'Recette',
			'ingredientsHeader' => 'Ingrédients',
			'instructionsHeader' => 'Instructions',
			'youtube' => 'YouTube',
			'source' => 'Source',
			'searchHint' => 'Rechercher une recette',
			'searchClear' => 'Effacer',
			'searchNoMatches' => 'Aucun résultat',
			'ingredientCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(n, one: '${n} ingrédient', other: '${n} ingrédients', ), 
			'a11y.switchLanguageTo' => ({required Object label}) => 'Changer la langue pour ${label}',
			'a11y.reloadFeed' => 'Actualiser la liste',
			'a11y.flagOf' => ({required Object label}) => 'Drapeau de ${label}',
			'a11y.offlineReloadUnavailable' => 'Hors ligne. Les recettes précédentes sont affichées.',
			'a11y.scrollToTop' => 'Revenir en haut',
			'a11y.addRecipe' => 'Ajouter une recette',
			'a11y.addRecipePhotoPicker' => 'Sélecteur de photo de recette',
			'addRecipeTitle' => 'Ajouter une recette',
			'addRecipeName' => 'Nom de la recette',
			'addRecipePhoto' => 'URL de la photo',
			'addRecipeCategory' => 'Catégorie',
			'addRecipeArea' => 'Cuisine (pays d’origine)',
			'addRecipeInstructions' => 'Instructions',
			'addRecipeIngredientsLabel' => 'Ingrédients',
			'addRecipeIngredientName' => 'Nom',
			'addRecipeIngredientQty' => 'Qté',
			'addRecipeIngredientMeasure' => 'Unité',
			'addRecipeIngredientAdd' => 'Ajouter un ingrédient',
			'addRecipeIngredientRemove' => 'Supprimer l’ingrédient',
			'addRecipeSubmit' => 'Enregistrer la recette',
			'addRecipeRequired' => 'Obligatoire',
			'addRecipeEnglishHint' => 'Saisissez en anglais — les traductions sont générées automatiquement.',
			'addRecipeSaving' => 'Enregistrement…',
			'addRecipeError' => 'Impossible d\'enregistrer la recette. Réessayez.',
			'addRecipeSuccess' => 'Recette ajoutée !',
			'addRecipePhotoFromGallery' => 'Choisir depuis la galerie',
			'addRecipePhotoFromCamera' => 'Prendre une photo',
			'addRecipePhotoRequired' => 'La photo est obligatoire',
			'addRecipePhotoRemove' => 'Supprimer la photo',
			'addRecipePhotoSourceTitle' => 'Ajouter une photo',
			'addRecipePhotoErrorAccessDenied' => 'Accès aux photos refusé. Autorisez-le dans les Réglages.',
			'addRecipePhotoErrorTooLarge' => 'Photo trop volumineuse même après compression. Essayez-en une autre.',
			_ => null,
		};
	}
}
