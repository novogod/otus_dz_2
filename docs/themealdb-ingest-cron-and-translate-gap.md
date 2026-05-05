# TheMealDB daily ingest cron — feature spec + auto-translate gap

> Companion to [`docs/recipe-ingester-and-size-cap.md`](recipe-ingester-and-size-cap.md).
> Created 2026-05-05 to document the running production cron in
> detail and capture the diagnosis of why freshly-ingested recipes
> never get translated into the non-English locales.

## 1. What the cron does

### 1.1 Origin

* Spec: [`docs/todo/recipe_ingester_and_size_cap.md`](todo/recipe_ingester_and_size_cap.md)
  + [`docs/recipe-ingester-and-size-cap.md`](recipe-ingester-and-size-cap.md).
* Single commit in this repo that documents it: `1c9015b56`
  ("docs: backend ingester + 1.5 GB byte-cap для recipes",
  2026-05-05). The backend implementation itself lives in the
  separate `local_user_portal` express service and was deployed by
  hand (`scp` + `docker cp` + restart) — there is no commit in
  `otus_dz_2` that ships server code.

### 1.2 Where the code lives in production

| Item                | Path                                                                                   |
| ------------------- | -------------------------------------------------------------------------------------- |
| Container           | `mahallem-user-portal`                                                                 |
| In-container source | `/app/routes/recipes.js`                                                               |
| Host source         | `/root/mahallem/mahallem_ist/local_user_portal/routes/recipes.js`                      |
| Cron library        | `node-cron` (already in image, single-replica assumed)                                 |
| Companion job       | `/app/lib/jobs/warmup-recipes.js` (`scheduleWarmupOnStart` from `server.js`)           |

### 1.3 Trigger and schedule

```js
// routes/recipes.js — Express wiring (~line 905)
if (INGEST_ENABLED && !opts.disableIngestCron) {
  cron.schedule(
    INGEST_CRON,                       // default: '0 4 * * *'
    () => repo.runDailyIngest()
                .catch((e) => console.error('[ingest] cron handler failed', e)),
    { timezone: INGEST_TIMEZONE },     // default: Europe/Istanbul
  );
  console.log(`[ingest] scheduled "${INGEST_CRON}" tz=${INGEST_TIMEZONE}`);
}
```

| Env var                          | Default      | Purpose                                 |
| -------------------------------- | ------------ | --------------------------------------- |
| `RECIPES_INGEST_ENABLED`         | `true`       | Kill switch                             |
| `RECIPES_INGEST_CRON`            | `0 4 * * *`  | Cron expression (04:00 daily)           |
| `RECIPES_INGEST_TZ` (or `TZ`)    | `Europe/Istanbul` | Timezone for the schedule          |
| `RECIPES_INGEST_BATCH_SIZE`      | `10`         | Target number of new meals per run      |
| `RECIPES_INGEST_MAX_PROBES`      | `50`         | Consecutive 404 misses tolerated        |
| `RECIPES_INGEST_PROBE_DELAY_MS`  | `150`        | Sleep between upstream probes           |
| `RECIPES_USER_MEAL_ID_FLOOR`     | `1_000_000`  | Boundary between TheMealDB ids and user-submitted ids |

### 1.4 What runs in `repo.runDailyIngest()`

`routes/recipes.js` ~line 541. Single pass, in-memory re-entrancy
guard `_ingestRunning`:

1. `SELECT COALESCE(MAX(id), 0)::bigint FROM recipes WHERE id < $FLOOR`
   → start probing at `MAX(id) + 1` so we never re-probe rows we
   already own and never collide with user-submitted ids.
2. While `ingested < INGEST_BATCH_SIZE` **and**
   `consecutiveMisses < INGEST_MAX_PROBES` **and**
   `probed < max(maxProbes, batch * 5)`:
   * `GET https://www.themealdb.com/api/json/v1/1/lookup.php?i=<id>`
   * On hit: `await this.upsertEnglish(meal)` → row inserted with
     `i18n = { en: <canonicalized meal> }`, `popularity = 0`,
     `fetched_at = NOW()`. `consecutiveMisses` resets.
   * On miss (`meals: null`): `consecutiveMisses += 1`.
   * On HTTP error: caught locally, `consecutiveMisses += 1` and
     a `[ingest] probe id=<id> failed: <msg>` warning is logged.
   * `id += 1`, `sleep(INGEST_PROBE_DELAY_MS)`.
