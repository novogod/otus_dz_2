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

	/// en: 'Install as app'
	String get pwaInstallTooltip => 'Install as app';

	/// en: 'Install Otus Food on your iPhone or iPad'
	String get pwaInstallTitle => 'Install Otus Food on your iPhone or iPad';

	/// en: 'Safari'
	String get pwaInstallSafariTitle => 'Safari';

	/// en: 'Tap the Share button at the bottom of the screen'
	String get pwaInstallSafariStep1 => 'Tap the Share button at the bottom of the screen';

	/// en: 'Scroll down and tap «Add to Home Screen»'
	String get pwaInstallSafariStep2 => 'Scroll down and tap «Add to Home Screen»';

	/// en: 'Tap «Add» in the top right corner'
	String get pwaInstallSafariStep3 => 'Tap «Add» in the top right corner';

	/// en: 'Chrome'
	String get pwaInstallChromeTitle => 'Chrome';

	/// en: 'Tap the Share icon in the address bar'
	String get pwaInstallChromeStep1 => 'Tap the Share icon in the address bar';

	/// en: 'Tap «Add to Home Screen»'
	String get pwaInstallChromeStep2 => 'Tap «Add to Home Screen»';

	/// en: 'Tap «Add» to confirm'
	String get pwaInstallChromeStep3 => 'Tap «Add» to confirm';

	/// en: 'Got it'
	String get pwaInstallGotIt => 'Got it';

	/// en: 'Share'
	String get shareTooltip => 'Share';

	/// en: 'Email'
	String get shareEmail => 'Email';

	/// en: 'Copy link'
	String get shareCopyLink => 'Copy link';

	/// en: 'Link copied to clipboard'
	String get shareLinkCopied => 'Link copied to clipboard';

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

	/// en: 'Login'
	String get loginUsername => 'Login';

	/// en: 'Password'
	String get loginPassword => 'Password';

	/// en: 'Log in'
	String get loginButton => 'Log in';

	/// en: 'Log out'
	String get logoutButton => 'Log out';

	/// en: 'Sign up'
	String get signUp => 'Sign up';

	/// en: 'Name'
	String get signUpName => 'Name';

	/// en: 'Email'
	String get signUpEmail => 'Email';

	/// en: 'Password'
	String get signUpPassword => 'Password';

	/// en: 'Create account'
	String get signUpButton => 'Create account';

	/// en: 'Enter a valid email address'
	String get signUpInvalidEmail => 'Enter a valid email address';

	/// en: 'Password must be at least 4 characters'
	String get signUpPasswordTooShort => 'Password must be at least 4 characters';

	/// en: 'User already exists'
	String get signUpDuplicateUser => 'User already exists';

	/// en: 'Account created, but email delivery failed'
	String get signUpSenderError => 'Account created, but email delivery failed';

	/// en: 'Couldn't create account. Try again.'
	String get signUpError => 'Couldn\'t create account. Try again.';

	/// en: 'Account created. Credentials were sent to your email.'
	String get signUpSuccess => 'Account created. Credentials were sent to your email.';

	/// en: 'Choose your language'
	String get signUpChooseLanguage => 'Choose your language';

	/// en: 'Invalid login or password'
	String get loginInvalidCredentials => 'Invalid login or password';

	/// en: 'Admin mode enabled'
	String get loginSuccessAdmin => 'Admin mode enabled';

	/// en: 'Logged in successfully'
	String get loginSuccessUser => 'Logged in successfully';

	/// en: 'Registration required for this feature, please tap ${button} button'
	String favoritesRegistrationRequired({required Object button}) => 'Registration required for this feature, please tap ${button} button';

	/// en: 'I forgot password'
	String get forgotPassword => 'I forgot password';

	/// en: 'Password recovery'
	String get passwordRecoveryTitle => 'Password recovery';

	/// en: 'Enter 4 digits recovery code from your email'
	String get passwordRecoveryInstruction => 'Enter 4 digits recovery code from your email';

	/// en: 'Recovery code'
	String get passwordRecoveryCodeLabel => 'Recovery code';

	/// en: '1234'
	String get passwordRecoveryCodeHint => '1234';

	/// en: 'New password'
	String get passwordRecoveryNewPassword => 'New password';

	/// en: 'Submit'
	String get passwordRecoverySubmit => 'Submit';

	/// en: 'Enter your email first'
	String get passwordRecoveryEnterEmail => 'Enter your email first';

	/// en: 'Enter a valid email address'
	String get passwordRecoveryInvalidEmail => 'Enter a valid email address';

	/// en: 'Couldn't start password recovery. Try again.'
	String get passwordRecoveryRequestFailed => 'Couldn\'t start password recovery. Try again.';

	/// en: 'Enter a valid 4-digit code'
	String get passwordRecoveryInvalidCode => 'Enter a valid 4-digit code';

	/// en: 'Password must be at least 6 characters'
	String get passwordRecoveryPasswordTooShort => 'Password must be at least 6 characters';

	/// en: 'Recovery session expired. Start again.'
	String get passwordRecoverySessionExpired => 'Recovery session expired. Start again.';

	/// en: 'Couldn't save new password. Try again.'
	String get passwordRecoverySaveFailed => 'Couldn\'t save new password. Try again.';

	/// en: 'Your new password is saved'
	String get passwordRecoverySaved => 'Your new password is saved';

	/// en: 'Delete recipe?'
	String get adminDeleteTitle => 'Delete recipe?';

	/// en: 'This will remove the recipe for everyone.'
	String get adminDeleteMessage => 'This will remove the recipe for everyone.';

	/// en: 'Delete'
	String get adminDeleteAction => 'Delete';

	/// en: 'Edit'
	String get adminEditAction => 'Edit';

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

	/// en: 'No favorites yet'
	String get favoritesEmpty => 'No favorites yet';

	/// en: 'by'
	String get recipeAddedByPrefix => 'by';

	/// en: '(one) {${n} recipe} (other) {${n} recipes}'
	String recipeAuthorRecipes({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} recipe',
		other: '${n} recipes',
	);

	/// en: 'Tap a star to rate'
	String get recipeRateTooltip => 'Tap a star to rate';

	/// en: '${avg} / 5'
	String recipeRatingAvg({required Object avg}) => '${avg} / 5';

	/// en: '(one) {${n} vote} (other) {${n} votes}'
	String recipeVotesCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} vote',
		other: '${n} votes',
	);

	/// en: 'Thanks for rating!'
	String get recipeRatedToast => 'Thanks for rating!';

	/// en: '(one) {${n} ingredient} (other) {${n} ingredients}'
	String ingredientCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} ingredient',
		other: '${n} ingredients',
	);

	late final TranslationsA11yEn a11y = TranslationsA11yEn._(_root);

	/// en: 'Add recipe'
	String get addRecipeTitle => 'Add recipe';

	/// en: 'Edit recipe'
	String get editRecipeTitle => 'Edit recipe';

	/// en: 'Recipe name'
	String get addRecipeName => 'Recipe name';

	/// en: 'Photo URL'
	String get addRecipePhoto => 'Photo URL';

	/// en: 'Category'
	String get addRecipeCategory => 'Category';

	/// en: 'Cuisine (country of origin)'
	String get addRecipeArea => 'Cuisine (country of origin)';

	/// en: 'Instructions'
	String get addRecipeInstructions => 'Instructions';

	/// en: 'Ingredients'
	String get addRecipeIngredientsLabel => 'Ingredients';

	/// en: 'Name'
	String get addRecipeIngredientName => 'Name';

	/// en: 'Sugar'
	String get addRecipeIngredientNameHint => 'Sugar';

	/// en: 'Qty'
	String get addRecipeIngredientQty => 'Qty';

	/// en: 'Qty'
	String get addRecipeIngredientQtyShort => 'Qty';

	/// en: '100'
	String get addRecipeIngredientQtyHint => '100';

	/// en: 'Unit'
	String get addRecipeIngredientMeasure => 'Unit';

	/// en: 'g'
	String get addRecipeIngredientMeasureHint => 'g';

	/// en: 'Add ingredient'
	String get addRecipeIngredientAdd => 'Add ingredient';

	/// en: 'Remove ingredient'
	String get addRecipeIngredientRemove => 'Remove ingredient';

	/// en: 'Save recipe'
	String get addRecipeSubmit => 'Save recipe';

	/// en: 'Required'
	String get addRecipeRequired => 'Required';

	/// en: 'Saving…'
	String get addRecipeSaving => 'Saving…';

	/// en: 'Couldn't save recipe. Try again.'
	String get addRecipeError => 'Couldn\'t save recipe. Try again.';

	/// en: 'Recipe added!'
	String get addRecipeSuccess => 'Recipe added!';

	/// en: 'Choose from gallery'
	String get addRecipePhotoFromGallery => 'Choose from gallery';

	/// en: 'Take photo'
	String get addRecipePhotoFromCamera => 'Take photo';

	/// en: 'Photo is required'
	String get addRecipePhotoRequired => 'Photo is required';

	/// en: 'Remove photo'
	String get addRecipePhotoRemove => 'Remove photo';

	/// en: 'Add a photo'
	String get addRecipePhotoSourceTitle => 'Add a photo';

	/// en: 'Access to photos denied. Allow access in Settings.'
	String get addRecipePhotoErrorAccessDenied => 'Access to photos denied. Allow access in Settings.';

	/// en: 'Photo is too large even after compression. Try another one.'
	String get addRecipePhotoErrorTooLarge => 'Photo is too large even after compression. Try another one.';
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

	/// en: 'Server is busy. Showing previous recipes.'
	String get reloadServerBusy => 'Server is busy. Showing previous recipes.';

	/// en: 'Scroll to top'
	String get scrollToTop => 'Scroll to top';

	/// en: 'Add recipe'
	String get addRecipe => 'Add recipe';

	/// en: 'Recipe photo picker'
	String get addRecipePhotoPicker => 'Recipe photo picker';
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
			'pwaInstallTooltip' => 'Install as app',
			'pwaInstallTitle' => 'Install Otus Food on your iPhone or iPad',
			'pwaInstallSafariTitle' => 'Safari',
			'pwaInstallSafariStep1' => 'Tap the Share button at the bottom of the screen',
			'pwaInstallSafariStep2' => 'Scroll down and tap «Add to Home Screen»',
			'pwaInstallSafariStep3' => 'Tap «Add» in the top right corner',
			'pwaInstallChromeTitle' => 'Chrome',
			'pwaInstallChromeStep1' => 'Tap the Share icon in the address bar',
			'pwaInstallChromeStep2' => 'Tap «Add to Home Screen»',
			'pwaInstallChromeStep3' => 'Tap «Add» to confirm',
			'pwaInstallGotIt' => 'Got it',
			'shareTooltip' => 'Share',
			'shareEmail' => 'Email',
			'shareCopyLink' => 'Copy link',
			'shareLinkCopied' => 'Link copied to clipboard',
			'tabRecipes' => 'Recipes',
			'tabFridge' => 'Fridge',
			'tabFavorites' => 'Favorites',
			'tabProfile' => 'Profile',
			'tabComingSoon' => 'This section is coming soon',
			'loginUsername' => 'Login',
			'loginPassword' => 'Password',
			'loginButton' => 'Log in',
			'logoutButton' => 'Log out',
			'signUp' => 'Sign up',
			'signUpName' => 'Name',
			'signUpEmail' => 'Email',
			'signUpPassword' => 'Password',
			'signUpButton' => 'Create account',
			'signUpInvalidEmail' => 'Enter a valid email address',
			'signUpPasswordTooShort' => 'Password must be at least 4 characters',
			'signUpDuplicateUser' => 'User already exists',
			'signUpSenderError' => 'Account created, but email delivery failed',
			'signUpError' => 'Couldn\'t create account. Try again.',
			'signUpSuccess' => 'Account created. Credentials were sent to your email.',
			'signUpChooseLanguage' => 'Choose your language',
			'loginInvalidCredentials' => 'Invalid login or password',
			'loginSuccessAdmin' => 'Admin mode enabled',
			'loginSuccessUser' => 'Logged in successfully',
			'favoritesRegistrationRequired' => ({required Object button}) => 'Registration required for this feature, please tap ${button} button',
			'forgotPassword' => 'I forgot password',
			'passwordRecoveryTitle' => 'Password recovery',
			'passwordRecoveryInstruction' => 'Enter 4 digits recovery code from your email',
			'passwordRecoveryCodeLabel' => 'Recovery code',
			'passwordRecoveryCodeHint' => '1234',
			'passwordRecoveryNewPassword' => 'New password',
			'passwordRecoverySubmit' => 'Submit',
			'passwordRecoveryEnterEmail' => 'Enter your email first',
			'passwordRecoveryInvalidEmail' => 'Enter a valid email address',
			'passwordRecoveryRequestFailed' => 'Couldn\'t start password recovery. Try again.',
			'passwordRecoveryInvalidCode' => 'Enter a valid 4-digit code',
			'passwordRecoveryPasswordTooShort' => 'Password must be at least 6 characters',
			'passwordRecoverySessionExpired' => 'Recovery session expired. Start again.',
			'passwordRecoverySaveFailed' => 'Couldn\'t save new password. Try again.',
			'passwordRecoverySaved' => 'Your new password is saved',
			'adminDeleteTitle' => 'Delete recipe?',
			'adminDeleteMessage' => 'This will remove the recipe for everyone.',
			'adminDeleteAction' => 'Delete',
			'adminEditAction' => 'Edit',
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
			'favoritesEmpty' => 'No favorites yet',
			'recipeAddedByPrefix' => 'by',
			'recipeAuthorRecipes' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} recipe', other: '${n} recipes', ), 
			'recipeRateTooltip' => 'Tap a star to rate',
			'recipeRatingAvg' => ({required Object avg}) => '${avg} / 5',
			'recipeVotesCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} vote', other: '${n} votes', ), 
			'recipeRatedToast' => 'Thanks for rating!',
			'ingredientCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} ingredient', other: '${n} ingredients', ), 
			'a11y.switchLanguageTo' => ({required Object label}) => 'Switch language to ${label}',
			'a11y.flagOf' => ({required Object label}) => '${label} flag',
			'a11y.reloadFeed' => 'Reload feed',
			'a11y.offlineReloadUnavailable' => 'You\'re offline. Showing previous recipes.',
			'a11y.reloadServerBusy' => 'Server is busy. Showing previous recipes.',
			'a11y.scrollToTop' => 'Scroll to top',
			'a11y.addRecipe' => 'Add recipe',
			'a11y.addRecipePhotoPicker' => 'Recipe photo picker',
			'addRecipeTitle' => 'Add recipe',
			'editRecipeTitle' => 'Edit recipe',
			'addRecipeName' => 'Recipe name',
			'addRecipePhoto' => 'Photo URL',
			'addRecipeCategory' => 'Category',
			'addRecipeArea' => 'Cuisine (country of origin)',
			'addRecipeInstructions' => 'Instructions',
			'addRecipeIngredientsLabel' => 'Ingredients',
			'addRecipeIngredientName' => 'Name',
			'addRecipeIngredientNameHint' => 'Sugar',
			'addRecipeIngredientQty' => 'Qty',
			'addRecipeIngredientQtyShort' => 'Qty',
			'addRecipeIngredientQtyHint' => '100',
			'addRecipeIngredientMeasure' => 'Unit',
			'addRecipeIngredientMeasureHint' => 'g',
			'addRecipeIngredientAdd' => 'Add ingredient',
			'addRecipeIngredientRemove' => 'Remove ingredient',
			'addRecipeSubmit' => 'Save recipe',
			'addRecipeRequired' => 'Required',
			'addRecipeSaving' => 'Saving…',
			'addRecipeError' => 'Couldn\'t save recipe. Try again.',
			'addRecipeSuccess' => 'Recipe added!',
			'addRecipePhotoFromGallery' => 'Choose from gallery',
			'addRecipePhotoFromCamera' => 'Take photo',
			'addRecipePhotoRequired' => 'Photo is required',
			'addRecipePhotoRemove' => 'Remove photo',
			'addRecipePhotoSourceTitle' => 'Add a photo',
			'addRecipePhotoErrorAccessDenied' => 'Access to photos denied. Allow access in Settings.',
			'addRecipePhotoErrorTooLarge' => 'Photo is too large even after compression. Try another one.',
			_ => null,
		};
	}
}
