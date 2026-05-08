# Consent Splash — i18n (todo/21)

## Problem

The startup consent screen (legal gate shown before the recipe feed)
was built with all UI text hardcoded in English, even though the app
detects the device/browser locale and correctly picks one of the 10
supported languages (`en ru es fr de it tr ar fa ku`). A Russian-locale
user saw English strings: "Legal consent required", "I accept the Terms
of Use", "I agree", etc.

The legal HTML documents themselves are already served in the correct
language (`/recipes/legal/<lang>/terms.html` etc.) — only the Flutter
UI wrapper was untranslated.

## Affected strings

All strings live in two files:

### `lib/ui/splash_and_recipes.dart` — `_StartupConsentPanel`

| Hardcoded string | Key |
|---|---|
| `'Legal consent required'` | `consentTitle` |
| `'Country: ${...} (${...}) · ${...}'` | `consentCountry` (with params) |
| `'Open "${...}"'` (link button) | `consentOpenDoc` (with param) |
| `'I agree'` | `consentAgree` |
| `'Saving...'` | `consentSaving` |
| `'Please check all required consents'` | `consentCheckAll` |
| `'Legal document URL is invalid'` | `consentDocUrlInvalid` |
| `'Failed to open legal document'` | `consentDocOpenFailed` |

### `lib/consent/startup_consent.dart` — `startupConsentLabel()`

| Hardcoded string | Key |
|---|---|
| `'I accept the Terms of Use'` | `consentLabelTerms` |
| `'I accept personal data processing (GDPR)'` | `consentLabelPersonalDataGdpr` |
| `'I accept personal data processing (152-FZ)'` | `consentLabelPersonalData152Fz` |
| `'I accept personal data processing (KVKK)'` | `consentLabelPersonalDataKvkk` |
| `'I accept personal data processing (PDPL)'` | `consentLabelPersonalDataPdpl` |
| `'I accept personal data processing'` | `consentLabelPersonalDataGeneral` |
| `'I accept cookies policy'` | `consentLabelCookies` |
| `'I accept local storage policy'` | `consentLabelStorage` |

### `lib/consent/startup_consent.dart` — `startupConsentSpecFor()` — `docTitle`

These are the link-button labels passed as `StartupConsentItem.docTitle`
and rendered via `Open "${docTitle}"`.  They are now replaced by the
`consentOpenDoc` key directly (the button just says "Open document"),
so no separate keys are needed for these.

## Solution (3 chunks)

### Chunk A — Add keys to all 10 `*.i18n.json` files

Add the new keys to `en.i18n.json` (canonical) and translate into the
remaining 9 locale JSON files. Keys use `${param}` placeholders where
needed (slang syntax for string parameters).

### Chunk B — Regenerate `strings.g.dart`

```bash
cd recipe_list
dart run slang
```

Verify the generated `Translations` class exposes the new getters /
string functions.

### Chunk C — Wire strings into Dart files

Replace every hardcoded English literal with the corresponding
`t.keyName` / `t.keyName(param: value)` call, where `t` is obtained
via `AppLocale.values[appLang.value.locale.index].build()` at the call
site (same pattern used in `lib/ui/recipe_card.dart` etc.).

## Usage pattern

```dart
// Get the current translation object for the active language:
final t = appLang.value.locale.build();

// Simple string:
Text(t.consentTitle)

// String with parameters:
Text(t.consentCountry(country: spec.countryName, code: spec.countryCode, law: spec.legislationLabel))
Text(t.consentOpenDoc(title: item.docTitle))
```

## RTL consideration

`ar`, `fa`, `ku` are RTL. The `_StartupConsentPanel` uses `Column` with
`CrossAxisAlignment.start` — this automatically respects the Flutter
`Directionality` inherited from `MaterialApp`, which slang sets correctly
via `TranslationProvider`. No extra work needed.

## Languages covered

All 10 app languages: EN, RU, ES, FR, DE, IT, TR, AR, FA, KU.