3. Final pass: `_evictIfOverCap()` enforces the
   `pg_total_relation_size('recipes') ≤ 1.5 GB` byte budget by
   deleting oldest non-user rows.
4. Logs:
   * `[ingest] start MAX(id)=N batch=10 probeBudget=…`
   * `[ingest] hit id=N "Meal Name"` per success
   * `[ingest] probe id=N failed: <msg>` per upstream error
   * `[ingest] done ingested=K probed=P lastId=N elapsed=Tms`

### 1.5 Per-process safety

* `_ingestRunning` is in-memory → assumes single replica. If the
  cron fires while a previous run is still going,
  `[ingest] skip — previous run still active` is logged and the
  trigger is no-op.
* All upstream errors are swallowed per-id; the cron itself never
  throws into the cron-handler boundary.

### 1.6 What is **not** in the cron

* **No translation.** `runDailyIngest` only persists English rows
  (`upsertEnglish` writes `i18n = { en: … }`). It never calls
  `translateRecipe()` for any of the 9 supported non-English
  languages.
* **No warmup integration.** `runDailyIngest` does not push the
  newly-ingested ids into the warmup pool. Translation is
  delegated to two paths that do not see them in time — see §2.

### 1.7 Operational status (snapshot 2026-05-05)

* `mahallem-user-portal` was restarted 10 hours ago and has only
  logged `[ingest] scheduled "0 4 * * *" tz=Europe/Istanbul` so
  far for this boot — the next 04:00 Istanbul run will be the
  first one to actually probe TheMealDB after the restart.
