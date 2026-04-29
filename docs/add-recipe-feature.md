# Add-recipe feature

User-facing flow that lets a person submit a brand-new recipe from inside
the app. Implemented across the Flutter client (`recipe_list`) and the
mahallem user-portal (`local_user_portal/routes/recipes.js`).

> Companion doc: [`themealdb-add-recipe-investigation.md`](./themealdb-add-recipe-investigation.md)
> documents *why* the user-submitted recipe lives only in our Postgres
> + sqflite layer (TheMealDB has no public POST endpoint).

---

## 1. UI — the `+` FAB and the form page

* **Location.** Recipe list page (`lib/ui/recipe_list_page.dart`).
  Inside the same `Stack` as the scroll-to-top FAB, mirrored at
  `Positioned(left: AppSpacing.lg, bottom: AppSpacing.lg)`. Always
  visible (independent of scroll offset).
* **Visuals.** Identical to scroll-to-top: 56×56 circle,
  `AppColors.primary @ 0.85 alpha`, `AppShadows.navBar`, white
  `Icons.add` glyph. See `docs/design_system.md` §9b/§9n.
* **A11y.** New i18n key `a11y.addRecipe` (10 locales). Tooltip and
  `Semantics(button: true, label: …)`.
* **Form page.** `lib/ui/add_recipe_page.dart`. Fields:
  | Field | Required | Notes |
  |---|---|---|
  | Recipe name | ✓ | maps to `strMeal` |
  | Photo URL | ✓ | maps to `strMealThumb` (no upload) |
  | Category | – | `strCategory` |
  | Area / cuisine | – | `strArea` |
  | Instructions | – | multi-line |
  | Ingredients | – | textarea, one per line `name | measure` |
  All input is expected in **English**. The hint at the top of the
  form spells this out — translations to the user's locale are
  generated lazily by the server cascade on the next
  `/recipes/lookup/:id?lang=ru` call (see
  `mahallem_ist/local_user_portal/docs/translation-pipeline.md`).

## 2. Client — `RecipeApi.createRecipe`

`recipe_list/lib/data/api/recipe_api.dart`:

```dart
Future<Recipe> createRecipe(Recipe draft) async {
  if (_client.backend != RecipeBackend.mahallem) {
    throw StateError('createRecipe requires the mahallem backend');
  }
  final meal = <String, dynamic>{
    'strMeal': draft.name,
    'strMealThumb': draft.photo,
    if (draft.category != null) 'strCategory': draft.category,
    // …strArea, strInstructions, strIngredient1..N / strMeasure1..N…
  };
  final res = await _client.dio.post<Map<String, dynamic>>(
    '', // dio.baseUrl is already https://mahallem.ist/recipes
    data: {'meal': meal},
  );
  return Recipe.fromMealDb(res.data!['meal']);
}
```

**Backend gating.** When `RecipeApiConfig.backend == RecipeBackend.mealDb`
(TheMealDB), `createRecipe` throws and the caller surfaces an error
snackbar. The FAB stays visible — the user can still toggle the
mahallem backend via `--dart-define=MAHALLEM_RECIPES_BASE=…`.

## 3. Server — `POST /recipes`

`mahallem_ist/local_user_portal/routes/recipes.js`:

```
POST /recipes
Headers: x-recipes-token: <RECIPES_API_SECRET>     (when configured)
Body:   { "meal": { "strMeal": "...", "strMealThumb": "https://...",
                    "strCategory": "...", "strArea": "...",
                    "strInstructions": "...",
                    "strIngredient1": "Beef", "strMeasure1": "200g",
                    ... up to strIngredient20/strMeasure20 ... } }

201 Created → { "id": 1000000, "meal": { idMeal:"1000000", strMeal:"...", ... } }
400         → { "error": "missing_meal" | "missing_required_fields" | "invalid_meal" }
401         → { "error": "unauthorized" }   (when shared-secret gating enabled)
500         → { "error": "internal" }
```

Behaviour:

1. Body parsed by `express.json({ limit: '10mb' })` (already in
   `server.js`).
