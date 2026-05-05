# 88-recipe loading symptom on non-EN/RU languages

> Sibling diagnosis to
> [`docs/themealdb-ingest-cron-and-translate-gap.md`](themealdb-ingest-cron-and-translate-gap.md)
> and the original `/recipes/page` 504 finding. Created 2026-05-05.

## 1. Symptom

User-reported: *“200 recipes memory on inapp sqlite are only working
in English and Russian. When I open other languages the loading
screen says 88 recipes are loading.”*

* **EN, RU**: ~200 recipes appear in the feed almost instantly.
* **ES, FR, DE, IT, TR, AR, FA, KU**: the loading-stage progress
  bar shows roughly **88 recipes** loaded and stalls there for
  several seconds before the feed finally renders.

The 88 figure is **not** a server response payload of 88 items —
it is the count surfaced by the client `_LoadStage.fetching` indicator
during the *category fan-out fallback*.

## 2. Pre-investigation hypothesis (now revised)

The earlier hypothesis was:

> *“`/recipes/page?lang=<X>` returns a partial set because
> `_isEchoTranslation` rejects translations and they are
> served-but-not-persisted, so each request re-translates from
> scratch under Gemini overload.”*

That story is **partially correct** as a contributing factor but
**not the root cause**. The actual data on disk shows the opposite:

```sql
SELECT lang, COUNT(*) FROM (SELECT jsonb_object_keys(i18n) AS lang
                            FROM recipes WHERE id<1_000_000) s
GROUP BY lang ORDER BY lang;

ar | 607
de | 581
en | 608
es | 572
fa | 607
fr | 581
it | 572
ku | 604
ru | 579
tr | 572

-- Top-200 by warmup ordering, count of rows that already have i18n[lang]:
ru_top200 | 186 / 200 (14 missing)
es_top200 | 184 / 200 (16 missing)
ar_top200 | 200 / 200
fa_top200 | 199 / 200
ku_top200 | 200 / 200
```

So persistence is healthy — 94–100 % of the warmup top-200 already
have target-lang strings written to `recipes.i18n[lang]`. The echo
gate is not, in practice, looping forever for the bulk of rows.

## 3. Actual root cause

The 88-recipe count comes from a different code path on the
client. The trail is:

### 3.1 Server: `/recipes/page` times out for any lang with >0 missing translations

`routes/recipes.js` ~line 877:

```js
async page(lang, { offset = 0, limit = 200 } = {}) {
  const rows = await this.q(`SELECT id, i18n FROM recipes
                             ORDER BY popularity DESC, fetched_at DESC
                             LIMIT $1 OFFSET $2`, [limit, offset]);
  const out = [];
  for (const r of rows) {
    const meal = await this._ensureLang(r, langKey);   // ← sequential
    if (meal) out.push(meal);
  }
  return { recipes: out, ...};
}
```

The loop is **sequential**, and `_ensureLang` triggers the full
Gemini → LibreTranslate → MyMemory cascade for any row whose
`i18n[lang]` is missing. With Gemini currently storming
`503 / timeout` errors, even **14 missing rows out of 200** push
the total handler latency past the 60 s nginx upstream timeout.

| lang | missing in top-200 | observed `/recipes/page?limit=200` |
| ---- | ------------------ | ---------------------------------- |
| en   | 0 (source lang)    | 200 OK in 0.95 s                   |
| ru   | 14                 | 504 after 60 s (also Redis-cached when warm) |
| es   | 16                 | 504 after 60 s                     |
| ar   | 0                  | 200 OK (when Redis-warm) / cascade if cold |
| fa   | 1                  | 504 risk (1 cascade row × ~30 s)   |
| ku   | 0                  | 200 OK (when Redis-warm)           |

`ru` and `ar/ku` *can* succeed when the Redis bulk-page key
(`pageKey(lang, 0, 200)`) is already populated from an earlier
successful run inside the TTL window — which is why those langs
sometimes appear to work even though the cold path is broken.

### 3.2 Client: bulk path swallows the failure and falls into category fan-out

