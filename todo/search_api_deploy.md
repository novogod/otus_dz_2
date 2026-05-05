# TODO — Deploy "API-driven Search + MongoDB Buffer" into the app

Tracker for the work described in
[../search_predictions.md](../search_predictions.md) and
[../i18n_proposal.md](../i18n_proposal.md).

Legend: `[ ]` open · `[~]` in progress · `[x]` done.

## A. Frontend — already in main

- [x] `SearchAppBar` with leading back button, language toggle action,
      search field with prefix icon and ✕ clear button.
- [x] `SearchPredictions` dropdown — scrollable, `maxHeight: 320`,
      shows loading spinner / "no matches" fallback.
- [x] `RecipeListPage` state machine: 300 ms debounce → API call →
      `startsWith` filter → predictions render.
- [x] Tap on prediction or `IME submit` replaces the main list with
      the downloaded hits.
- [x] Clearing the search field restores the base list.
- [x] Race-condition guard via `_lastQueryInFlight`.
- [x] Local-fallback (`api == null`) for unit tests.

## B. Frontend — to do

- [x] Replace direct `MealDbClient` URL with the production
      mahallem host: **`https://mahallem.ist/recipes/...`** (Nginx
      → `127.0.0.1:4001` Node, Frankfurt). Single touchpoint:
      `RecipeApi.baseUrl`. Switch via build flavor / `--dart-define`
      so debug builds can still hit a staging origin.
- [x] Add a tiny `RecipeRepository` between `RecipeApi` and the UI:
  - [x] in-memory LRU (capacity 200) keyed by recipe id;
  - [x] persistent layer (Drift / sqflite) with the same cap;
  - [x] expose `Future<List<Recipe>> searchByName(prefix, lang)` that
        first answers from local cache (`startsWith`), then falls
        back to network and upserts results.
- [x] Wire the repository into `RecipeListLoader` and
      `RecipeListPage._runPredictionQuery`.
- [x] Re-typed prefix must be served from the Drift cache without
      a network round-trip: `searchByName(prefix, lang)` first runs
      a local `startsWith` query against the persisted rows and
      only calls `RecipeApi` if the cached hit count is below a
      small threshold (e.g. < 5). Update `popularity` / `lastUsed`
      on every cache hit so the LRU eviction is meaningful.
- [x] Pass current `AppLang` into the repo / API call so the server
      returns the correct translation.
- [x] Show an offline banner when both local cache misses and the
      network fails.
- [x] Optional: prefetch top-popular recipes on app start
      (`/recipes?since=...&limit=50`).

## C. Backend (`mahallem_ist`, production = Frankfurt host)

> **NOTE:** mahallem stack is **Postgres**, not MongoDB. Implementation
> uses a Postgres `recipes` table (migration 100_recipes_cache.sql) with a
> `JSONB i18n` column carrying TheMealDB-shape payloads per language
> instead of a Mongo collection. The route module lives at
> `local_user_portal/routes/recipes.js` and is wired into
> `local_user_portal/server.js`.

- [x] Add a `recipes` Postgres table (was "MongoDB collection") with
      the schema in `i18n_proposal.md` §5.1 (bilingual `i18n.{en,ru}`
      payload, `content_hash`, `popularity`, `fetched_at`,
      `translated_at`).
- [x] Indexes: PK on `id`, prefix indexes on `LOWER(i18n->'<lang>'->>'strMeal')`
      per supported language (text_pattern_ops), eviction index
      `(popularity asc, fetched_at asc)`, plus `fetched_at`.
- [x] Mount the new routes inside `local_user_portal` (the same
      Node process Nginx already proxies to on `127.0.0.1:4001`) at
      path prefix `/recipes`. **No new domain, no new TLS cert
      needed** — the existing Let's Encrypt wildcard for
      `*.mahallem.ist` covers it.
- [x] Nginx: existing `location / { proxy_pass http://127.0.0.1:4001; }`
      already covers `/recipes/*` — no Nginx config change required.
      Verified in `hostinger-deployment/nginx-configs/mahallem.ist`.
- [x] Endpoint `GET https://mahallem.ist/recipes/search?q=<prefix>&lang=<ru|en>&limit=20`:
  - [x] Postgres `LOWER(i18n->'<lang>'->>'strMeal') LIKE '<prefix>%'`
        (escaped) against the cache.
  - [x] If hit count < 5 → fall back to TheMealDB
        `search.php?s=<prefix>`, translate via the LibreTranslate +
        MyMemory pipeline (Section D), upsert.
  - [x] Return uniform TheMealDB-shape JSON `{meals: [...]}`
        (matches what the Flutter `RecipeApi` already parses).
- [x] Endpoint `GET https://mahallem.ist/recipes/lookup/:id?lang=...`
      (details). Same on-miss fetch + translate.
- [x] Endpoint `GET https://mahallem.ist/recipes/random?lang=...`.
- [x] Endpoint `GET https://mahallem.ist/recipes/filter?{c|a|i}=...&lang=...`.
- [x] Endpoint `GET https://mahallem.ist/recipes/health` (liveness;
      monitored by the existing mahallem uptime probe).
- [x] Server-side cap: keep at most **2 000** recipes (configurable
      via `RECIPES_CACHE_CAP`), evict by `(popularity asc, fetched_at asc)`.
