# Nutrition service — design proposal

> Status: **proposal / not implemented**.
> Author: GitHub Copilot, 2026-05-07.
> Sibling docs: [translation-pipeline.md](../translation-pipeline.md),
> [recipe-ingester-and-size-cap.md](../recipe-ingester-and-size-cap.md),
> [user-card-and-social-signals.md](../user-card-and-social-signals.md).

## 1. Goals

Add per-recipe nutrition facts to the app:

- Total **calories**, **protein**, **fat**, **carbohydrates** in
  **grams** and as **% of total macro grams** (P/F/C balance pie).
- Per-100 g and per-serving variants.
- Coverage = TheMealDB seed recipes **and** user-posted recipes,
  both originals and translations.
- Multilingual: an ingredient line written as `"стакан муки"` or
  `"1 cup flour"` should resolve to the same USDA food row.
- Robust to messy ingredient text (no panics, partial matches OK,
  uncertainty surfaced to the UI as a confidence badge).

## 2. Architecture

A new container `nutrition` is added to
[docker-compose.web.yml](../../docker-compose.web.yml), parallel to
`prerender` and `flutter-web`:

```
                     ┌──────────────────────────────┐
  Flutter SPA / iOS  │  GET /nutrition/recipes/:id   │
  (recipe details)   │  POST /nutrition/preview      │
  ───────────────►   │                                │
                     │   ┌──────────────────────────┐ │
                     │   │  parser  (ingredient →   │ │
                     │   │   {food_id, grams})      │ │
                     │   └──────────┬───────────────┘ │
                     │              │                 │
                     │   ┌──────────▼───────────────┐ │
                     │   │  resolver  (food_id      │ │
                     │   │   → USDA row, cached)    │ │
                     │   └──────────┬───────────────┘ │
                     │              │                 │
                     │   ┌──────────▼───────────────┐ │
                     │   │  aggregator (Σ macros,   │ │
                     │   │   per-100g, per-serv.)   │ │
                     │   └──────────────────────────┘ │
                     │                                │
                     │  Postgres: nutrition_recipe,    │
                     │   nutrition_food, alias_map     │
                     └──────────────────────────────┘
                                    ▲
                                    │ subscribe
                                    │
                     mahallem-user-portal events
                     (recipe.created / .updated /
                      .translated)
```

### 2.1 Why a separate container

- Heavy CPU bursts (regex + token matching for 20 ingredient lines
  per recipe) shouldn't share a worker pool with the auth API.
- The USDA dataset (~400k rows, ~700 MB CSV) is loaded once at
  boot into an in-memory inverted index. We don't want that
  resident in the user-portal node process.
- Independent rolling restarts when the alias map / stop-word
  list is retrained.
- Language stack flexibility: parser benefits from a Python /
  spaCy + scikit toolchain; the rest of the stack is Node. The
  HTTP boundary keeps that choice local.

### 2.2 Network placement

Same pattern as `prerender`:

- Joins the existing `local_docker_admin_backend_mahallem_network`
  bridge, so it can reach `mahallem-user-portal:4000` for recipe
  lookups and event subscription.
- Bound to `127.0.0.1:8090:8090` only; host nginx terminates TLS
  at `recipies.mahallem.ist/api/nutrition/*` and proxies to it.
- `extra_hosts: recipies.mahallem.ist:host-gateway` so internal
  callers can hit the same canonical origin the SPA uses.

### 2.3 Dependencies

- **USDA FoodData Central** (CC0, downloadable bulk CSV/JSON).
  Provides `Foundation`, `SR Legacy`, `Survey (FNDDS)` rows with
  Energy/Protein/Fat/Carb per 100 g. ~400k rows total; we only
  ingest Foundation + SR Legacy (~20k rows) by default — the rest
  is FNDDS branded products which add noise.
- **Open Food Facts** (ODbL) as a backfill for branded items
  user-uploaded recipes mention by brand name.
- **udunits2** or pure-JS `convert-units` for unit normalisation.