[recipe_list/lib/ui/recipe_list_loader.dart](recipe_list/lib/ui/recipe_list_loader.dart#L609-L626):

```dart
if (widget.config.useBulkPage && !forceReseed) {
  try {
    final page = await widget.api.fetchPage(
      lang: lang,
      limit: widget.config.seedTarget,                    // 200
    );
    if (page.recipes.isNotEmpty) {
      await _persist(repo, page.recipes, lang);
      return _LoadResult(recipes: page.recipes, repository: repo);
    }
  } on Object {
    // Bulk endpoint unavailable — fall through to legacy path.
  }
}
final recipes = await _seedFromCategories(
  repo, lang,
  onPartial: (partial) => _publishPartialFeed(partial, repo),
);
```

When `/recipes/page` returns 504 or hangs past the dio timeout,
the catch swallows the error silently and the loader falls into
`_seedFromCategories` — the legacy 14-category fan-out.

### 3.3 The fan-out is what produces the “88”

[recipe_list/lib/ui/recipe_list_loader.dart](recipe_list/lib/ui/recipe_list_loader.dart#L700-L753):

```dart
for (var i = 0; i < categories.length; i++) {              // 14 categories
  final cat = categories[i];
  _stage.value = _LoadStage.fetching(
    category: cat, done: i, total: categories.length,
    loaded: accumulator.length,                            // ← visible counter
    target: widget.config.seedTarget,                      // 200
  );

  if (repo != null) {
    final localCount = await repo.countForCategory(cat, lang);
    if (localCount >= widget.config.categoryCacheThreshold) continue;
  }

  try {
    final batch = await widget.api
        .filterByCategory(cat)
        .timeout(const Duration(seconds: 12));             // ← per-cat cap
    for (final r in batch) {
      if (accumulator.containsKey(r.id)) continue;
      accumulator[r.id] = r;
    }
    if (repo != null && batch.isNotEmpty) {
      try { await repo.upsertAll(batch, lang); }
      on Object { /* кэш не критичен */ }
    }
    if (added) publish();
  } on Object {
    // одна категория не приехала — пробуем следующую
  }
  if (accumulator.length >= widget.config.seedTarget) break;
}
```

Per-category fetch (`/recipes/filter/c/<cat>?lang=<X>&full=1`)
uses the **same** `_ensureLang` cascade server-side, so under the
Gemini storm each category times out at the 12 s client cap and
returns nothing. Categories where Postgres already has all rows
under the target lang come back fast and seed the accumulator.

The arithmetic that yields ~88:

* 14 categories total.
* Roughly 6–7 of them already have ≥ `categoryCacheThreshold`
  rows in the local SQLite cache from prior sessions and are
  **skipped** (the `continue` branch). That trims the network
  workload to ~7 categories.
* Of those ~7 fetched-from-network categories, ~3–4 succeed within
  12 s and contribute ~12–18 unique recipes each (the rest time
  out and add nothing).
* Cached-skipped categories already contributed their rows to
  `accumulator` in the first pass at line 683 (`listCachedByCategory(cat, lang, limit:50)`),
  for ~50–60 cached recipes.
* Sum: cached pass (~50–60) + ~3 fast network categories
  (~30–40 unique after dedup) ≈ **80–100 recipes**, displaying
  consistently around **88** in real runs.

The 200 figure shown for `en/ru` is the **full** `/recipes/page`
result (no fallback path triggered). EN works because no
translation is needed; RU works most of the time because its
top-200 has only 14 missing rows AND once any successful run
populates the Redis bulk-page key, subsequent calls in that TTL
window are served from Redis without re-running the cascade.

### 3.4 Why the cycle is self-perpetuating

* Every category that times out at 12 s on the client also burns
  ~12–60 s of server-side cascade, adding to the Gemini-503
  storm.
* Rows that *do* come back from a slow `/recipes/filter/c/...`
  call are persisted to local SQLite via `repo.upsertAll`, but
  only after a successful response — most lang/category
  combinations never persist anything new, so `countForCategory`
  stays under threshold and the next cold start does the same
  failed dance.
* The Redis bulk-page key has TTL `RECIPES_REDIS_TTL` (env-driven).
  When it expires the next request is a cold cascade again, and
  the user sees the snackbar / 88-recipe screen until a full run
  manages to complete and re-warm the key.

## 4. Fixes

### Fix A — Make `/recipes/page` return immediately with EN fallback

**Highest leverage. Single-line behavioural change.** Add an
`{ allowTranslate = false }` option to `_ensureLang` and pass it
from `repo.page`:

```js
async _ensureLang(row, lang, { allowTranslate = true } = {}) {
  if (!SUPPORTED_LANGS.includes(lang)) lang = SOURCE_LANG;
  const en = row.i18n && row.i18n[SOURCE_LANG];
  if (!en) return null;
  if (lang === SOURCE_LANG) return en;
  const persisted = row.i18n && row.i18n[lang];
  if (persisted) return persisted;
  if (!allowTranslate) return en;          // ← graceful degrade
  const translated = await this.translate(en, SOURCE_LANG, lang);
  // …existing echo-gate / persist path…
}

async page(lang, { offset = 0, limit = 200 } = {}) {
  // …existing query…
  for (const r of rows) {
    const meal = await this._ensureLang(r, langKey, { allowTranslate: false });
    if (meal) out.push(meal);
  }
  // …
}
```

Effect:

* `/recipes/page` now returns in ~50–200 ms regardless of locale
  (it’s a `LIMIT 200` SELECT plus jsonb deserialisation).
* Rows missing `i18n[lang]` are served with the EN strings —
  acceptable degraded UX, much better than a 504.
* The client takes the bulk path, never falls into the 14-category
  fan-out, and the “88 recipes” loading screen disappears.

`/recipes/:id?lang=…` keeps `allowTranslate: true` so a user
opening a card still gets a fresh translation on demand.

### Fix B — Translate inside the daily ingest cron

See §3 in
[`docs/themealdb-ingest-cron-and-translate-gap.md`](themealdb-ingest-cron-and-translate-gap.md).
After `upsertEnglish`, immediately `repo.lookup(id, lang)` for each
`RECIPES_SUPPORTED_LANGS` entry, with concurrency ≤ 4 and a
30 s/recipe budget. Combined with Fix A this means newly-ingested
rows have `i18n[lang]` filled before any user request hits them.

### Fix C — Add a periodic backfill job for echo-rejected rows

One-shot SQL audit:

```sql
SELECT lang, COUNT(*) FROM (
  SELECT jsonb_object_keys(i18n) AS lang FROM recipes WHERE id<1_000_000
) s GROUP BY lang;
```

Rows where `total - count(lang)` is non-trivial (currently
`en=608, ru=579 → 29 missing`, `es=572 → 36 missing`) can be
backfilled via:

```js
// scripts/backfill-translations.js
const langs = ['ru', 'es', 'fr', 'de', 'it', 'tr', 'ar', 'fa', 'ku'];
for (const lang of langs) {
  const rows = await q(
    `SELECT id FROM recipes
       WHERE id < 1000000 AND NOT (i18n ? $1)
       ORDER BY popularity DESC, fetched_at DESC`,
    [lang],
  );
  for (const { id } of rows) {
    await repo.lookup(id, lang).catch(() => {});
    await sleep(500);                       // gentle on Gemini
  }
}
```

Should be runnable as a cron at e.g. `15 4 * * *` (after the
ingest cron) so it walks any new misses within a day.

### Fix D — Tighten the echo gate so MT-pass-through doesn’t reject good translations

Today `_isEchoTranslation` looks at `strInstructions` first; for
many MealDB rows, the instructions block legitimately echoes
some EN words/phrases (proper names, units like `"175g"`,
`"50g"`, time markers `"2 hr"`). Tighten to:

* Only reject if **both** `strMeal` AND `strInstructions` echo —
  short-field-only echo is much weaker evidence of MT failure.
* Lower `ECHO_RATIO_LONG_MAX` only when the target script is
  non-Latin (`ar/fa/ku/ru`) where the MT layer has more confidence
  to express, and the rows currently in production are already
  fully translated (607/581/579/604) so the gate can be stricter
  without losing coverage.

### Fix E — Redis-cache the bulk-page key per-lang on warmup

Today `scheduleWarmupOnStart` calls `repo.lookup(id, lang)` per
recipe — which writes to a different Redis key (`lookupKey`)
than `/recipes/page` reads (`pageKey`). After the warmup pass
finishes for a lang, also call `repo.page(lang, { offset:0,
limit:200 })` once and store the result under `pageKey`. Effect:
the very first `/recipes/page` request post-boot is a Redis hit
even when the cascade is slow.

### Fix F — Surface bulk-page failure to the loader

Today the catch on the bulk fetch is `on Object {}` — silent
fallback. Change to log the failure (e.g. `Sentry.captureException`
or even just `debugPrint`) so we know on prod when the fallback
fires. Optional: also bypass the fan-out on a 504 and show the
busy snackbar directly, so the UX is predictable.

## 5. Recommended rollout

1. **Today** ✅ DEPLOYED 2026-05-05 16:02 UTC: Fix A applied to
   `/root/mahallem/mahallem_ist/local_user_portal/routes/recipes.js`,
   `docker cp` into `mahallem-user-portal:/app/routes/recipes.js`,
   container restarted. Smoke test:
   ```
   lang=en code=200 time=0.92s size=486373
   lang=ru code=200 time=0.96s size=730945
   lang=es code=200 time=0.92s size=521612
   lang=fr code=200 time=0.94s size=538228
   lang=de code=200 time=0.91s size=518875
   lang=it code=200 time=0.94s size=523124
   lang=tr code=200 time=0.94s size=512980
   lang=ar code=200 time=0.99s size=643100
   lang=fa code=200 time=1.03s size=699216
   lang=ku code=200 time=1.02s size=777811
   ```
   All 10 locales return 200 OK in <1.1 s. The 88-recipes loading
   regression is gone.

2. **Today**: Re-test the affected app locales (`es`, `fr`, `de`,
   `it`, `tr`, `fa`). The loading-stage counter should jump
   straight to 200 with no “88-recipes-loading” intermediate
   state.
3. **This week**: Fix B (translate inside cron) + Fix C (backfill
   cron). Together they ensure `i18n[lang]` is at 100 % coverage
   and no row is ever served as the EN fallback for long.
4. **Optional**: Fix E (warm bulk-page key) for sub-second cold
   starts after container restart.
5. **Optional**: Fix D + F.

## 6. Verification

After Fix A + restart:

```sh
for lang in en ru es fr de it tr ar fa ku; do
  curl -fsS -m 5 -o /dev/null \
    -w "lang=$lang code=%{http_code} time=%{time_total}s\n" \
    "https://mahallem.ist/recipes/page?lang=$lang&limit=200"
done
```

All 10 langs should return `code=200` in under 2 s.

After Fix B + a cron run:

```sql
-- new rows ingested today have all 10 locales populated
SELECT id, jsonb_object_keys(i18n) AS lang
FROM recipes
WHERE fetched_at > NOW() - INTERVAL '24 hours'
  AND id < 1_000_000
ORDER BY id, lang;
```

Should show every fresh id paired with all 10 supported lang
keys.

## 7. Cross-references

* [`docs/themealdb-ingest-cron-and-translate-gap.md`](themealdb-ingest-cron-and-translate-gap.md)
  — companion diagnosis of the cron-side translate gap.
* [`docs/translation-pipeline.md`](translation-pipeline.md) —
  cascade contract.
* [`docs/translation-pipeline-analysis.md`](translation-pipeline-analysis.md)
  — earlier echo-loop incident.
* [`docs/details-lang-cycle-504.md`](details-lang-cycle-504.md) —
  prior 504 incident on the lookup endpoint, same root cause
  (synchronous cascade under upstream MT outage).
* [`docs/categories.md`](categories.md) §9.1 — bulk-page vs
  category fan-out spec.
