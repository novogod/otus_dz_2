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
class TranslationsDe with BaseTranslations<AppLocale, Translations> implements Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsDe({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.de,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <de>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key);

	late final TranslationsDe _root = this; // ignore: unused_field

	@override 
	TranslationsDe $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsDe(meta: meta ?? this.$meta);

	// Translations
	@override String get appTitle => 'Otus Food';
	@override String get back => 'Zurück';
	@override String get dismiss => 'Schließen';
	@override String get tabRecipes => 'Rezepte';
	@override String get tabFridge => 'Kühlschrank';
	@override String get tabFavorites => 'Favoriten';
	@override String get tabProfile => 'Profil';
	@override String get tabComingSoon => 'Dieser Bereich kommt bald';
	@override String get emptyList => 'Keine Rezepte';
	@override String loadError({required Object error}) => 'Laden fehlgeschlagen: ${error}';
	@override String get retry => 'Erneut versuchen';
	@override String get offlineNotice => 'Keine Verbindung – zeige zwischengespeicherte Rezepte an.';
	@override String get loadingTitle => 'Rezeptsammlung wird vorbereitet';
	@override String loadingStage({required Object category, required Object done, required Object total}) => 'Lade „${category}“ (${done}/${total} Kategorien)…';
	@override String loadingProgress({required Object loaded, required Object target}) => '${loaded} von ${target} Rezepten geladen';
	@override String get loadingFromCache => 'Öffne zwischengespeicherte Rezepte…';
	@override String get emptyHint => 'Der Server hat keine Rezepte zurückgegeben. Überprüfen Sie Ihre Verbindung und tippen Sie auf „Erneut versuchen“.';
	@override String get recipeTitle => 'Rezept';
	@override String get ingredientsHeader => 'Zutaten';
	@override String get instructionsHeader => 'Zubereitung';
	@override String get youtube => 'YouTube';
	@override String get source => 'Quelle';
	@override String get searchHint => 'Rezept suchen';
	@override String get searchClear => 'Löschen';
	@override String get searchNoMatches => 'Keine Treffer';
	@override String ingredientCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(n,
		one: '${n} Zutat',
		other: '${n} Zutaten',
	);
	@override late final _TranslationsA11yDe a11y = _TranslationsA11yDe._(_root);
	@override String get addRecipeTitle => 'Rezept hinzufügen';
	@override String get addRecipeName => 'Rezeptname';
	@override String get addRecipePhoto => 'Foto-URL';
	@override String get addRecipeCategory => 'Kategorie';
	@override String get addRecipeArea => 'Küche (Herkunftsland)';
	@override String get addRecipeInstructions => 'Anleitung';
	@override String get addRecipeIngredientsLabel => 'Zutaten';
	@override String get addRecipeIngredientName => 'Name';
	@override String get addRecipeIngredientQty => 'Menge';
	@override String get addRecipeIngredientMeasure => 'Einheit';
	@override String get addRecipeIngredientAdd => 'Zutat hinzufügen';
	@override String get addRecipeIngredientRemove => 'Zutat entfernen';
	@override String get addRecipeSubmit => 'Rezept speichern';
	@override String get addRecipeRequired => 'Pflichtfeld';
	@override String get addRecipeEnglishHint => 'Bitte auf Englisch eingeben — Übersetzungen werden automatisch erstellt.';
	@override String get addRecipeSaving => 'Speichert…';
	@override String get addRecipeError => 'Rezept konnte nicht gespeichert werden. Versuche es erneut.';
	@override String get addRecipeSuccess => 'Rezept hinzugefügt!';
}

// Path: a11y
class _TranslationsA11yDe implements TranslationsA11yEn {
	_TranslationsA11yDe._(this._root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String switchLanguageTo({required Object label}) => 'Sprache wechseln zu ${label}';
	@override String get reloadFeed => 'Liste aktualisieren';
	@override String flagOf({required Object label}) => 'Flagge von ${label}';
	@override String get offlineReloadUnavailable => 'Offline. Vorherige Rezepte werden angezeigt.';
	@override String get scrollToTop => 'Nach oben scrollen';
	@override String get addRecipe => 'Rezept hinzufügen';
}

/// The flat map containing all translations for locale <de>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsDe {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'appTitle' => 'Otus Food',
			'back' => 'Zurück',
			'dismiss' => 'Schließen',
			'tabRecipes' => 'Rezepte',
			'tabFridge' => 'Kühlschrank',
			'tabFavorites' => 'Favoriten',
			'tabProfile' => 'Profil',
			'tabComingSoon' => 'Dieser Bereich kommt bald',
			'emptyList' => 'Keine Rezepte',
			'loadError' => ({required Object error}) => 'Laden fehlgeschlagen: ${error}',
			'retry' => 'Erneut versuchen',
			'offlineNotice' => 'Keine Verbindung – zeige zwischengespeicherte Rezepte an.',
			'loadingTitle' => 'Rezeptsammlung wird vorbereitet',
			'loadingStage' => ({required Object category, required Object done, required Object total}) => 'Lade „${category}“ (${done}/${total} Kategorien)…',
			'loadingProgress' => ({required Object loaded, required Object target}) => '${loaded} von ${target} Rezepten geladen',
			'loadingFromCache' => 'Öffne zwischengespeicherte Rezepte…',
			'emptyHint' => 'Der Server hat keine Rezepte zurückgegeben. Überprüfen Sie Ihre Verbindung und tippen Sie auf „Erneut versuchen“.',
			'recipeTitle' => 'Rezept',
			'ingredientsHeader' => 'Zutaten',
			'instructionsHeader' => 'Zubereitung',
			'youtube' => 'YouTube',
			'source' => 'Quelle',
			'searchHint' => 'Rezept suchen',
			'searchClear' => 'Löschen',
			'searchNoMatches' => 'Keine Treffer',
			'ingredientCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(n, one: '${n} Zutat', other: '${n} Zutaten', ), 
			'a11y.switchLanguageTo' => ({required Object label}) => 'Sprache wechseln zu ${label}',
			'a11y.reloadFeed' => 'Liste aktualisieren',
			'a11y.flagOf' => ({required Object label}) => 'Flagge von ${label}',
			'a11y.offlineReloadUnavailable' => 'Offline. Vorherige Rezepte werden angezeigt.',
			'a11y.scrollToTop' => 'Nach oben scrollen',
			'a11y.addRecipe' => 'Rezept hinzufügen',
			'addRecipeTitle' => 'Rezept hinzufügen',
			'addRecipeName' => 'Rezeptname',
			'addRecipePhoto' => 'Foto-URL',
			'addRecipeCategory' => 'Kategorie',
			'addRecipeArea' => 'Küche (Herkunftsland)',
			'addRecipeInstructions' => 'Anleitung',
			'addRecipeIngredientsLabel' => 'Zutaten',
			'addRecipeIngredientName' => 'Name',
			'addRecipeIngredientQty' => 'Menge',
			'addRecipeIngredientMeasure' => 'Einheit',
			'addRecipeIngredientAdd' => 'Zutat hinzufügen',
			'addRecipeIngredientRemove' => 'Zutat entfernen',
			'addRecipeSubmit' => 'Rezept speichern',
			'addRecipeRequired' => 'Pflichtfeld',
			'addRecipeEnglishHint' => 'Bitte auf Englisch eingeben — Übersetzungen werden automatisch erstellt.',
			'addRecipeSaving' => 'Speichert…',
			'addRecipeError' => 'Rezept konnte nicht gespeichert werden. Versuche es erneut.',
			'addRecipeSuccess' => 'Rezept hinzugefügt!',
			_ => null,
		};
	}
}
