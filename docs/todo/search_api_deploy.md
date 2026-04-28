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

- [ ] Replace direct `MealDbClient` URL with the new
      `https://api.<our-domain>/recipes/...` once the backend ships.
      Single touchpoint: `RecipeApi`.
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

## C. Backend (`mahallem_ist`)

- [ ] Add a `recipes` MongoDB collection with the schema in
      `i18n_proposal.md` §5.1 (bilingual `i18n.{en,ru}` payload,
      `contentHash`, `popularity`, `fetchedAt`, `translatedAt`).
- [ ] Indexes: `_id`, text index on `i18n.en.name` + `i18n.ru.name`,
      `fetchedAt`.
- [ ] Endpoint `GET /recipes/search?q=<prefix>&lang=<ru|en>&limit=20`:
  - [ ] Mongo regex `^<prefix>` (case-insensitive) against
        `i18n.<lang>.name`.
  - [ ] If hit count < 5 → fall back to TheMealDB
        `search.php?s=<prefix>`, translate via Gemini, upsert.
  - [ ] Return uniform `Recipe` JSON.
- [ ] Endpoint `GET /recipes/:id?lang=...` (details). Same on-miss
      fetch + translate.
- [ ] Endpoint `GET /recipes?since=<iso>&lang=...&limit=200` for
      incremental sync.
- [ ] Server-side cap: keep at most **2 000** recipes, evict by
      `(popularity asc, fetchedAt asc)`.
- [ ] Hourly job: pull from `random.php`, translate, upsert.
- [ ] Daily job: re-validate top-popular against TheMealDB
      `lookup.php`, refresh if `contentHash` changed.

## D. Translation pipeline

- [ ] Server module that batches recipe fields into a single Gemini
      prompt (`gemini-1.5-flash`).
- [ ] Re-uses `GEMINI_API_KEY` from
      `local_docker_admin_backend/.env` — never reaches the Flutter
      binary.
- [ ] Echo guard: if Gemini returns the source unchanged, retry once
      with a stricter prompt.
- [ ] 429 backoff with jitter.
- [ ] Daily token / cost cap; on cap, return source language only
      and log a warning.

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