* User-reported symptoms attributed to the cron (`404`, `402`,
  `… high server loads …`) almost certainly are **not** generated
  by this cron: per-id 404/402 from TheMealDB are caught and turn
  into `consecutiveMisses` increments — they never reach the
  client. The symptoms are produced by the bulk-page endpoint
  timing out under the Gemini 503 storm (see [§2](#2-why-auto-translate-does-not-work-for-the-cron)).

## 2. Why auto-translate does not work for the cron

Newly-ingested rows live with `popularity = 0` and
`i18n = { en: … }`. There are exactly two code paths that can
ever populate `i18n[lang]` for a non-English locale:

1. **Warmup cron** (`lib/jobs/warmup-recipes.js`) on container
   start, then on whatever schedule `scheduleWarmupOnStart`
   triggers — currently *only on boot* (no recurrent schedule).
2. **On-demand cascade** inside `RecipeRepository._ensureLang`
   (`routes/recipes.js` ~line 337), invoked by:
   * `repo.lookup(id, lang)` → `GET /recipes/:id?lang=…`
   * `repo.page(lang, …)` → `GET /recipes/page?lang=…`
   * `repo.search` / `repo.random` / `repo.filter` with `lang`.

Both paths are broken for the new rows.

### 2.1 Warmup never sees the new rows

`_pickIds` selects the top-200 by:

```sql
SELECT id FROM recipes
ORDER BY popularity DESC NULLS LAST, fetched_at DESC NULLS LAST
LIMIT 200;
```

Production currently has 616 upstream rows whose `popularity`
counter has been bumped many times by `incrementPopularity` (one
`+1` per `/lookup`). New rows arrive with `popularity = 0` and
sort to the **bottom** of the list. Even if their `fetched_at`
is fresher than every other row, the primary sort key wins:
they only enter the warmup top-200 once they have been clicked
enough times to outrank a row currently in the set, which by
definition cannot happen until at least one user has already
opened the recipe under at least one language. Result: a freshly
ingested meal id is never chosen by `_pickIds`, so the warmup
cron never triggers `repo.lookup(id, lang)` for it, so
`i18n.<lang>` stays empty.

This also explains the warmup log `hits=200/200 in 0s` for
`ar/fa/ku`: those 200 ids are all already-translated rows whose
Redis `lookup-key` is a hit; new rows that *would* need
translating are never in the set.

### 2.2 On-demand cascade is gated by Gemini

When a user finally requests a new recipe in `lang ≠ en`,
`_ensureLang` calls `translateRecipe(en, 'en', lang)`. The
cascade is:

```
Gemini → LibreTranslate → MyMemory → fallback (echo)
```

In the current production state the Gemini side is producing a
sustained storm of:

```
⚠️ Gemini API timeout, retrying (attempt 1/2)
⚠️ Gemini API 503, retrying in 1000ms/2000ms (attempt 1/2 … 2/2)
```

So the synchronous cascade per row takes 10–30 s. For
`/recipes/page?lang=ru&limit=200` the handler is a sequential
loop over 200 rows, so even a handful of misses easily overruns
the 60 s nginx upstream timeout and the client gets `504 Gateway
Timeout` (reproduced today: `lang=en` → 0.95 s, `lang=ru|es`
→ 504 after 60 s).

For `/recipes/:id?lang=…` the same cascade fires per-recipe;
the user sees the spinner for 10–30 s and often a `504` if
nginx times out first.

Worse, because the upstream MT services frequently return the
**English source unchanged** for short non-Latin fields like
`"175g"`, `"50g"`, `"1"` (visible in the live logs as
`🌐 MyMemory [en→fr]: "175g" → "175g"`), the produced
translation routinely fails the
`_isEchoTranslation` quality gate. When the gate trips the
translation is **served once but not persisted** — the next
request re-runs the same 10–30 s cascade. Brand-new ingested
rows are exactly the cohort most exposed to this:
they are short-content rows (often imported with sparse
ingredient lists) where the echo gate is easiest to trip.

### 2.3 Net effect

* Warmup never picks the new rows (popularity=0).
* On-demand `_ensureLang` fires only when a user opens the row
  in a non-EN locale, and during the current Gemini outage that
  call either 504s or returns an echo-rejected translation that
  is not persisted.
* So the cron does its job (English rows land in Postgres) but
  no localized variant ever reaches a steady state.

## 3. Proposed fixes

The fixes are listed in increasing order of intrusiveness. Pick
one or more.

### Fix A — Translate inside the ingest cron (recommended)

After `upsertEnglish(meal)` succeeds, immediately call
`repo.lookup(id, lang)` for each `lang` in `RECIPES_SUPPORTED_LANGS`,
sequentially with a small concurrency pool (e.g. 4) and a
per-recipe budget (e.g. 30 s). The cron runs at 04:00 Istanbul
time when the rest of the system is quiet, and a 10-meal × 9-lang
= 90 lookup batch with concurrency 4 finishes in ≈ 5–10 minutes
even with the Gemini cascade. Budget overruns are logged but do
not block the next meal.

```js
// routes/recipes.js — runDailyIngest, after upsertEnglish(meal):
const langs = (process.env.RECIPES_SUPPORTED_LANGS || 'en')
  .split(',').map((s) => s.trim()).filter((l) => l !== SOURCE_LANG);
await Promise.allSettled(
  langs.map(async (lang) => {
    try {
      await Promise.race([
        this.lookup(id, lang),
        new Promise((_, rej) =>
          setTimeout(() => rej(new Error('translate_budget')), 30_000)),
      ]);
    } catch (e) {
      console.warn(`[ingest] translate id=${id} lang=${lang} failed: ${e.message}`);
    }
  }),
);
```

Result: by the time a user opens a new recipe in any language,
`i18n[lang]` is already populated.

### Fix B — Promote new rows in the warmup ordering

Change `_pickIds` to use a hybrid score so freshly-ingested rows
get a temporary boost:

```sql
SELECT id FROM recipes
ORDER BY (
  popularity + GREATEST(0, 100 - EXTRACT(epoch FROM (NOW() - fetched_at)) / 86400)
) DESC,
fetched_at DESC
LIMIT 200;
```

The bonus decays after 100 days; new rows automatically enter
the top-200 and get translated by the next warmup pass. Cheap
to ship (one SQL change) but only helps if the warmup runs again
— the current `scheduleWarmupOnStart` only fires on container
boot, so combine with Fix C.

### Fix C — Recurring warmup schedule

`scheduleWarmupOnStart` currently runs once at boot. Add a
`cron.schedule(WARMUP_CRON, runWarmup, …)` (e.g. `30 4 * * *`,
30 minutes after the ingest cron) so newly-ingested rows are
guaranteed to be warmed within 24 h even if Fix A is not
applied.

### Fix D — Make `repo.page` non-blocking under translate misses

Independent of the cron itself, but the user-visible failure
mode (#2 reload only works on English) lives here:

* Add an option `{ allowTranslate = true }` to `_ensureLang`.
  When `false` and `i18n[lang]` is missing, return the English
  variant unchanged (no Gemini call).
* In `repo.page`, pass `allowTranslate: false`. Result: the
  bulk-page endpoint always returns within milliseconds, with
  EN fallbacks for not-yet-translated rows. No more 504s under
  Gemini storms.
* Translations continue to back-fill via Fix A or via
  `/recipes/:id?lang=…` (which keeps `allowTranslate: true`).

### Fix E — Persist echo translations as a "stub" with retry

Change `_isEchoTranslation` so that when it trips, the row is
written with a sentinel (e.g. `i18n[lang] = { __echo: true,
…englishCopy }`) and an `echo_retry_at` timestamp. A nightly
job retries echoed rows. This stops the per-request retranslate
loop for short-content rows while keeping the immutability
contract for trusted translations.

### Fix F — Drop Gemini retries to 1 attempt while it is degraded

Reduces total cascade latency from `(2 retries × Gemini timeout) +
LibreTranslate + MyMemory` to `(1 attempt) + LibreTranslate +
MyMemory`. Cheap, reversible, helps both `repo.page` and the cron
during the current outage.

## 4. Recommended rollout

1. **Today**: Ship Fix D (instant UX win — no more `reloadServerBusy`
   snackbar on non-EN). User-facing.
2. **Today**: Ship Fix A (translate inside the cron). Backfills the
   ingested batch and prevents future occurrences of the same
   regression.
3. **Tomorrow**: Backfill once with a manual run:
   ```sh
   docker exec mahallem-user-portal node -e "
     import('./routes/recipes.js').then(async ({}) => { /* … */ });
   "
   ```
   or simply trigger the cron at a chosen time:
   ```sh
   docker exec mahallem-user-portal node --eval "
     /* require recipes module + repo + runDailyIngest */
   "
   ```
4. **Optional**: Ship Fix B + C for long-term stability.
5. **Optional**: Ship Fix E if the echo-loop reappears after Fix A.

## 5. Verification checklist

After deploy:

* `docker logs --since 1h mahallem-user-portal | grep '\[ingest\]'`
  → expect `[ingest] hit id=…` lines after 04:00 Istanbul.
* Immediately after the cron run:
  ```sh
  curl -s 'https://mahallem.ist/recipes/page?lang=ru&limit=200' \
    | python3 -c "import json,sys;d=json.load(sys.stdin);
                  print('recipes',len(d.get('recipes',[])),'total',d['total'])"
  ```
  Should return `200` recipes within ≤ 2 s (Fix D) and the new
  ids should be present with translated fields (Fix A).
* `SELECT COUNT(*) FROM recipes
   WHERE i18n ? 'ru' AND id IN (<new ids>);`
  → must equal the number of rows ingested today.

## 6. Cross-references

* [`docs/recipe-ingester-and-size-cap.md`](recipe-ingester-and-size-cap.md)
  — original ingest + size-cap spec (Russian).
* [`docs/todo/recipe_ingester_and_size_cap.md`](todo/recipe_ingester_and_size_cap.md)
  — implementation checklist.
* [`docs/translation-pipeline.md`](translation-pipeline.md) —
  Gemini → LibreTranslate → MyMemory cascade contract,
  `_isEchoTranslation` rationale.
* [`docs/translation-pipeline-analysis.md`](translation-pipeline-analysis.md)
  — diagnostics from earlier echo-storm incident.
* [`docs/details-lang-cycle-504.md`](details-lang-cycle-504.md) —
  prior `504` incident on the lookup endpoint, same root cause
  (synchronous cascade under upstream MT outage).
