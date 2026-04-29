///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations

	/// en: 'Otus Food'
	String get appTitle => 'Otus Food';

	/// en: 'Back'
	String get back => 'Back';

	/// en: 'Dismiss'
	String get dismiss => 'Dismiss';

	/// en: 'Recipes'
	String get tabRecipes => 'Recipes';

	/// en: 'Fridge'
	String get tabFridge => 'Fridge';

	/// en: 'Favorites'
	String get tabFavorites => 'Favorites';

	/// en: 'Profile'
	String get tabProfile => 'Profile';

	/// en: 'This section is coming soon'
	String get tabComingSoon => 'This section is coming soon';

	/// en: 'No recipes'
	String get emptyList => 'No recipes';

	/// en: 'Failed to load: ${error}'
	String loadError({required Object error}) => 'Failed to load: ${error}';

	/// en: 'Retry'
	String get retry => 'Retry';

	/// en: 'No connection — showing cached recipes.'
	String get offlineNotice => 'No connection — showing cached recipes.';

	/// en: 'Preparing recipe collection'
	String get loadingTitle => 'Preparing recipe collection';

	/// en: 'Loading "${category}" (${done}/${total} categories)…'
	String loadingStage({required Object category, required Object done, required Object total}) => 'Loading "${category}" (${done}/${total} categories)…';

	/// en: 'Loaded ${loaded} of ${target} recipes'
	String loadingProgress({required Object loaded, required Object target}) => 'Loaded ${loaded} of ${target} recipes';

	/// en: 'Opening cached recipes…'
	String get loadingFromCache => 'Opening cached recipes…';

	/// en: 'The server returned no recipes. Check your connection and tap "Retry".'
	String get emptyHint => 'The server returned no recipes. Check your connection and tap "Retry".';

	/// en: 'Recipe'
	String get recipeTitle => 'Recipe';

	/// en: 'Ingredients'
	String get ingredientsHeader => 'Ingredients';

	/// en: 'Instructions'
	String get instructionsHeader => 'Instructions';

	/// en: 'YouTube'
	String get youtube => 'YouTube';

	/// en: 'Source'
	String get source => 'Source';

	/// en: 'Search recipe'
	String get searchHint => 'Search recipe';

	/// en: 'Clear'
	String get searchClear => 'Clear';

	/// en: 'No matches'
	String get searchNoMatches => 'No matches';

	/// en: '(one) {${n} ingredient} (other) {${n} ingredients}'
	String ingredientCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} ingredient',
		other: '${n} ingredients',
	);

	late final TranslationsA11yEn a11y = TranslationsA11yEn._(_root);

	/// en: 'Add recipe'
	String get addRecipeTitle => 'Add recipe';

	/// en: 'Recipe name'
	String get addRecipeName => 'Recipe name';

	/// en: 'Photo URL'
	String get addRecipePhoto => 'Photo URL';

	/// en: 'Category'
	String get addRecipeCategory => 'Category';

	/// en: 'Area / cuisine'
	String get addRecipeArea => 'Area / cuisine';

	/// en: 'Instructions'
	String get addRecipeInstructions => 'Instructions';

	/// en: 'Ingredients (one per line: name | measure)'
	String get addRecipeIngredientsLabel => 'Ingredients (one per line: name | measure)';

	/// en: 'Save recipe'
	String get addRecipeSubmit => 'Save recipe';

	/// en: 'Required'
	String get addRecipeRequired => 'Required';

	/// en: 'Please enter in English — translations are generated automatically.'
	String get addRecipeEnglishHint => 'Please enter in English — translations are generated automatically.';

	/// en: 'Saving…'
	String get addRecipeSaving => 'Saving…';

	/// en: 'Couldn't save recipe. Try again.'
	String get addRecipeError => 'Couldn\'t save recipe. Try again.';

	/// en: 'Recipe added!'
	String get addRecipeSuccess => 'Recipe added!';
}

// Path: a11y
class TranslationsA11yEn {
	TranslationsA11yEn._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Switch language to ${label}'
	String switchLanguageTo({required Object label}) => 'Switch language to ${label}';

	/// en: '${label} flag'
	String flagOf({required Object label}) => '${label} flag';

	/// en: 'Reload feed'
	String get reloadFeed => 'Reload feed';

	/// en: 'You're offline. Showing previous recipes.'
	String get offlineReloadUnavailable => 'You\'re offline. Showing previous recipes.';

	/// en: 'Scroll to top'
	String get scrollToTop => 'Scroll to top';

	/// en: 'Add recipe'
	String get addRecipe => 'Add recipe';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'appTitle' => 'Otus Food',
			'back' => 'Back',
			'dismiss' => 'Dismiss',
			'tabRecipes' => 'Recipes',
			'tabFridge' => 'Fridge',
			'tabFavorites' => 'Favorites',
			'tabProfile' => 'Profile',
			'tabComingSoon' => 'This section is coming soon',
			'emptyList' => 'No recipes',
			'loadError' => ({required Object error}) => 'Failed to load: ${error}',
			'retry' => 'Retry',
			'offlineNotice' => 'No connection — showing cached recipes.',
			'loadingTitle' => 'Preparing recipe collection',
			'loadingStage' => ({required Object category, required Object done, required Object total}) => 'Loading "${category}" (${done}/${total} categories)…',
			'loadingProgress' => ({required Object loaded, required Object target}) => 'Loaded ${loaded} of ${target} recipes',
			'loadingFromCache' => 'Opening cached recipes…',
			'emptyHint' => 'The server returned no recipes. Check your connection and tap "Retry".',
			'recipeTitle' => 'Recipe',
			'ingredientsHeader' => 'Ingredients',
			'instructionsHeader' => 'Instructions',
			'youtube' => 'YouTube',
			'source' => 'Source',
			'searchHint' => 'Search recipe',
			'searchClear' => 'Clear',
			'searchNoMatches' => 'No matches',
			'ingredientCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} ingredient', other: '${n} ingredients', ), 
			'a11y.switchLanguageTo' => ({required Object label}) => 'Switch language to ${label}',
			'a11y.flagOf' => ({required Object label}) => '${label} flag',
			'a11y.reloadFeed' => 'Reload feed',
			'a11y.offlineReloadUnavailable' => 'You\'re offline. Showing previous recipes.',
			'a11y.scrollToTop' => 'Scroll to top',
			'a11y.addRecipe' => 'Add recipe',
			'addRecipeTitle' => 'Add recipe',
			'addRecipeName' => 'Recipe name',
			'addRecipePhoto' => 'Photo URL',
			'addRecipeCategory' => 'Category',
			'addRecipeArea' => 'Area / cuisine',
			'addRecipeInstructions' => 'Instructions',
			'addRecipeIngredientsLabel' => 'Ingredients (one per line: name | measure)',
			'addRecipeSubmit' => 'Save recipe',
			'addRecipeRequired' => 'Required',
			'addRecipeEnglishHint' => 'Please enter in English — translations are generated automatically.',
			'addRecipeSaving' => 'Saving…',
			'addRecipeError' => 'Couldn\'t save recipe. Try again.',
			'addRecipeSuccess' => 'Recipe added!',
			_ => null,
		};
	}
}
