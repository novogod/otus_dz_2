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
class TranslationsIt with BaseTranslations<AppLocale, Translations> implements Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsIt({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.it,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <it>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key);

	late final TranslationsIt _root = this; // ignore: unused_field

	@override 
	TranslationsIt $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsIt(meta: meta ?? this.$meta);

	// Translations
	@override String get appTitle => 'Otus Food';
	@override String get back => 'Indietro';
	@override String get dismiss => 'Ignora';
	@override String get tabRecipes => 'Ricette';
	@override String get tabFridge => 'Frigo';
	@override String get tabFavorites => 'Preferiti';
	@override String get tabProfile => 'Profilo';
	@override String get tabComingSoon => 'Questa sezione sarà disponibile a breve';
	@override String get loginUsername => 'Login';
	@override String get loginPassword => 'Password';
	@override String get loginButton => 'Accedi';
	@override String get logoutButton => 'Esci';
	@override String get signUp => 'Registrati';
	@override String get signUpName => 'Nome';
	@override String get signUpEmail => 'Email';
	@override String get signUpPassword => 'Password';
	@override String get signUpButton => 'Crea account';
	@override String get signUpInvalidEmail => 'Inserisci un\'email valida';
	@override String get signUpPasswordTooShort => 'La password deve contenere almeno 4 caratteri';
	@override String get signUpDuplicateUser => 'L\'utente esiste già';
	@override String get signUpSenderError => 'Account creato, ma invio email non riuscito';
	@override String get signUpError => 'Impossibile creare l\'account. Riprova.';
	@override String get signUpSuccess => 'Account creato. Credenziali inviate via email.';
	@override String get loginInvalidCredentials => 'Login o password non validi';
	@override String get loginSuccessAdmin => 'Modalità amministratore attivata';
	@override String get loginSuccessUser => 'Accesso effettuato con successo';
	@override String get favoritesRegistrationRequired => 'Registrazione richiesta per questa funzione, tocca il pulsante Sign Up';
	@override String get forgotPassword => 'Ho dimenticato la password';
	@override String get passwordRecoveryTitle => 'Recupero password';
	@override String get passwordRecoveryInstruction => 'Inserisci il codice di recupero a 4 cifre ricevuto via email';
	@override String get passwordRecoveryCodeLabel => 'Codice di recupero';
	@override String get passwordRecoveryCodeHint => '1234';
	@override String get passwordRecoveryNewPassword => 'Nuova password';
	@override String get passwordRecoverySubmit => 'Invia';
	@override String get passwordRecoveryEnterEmail => 'Inserisci prima la tua email';
	@override String get passwordRecoveryInvalidEmail => 'Inserisci un\'email valida';
	@override String get passwordRecoveryRequestFailed => 'Impossibile avviare il recupero password. Riprova.';
	@override String get passwordRecoveryInvalidCode => 'Inserisci un codice valido di 4 cifre';
	@override String get passwordRecoveryPasswordTooShort => 'La password deve contenere almeno 6 caratteri';
	@override String get passwordRecoverySessionExpired => 'La sessione di recupero è scaduta. Ricomincia da capo.';
	@override String get passwordRecoverySaveFailed => 'Impossibile salvare la nuova password. Riprova.';
	@override String get passwordRecoverySaved => 'La tua nuova password è stata salvata';
	@override String get adminDeleteTitle => 'Eliminare la ricetta?';
	@override String get adminDeleteMessage => 'Questa azione rimuoverà la ricetta per tutti.';
	@override String get adminDeleteAction => 'Elimina';
	@override String get adminEditAction => 'Modifica';
	@override String get emptyList => 'Nessuna ricetta';
	@override String loadError({required Object error}) => 'Caricamento fallito: ${error}';
	@override String get retry => 'Riprova';
	@override String get offlineNotice => 'Nessuna connessione — mostro le ricette in cache.';
	@override String get loadingTitle => 'Preparazione della raccolta di ricette';
	@override String loadingStage({required Object category, required Object done, required Object total}) => 'Caricamento di "${category}" (${done}/${total} categorie)…';
	@override String loadingProgress({required Object loaded, required Object target}) => 'Caricate ${loaded} di ${target} ricette';
	@override String get loadingFromCache => 'Apertura delle ricette in cache…';
	@override String get emptyHint => 'Il server non ha restituito ricette. Controlla la tua connessione e tocca "Riprova".';
	@override String get recipeTitle => 'Ricetta';
	@override String get ingredientsHeader => 'Ingredienti';
	@override String get instructionsHeader => 'Istruzioni';
	@override String get youtube => 'YouTube';
	@override String get source => 'Fonte';
	@override String get searchHint => 'Cerca ricetta';
	@override String get searchClear => 'Cancella';
	@override String get searchNoMatches => 'Nessun risultato';
	@override String get favoritesEmpty => 'Ancora nessun preferito';
	@override String ingredientCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(n,
		one: '${n} ingrediente',
		other: '${n} ingredienti',
	);
	@override late final _TranslationsA11yIt a11y = _TranslationsA11yIt._(_root);
	@override String get addRecipeTitle => 'Aggiungi ricetta';
	@override String get editRecipeTitle => 'Modifica ricetta';
	@override String get addRecipeName => 'Nome della ricetta';
	@override String get addRecipePhoto => 'URL della foto';
	@override String get addRecipeCategory => 'Categoria';
	@override String get addRecipeArea => 'Cucina (paese d’origine)';
	@override String get addRecipeInstructions => 'Istruzioni';
	@override String get addRecipeIngredientsLabel => 'Ingredienti';
	@override String get addRecipeIngredientName => 'Nome';
	@override String get addRecipeIngredientNameHint => 'Zucchero';
	@override String get addRecipeIngredientQty => 'Q.tà';
	@override String get addRecipeIngredientQtyShort => 'Q.tà';
	@override String get addRecipeIngredientQtyHint => '100';
	@override String get addRecipeIngredientMeasure => 'Unità';
	@override String get addRecipeIngredientMeasureHint => 'g';
	@override String get addRecipeIngredientAdd => 'Aggiungi ingrediente';
	@override String get addRecipeIngredientRemove => 'Rimuovi ingrediente';
	@override String get addRecipeSubmit => 'Salva ricetta';
	@override String get addRecipeRequired => 'Obbligatorio';
	@override String get addRecipeSaving => 'Salvataggio…';
	@override String get addRecipeError => 'Impossibile salvare la ricetta. Riprova.';
	@override String get addRecipeSuccess => 'Ricetta aggiunta!';
	@override String get addRecipePhotoFromGallery => 'Scegli dalla galleria';
	@override String get addRecipePhotoFromCamera => 'Scatta foto';
	@override String get addRecipePhotoRequired => 'La foto è obbligatoria';
	@override String get addRecipePhotoRemove => 'Rimuovi foto';
	@override String get addRecipePhotoSourceTitle => 'Aggiungi una foto';
	@override String get addRecipePhotoErrorAccessDenied => 'Accesso alle foto negato. Consentilo nelle Impostazioni.';
	@override String get addRecipePhotoErrorTooLarge => 'La foto è troppo grande anche dopo la compressione. Provane un\'altra.';
}

