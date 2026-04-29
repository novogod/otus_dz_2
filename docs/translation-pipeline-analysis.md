# Translation pipeline — implementation analysis & TODO

Companion to [`translation-pipeline.md`](translation-pipeline.md).
Goes through every step of the contract and verifies the running code.

Reviewed at commit `mahallem_ist@7fe530b8` and `recipe_list/main` on
2026-04-28.

## Mapping the spec to source

| Step                                         | Code path                                                                  | Status |
| -------------------------------------------- | -------------------------------------------------------------------------- | ------ |
| 1. Lang button → query in-app DB             | `RecipeListLoader._onLangChanged` → `_retranslate` → `repo.lookupManyCached` | ✅ |
| 2. Found → render                            | `firstPass[idx] = cached[id]`, no HTTP                                     | ✅ |
| 3a. Miss → app asks in-app DB                | `repo.lookup(id, lang)` SELECT first                                       | ✅ |
| 3b. In-app DB asks mahallem                  | `_api.lookup(id, lang)` over Dio                                           | ✅ |
| 3c. Mahallem returns → in-app DB stores forever | `_upsert` with no TTL; LRU only on byte/row cap                          | ✅ |
| 4a. Mahallem miss → translates               | `_ensureLang` → `translateRecipe` → `translateBest` cascade                | ✅ |
| 4b. Mahallem stores forever                  | `cacheTranslation` `INSERT … ON CONFLICT DO NOTHING` + `recipes.i18n` JSONB | ✅ |
| 5. Loading page until all done               | `_translating = true` → `build()` returns `_LoadingScreen`                 | ✅ |

## Detailed analysis

### ① Local SQLite cache — `recipe_list/lib/data/local/recipe_db.dart`

```sql
CREATE TABLE recipes (
  id INTEGER, lang TEXT, …, last_used_at INTEGER, byte_size INTEGER,
  PRIMARY KEY (id, lang)
);
```

- ✅ Persistent (path_provider/getApplicationSupportDirectory).
- ✅ No TTL: `_evictIfOverCap` evicts only when total bytes > 5 MB or
  rows > 2000, oldest `last_used_at` first.
- ⚠️ Schema version = 3; bumping it drops the table (intentional, but
  flagged: a future version bump will erase user-acquired translations,
  forcing a full re-fetch).

### ② Repository — `recipe_list/lib/data/repository/recipe_repository.dart`

- ✅ `lookupManyCached(ids, lang)` — single bulk SQL, no network.
  Used on language switch.
- ✅ `lookup(id, lang)`: cache → network → upsert. Returns null only
  when both fail.
- ⚠️ `_upsertAll` uses `ConflictAlgorithm.replace`. This **is** an
  overwrite, contrary to a strict reading of "stored forever, never
  overwritten". However, in this architecture overwrite is benign:
  the server is the immutable source of truth, so re-fetching the
  same `(id, lang)` returns byte-identical content. We keep `replace`
  because it allows a "lite" row (only id+name+photo from the
  category-filter endpoint) to be upgraded to a full row when
  `/lookup` later returns instructions/ingredients. **No fix needed**;
  documented in `translation-pipeline.md` §3.

### ③ Loader — `recipe_list/lib/ui/recipe_list_loader.dart`

- ✅ `_translating` flag: `build()` returns `_LoadingScreen` whenever
  `_translating == true`, suppressing partial lists.
- ✅ Progress: `_stage` updated after every batch of 8 lookups.
- ✅ Concurrency cap (8) matches server `LT_MAX_CONCURRENCY=6` plus
  one queued.
- ✅ On `lookup` failure, original-lang `Recipe` remains in slot;
  nothing is cached as that lang.
- ✅ `_runLoad` cold start: respects `countFor(lang) ≥ 50` cache-hit
  threshold; otherwise seeds via `filterByCategory` (server returns
  already-translated payloads via `?lang=…&full=1`).

### ④ Server `translation_cache` — `local_user_portal/utils/translation.js`

- ✅ `getCachedTranslation` returns immediately on hit (UPDATE
  last_hit_at + hit_count, then RETURNING translated_text). Echo
  rows (translated == source) are deleted defensively.
- ✅ `cacheTranslation` writes `INSERT … ON CONFLICT DO NOTHING` —
  immutable.

### ⑤ Server pipeline — `local_user_portal/utils/translate-recipe.js`

- ✅ `translateBest` is a strict 2-tier pipeline: glossary →
  primary engine → Gemini fallback. No MyMemory, no public LT.
- ✅ `evaluateCandidate` rejects garbage / wrong-script / echo
  candidates before they reach `cacheTranslation`.
- ✅ Engine assignment table matches the contract.

### ⑥ Server endpoints — `local_user_portal/routes/recipes.js`

- ✅ `_ensureLang(row, lang)` checks `row.i18n[lang]` first; only on
  miss does it call `translateRecipe`. On success, `UPDATE recipes
  SET i18n = $1::jsonb WHERE id = $2` writes the whole blob — meaning
  subsequent `/lookup` calls for the same `(id, lang)` skip the
  per-string pipeline entirely.
- ✅ Echo detection (`_isEchoTranslation`): a fully-echoed translation
  is served to the caller but **not** persisted, so the next request
  retries. Matches server cache rule #3.

## TODO

Nothing actionable from a correctness standpoint — the contract is
already met. Items below are observability / hygiene polish.

- [ ] **(P3) Cleanup unused imports.**
  `recipe_list/lib/data/api/recipe_api.dart` no longer needs
  `MyMemory`/`publicLT` references — already clean. Verify
  `mahallem_ist/local_user_portal/utils/libretranslate-public.js`
  is not imported anywhere and delete it in a follow-up commit.
- [ ] **(P3) Migration safety.**
  When `kRecipeDbSchemaVersion` is bumped next, write an additive
  migration instead of `DROP TABLE`. Currently a schema bump throws
  away every user-cached translation.
- [ ] **(P3) Telemetry.**
  Optional: add a counter of cache-hit vs network-miss in
  `_retranslate` exposed via debug overlay so QA can verify the
  4-tier flow visually on device.
- [ ] **(P3) Empty-state UX on partial offline.**
  If 30 of 200 recipes fail to translate (network drop mid-batch),
  the user gets 30 untranslated cards mixed in. Today: silently
  rendered. Could show a one-line banner "30 recipes could not be
  translated, tap to retry".

None of these block the contract; all are deferred.

## Verification plan (executed below)

1. iOS simulator (`8BD26741-3207-42F9-A0D4-55D0CC63AED0`):
   fresh install, switch to Persian (no local cache), watch logs.
2. Android emulator (`emulator-5554`):
   fresh install, switch to German, watch logs.
3. For each: confirm the four observable signals
   - `/recipes/lookup` HTTP 200 with `lang=` set;
   - server log line `Cache HIT [en→…]` for repeat translations;
   - server log line `via gemini|local-libretranslate` for first calls;
   - app: loading screen → list page transition (no flicker).
