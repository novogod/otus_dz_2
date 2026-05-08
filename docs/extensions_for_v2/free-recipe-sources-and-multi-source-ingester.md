# Free recipe data sources & multi-source daily ingester

> Companion to [`docs/recipe-ingester-and-size-cap.md`](recipe-ingester-and-size-cap.md)
> and [`docs/themealdb-ingest-cron-and-translate-gap.md`](themealdb-ingest-cron-and-translate-gap.md).
> Created 2026-05-08 to capture an inventory of free recipe APIs / open
> datasets and propose extending the existing cron from a single
> upstream (TheMealDB) into a **carousel** that rotates the source
> every day while still ingesting **10 recipes per day total**.

## 1. Why rotate

Today the daily cron walks `MAX(id)+1` upward against TheMealDB and
stops once `INGEST_BATCH=10` new rows are persisted. The free
public TheMealDB endpoint exposes ~605 recipes (verified 2026-05-08),
of which we have already mirrored 608 — so any further runs will
churn through holes in the id-space and add nothing useful. To keep
adding 10 fresh recipes per day forever we need:

1. A pluggable list of sources, each with an adapter that maps its
   native shape to our canonical TheMealDB-style schema (the
   `CANONICAL_FIELDS` array in `routes/recipes.js`).
2. A deterministic per-day rotation so a single source never
   monopolises the slot and so missing/quota-exhausted sources fall
   through gracefully.
3. The same downstream contract (`upsertEnglish` + per-lang
   translate fan-out) so nothing else in the stack changes.

## 2. Inventory of free sources

> Legend: **Quota** = free-tier hard cap. **Vol.** = approximate
> total recipes reachable. **Img.** = ships image URLs we can re-host.
> **License** = redistribution allowance for ingested rows.

### 2.1 Public REST APIs (no key, anonymous)

| Source | Vol. | Quota | Img. | License | Notes |
| --- | --- | --- | --- | --- | --- |
| **TheMealDB v1** (`https://www.themealdb.com/api/json/v1/1/`) | ~605 | none (be polite) | yes | CC BY 4.0 (per their FAQ) | Already wired. Endpoints: `lookup.php?i=`, `search.php?f=<a..z>`, `filter.php?c=`, `random.php`, `categories.php`. |
| **DummyJSON Recipes** (`https://dummyjson.com/recipes`) | 50 | none | yes | MIT (mock data) | Tiny but free; usable as low-priority filler / smoke-test source. |
| **Recipe Puppy mirror — recipe-puppy-api** | ~1 M | none | URL-only | unclear, treat as link-only | Returns title + ingredients + thumbnail + source URL only; safer to import as **stub recipes** linking out (`strSource`). |

### 2.2 Free tier with API key

| Source | Vol. | Free quota | Img. | License | Notes |
| --- | --- | --- | --- | --- | --- |
| **Spoonacular** (`api.spoonacular.com/recipes`) | ~5 000 owned + 360 000 indexed | 150 pts/day (~30 reads) | yes (CDN) | redistribution **not allowed** for the indexed crawled set; the curated `complexSearch` rows are licensed for app display | Best-quality structured ingredients/instructions. Use `random` + `informationBulk`. |
| **Edamam Recipe Search v2** | ~2.3 M | 10 req/min, 10 000 req/month | yes (publisher) | display-only — must show their attribution + link out, no full-text storage | Useful only if we display + link out, not for full mirroring. |
| **Tasty (RapidAPI)** | ~3 500 | 500 req/month | yes + video | display-only | Buzzfeed Tasty; high-quality but small free quota. |
| **API-Ninjas Recipe** | ~10 000 | 50 000/month | no images | unclear (treat as link-only) | Title + ingredients + instructions only; cheap volume booster. |
| **WGER nutrition** | small | unlimited | no | CC BY-SA | Not really a recipe source but contains meal templates. |

### 2.3 Open datasets / dumps (preferred for bulk)

| Source | Vol. | Format | License | Notes |
| --- | --- | --- | --- | --- |
| **OpenRecipes** (`fictivekin/openrecipes`) | ~170 000 | newline-JSON dump | MIT (metadata) | Title + URL + ingredients + image. Designed as a search index, not a cookbook. |
| **RecipeNLG** (HuggingFace) | ~2.2 M | TSV | research-only (non-commercial) | Largest publicly available; cannot ship in production app. |
| **Food.com Recipes & Reviews** (Kaggle) | ~500 000 | CSV | **non-commercial** (Kaggle TOS) | Same blocker as RecipeNLG. |
| **Wikibooks Cookbook** | ~3 000 | MediaWiki XML | CC BY-SA 4.0 | Free to redistribute with attribution; needs scraping + parsing of templated wikitext. |
| **schema.org/Recipe in the wild** | unbounded | JSON-LD per page | per-publisher | Most modern food blogs ship `<script type="application/ld+json">` describing the recipe. Legal model: ingest only the user's own bookmarked URL on demand, not bulk-crawl. |