## 3. Ingredient parsing

Input: `RecipeIngredient { name: "flour", measure: "1 cup" }`
(see [recipe.dart](../../recipe_list/lib/models/recipe.dart#L31)).
Output: `{ canonical_food_id, grams, confidence ∈ [0,1] }`.

### 3.1 Pipeline

1. **Locale detect** — recipe `sourceLanguage` (already tracked,
   see [recipe-source-language.md](../recipe-source-language.md))
   tells us which tokeniser/lemma table to use.
2. **Tokenise + lemmatise** — language-specific. Russian: pymorphy3.
   English: spaCy `en_core_web_sm`. Turkish: zeyrek. Fallback:
   ICU word-break + lowercased substring match.
3. **Quantity + unit extraction** — regex over the `measure`
   field first (`"1 cup"`, `"3/4 ст."`, `"200 g"`, `"a pinch"`).
   Mixed fractions, ranges (`"1-2"` → average), word numerals
   (`"two"`, `"полстакана"`). Unrecognised → `grams=null,
   confidence-=0.3`.
4. **Unit → grams** — use a per-ingredient density map for volume
   units (1 cup flour = 120 g, 1 cup water = 240 g, 1 tbsp oil =
   13.5 g). The map ships as a static JSON, sourced from USDA's
   `food_portion` table. Unknown unit + known food → fallback to
   serving size from USDA, `confidence-=0.2`.
5. **Food resolution** — exact lemma match in the alias map
   (`мука пшеничная` → fdc_id 169761) wins. Otherwise
   BM25 over the `description` index (Lucene-equivalent), top-3
   candidates re-ranked by token overlap. Score < 0.4 → mark line
   as `unresolved`, store the raw text for later admin review.

### 3.2 Alias map

`nutrition_alias` (lang, alias, fdc_id, weight). Seeded from:

- USDA's own multi-name fields (`description`,
  `common_names`).
- Wikidata `food` items + `instance of` chains. Wikidata entities
  carry labels in every locale we support, so one Wikidata row
  expands into ~10 language rows automatically.
- Manual overrides (admin UI, see §6.4).

### 3.3 User-posted recipes

User recipes go through the **same** parser. The translation
pipeline (translation-pipeline.md §3) already produces canonical
ingredient strings in every supported locale; we hook the same
event so a fresh translation triggers a re-parse for that locale
(better recall in the user's own language).

If the user wrote `"мой особый соус"` and no row resolves, the
recipe simply gets a `nutrition_partial=true` flag and the UI
hides the macro card with a tooltip "Not enough data — help us
translate". Admins can map the alias from the dashboard.

## 4. API contract

Base path: `https://recipies.mahallem.ist/api/nutrition`.

All responses are JSON, `Cache-Control: public, max-age=300,
stale-while-revalidate=86400`. ETag based on
`(recipe_id, recipe.updatedAt, alias_map_version)`.

### 4.1 Public read

#### `GET /recipes/:id?lang=en&servings=auto`

```jsonc
// 200 OK
{
  "recipeId": 53220,
  "lang": "en",
  "servingsAssumed": 4,         // from recipe.strServings, fallback heuristics
  "perServing": {
    "calories": 612,
    "protein":  { "grams": 28.4, "percent": 24 },
    "fat":      { "grams": 18.7, "percent": 16 },
    "carbs":    { "grams": 71.2, "percent": 60 }
  },
  "perHundredGrams": { "calories": 192, /* …same shape… */ },
  "totals":          { "weightGrams": 1284, /* …same shape… */ },
  "lines": [
    {
      "raw": "200 g rice",
      "fdcId": 169704,
      "grams": 200,
      "confidence": 0.97,
      "macros": { "calories": 720, "protein": 13.2, "fat": 1.4, "carbs": 158.0 }
    },
    {
      "raw": "salt to taste",
      "resolved": false,
      "ignored": true,
      "reason": "negligible-macros"
    }
  ],
  "coverage": 0.92,             // fraction of grams successfully resolved
  "computedAt": "2026-05-07T08:33:11Z",
  "version": "alias-2026-05-01"
}
```

- `coverage < 0.6` → SPA renders an "estimate" badge.
- `coverage = 0` → SPA hides the macro card; service still
  responds 200 (no 404, so the SPA can show the empty state
  consistently).

#### `GET /recipes/:id/lines?lang=…`

Returns just the `lines[]` array — used by the recipe-edit screen
when a creator wants to spot-fix a line.

#### `GET /recipes/:id/summary?lang=en&servings=auto`

Compact projection used by the **recipe-list card** (§6.1). Strips
the per-line breakdown so the response stays small enough to ship
with the existing list-page payload.

```jsonc
// 200 OK
{
  "recipeId": 53220,
  "kcal": 612,                  // per serving, rounded
  "p": 24, "f": 16, "c": 60,    // % of total macro grams
  "coverage": 0.92
}
```

The user-portal `/recipes/page` and `/recipes/lookup/:id`
endpoints denormalise these four numbers onto the recipe row
(same pattern as `favoritesCount` / `ratingsSum` in
[user-card-and-social-signals.md](../user-card-and-social-signals.md))
so the SPA does **not** issue a second round-trip per card.
Nutrition writes to the projection via the same Redis event bus
(§4.4) whenever it recomputes a recipe.

#### `GET /recipes/:id/full?lang=en&servings=auto`

Detailed projection for the **modal card** behind the "Details"
button (§6.1). Includes everything in `/recipes/:id` PLUS
micronutrients with % of daily norm (DV) per serving.

```jsonc
// 200 OK
{
  "recipeId": 53220,
  "lang": "en",
  "servingsAssumed": 4,
  "perServing": {
    "calories": 612,
    "protein": { "grams": 28.4, "percent": 24, "dv": 57 },
    "fat":     { "grams": 18.7, "percent": 16, "dv": 24,
                 "saturated": { "grams": 5.1, "dv": 26 },
                 "trans":     { "grams": 0.0 },
                 "mono":      { "grams": 8.2 },
                 "poly":      { "grams": 4.4 } },
    "carbs":   { "grams": 71.2, "percent": 60, "dv": 26,
                 "sugar":   { "grams": 4.8 },
                 "fiber":   { "grams": 6.1, "dv": 22 },
                 "starch":  { "grams": 60.3 } },
    "cholesterolMg": 78,
    "sodiumMg":      612,
    "waterG":        184,
    "vitamins": {
      "a_mcg":  { "amount":  92, "dv": 10 },
      "c_mg":   { "amount":  18, "dv": 20 },
      "d_mcg":  { "amount":   1, "dv":  5 },
      "e_mg":   { "amount":   2, "dv": 13 },
      "k_mcg":  { "amount":  41, "dv": 34 },
      "b1_mg":  { "amount": 0.3, "dv": 25 },
      "b2_mg":  { "amount": 0.4, "dv": 31 },
      "b3_mg":  { "amount":   8, "dv": 50 },
      "b6_mg":  { "amount": 0.6, "dv": 35 },
      "b9_mcg": { "amount": 120, "dv": 30 },
      "b12_mcg":{ "amount": 1.2, "dv": 50 }
    },
    "minerals": {
      "calcium_mg":   { "amount": 102, "dv":  8 },
      "iron_mg":      { "amount": 3.4, "dv": 19 },
      "magnesium_mg": { "amount":  64, "dv": 15 },
      "phosphorus_mg":{ "amount": 280, "dv": 22 },
      "potassium_mg": { "amount": 540, "dv": 11 },
      "zinc_mg":      { "amount": 2.8, "dv": 25 },
      "selenium_mcg": { "amount":  18, "dv": 33 },
      "copper_mg":    { "amount": 0.2, "dv": 22 },
      "manganese_mg": { "amount": 0.6, "dv": 26 }
    }
  },
  "perHundredGrams": { /* same shape, dv values omitted */ },
  "totals":          { /* same shape, dv values omitted */ },
  "lines":           [ /* same as /recipes/:id */ ],
  "coverage": 0.92,
  "dvProfile": "fda-2016-adult",
  "computedAt": "2026-05-07T08:33:11Z"
}
```

Notes:

- `dv` is `% of Daily Value` for an adult on the FDA 2016 reference
  diet (the most widely reproducible profile). The active profile
  is identified by `dvProfile`; future work may add
  `eu-2011-adult`, `who-2003-adult`, child profiles, etc.
- Nulls allowed for any nutrient absent from USDA's row — the
  Flutter card greys those out instead of showing 0.
- Same caching and ETag rules as `/recipes/:id`; payload is
  ~3 kB gzipped so we ship it on demand (only when the modal
  opens) rather than in `/recipes/page`.

### 4.2 Preview / dry-run (used by add-recipe form)

#### `POST /preview`

```jsonc
// request
{
  "lang": "ru",
  "servings": 4,
  "ingredients": [
    { "name": "мука",    "measure": "200 г" },
    { "name": "сахар",   "measure": "1 стакан" },
    { "name": "молоко",  "measure": "500 мл" }
  ]
}

// 200 OK – same shape as /recipes/:id but recipeId=null
```

Lets the Flutter "add recipe" form show live macros while the
user is typing — no DB write happens on preview.

### 4.3 Admin / write-back

All under `Authorization: Bearer <admin JWT>`,
allowlist enforced by user-portal (existing role check).

#### `POST /alias`

Add an alias map row (`lang`, `alias`, `fdcId`, optional
`densityG`). Triggers a re-parse of every recipe that previously
failed on `alias`.

#### `POST /recompute`

```jsonc
{ "recipeIds": [53220, 53221] }   // or { "all": true }
```

#### `GET /unresolved?lang=ru&limit=50`

Returns ingredient lines the parser couldn't resolve, grouped by
normalised lemma + count, so an admin can knock out the long
tail of misses with a few alias entries.

### 4.4 Internal (service-to-service)

#### `GET /healthz`

Returns `{ aliasVersion, indexedFoods, parserBuild }`. Polled by
the existing prod health check.

#### Event subscription

Nutrition consumes the same Redis pub-sub channel the translation
pipeline uses (`recipe.events`). Events:

- `recipe.created` → enqueue parse.
- `recipe.updated` → invalidate cache, re-enqueue.
- `recipe.translated.{lang}` → re-parse for that lang only.
- `recipe.deleted` → soft-delete `nutrition_recipe` row.

Queue is a Redis stream `nutrition:jobs` with consumer group
`nutrition-workers`, mirroring `translation:jobs`.

## 5. Storage

Two new Postgres tables in the existing `recipes` schema (so
joins with `recipes`/`recipes_i18n` are local).

```sql
CREATE TABLE nutrition_recipe (
  recipe_id        BIGINT      NOT NULL,
  lang             TEXT        NOT NULL,
  servings         INT         NOT NULL,
  weight_g         NUMERIC(8,1) NOT NULL,
  kcal             NUMERIC(8,1) NOT NULL,
  protein_g        NUMERIC(7,2) NOT NULL,
  fat_g            NUMERIC(7,2) NOT NULL,
  carbs_g          NUMERIC(7,2) NOT NULL,
  coverage         NUMERIC(3,2) NOT NULL,
  alias_version    TEXT         NOT NULL,
  computed_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
  lines_json       JSONB        NOT NULL,
  PRIMARY KEY (recipe_id, lang)
);

CREATE TABLE nutrition_alias (
  lang     TEXT NOT NULL,
  alias    TEXT NOT NULL,        -- already lemma-normalised
  fdc_id   BIGINT NOT NULL,
  density  NUMERIC(7,3),         -- g/ml; null = use USDA serving
  weight   REAL NOT NULL DEFAULT 1.0,
  PRIMARY KEY (lang, alias)
);
```

USDA data lives in **read-only** tables `usda_food`,
`usda_nutrient`, refreshed by a quarterly cron (separate
container `nutrition-ingest`, off the hot path).

## 6. Flutter integration

### 6.1 Read path — list card and details

Two surfaces consume nutrition:

**Recipe-list card** ([recipe_card.dart](../../recipe_list/lib/ui/recipe_card.dart))
gains a one-line nutrition strip immediately **after** the
existing "ingredients" string. Layout (LTR/RTL mirrored):

```
┌───────────────────────────────────────────────────────┐
│  [photo]                                              │
│  Teriyaki Chicken Casserole                           │
│  Chicken · Japanese                                    │
│  Ingredients: chicken, soy sauce, brown sugar, ...    │  ← existing
│  612 kcal · P 24% · F 16% · C 60%                     │  ← NEW
│  ★ 4.6 (18) · ♥ 42                                    │
└───────────────────────────────────────────────────────┘
```

- Data source: the `summary` projection (§4.1
  `GET /recipes/:id/summary`) denormalised onto the card row by
  the user-portal — **no extra HTTP round-trip per card**.
- When `coverage < 0.6` the strip renders as "≈ 612 kcal · …" with
  a light "estimate" tone; when nutrition rows are missing
  entirely the strip is hidden (the card height is unchanged
  because the strip occupies the rating row's leading edge —
  see widget code below).
- The strip is non-interactive on the list — tap propagates to
  the card's existing details navigation.

**Recipe-details page**
([recipe_details_page.dart](../../recipe_list/lib/ui/recipe_details_page.dart))
renders a `NutritionCard` block immediately **after** the
ingredients section (and before instructions). Layout:

```
Ingredients
  • 200 g rice
  • 400 g chicken thigh
  • …

┌─ Nutrition (per serving) ─────────────────────────────┐
│  612 kcal                                             │
│  ┌─────────┬──────────┬──────────┐                    │
│  │ Protein │   Fat    │  Carbs   │  ← bar / pie       │
│  │  24%    │   16%    │   60%    │                    │
│  │  28 g   │   19 g   │   71 g   │                    │
│  └─────────┴──────────┴──────────┘                    │
│                                          [ Details ▸ ] │  ← NEW
└───────────────────────────────────────────────────────┘

Instructions
  1. …
```

- The "Details" button opens a modal sheet
  (`NutritionDetailsSheet`) that fills the data from
  `GET /recipes/:id/full` (§4.1). Loading state is a shimmer
  skeleton; error state shows "Couldn't load nutrition" with a
  retry button — never blocks the rest of the recipe.
- The sheet is sectioned: **Macros** (kcal, P/F/C with % of total
  macro grams AND % DV, plus saturated/trans/mono/poly fat,
  sugar/fiber/starch breakdown), **Vitamins**, **Minerals**.
  Each row shows `<amount> <unit> · <bar> <dv>% DV`.
- A footer line cites the DV profile (`Based on FDA 2016 adult
  daily values`) so users understand the reference diet.
- The same modal is reachable from the list card on long-press
  (web hover → "Details" tooltip), as a convenience.

### 6.2 Add-recipe form

`add_recipe_page.dart` calls `POST /preview` debounced 600 ms
after the last edit. The macros pie + total kcal update inline.
A red "?" badge marks unresolved lines, tap → opens a small
chooser populated by `GET /alias/suggest?q=<line>&lang=<lang>`.

### 6.3 Models

```dart
/// Compact summary shipped on every list card via /recipes/page
/// (denormalised, no extra HTTP).
class RecipeNutritionSummary {
  final double calories;        // per serving, kcal
  final int proteinPercent;     // % of (P+F+C) grams
  final int fatPercent;
  final int carbPercent;
  final double coverage;
}

/// Full payload for /recipes/:id (details page block).
class RecipeNutrition {
  final int recipeId;
  final int servingsAssumed;
  final NutritionFacts perServing;
  final NutritionFacts perHundredGrams;
  final double coverage;
  final List<NutritionLine> lines;
}

/// Detailed payload for /recipes/:id/full (Details modal).
/// Adds vitamin / mineral maps and DV percentages.
class RecipeNutritionFull extends RecipeNutrition {
  final NutritionFatBreakdown fat;        // sat / trans / mono / poly
  final NutritionCarbBreakdown carbs;     // sugar / fiber / starch
  final double cholesterolMg;
  final double sodiumMg;
  final double waterG;
  final Map<String, NutrientAmount> vitamins;  // 'a_mcg' → {amount, dv}
  final Map<String, NutrientAmount> minerals;  // 'iron_mg' → {amount, dv}
  final String dvProfile;                 // e.g. 'fda-2016-adult'
}

class NutritionFacts {
  final double calories;
  final Macro protein, fat, carbs;
  final double weightGrams;
}
class Macro {
  final double grams;
  final int percent;        // % of macro-gram total (P+F+C)
  final int? dv;            // % of daily value, when available
}
class NutrientAmount {
  final double amount;
  final String unit;        // 'mg', 'mcg', 'g'
  final int? dv;
}
```

### 6.4 Admin UI

`/admin/nutrition` route (web only, gated behind existing admin
role). Two tabs:

- **Unresolved** — list from §4.3 `GET /unresolved`, click a row
  → search USDA → `POST /alias`.
- **Misclassified** — flagged by users via the "Report wrong
  nutrition" link in the card.

## 7. Rollout

1. **Stage 0 — ingest cron.** Stand up `nutrition-ingest`, load
   USDA, materialise indices, no API yet.
2. **Stage 1 — read-only API for TheMealDB.** Backfill all 281
   seed recipes in English. Verify coverage > 0.85 average.
3. **Stage 2 — Flutter card on details page (en only).**
   - Adds the kcal + P/F/C bar block on the details page (§6.1).
   - Adds the kcal + P/F/C strip on the recipe-list card,
     populated from the denormalised `summary` projection
     (§4.1 `GET /recipes/:id/summary`) so list payloads stay
     fast.
   - Behind a feature flag (`nutrition.enabled`).
4. **Stage 2.5 — "Details" modal** with full nutrient + vitamin
   + mineral table (§4.1 `GET /recipes/:id/full`). Same flag.
5. **Stage 3 — multilingual.** Hook translation pipeline events,
   build per-lang alias maps from Wikidata.
6. **Stage 4 — preview API + add-recipe form.**
7. **Stage 5 — admin tools** (unresolved queue, alias editor).
8. **Stage 6 — public.** Flip the feature flag, document the API
   in [project_docs.md](../../project_docs.md).

## 8. Operational notes

- USDA bulk download is ~700 MB; pinned in a named volume
  `nutrition_usda` so container rebuilds don't re-download.
- Container memory budget: ~1.2 GB resident (inverted index +
  pymorphy3 dictionaries). Falls within the existing 4 GB host
  budget.
- Worker count = `min(2, vCPU)`; CPU-bound parse averages ~120 ms
  per recipe cold, ~5 ms warm.
- Failure modes are ALL non-fatal — the SPA hides the card if
  the API 5xx's; recipe pages keep rendering. The prerender
  service does **not** depend on this service (we don't put
  macros into og:* atoms in stage 1; revisit if SEO calls for
  it).

## 9. Out of scope (future work)

- Glycemic index, fibre, cholesterol, sodium, vitamins. The
  schema reserves a JSONB `extras` column for these; UI work
  separate.
- Allergen detection (gluten, lactose, nuts). Doable from FDC's
  `food_attribute` table but cross-cuts the recipe domain.
- Cooking-loss models (frying loses water, baking concentrates
  sugars). USDA's `Cooked` rows cover the common cases — the
  parser already prefers a `Cooked` variant when the instruction
  text mentions a heat verb, but there's no whole-recipe
  thermodynamic model.
- AI-generated nutrition for fully unresolved recipes. Cheap to
  add (one LLM call), but the failure mode (confident
  hallucinated calories) is worse than the empty state.
