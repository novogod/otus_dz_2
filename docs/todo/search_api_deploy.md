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

- [ ] Replace direct `MealDbClient` URL with the production
      mahallem host: **`https://mahallem.ist/recipes/...`** (Nginx
      → `127.0.0.1:4001` Node, Frankfurt). Single touchpoint:
      `RecipeApi.baseUrl`. Switch via build flavor / `--dart-define`
      so debug builds can still hit a staging origin.
- [ ] Add a tiny `RecipeRepository` between `RecipeApi` and the UI:
  - [ ] in-memory LRU (capacity 200) keyed by recipe id;
  - [ ] persistent layer (Drift / sqflite) with the same cap;
  - [ ] expose `Future<List<Recipe>> searchByName(prefix, lang)` that
        first answers from local cache (`startsWith`), then falls
        back to network and upserts results.
- [ ] Wire the repository into `RecipeListLoader` and
      `RecipeListPage._runPredictionQuery`.
- [ ] Pass current `AppLang` into the repo / API call so the server
      returns the correct translation.
- [ ] Show an offline banner when both local cache misses and the
      network fails.
- [ ] Optional: prefetch top-popular recipes on app start
      (`/recipes?since=...&limit=50`).

## C. Backend (`mahallem_ist`, production = Frankfurt host)

- [ ] Add a `recipes` MongoDB collection with the schema in
      `i18n_proposal.md` §5.1 (bilingual `i18n.{en,ru}` payload,
      `contentHash`, `popularity`, `fetchedAt`, `translatedAt`).
- [ ] Indexes: `_id`, text index on `i18n.en.name` + `i18n.ru.name`,
      `fetchedAt`.
- [ ] Mount the new routes inside `local_user_portal` (the same
      Node process Nginx already proxies to on `127.0.0.1:4001`) at
      path prefix `/recipes`. **No new domain, no new TLS cert
      needed** — the existing Let's Encrypt wildcard for
      `*.mahallem.ist` covers it.
- [ ] Add a `location /recipes/ { proxy_pass http://127.0.0.1:4001; }`
      block to `hostinger-deployment/nginx-configs/mahallem.ist`
      (or just rely on the existing root proxy if it already covers
      `/`).
- [ ] Endpoint `GET https://mahallem.ist/recipes/search?q=<prefix>&lang=<ru|en>&limit=20`:
  - [ ] Mongo regex `^<prefix>` (case-insensitive) against
        `i18n.<lang>.name`.
  - [ ] If hit count < 5 → fall back to TheMealDB
        `search.php?s=<prefix>`, translate via the LibreTranslate +
        MyMemory pipeline (Section D), upsert.
  - [ ] Return uniform `Recipe` JSON.
- [ ] Endpoint `GET https://mahallem.ist/recipes/:id?lang=...`
      (details). Same on-miss fetch + translate.
- [ ] Endpoint `GET https://mahallem.ist/recipes?since=<iso>&lang=...&limit=200`
      for incremental sync.
- [ ] Endpoint `GET https://mahallem.ist/recipes/health` (liveness;
      monitored by the existing mahallem uptime probe).
- [ ] Server-side cap: keep at most **2 000** recipes, evict by
      `(popularity asc, fetchedAt asc)`.
- [ ] Hourly job: pull from `random.php`, translate, upsert.
- [ ] Daily job: re-validate top-popular against TheMealDB
      `lookup.php`, refresh if `contentHash` changed.
- [ ] Confirm the `mahallem-translate` container is reachable from
      `local_user_portal` over the docker network (it already is for
      the existing job-translation flow); recipes reuse the same
      service — no new container, no new firewall rule.

## D. Translation pipeline (Google-free — Russia compatible)

- [ ] Reuse mahallem's `local_user_portal/utils/translation.js`
      helper. It already wraps **LibreTranslate** — docker-internal
      at `http://mahallem-translate:5000` (env
      `LIBRETRANSLATE_URL`), confirmed not exposed publicly per
      `DOCKER_NETWORK_AND_ROUTING_ARCHITECTURE.md` — with
      **MyMemory** (`https://api.mymemory.translated.net`, signed
      with `support@mahallem.ist`) as a fallback.
- [ ] Verify the production container's port (5000 vs 5050) via
      `docker ps` on the Frankfurt host before wiring.
- [ ] Add a `translateRecipe(meal, src='en', dst='ru')` wrapper that
      batches name, category, area, tags, ingredient names, and
      instructions into one pass and returns the bilingual payload
      shape used by the recipe MongoDB collection.
- [ ] Lowercase inputs before calling LibreTranslate (known LT
      quirk) and recapitalize the first letter of each returned
      string — same workaround mahallem already uses.
- [ ] Echo guard: if LT returns the source unchanged, retry once via
      MyMemory before giving up.
- [ ] 429 backoff with jitter (MyMemory enforces ~1 req/s on the
      free tier).
- [ ] Permanent `translation_cache` (Postgres) keyed by
      `(source_text, source_lang, target_lang)` — reused from
      mahallem.
- [ ] `translation_glossary` table seeded with TheMealDB category /
      area names and the top ~150 ingredients, edited via a small
      admin endpoint.
- [ ] Background retry cron (10 min, mahallem-style): pick recipes
      with NULL fields, retry up to 10 times, then mark
      `translation_failed=true` and stop.
- [ ] Daily quota cap on MyMemory; on cap, only LibreTranslate is
      used and rows that fall through stay NULL until next day.
- [ ] **Do not introduce any Google product** (Translate, Gemini,
      Vertex, Cloud Translation) on the translation hot path — the
      app must keep working from a Russian IP.

## E. Auth & abuse protection

- [ ] App Check (Android Play Integrity, iOS DeviceCheck) gate on
      every `/recipes/*` endpoint.
- [ ] Per-IP rate limit (e.g. 60 req / min) and request-size cap.
- [ ] Reject prefixes shorter than 2 characters server-side to avoid
      "search for `a`" abuse.

## F. Tests

- [ ] Backend unit tests: search, on-miss fetch, eviction, cap.
- [ ] Backend integration test against a Mongo testcontainer.
- [ ] Frontend repository tests (Drift cache hit / miss / eviction).
- [ ] Widget test that mocks the `RecipeApi` to return fixed hits and
      asserts the dropdown is scrollable and that submitting replaces
      the list.

## G. Rollout

- [ ] Stage 1 — backend behind a feature flag, app keeps using
      TheMealDB directly.
- [ ] Stage 2 — flip `RecipeApi` base URL on a debug build, dogfood
      for a week.
- [ ] Stage 3 — promote to release. Keep TheMealDB direct path as a
      fallback for one more release in case the backend goes down.
- [ ] Stage 4 — remove TheMealDB direct path; add a status-page
      dependency on the new endpoint.