### 2.4 Quick legal cheat-sheet for our stack

* **Safe to mirror full text + images**: TheMealDB, DummyJSON,
  Wikibooks Cookbook, OpenRecipes (metadata fields only).
* **Display-only** (must hit upstream on render OR show
  attribution + link out): Edamam, Spoonacular crawled set, Tasty.
* **Forbidden**: RecipeNLG, Food.com Kaggle dump (research/
  non-commercial). Listed only for completeness.

## 3. Canonical target schema

Adapters MUST emit objects shaped exactly like a TheMealDB lookup
result so `RecipeRepository.upsertEnglish(meal)` keeps working
unchanged. `CANONICAL_FIELDS` (see `routes/recipes.js`):

```js
[
  'idMeal', 'strMeal', 'strCategory', 'strArea', 'strTags',
  'strInstructions', 'strMealThumb', 'strYoutube', 'strSource',
  'strIngredient1'..'strIngredient20',
  'strMeasure1'..'strMeasure20',
]
```

Mapping rules:

* `idMeal` — globally unique, strictly **below** `USER_MEAL_ID_FLOOR`
  (1 000 000). Allocate id ranges per source so they never collide:
  - 1 – 99 999 → TheMealDB (existing)
  - 100 000 – 199 999 → Spoonacular
  - 200 000 – 299 999 → Edamam (link-out stubs)
  - 300 000 – 399 999 → Tasty
  - 400 000 – 499 999 → DummyJSON
  - 500 000 – 699 999 → OpenRecipes
  - 700 000 – 799 999 → API-Ninjas
  - 800 000 – 899 999 → Wikibooks Cookbook
  - 900 000 – 999 999 → reserved for future paid sources
  Implementation: `const id = SOURCE_ID_BASE + sourceLocalId`.
* `strMeal` — recipe title, trimmed.
* `strCategory` / `strArea` — best-effort mapping; fall back to a
  source-level constant (`'Misc'` / `'International'`) so the
  category/area filters keep returning data.
* `strInstructions` — plain text, newline-joined steps. Strip HTML.
* `strMealThumb` — absolute https URL (we proxy via imgproxy at read
  time). If the source returns relative paths, resolve against its
  base.
* `strIngredient<N>` / `strMeasure<N>` — packed left-to-right; pad
  unused slots with `null`. If a source has > 20 ingredients,
  truncate and append a single overflow line into
  `strInstructions` ("More: …").
* `strYoutube` — populate from any `videoUrl` field, otherwise null.
* `strSource` — original publisher URL (mandatory for display-only
  sources to satisfy attribution requirements).
* `strTags` — comma-joined free-form tags (cuisine, diet, etc.).

## 4. Proposed multi-source ingester

### 4.1 Module layout

```
local_user_portal/
└── routes/
    ├── recipes.js                  # unchanged public surface
    └── ingest/
        ├── index.js                # carousel runner, picks source-of-the-day
        ├── sources/
        │   ├── themealdb.js        # extracted from current runDailyIngest
        │   ├── spoonacular.js
        │   ├── edamam.js           # link-out stubs
        │   ├── tasty.js
        │   ├── dummyjson.js
        │   ├── openrecipes.js      # streams the dump
        │   ├── apininjas.js
        │   └── wikibooks.js
        └── adapters/
            └── *.js                # source -> CANONICAL_FIELDS mapping
```

### 4.2 Source contract

Each source exports the same async interface so the carousel stays
trivial:

```js
// routes/ingest/sources/<name>.js
export default {
  /** Stable string id used for daily rotation + DB id base. */
  name: 'spoonacular',
  /** First id in our DB allocated to this source. */
  idBase: 100_000,
  /** True iff the source's required env (API key, dump path) is set. */
  isConfigured(env) { return Boolean(env.SPOONACULAR_KEY); },
  /**
   * Yield up to `batch` raw upstream meals.
   * Implementations are responsible for deduping against
   * `repo.q('SELECT id FROM recipes WHERE id BETWEEN $1 AND $2', ...)`.
   * Must NOT translate — that stays in the carousel.
   */
  async *fetchNext({ repo, batch, env, log }) { /* yields canonicalised meals */ },
};
```

