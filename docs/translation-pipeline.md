# End-to-end translation pipeline (recipe_list ↔ mahallem)

**Status:** authoritative. Spec verbatim from product 2026-04-28:

> 1. On language-button press the app checks if the local in-app DB
>    already has translated pairs.
> 2. If found — read from in-app DB, render.
> 3. If not — app → in-app DB → mahallem DB → return → in-app DB stores
>    forever → returns to app.
> 4. If not in mahallem DB — mahallem requests translation → stores
>    forever → returns to in-app DB → in-app DB stores forever → returns
>    to app.
>
> During the entire process the loading page shows progress until every
> recipe is translated; only then does it route to the list page.
>
> **Quality gate (added 2026-04-28).** A translation is only stored
> "forever" if it passes mahallem's scoring system:
> `evaluateCandidate` (round-trip / Jaccard / script + length sanity)
> and the predicates `isGarbageTranslation`, `isWrongScriptTranslation`,
> `isLowQualityTranslation`, plus a per-field echo-ratio check on long
> instructions blobs. **Paid translation APIs (Gemini) are invoked
> only when the DB has no entry, the stored entry's score is low, or
> the entry is detected as wrong.** A row that fails the gate is
> served once but **NOT** persisted to either `translation_cache` or
> `recipes.i18n`, so the next request re-runs the engine pipeline.

This document is the canonical contract for both client and server. The
server-side internals are documented separately in
`mahallem_ist/docs/translation-pipeline.md`; this one covers the round
trip the user actually experiences.

## Layers

```
┌──────────────────────────────────────────────────────────────────────┐
│ Flutter app  (recipe_list)                                           │
│                                                                      │
│  ① Local SQLite cache  (data/local/recipe_db.dart)                   │
│      table recipes(id, lang, name, …, last_used_at, byte_size)      │
│      ── permanent, LRU only when over byteCap (5 MB) / cap (2000)   │
│                                                                      │
│         miss ↓                                                      │
└──────────────────────────────────────────────────────────────────────┘
                          │ HTTPS  GET /recipes/lookup/{id}?lang=…
                          ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Mahallem server  (mahallem_ist / local_user_portal)                  │
│                                                                      │
│  ② Postgres recipes.i18n JSONB   row.i18n[lang] = full meal blob    │
│         hit → return                                                │
│         miss ↓                                                      │
│                                                                      │
│  ③ translateRecipe()  (utils/translate-recipe.js)                   │
│      ↳ for each translatable string ↓                               │
│                                                                      │
│        ④ translation_cache row    UNIQUE(source_text,src,tgt)       │
│             hit → return (forever, never overwritten)               │
│             miss ↓                                                  │
│                                                                      │
│             ⑤ glossary  → cache + return                            │
│             ⑥ primary engine                                        │
│                  ar/fa/ku → Gemini                                  │
│                  else    → local LibreTranslate                     │
│             ⑦ Gemini fallback (only if primary ≠ Gemini)            │
│                                                                      │
│      Whole translated meal blob is then written to recipes.i18n     │
│      (so subsequent /lookup for the same id+lang never reaches ④).  │
└──────────────────────────────────────────────────────────────────────┘
```

## Step-by-step (matches user's 1–4 contract verbatim)

### 1. Language-button tap → check local in-app DB

`appLang.value = …` triggers `RecipeListLoader._onLangChanged`. State
becomes `_translating = true` so `build()` forces `_LoadingScreen`.

`_retranslate(prev, lang)` calls
**`RecipeRepository.lookupManyCached(ids, lang)`** — a single SQL query
against `recipes WHERE id IN (…) AND lang = ?`. No network. Returns
`Map<int, Recipe>` with every recipe already cached for that language.

### 2. Pair found → render

For every id present in the cache map, the cached `Recipe` replaces
the previous-language one in `translated[idx]`. The loading screen's
counter ticks up. **No HTTP call is made.**

### 3. Pair missing → app → in-app DB → mahallem → in-app DB stores forever

For every id NOT in `cached`, `_retranslate` falls into the parallel
batch loop (`_translateConcurrency = 8`) which calls
`repo.lookup(id, lang)`. That method:

```
RecipeRepository.lookup(id, lang)
  ├── SELECT * FROM recipes WHERE id=? AND lang=?
  │     hit (full payload, !isLite) → touch + return
  │     miss → ↓
  ├── api.lookup(id, lang)            ← HTTP GET /recipes/lookup/{id}?lang=…
  │     ok    → upsert(recipes(id, lang, …))   ← stored forever locally
  │     fail  → fall back to lite cached row if any
  └── return Recipe?
```

