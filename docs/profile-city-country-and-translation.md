# Profile City/Country fields + creator-city translation

**Status:** shipped 2026-05-07.

## Goal

Show the recipe author's location (`City` / `Country`) on every
recipe card and on the recipe details page, in the viewer's UI
language, without polluting the recipe translation pipeline.

Three product constraints drove the design:

1. **Country** must localize per viewer (e.g. an Italian viewer
   sees "Russia" as "Russia", a French viewer sees "Russie", an
   Arabic viewer sees "روسيا"). It also has to round-trip cleanly
   between users on different UI languages.
2. **City** is free-form (there is no canonical city dataset
   comparable to ISO 3166), but should still translate when the
   viewer's language differs from the creator's.
3. **No regressions** in the existing recipe translation pipeline
   (`utils/translate-recipe.js`) — recipes are cached per language
   and city translation must not invalidate that cache.

## Solution at a glance

| Field     | Storage                              | Display strategy                                                                                                |
| --------- | ------------------------------------ | --------------------------------------------------------------------------------------------------------------- |
| `country` | ISO 3166-1 alpha-2 (e.g. `RU`)       | Client-side via `country_picker`'s `CountryLocalizations.countryName(countryCode)` — instant, offline.          |
| `city`    | Raw text in the creator's UI language | Server-side via `translateLabel()` in `attachSocialSignals`, with a per-process LRU cache keyed by `(src,tgt,raw)`. |

Why split the strategy:

- Country has a finite set (~250 codes) with high-quality offline
  i18n already bundled in `country_picker`. No network round-trip,
  no engine bills.
- City is unbounded, so we lean on the existing translation
  engines (MyMemory → LibreTranslate → Gemini fallback) used for
  recipe titles and tags. Caching by the raw city string means
  popular cities like Moscow or Paris are translated once per
  `(srcLang, tgtLang)` pair.

## Backend

### Schema additions

`recipe_app_users` now has two text columns:

```sql
ALTER TABLE recipe_app_users
  ADD COLUMN IF NOT EXISTS city    TEXT,
  ADD COLUMN IF NOT EXISTS country TEXT;
```

The column is auto-applied at boot inside
`ensureRecipeAppUsersAvatarColumn` (idempotent IIFE).

### Profile endpoints

`GET /recipes/users/me` — projects `city, country`.

`PUT /recipes/users/me` — accepts `{displayName, language, city,
country}`. Validation:

- `city`: trimmed, max 80 chars; empty string clears.
- `country`: trimmed, must match `/^[A-Z]{2}$/i` or be empty;
  uppercased on write. Returns `400 invalid_country` otherwise.

### Recipe projection (`attachSocialSignals`)

The function now SELECTs `u.preferred_language AS creator_lang`
alongside city/country and accepts a `targetLang` argument. After
the meal-row projection is done, it runs a translation pass:

```js
if (targetLang) {
  await Promise.all(meals.map(async (m) => {
    const city = m && m.creatorCity;
    const src  = m && m._creatorCityLang;
    if (city && src && src !== targetLang) {
      try {
        m.creatorCity = await translateCityCached(city, src, targetLang);
      } catch (_) { /* preserve original on engine failure */ }
    }
    if (m) delete m._creatorCityLang;
  }));
}
```

`translateCityCached` is a tiny LRU wrapping `translateLabel`:

- Map keyed `${src}|${tgt}|${rawCity}`.
- Cap 2000 entries; on overflow drop the oldest insertion (Map
  preserves insertion order).
- Surfaces `translateLabel`'s engine cascade
  (MyMemory → LibreTranslate → Gemini) used for `strMeal` and
  `strCategory`.

`targetLang` is threaded into all five callers:
`/recipes/search`, `/recipes/lookup`, `/recipes/random`,
`/recipes/filter`, `/recipes/page`.

### Why not bake the city into the recipe payload?