### 4.3 Carousel algorithm

```js
// routes/ingest/index.js
const SOURCES = [
  themealdb, spoonacular, edamam, tasty,
  dummyjson, openrecipes, apininjas, wikibooks,
];

export async function runDailyMultiIngest(repo, { batch = INGEST_BATCH } = {}) {
  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
  // Deterministic per-day rotation: same picker on every replica,
  // independent of process restart time.
  const ordinal = daysSinceEpoch(today);
  const enabled = SOURCES.filter((s) => s.isConfigured(process.env));
  if (enabled.length === 0) return { ingested: 0, source: null };

  // Primary source = today's pick; failover walks the rest.
  for (let offset = 0; offset < enabled.length; offset += 1) {
    const src = enabled[(ordinal + offset) % enabled.length];
    const ingested = await ingestFromSource(repo, src, batch);
    if (ingested >= batch) return { ingested, source: src.name };
    // Source exhausted/quota hit → fall through to next, but DO NOT
    // exceed the global daily budget — pass the remaining slots only.
    batch -= ingested;
    if (batch <= 0) return { ingested, source: src.name };
  }
  return { ingested: 0, source: null };
}
```

`daysSinceEpoch()` keeps the rotation reproducible across restarts
and guarantees that across an N-day window every source is the
"primary" exactly `⌈N/len(SOURCES)⌉` times. Scheduled by the same
`cron.schedule(INGEST_CRON, …)` we use today; the Express wiring
in `recipesRoute()` swaps `repo.runDailyIngest` for
`runDailyMultiIngest(repo)` and nothing else changes.

### 4.4 Reusing existing safety rails

`ingestFromSource(repo, src, batch)` calls `repo.upsertEnglish(meal)`
for each canonicalised payload, then runs the **same** translate
fan-out that `runDailyIngest` already performs:

```js
const targetLangs = SUPPORTED_LANGS.filter((l) => l !== SOURCE_LANG);
const queue = targetLangs.slice();
const workers = [];
for (let w = 0; w < Math.min(INGEST_TRANSLATE_CONCURRENCY, queue.length); w += 1) {
  workers.push((async () => {
    while (queue.length) {
      const lang = queue.shift();
      try { await repo.lookup(meal.idMeal, lang); }
      catch (err) { log.warn(`translate ${meal.idMeal} ${lang}: ${err.message}`); }
    }
  })());
}
await Promise.all(workers);
```

The byte-budget cap (`_evictIfOverCap`) and `_ingestRunning` re-entry
guard stay where they are — we wrap the whole carousel inside the
existing `try { this._ingestRunning = true } finally { … }` block.

### 4.5 Per-source quota awareness

Sources with daily quotas advertise it via a `quotaPerDay` field;
the carousel skips a source for that day once it reports
`quotaExceeded` from a fetch (HTTP 429 or sentinel JSON). Skipping
counts as "0 ingested", so failover proceeds to the next source.

### 4.6 Configuration surface (env)

Add to the user-portal `.env`:

```
RECIPES_INGEST_BATCH_SIZE=10            # already exists, unchanged
RECIPES_INGEST_SOURCES=themealdb,spoonacular,dummyjson,openrecipes
                                        # subset/order override
SPOONACULAR_KEY=…
EDAMAM_APP_ID=…
EDAMAM_APP_KEY=…
TASTY_RAPIDAPI_KEY=…
APININJAS_KEY=…
OPENRECIPES_DUMP_PATH=/var/lib/openrecipes/recipes.jsonl
WIKIBOOKS_DUMP_PATH=/var/lib/wikibooks/cookbook-pages.xml
```

Anything missing causes the source to report
`isConfigured() === false` and to be skipped silently.

### 4.7 Observability

Each pass logs one structured line so the existing
`/admin/system-metrics` dashboard can aggregate:

```
[ingest] day=2026-05-08 source=spoonacular ingested=10 probed=18 elapsed=12s
```

Failure paths log `source=<name> error=<message>` and are surfaced
via the existing `system_error_logs` table.

## 5. Adapter notes (per source)

### 5.1 TheMealDB (existing)

Already produces TheMealDB shape natively → adapter is identity.
Move current loop body into `sources/themealdb.js` unchanged.

### 5.2 Spoonacular