`_upsertAll` uses `ConflictAlgorithm.replace`, **but** because the
server is the immutable source of truth and never overwrites an
already-cached translation (see §4), every refresh writes the same
content. The "forever" rule on the user's contract concerns
**expiration** — there is no TTL, no time-based eviction; rows only
ever drop out of the local DB when the table exceeds 64 MB / 8000 rows
and the **least-recently-used** row gets bumped (`_evictIfOverCap`).

### 4. Mahallem cache miss → translate → store forever both sides

Server handler `RecipeRepository._ensureLang(row, lang)` in
`local_user_portal/routes/recipes.js`:

```
_ensureLang(row, lang)
  ├── if row.i18n[lang] exists  → return cached blob
  ├── translateRecipe(en, lang)  ── per-string pipeline (see below)
  ├── if translated == source (echo) → serve, do NOT persist
  └── UPDATE recipes SET i18n = $1::jsonb WHERE id = $2
       → cached forever in Postgres
```

Per-string `translateBest(text, src, tgt)` in
`utils/translate-recipe.js`:

```
translateBest
  ├── ④ getCachedTranslation(text, src, tgt)
  │       SELECT translated_text FROM translation_cache
  │       hit → UPDATE last_hit_at, hit_count + return
  ├── ⑤ glossary[text]
  ├── ⑥ primary engine
  │       ar/fa/ku → Gemini
  │       else    → local LibreTranslate (LT_MAX_CONCURRENCY=6)
  ├── ⑦ Gemini fallback (only if primary ≠ Gemini)
  └── on accept: cacheTranslation(...)
        INSERT INTO translation_cache (...) VALUES (...)
        ON CONFLICT (source_text, source_lang, target_lang)
        DO NOTHING                       ← immutable forever
```

`DO NOTHING` guarantees the user's "stored forever, never overwritten"
clause: the first engine to produce an accepted translation wins; all
subsequent calls for the same triple short-circuit on the cache hit
**before** any engine is invoked.

### 5. Loading page shows progress until every recipe is translated

`RecipeListLoader._stage` is a `ValueNotifier<_LoadStage>` updated
after every batch of `_translateConcurrency` lookups:

```
_stage.value = _LoadStage.fetching(
  done: cached.length + completedNetworkBatches,
  total: prev.recipes.length,
  …
);
```

While `_translating == true`, `build()` returns `_LoadingScreen` —
not the recipe list — regardless of `FutureBuilder` snapshot state.
Only when `_retranslate(...)` resolves and `setState(() =>
_translating = false)` runs does the page swap to `RecipeListPage`.

## What the contract guarantees

- **No engine fan-out from the app.** The Flutter app makes exactly
  one HTTP call per missing recipe per language: `/recipes/lookup/{id}?lang=`.
- **No cache rewrites.** Server-side `translation_cache` is immutable;
  client-side `recipes` is functionally immutable (server returns the
  same blob).
- **No flicker.** `_translating` keeps the loader on screen; the app
  never shows half-English / half-target lists.
- **Bounded latency.** Cold language: ≈ N × (1–4 s) for N recipes,
  parallelized 8-wide. Warm language: single bulk SELECT, sub-50 ms.
- **Offline tolerance.** If `/lookup` fails, the previous-language
  copy stays on screen; the next press of the language button retries.

## File map

| concern | file |
| ------- | ---- |
| local schema, open db | `recipe_list/lib/data/local/recipe_db.dart` |
| repository (cache + api) | `recipe_list/lib/data/repository/recipe_repository.dart` |
| HTTP client | `recipe_list/lib/data/api/recipe_api.dart` |
| loading orchestration | `recipe_list/lib/ui/recipe_list_loader.dart` |
| server endpoints | `mahallem_ist/local_user_portal/routes/recipes.js` |
| server pipeline | `mahallem_ist/local_user_portal/utils/translate-recipe.js` |
| server cache layer | `mahallem_ist/local_user_portal/utils/translation.js` |

## Change log

- **2026-04-28 (a).** Server cascade collapsed 6 → 2 tiers, cache made
  immutable (`DO NOTHING`), MyMemory and public LT removed.
- **2026-04-28 (b).** This document authored: end-to-end client+server
  contract is now canonical and mirrors the implementation 1:1.
- **2026-04-28 (c).** Scoring gate made authoritative: persistence to
  both `translation_cache` AND `recipes.i18n[lang]` is conditional on
  passing `evaluateCandidate` + echo-ratio. Long-instruction fields
  with mostly-English residue are no longer written to `recipes.i18n`,
  preventing cache-poisoning. Paid APIs (Gemini) are invoked **only**
  when the DB has no entry, score is low, or content is detected as
  wrong (script mismatch, latin residue ≥ threshold, byte/sentence
  echo of source).