The recipe `redis` cache is keyed by `(recipeId, lang)`. If we
embedded the translated city into the recipe body, every change
to a creator's city or display name would have to invalidate
every cached recipe row across all 9 supported languages. Keeping
city/country in the social-signals projection (which already runs
*after* the cache hit) means creator profile edits never touch
recipe cache.

## Client

### Country picker (canonical alpha-2)

`pubspec.yaml`: `country_picker: ^2.0.27`.

`main.dart`: registers `CountryLocalizations.delegate` alongside
`GlobalMaterialLocalizations.delegates` so `countryName(...)` is
available to every BuildContext.

`user_card_page.dart`:

- Stores `String? _countryCode` (alpha-2). Free-form
  `_countryController` is gone.
- Field is an `InkWell` + `InputDecorator` showing the flag
  emoji, the localized country name, an "×" clear button, and a
  dropdown caret. Tapping opens `showCountryPicker(...)`.
- Save sends `country: _countryCode ?? ''` (empty clears the
  column).

The flag emoji is built with the regional-indicator offset:
`String.fromCharCodes([0x1F1E6 + (cc[0] - 65), 0x1F1E6 + (cc[1] - 65)])`.

### City autocomplete (OSM Nominatim)

`user_card_page.dart`:

- `RawAutocomplete<String>` reusing the existing
  `_cityController` and `_cityFocus`.
- Suggestions queried from
  `https://nominatim.openstreetmap.org/search` with:
  - `q` = trimmed user input (≥ 2 chars),
  - `accept-language` = current UI language (so suggestions
    are localized for the user typing),
  - `countrycodes` = lowercased `_countryCode` when set,
  - `format=jsonv2&addressdetails=1&limit=8`.
- 350 ms debounce + race-guard via `_latestCityQuery` to discard
  stale responses.
- Per-tap fresh `Dio` instance with `User-Agent:
  mahallem-recipes/1.0 (https://mahallem.com)` per Nominatim's
  usage policy. App auth headers are not leaked to OSM.
- Each result's address is folded down to
  `city ?? town ?? village ?? municipality ?? hamlet ?? name`.
- Network/parse errors degrade silently to plain free-text input
  (still capped at 80 chars).

### Author chip layout

Both `_AuthorChip` (cards list) and `AddedByRow` (recipe details)
now render two stacked rows in a `Column`:

- Upper row: `name  •  N recipes`. Sits above the avatar's
  horizontal axis.
- Lower row: `city/country` (no brackets). Hidden when both are
  empty. Sits below the avatar's horizontal axis.

The Row uses `crossAxisAlignment.center` so the avatar's vertical
center falls between the two rows.

The country part of the lower row is rendered through
`CountryLocalizations.of(context).countryName(countryCode: cc)`,
falling back to the raw code when the lookup fails (offline tests
or unknown future codes).

## Edge cases & pre-existing data

Free-form rows that pre-date the picker (length ≠ 2) are left
untranslated by `CountryLocalizations` and rendered as-is. Two
such rows exist on prod (`Russia`, `Россия`) — users will pick
again on next profile edit and the rows become canonical
alpha-2.

When `creator_lang` is null (legacy users with no
`preferred_language`), the city translation pass is skipped — the
city is shown as stored.

## Files touched

- `mahallem_ist/local_user_portal/routes/recipes.js`
- `otus_dz/recipe_list/pubspec.yaml`
- `otus_dz/recipe_list/lib/main.dart`
- `otus_dz/recipe_list/lib/models/recipe.dart`
- `otus_dz/recipe_list/lib/data/api/recipe_api.dart`
- `otus_dz/recipe_list/lib/data/local/recipe_db.dart` (schema v15)
- `otus_dz/recipe_list/lib/ui/user_card_page.dart`
- `otus_dz/recipe_list/lib/ui/recipe_card.dart`
- `otus_dz/recipe_list/lib/ui/social/added_by_row.dart`
- `otus_dz/recipe_list/lib/ui/recipe_details_page.dart`
- `otus_dz/recipe_list/lib/ui/admin_after_login_page.dart` (480px content cap)