```
GET https://api.spoonacular.com/recipes/random?number=10&apiKey=…
```

Mapping:

* `idMeal = 100_000 + body.id`
* `strMeal = body.title`
* `strCategory = body.dishTypes?.[0] ?? 'Misc'`
* `strArea = body.cuisines?.[0] ?? 'International'`
* `strInstructions = stripHtml(body.instructions)` (or join
  `analyzedInstructions[0].steps[].step`)
* `strMealThumb = body.image`
* `strSource = body.sourceUrl`
* `strYoutube = null` (Spoonacular has no video field)
* Ingredients/measures from `extendedIngredients[i].original`
  split on first whitespace; or amount + unit + name.

### 5.3 Edamam

Use as **link-out** only because TOS forbids storing the full
recipe text. Ingest a stub:

* `strInstructions = ''` + `'See full recipe at ' + body.url`
* All ingredients still mapped (Edamam returns `ingredientLines`).
* `strSource = body.url` (mandatory display).

### 5.4 Tasty

Map `instructions[i].display_text` → joined `strInstructions`,
`sections[0].components[i].raw_text` → ingredients. Video lives in
`original_video_url` → `strYoutube`.

### 5.5 DummyJSON

Trivial 1-to-1 mapping (`title`, `cuisine`, `mealType`,
`instructions[]`, `ingredients[]`, `image`). Useful as a tiny
always-available filler for staging.

### 5.6 OpenRecipes

Stream the local JSONL dump line-by-line. Each row has
`name`, `description`, `ingredients`, `source`, `image`. No
instructions in the dump → `strInstructions = description` and
`strSource = source` so users can click through. Best high-volume
source because no rate limit applies.

### 5.7 API-Ninjas

`GET https://api.api-ninjas.com/v1/recipe?query=<keyword>` with
`X-Api-Key` header. Returns `title`, `ingredients` (string),
`instructions`, `servings`. No image → skip if
`!REQUIRE_IMAGE` or use a category placeholder.

### 5.8 Wikibooks Cookbook

Pre-process the XML dump to JSONL (`page-title`, `wikitext`),
then a tiny `wikitext-to-recipe` parser pulls
`{{recipe-summary|…}}` template + `==Ingredients==` /
`==Procedure==` sections. Slowest to implement but yields
~3 000 CC BY-SA recipes that are legally safe to mirror.

## 6. Roll-out plan

1. Land `routes/ingest/` skeleton + carousel + the existing
   TheMealDB extraction. Behaviour-equivalent to today.
2. Add `dummyjson` source (no key required) → first proof the
   carousel actually rotates.
3. Add `openrecipes` source (offline dump) → unlocks effectively
   unlimited future capacity at zero cost.
4. Add `spoonacular` once the key is provisioned. Cap at the
   free-tier 30 reads/day; carousel will dip below the 10/day
   floor on heavy days, which is fine because it falls through to
   the next source.
5. Add `tasty`, `apininjas`, `edamam` as the audience grows.
6. Wikibooks last — needs the wikitext parser.

## 7. Open questions

* **Image rehosting.** Do we want a parallel pass that downloads
  every new `strMealThumb` into our object store? Today we hot-link
  TheMealDB's CDN, which has been stable; less so for arbitrary
  blogs reachable via OpenRecipes.
* **Per-source weighting.** Strict round-robin treats every source
  as equal. Likely we want TheMealDB-quality > Spoonacular >
  OpenRecipes-stub. A weight vector (e.g. `[3,2,2,1,…]`) on the
  carousel index covers this without changing the algorithm.
* **Deduping across sources.** Two sources may carry the same
  recipe under different ids. A title-+-cuisine fingerprint stored
  in `recipes.content_hash` already exists; extend it to a fuzzy
  index (`pg_trgm` on `lower(strMeal)`) and skip near-duplicates
  during `upsertEnglish`.

## 8. Files this will touch

* `local_user_portal/routes/recipes.js` — replace
  `cron.schedule(INGEST_CRON, () => repo.runDailyIngest())` with
  `cron.schedule(INGEST_CRON, () => runDailyMultiIngest(repo))`.
  Keep `runDailyIngest` exported for tests / manual trigger.
* `local_user_portal/routes/ingest/**` — new module tree (§4.1).
* `local_user_portal/.env.example` — document new env vars (§4.6).
* `docs/recipe-ingester-and-size-cap.md` — cross-link to this
  document under "Future work".
* `docs/project_log.md` — single entry once the multi-source
  carousel ships to production.