// Path: a11y
class _TranslationsA11yIt implements TranslationsA11yEn {
	_TranslationsA11yIt._(this._root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String switchLanguageTo({required Object label}) => 'Cambia lingua in ${label}';
	@override String get reloadFeed => 'Aggiorna lista';
	@override String flagOf({required Object label}) => 'Bandiera di ${label}';
	@override String get offlineReloadUnavailable => 'Sei offline. Vengono mostrate le ricette precedenti.';
	@override String get reloadServerBusy => 'Server occupato. Vengono mostrate le ricette precedenti.';
	@override String get scrollToTop => 'Torna su';
	@override String get addRecipe => 'Aggiungi ricetta';
	@override String get addRecipePhotoPicker => 'Selezione foto ricetta';
}

/// The flat map containing all translations for locale <it>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsIt {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'appTitle' => 'Otus Food',
			'back' => 'Indietro',
			'dismiss' => 'Ignora',
			'tabRecipes' => 'Ricette',
			'tabFridge' => 'Frigo',
			'tabFavorites' => 'Preferiti',
			'tabProfile' => 'Profilo',
			'tabComingSoon' => 'Questa sezione sarà disponibile a breve',
			'loginUsername' => 'Login',
			'loginPassword' => 'Password',
			'loginButton' => 'Accedi',
			'logoutButton' => 'Esci',
			'signUp' => 'Registrati',
			'signUpName' => 'Nome',
			'signUpEmail' => 'Email',
			'signUpPassword' => 'Password',
			'signUpButton' => 'Crea account',
			'signUpInvalidEmail' => 'Inserisci un\'email valida',
			'signUpPasswordTooShort' => 'La password deve contenere almeno 4 caratteri',
			'signUpDuplicateUser' => 'L\'utente esiste già',
			'signUpSenderError' => 'Account creato, ma invio email non riuscito',
			'signUpError' => 'Impossibile creare l\'account. Riprova.',
			'signUpSuccess' => 'Account creato. Credenziali inviate via email.',
			'loginInvalidCredentials' => 'Login o password non validi',
			'loginSuccessAdmin' => 'Modalità amministratore attivata',
			'loginSuccessUser' => 'Accesso effettuato con successo',
			'favoritesRegistrationRequired' => 'Registrazione richiesta per questa funzione, tocca il pulsante Sign Up',
			'forgotPassword' => 'Ho dimenticato la password',
			'passwordRecoveryTitle' => 'Recupero password',
			'passwordRecoveryInstruction' => 'Inserisci il codice di recupero a 4 cifre ricevuto via email',
			'passwordRecoveryCodeLabel' => 'Codice di recupero',
			'passwordRecoveryCodeHint' => '1234',
			'passwordRecoveryNewPassword' => 'Nuova password',
			'passwordRecoverySubmit' => 'Invia',
			'passwordRecoveryEnterEmail' => 'Inserisci prima la tua email',
			'passwordRecoveryInvalidEmail' => 'Inserisci un\'email valida',
			'passwordRecoveryRequestFailed' => 'Impossibile avviare il recupero password. Riprova.',
			'passwordRecoveryInvalidCode' => 'Inserisci un codice valido di 4 cifre',
			'passwordRecoveryPasswordTooShort' => 'La password deve contenere almeno 6 caratteri',
			'passwordRecoverySessionExpired' => 'La sessione di recupero è scaduta. Ricomincia da capo.',
			'passwordRecoverySaveFailed' => 'Impossibile salvare la nuova password. Riprova.',
			'passwordRecoverySaved' => 'La tua nuova password è stata salvata',
			'adminDeleteTitle' => 'Eliminare la ricetta?',
			'adminDeleteMessage' => 'Questa azione rimuoverà la ricetta per tutti.',
			'adminDeleteAction' => 'Elimina',
			'adminEditAction' => 'Modifica',
			'emptyList' => 'Nessuna ricetta',
			'loadError' => ({required Object error}) => 'Caricamento fallito: ${error}',
			'retry' => 'Riprova',
			'offlineNotice' => 'Nessuna connessione — mostro le ricette in cache.',
			'loadingTitle' => 'Preparazione della raccolta di ricette',
			'loadingStage' => ({required Object category, required Object done, required Object total}) => 'Caricamento di "${category}" (${done}/${total} categorie)…',
			'loadingProgress' => ({required Object loaded, required Object target}) => 'Caricate ${loaded} di ${target} ricette',
			'loadingFromCache' => 'Apertura delle ricette in cache…',
			'emptyHint' => 'Il server non ha restituito ricette. Controlla la tua connessione e tocca "Riprova".',
			'recipeTitle' => 'Ricetta',
			'ingredientsHeader' => 'Ingredienti',
			'instructionsHeader' => 'Istruzioni',
			'youtube' => 'YouTube',
			'source' => 'Fonte',
			'searchHint' => 'Cerca ricetta',
			'searchClear' => 'Cancella',
			'searchNoMatches' => 'Nessun risultato',
			'favoritesEmpty' => 'Ancora nessun preferito',
			'ingredientCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(n, one: '${n} ingrediente', other: '${n} ingredienti', ), 
			'a11y.switchLanguageTo' => ({required Object label}) => 'Cambia lingua in ${label}',
			'a11y.reloadFeed' => 'Aggiorna lista',
			'a11y.flagOf' => ({required Object label}) => 'Bandiera di ${label}',
			'a11y.offlineReloadUnavailable' => 'Sei offline. Vengono mostrate le ricette precedenti.',
			'a11y.reloadServerBusy' => 'Server occupato. Vengono mostrate le ricette precedenti.',
			'a11y.scrollToTop' => 'Torna su',
			'a11y.addRecipe' => 'Aggiungi ricetta',
			'a11y.addRecipePhotoPicker' => 'Selezione foto ricetta',
			'addRecipeTitle' => 'Aggiungi ricetta',
			'editRecipeTitle' => 'Modifica ricetta',
			'addRecipeName' => 'Nome della ricetta',
			'addRecipePhoto' => 'URL della foto',
			'addRecipeCategory' => 'Categoria',
			'addRecipeArea' => 'Cucina (paese d’origine)',
			'addRecipeInstructions' => 'Istruzioni',
			'addRecipeIngredientsLabel' => 'Ingredienti',
			'addRecipeIngredientName' => 'Nome',
			'addRecipeIngredientNameHint' => 'Zucchero',
			'addRecipeIngredientQty' => 'Q.tà',
			'addRecipeIngredientQtyShort' => 'Q.tà',
			'addRecipeIngredientQtyHint' => '100',
			'addRecipeIngredientMeasure' => 'Unità',
			'addRecipeIngredientMeasureHint' => 'g',
			'addRecipeIngredientAdd' => 'Aggiungi ingrediente',
			'addRecipeIngredientRemove' => 'Rimuovi ingrediente',
			'addRecipeSubmit' => 'Salva ricetta',
			'addRecipeRequired' => 'Obbligatorio',
			'addRecipeSaving' => 'Salvataggio…',
			'addRecipeError' => 'Impossibile salvare la ricetta. Riprova.',
			'addRecipeSuccess' => 'Ricetta aggiunta!',
			'addRecipePhotoFromGallery' => 'Scegli dalla galleria',
			'addRecipePhotoFromCamera' => 'Scatta foto',
			'addRecipePhotoRequired' => 'La foto è obbligatoria',
			'addRecipePhotoRemove' => 'Rimuovi foto',
			'addRecipePhotoSourceTitle' => 'Aggiungi una foto',
			'addRecipePhotoErrorAccessDenied' => 'Accesso alle foto negato. Consentilo nelle Impostazioni.',
			'addRecipePhotoErrorTooLarge' => 'La foto è troppo grande anche dopo la compressione. Provane un\'altra.',
			_ => null,
		};
	}
}