2. The route delegates to `RecipeRepository.createUserMeal(meal)`.
3. `createUserMeal`:
   * runs `canonicalize(meal)` (49 fields), enforces `strMeal` and
     `strMealThumb`;
   * allocates the next id from the **user-meal range**:

     ```sql
     SELECT COALESCE(MAX(id), $floor::bigint - 1) + 1 AS next
     FROM recipes WHERE id >= $floor;
     ```

     The floor is `RECIPES_USER_MEAL_ID_FLOOR` (default `1_000_000`).
     TheMealDB ids are 5–6 digits, so user-submitted recipes can
     never collide with upstream pulls.
   * `INSERT` (NOT upsert) into `recipes` with the canonical payload
     stored under `i18n[SOURCE_LANG]` (= `i18n.en`);
   * runs the standard `_evictIfOverCap()` (todo/06).
4. The first `/recipes/lookup/:id?lang=ru` from any client after
   the insert triggers the regular `_ensureLang` cascade
   (Gemini-translated, echo-gated, persisted) — same path as for
   meals fetched from TheMealDB.

### Authentication

The new route is mounted **inside** the existing
`app.use('/recipes', limiter, authMiddleware)` chain, so when
`RECIPES_API_SECRET` is set in the production env, the client must
attach the `x-recipes-token` header. Today the Flutter client does
not send this header (the GET endpoints don't require it in our
deployment because the env var is unset). If we ever turn on the
secret, the dart-side `Dio` instance must be updated to forward the
token; consider injecting it via `--dart-define=RECIPES_API_TOKEN=…`.

## 4. Local cache mirroring

After the server returns the saved meal, the client calls
`RecipeRepository.upsertAll([saved], appLang.value)`. This:

* writes to `recipes` (sqflite) with `lang = active locale`;
* writes the body to the sibling `recipe_bodies` table (todo/12)
  keyed by `(id, lang)`;
* triggers the same 60/40 LRU split as cached upstream lookups
  (todo/13).

If the local write fails (disk full, etc.) we **don't** roll back
the server insert — the row exists in Postgres and will sync into
the device on the next `/recipes/page` refresh.

## 5. Sequence

```
[user]                [recipe_list]                  [mahallem]                [postgres]
  | tap +                  |                              |                          |
  |----------------------->|                              |                          |
  | fill form              |                              |                          |
  | tap "Save"             |                              |                          |
  |----------------------->| POST /recipes {meal}         |                          |
  |                        |----------------------------->|                          |
  |                        |                              | createUserMeal()         |
  |                        |                              | SELECT next id ----------|--> next id (e.g. 1000001)
  |                        |                              | INSERT INTO recipes -----|--> row {id, i18n.en}
  |                        |                              | _evictIfOverCap          |
  |                        |          201 {id, meal}      |                          |
  |                        |<-----------------------------|                          |
  |                        | upsertAll([meal], lang)      |                          |
  |                        |   → sqflite recipes +        |                          |
  |                        |     recipe_bodies            |                          |
  |                        | pop(meal) → list rebuilds    |                          |
  | snackbar: success      |                              |                          |
  |<-----------------------|                              |                          |
```

## 6. Files touched

| Side | File |
|---|---|
| client | `recipe_list/lib/ui/recipe_list_page.dart` (`+` FAB, navigation) |
| client | `recipe_list/lib/ui/add_recipe_page.dart` (new) |
| client | `recipe_list/lib/data/api/recipe_api.dart` (`createRecipe`) |
| client | `recipe_list/lib/i18n.dart` + 10 `*.i18n.json` locales |
| server | `mahallem_ist/local_user_portal/routes/recipes.js` (`createUserMeal`, `POST /recipes`) |
| server | `mahallem_ist/local_user_portal/tests/recipes.test.js` (2 new tests) |
| docs | `otus_dz/docs/add-recipe-feature.md` (this file) |
| docs | `otus_dz/docs/themealdb-add-recipe-investigation.md` |

## 7. Out of scope

* **Image upload.** The form takes a URL, not a file. Adding upload
  would require object storage (S3 / DO Spaces / Hostinger) and a
  signed-URL flow — left for a follow-up.
* **Editing or deleting** user-submitted recipes. The `POST /recipes`
  endpoint always allocates a fresh id; there is no `PUT` or `DELETE`
  yet.
* **Pushing to TheMealDB.** Not possible — see the companion doc.