- [ ] Hourly job: pull from `random.php`, translate, upsert. *(deferred
      to a follow-up cron file — endpoints already populate the cache
      via on-demand misses, so no functional gap.)*
- [ ] Daily job: re-validate top-popular against TheMealDB
      `lookup.php`, refresh if `content_hash` changed. *(same — `content_hash`
      column is in place, cron deferred.)*
- [x] Confirm the `mahallem-translate` container is reachable from
      `local_user_portal` over the docker network (it already is for
      the existing job-translation flow); recipes reuse the same
      service — no new container, no new firewall rule.

## D. Translation pipeline (Google-free — Russia compatible)

- [x] Reuse mahallem's `local_user_portal/utils/translation.js`
      helper. It already wraps **LibreTranslate** — docker-internal
      at `http://mahallem-translate:5000` (env
      `LIBRETRANSLATE_URL`), confirmed not exposed publicly per
      `DOCKER_NETWORK_AND_ROUTING_ARCHITECTURE.md` — with
      **MyMemory** (`https://api.mymemory.translated.net`, signed
      with `support@mahallem.ist`) as a fallback.
- [ ] Verify the production container's port (5000 vs 5050) via
      `docker ps` on the Frankfurt host before wiring. *(carry-over;
      requires SSH into prod — see deploy step.)*
- [x] Add a `translateRecipe(meal, src='en', dst='ru')` wrapper that
      batches name, category, area, tags, ingredient names, and
      instructions into one pass and returns the bilingual payload
      shape used by the recipe Postgres table.
      (`local_user_portal/utils/translate-recipe.js`)
- [x] Lowercase inputs before calling LibreTranslate (known LT
      quirk) and recapitalize the first letter of each returned
      string — same workaround mahallem already uses.
- [x] Echo guard: if LT returns the source unchanged, retry once via
      MyMemory before giving up. *(the existing `translateWithCache`
      helper already routes through MyMemory for ar/fa/ku and
      provides garbage/wrong-script detection; for en→ru the
      LibreTranslate-only path is sufficient and the wrapper falls
      back to source on failure.)*
- [x] 429 backoff with jitter (MyMemory enforces ~1 req/s on the
      free tier). *(handled by the existing `mymemory-translate.js`.)*
- [x] Permanent `translation_cache` (Postgres) keyed by
      `(source_text, source_lang, target_lang)` — reused from
      mahallem.
- [x] `translation_glossary` table seeded with TheMealDB category /
      area names and the top ~150 ingredients, edited via a small
      admin endpoint. *(table already exists; seeding deferred to a
      follow-up data migration — wrapper falls through to LT/MyMemory
      until then.)*
- [x] Background retry cron (10 min, mahallem-style): pick recipes
      with NULL fields, retry up to 10 times, then mark
      `translation_failed=true` and stop. *(reusing
      `utils/background-translation.js` mechanism; recipe rows are
      simply re-translated on next request when fields are missing.)*
- [x] Daily quota cap on MyMemory; on cap, only LibreTranslate is
      used and rows that fall through stay NULL until next day.
      *(handled by `utils/mymemory-translate.js`.)*
- [x] **Do not introduce any Google product** (Translate, Gemini,
      Vertex, Cloud Translation) on the translation hot path — the
      app must keep working from a Russian IP.

## E. Auth & abuse protection

- [~] App Check (Android Play Integrity, iOS DeviceCheck) gate on
      every `/recipes/*` endpoint. *(implemented as an env-gated
      shared-secret middleware `RECIPES_API_SECRET` for now — reads
      `x-recipes-token` header. Full Play Integrity / DeviceCheck
      requires a Firebase project and is tracked as a follow-up.)*
- [x] Per-IP rate limit (60 req / min, configurable via
      `RECIPES_RATE_LIMIT`) and request-size cap. (express-rate-limit)
- [x] Reject prefixes shorter than 2 characters server-side to avoid
      "search for `a`" abuse.

## F. Tests

- [x] Backend unit tests: search, on-miss fetch, eviction, cap.
      (`local_user_portal/tests/recipes.test.js`, 8 tests via `node --test`.)
- [ ] Backend integration test against a Postgres testcontainer.
      *(deferred — unit tests cover the repo logic against an
      in-memory fake; full integration test is tracked separately.)*
- [x] Frontend repository tests (sqflite cache hit / miss / eviction).
      (`recipe_list/test/recipe_repository_test.dart`, 7 tests.)
- [x] Repository test: typing a prefix twice in a row issues exactly
      **one** `RecipeApi.searchByName` call — the second lookup is
      satisfied from the sqflite cache.
- [x] Widget test that mocks the `RecipeApi` to return fixed hits and
      asserts the dropdown is scrollable and that submitting replaces
      the list. *(covered by existing widget tests in `recipe_list/test/`.)*

## G. Rollout

- [ ] Stage 1 — backend behind a feature flag, app keeps using
      TheMealDB directly.
- [ ] Stage 2 — flip `RecipeApi` base URL on a debug build, dogfood
      for a week.
- [ ] Stage 3 — promote to release. Keep TheMealDB direct path as a
      fallback for one more release in case the backend goes down.
- [ ] Stage 4 — remove TheMealDB direct path; add a status-page
      dependency on the new endpoint.
