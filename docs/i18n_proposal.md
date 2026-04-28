# i18n & Recipe Sync Proposal

Status: **proposal**. Today only the offline RU/EN switcher is live —
see `lib/i18n.dart`, `lib/ui/lang_icon_button.dart` (language toggle in
the AppBar), and `lib/ui/search_app_bar.dart` (search field with
predictions). This document describes what we add next.

> Note on terminology: there is no library called "Libramentum" in the
> Flutter ecosystem. The first-party localization stack is
> `flutter_localizations` + `intl` with the `gen-l10n` code generator
> (ARB files → `AppLocalizations` class). That's what we use below.

## 1. Goals

1. Every visible string — static UI **and** dynamic recipe content
   (name, category, area, tags, ingredients, instructions) — is shown
   in English or Russian, switched by the AppBar `RU` / `EN` button.
2. **No Google services in the translation path.** The app is
   targeted at Russia, where Google Translate / Gemini availability
   is unreliable and access from a Russian IP is intermittently
   blocked. The pipeline must work end-to-end without any Google
   product, including no Google reCAPTCHA, no Cloud Translation, no
   Vertex / Gemini.
3. Reuse the translation infrastructure already running in the
   `mahallem_ist` docker stack — see
   [TRANSLATION_SYSTEM_IMPLEMENTATION.md](https://internal/mahallem_ist/project_docs/TRANSLATION_SYSTEM_IMPLEMENTATION.md),
   [DYNAMIC_TRANSLATION_SYSTEM.md](https://internal/mahallem_ist/project_docs/DYNAMIC_TRANSLATION_SYSTEM.md),
   [SMART_BACKGROUND_TRANSLATION.md](https://internal/mahallem_ist/project_docs/SMART_BACKGROUND_TRANSLATION.md).
   Two providers, both Google-free:
   * **LibreTranslate** (self-hosted, container `mahallem-translate`
     on port 5000) — primary, used for `en ↔ ru` (and the other
     mahallem languages: `tr, es, fr, de, it, uk` if we ever scale).
   * **MyMemory** (`https://api.mymemory.translated.net`) — fallback
     and the only path for `fa, ar, ku` in mahallem. Free tier covers
     ~50 K chars/day per email; we sign with `support@mahallem.ist`
     same as the main platform.
4. Phone-side storage for recipes is a small, capped MongoDB-backed
   cache — both as a "buffer" so we don't translate the same recipe
   twice, and as the source of the list / details / images while
   online or offline.
5. The phone always shows the freshest data when connected. If the
   user searches for something not yet cached, it is fetched from the
   server and added to the cache (evicting the oldest entries).

## 2. What is already done

* `AppLang { ru, en }` enum + global `ValueNotifier<AppLang>` in
  `lib/i18n.dart`.
* `AppLangScope` wraps the root subtree under `MaterialApp.home`, so
  toggling rebuilds the whole UI.
* `S.of(context)` returns a const string bag for the current language.
  All visible **static** strings (navbar, snackbars, list/empty/error
  states, details headers, ingredient pluralization, search hints) go
  through `S`.
* The language toggle is `LangIconButton` in `AppBar.actions`. It is
  **not** shown on the splash screen — splash has no AppBar.

This covers static UI. It does **not** translate dynamic recipe
content from TheMealDB. Sections 3–6 below address that.

## 3. Static strings — `flutter_localizations` + `gen-l10n`

The hand-rolled `S` class is fine for ~20 keys but doesn't scale. The
target structure once the recipe sync is in place:

```
recipe_list/
  l10n.yaml
  lib/l10n/
    app_en.arb
    app_ru.arb
    (generated) app_localizations.dart
```

* `MaterialApp.localizationsDelegates: AppLocalizations.localizationsDelegates`
* `MaterialApp.supportedLocales: AppLocalizations.supportedLocales`
* `MaterialApp.locale` is driven by the `AppLang` notifier — the
  toggle still cycles `RU` ↔ `EN`, but it now flips
  `Locale('ru')` ↔ `Locale('en')` and the standard
  `AppLocalizations.of(context)` resolves the strings.
* `S.of(context)` becomes a thin wrapper over `AppLocalizations` so
  every existing call site (`s.tabRecipes`, `s.searchHint`, …)
  continues to compile. The migration is mechanical.

Pluralization (`s.ingredientCount`) moves into ARB plural syntax:
```
"ingredientCount": "{count, plural, one{{count} ingredient} other{{count} ingredients}}"
```
RU has the four-form rule (`one` / `few` / `many` / `other`) handled
natively by `intl`.

## 4. Dynamic content — LibreTranslate (+ MyMemory fallback), server-side only

No translation provider is ever called from the Flutter binary. All
requests go to the existing `mahallem_ist` Node service, which talks
to an in-cluster LibreTranslate container — no API key needs to ship
in an APK/IPA, which is what would let an attacker exhaust paid
quota (OWASP A02 / A07).

```
   Flutter app
       │  HTTPS
       ▼
   Recipes API ──┬─→ http://mahallem-translate:5000/translate   (LibreTranslate, self-hosted)
   (Node, in     │
    mahallem_ist │
    docker stack)└─→ https://api.mymemory.translated.net/get    (MyMemory, fallback)
       │
       ▼
   MongoDB (recipes + translations)
       ▲
       │  scheduled refresh
   TheMealDB (upstream)
```

The same Node service that runs the existing translation pipeline
for `mahallem_ist` exposes a new namespace `/recipes/*`. Endpoints —
Section 5.

### 4.1 Providers

**Primary — LibreTranslate (self-hosted).**

* Reachable at `http://mahallem-translate:5000/translate` from
  inside the docker network. Same container the user portal uses.
* Open-source, Apache-2 licensed; runs entirely on our hardware. No
  Google / Microsoft / Yandex / DeepL leg of the request, so it is
  not subject to RU sanctions or Roskomnadzor blocks against US
  cloud APIs.
* Languages enabled in mahallem and reused here: `en, ru, tr, es,
  fr, de, it, uk`. The recipe app only needs `en, ru` — the other
  six are listed for posterity in case we ship the app to other
  mahallem markets later.
* Request shape (matches mahallem's helper exactly):
  ```json
  POST /translate
  { "q": "chicken handi", "source": "en", "target": "ru", "format": "text" }
  ```
* Quality on culinary copy: serviceable for tags / category /
  ingredients; somewhat literal on instructions. We tighten the
  output with a small **glossary** table (Section 4.4) for the
  ~150 high-traffic culinary terms.

**Fallback — MyMemory.**

* Reachable at `https://api.mymemory.translated.net/get?q=...&langpair=en|ru&de=support@mahallem.ist`.
* Free tier (anonymous): 1 000 words/day, ~5 000 with the email
  parameter, ~50 K with the keyed plan — same email mahallem
  already uses.
* Used when LibreTranslate (a) returns an empty / echo response,
  (b) fails 5xx, or (c) is unreachable for > 2 s.
* Also used as **primary** for the three RTL/Persianate languages
  LibreTranslate doesn't ship models for in mahallem (`fa, ar, ku`),
  if we ever expand beyond `en/ru`.

Neither provider routes traffic via Google. Both work from a
Russian IP today.

### 4.2 What to translate, what not

| Field | Translate? | Notes |
| --- | --- | --- |
| `name`, `category`, `area`, `tags`, `ingredients[].name`, `instructions` | yes | Stored bilingually. |
| `ingredients[].measure` | no | "1 cup", "200 g" — formatting risk outweighs benefit. |
| `youtubeUrl`, `sourceUrl`, `imageUrl` | no | URLs. |

LibreTranslate has a known quirk where capitalized inputs can be
left untranslated. mahallem normalizes by sending `q.toLowerCase()`
and re-capitalizing the first letter of the response; we copy that
behaviour.

### 4.3 Failure modes & fallback chain

```
translate(text, src, dst):
  if glossary[src→dst].has(text): return glossary[...][text]
  if cache.has(text, src, dst):    return cache.get(...)
  try: return libreTranslate(text, src, dst)        # primary
  catch (timeout, 5xx, empty, echo):
    try: return myMemory(text, src, dst)            # fallback
    catch:
      enqueueRetry(recipeId, field)                 # background job
      return null                                    # caller renders source-lang text
```

* Network error / 5xx on **both** providers → write `null` for that
  field, increment `translation_retry_count`. The 10-minute cron
  (mahallem already runs it — see
  `SMART_BACKGROUND_TRANSLATION.md`) picks rows with NULLs and
  retries up to 10 times before giving up.
* 429 → exponential backoff, jitter; client sees a generic transient
  error.
* Echo (output equals input) → treat as failure, fall through to
  MyMemory.
* On total failure the phone renders the source-language string. We
  do **not** show "translation unavailable" placeholders — graceful
  degrade is required by the mahallem playbook and avoids dead-end
  UX for users who can read both languages anyway.

### 4.4 Glossary table

A tiny `translation_glossary` table (mirrors mahallem's) bypasses the
MT engine for high-traffic phrases that LibreTranslate gets wrong:

```sql
CREATE TABLE translation_glossary (
  phrase_en VARCHAR(200) PRIMARY KEY,
  phrase_ru VARCHAR(200) NOT NULL,
  hit_count INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMP DEFAULT NOW()
);
```

Seeded with category / area names (`Beef → Говядина`, `Italian →
Итальянская`) and the top ~150 ingredients from TheMealDB. Edits go
through a small admin endpoint; cache invalidation is by
`phrase_en`. The glossary is checked **before** the cache and the
MT call.

### 4.5 Permanent translation cache

A second table holds every successful MT call so we never pay twice
for the same string (mahallem's pattern, transcribed verbatim):

```sql
CREATE TABLE translation_cache (
  source_text   TEXT NOT NULL,
  source_lang   VARCHAR(5) NOT NULL,
  target_lang   VARCHAR(5) NOT NULL,
  translated_text TEXT NOT NULL,
  hit_count     INT NOT NULL DEFAULT 1,
  created_at    TIMESTAMP DEFAULT NOW(),
  last_hit_at   TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (source_text, source_lang, target_lang)
);
```

No TTL — translations of recipe ingredients don't go stale. Eviction
only if the table outgrows its disk budget (we cap at 1 M rows;
LRU on `last_hit_at` if exceeded). For 2 000 recipes × ~25 fields
that is ~50 K rows, well under cap.

## 5. MongoDB as the recipe buffer

MongoDB lives in the `mahallem_ist` docker stack alongside the
translation containers. The phone never talks to MongoDB directly —
only through the Node API. The `translation_glossary` and
`translation_cache` tables (Section 4.4–4.5) live in the existing
Postgres alongside other mahallem caches; only the bilingual recipe
payload itself goes into MongoDB.

### 5.1 Collection `recipes`

```js
{
  _id: 52772,                       // TheMealDB idMeal
  source: "themealdb",
  imageUrl: "https://www.themealdb.com/images/media/meals/.../<id>.jpg",
  thumbUrl: "<imageUrl>/medium",
  youtubeUrl: "...",
  sourceUrl: "...",
  // bilingual payload
  i18n: {
    en: {
      name, category, area, tags: [...],
      ingredients: [{ name, measure }, ...],
      instructions
    },
    ru: { /* same shape, translated */ }
  },
  // bookkeeping
  fetchedAt: ISODate,               // when we pulled from TheMealDB
  translatedAt: ISODate,            // when ru side was filled
  popularity: 0,                    // tap count (optional)
  contentHash: "<sha256 of english payload>"
}
```

* Indexes: `{ _id: 1 }` (default), `{ "i18n.en.name": "text", "i18n.ru.name": "text" }`,
  `{ fetchedAt: -1 }`.
* `contentHash` lets us detect when TheMealDB updated a recipe and
  re-translate only the changed fields.
* Server-side cap: keep at most **2 000** recipes in MongoDB. When
  the cap is exceeded, drop the lowest-popularity / oldest-fetched
  entries.

### 5.2 Server endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/recipes?lang=ru&since=<iso>&limit=200` | Returns recipes updated after `since`, oldest-first, capped at `limit`. Used by the phone for incremental sync. |
| `GET` | `/recipes/:id?lang=ru` | Single recipe details, including image URLs, in the requested language. If missing in MongoDB, the server pulls from TheMealDB, translates, persists, then responds. |
| `GET` | `/recipes/search?q=...&lang=ru&limit=20` | Server-side text search over `i18n.<lang>.name`. On miss falls back to `TheMealDB /search.php?s=q`, then translates and persists each hit. |
| `GET` | `/health` | Liveness. |

All endpoints are protected by the same auth the rest of the
mahallem_ist stack uses (App Check / signed app-attestation token).
Per-IP rate limit + body-size cap stay in front.

### 5.3 Server background jobs

* **Hourly**: pull random recipes from `TheMealDB /random.php` to
  keep the cache fresh; translate; insert/update.
* **Daily**: re-validate top-popular recipes (`HEAD` against
  TheMealDB if available; otherwise re-`lookup`) and refresh if
  `contentHash` changed.

## 6. Phone-side storage — capped local mirror

The phone keeps **at most 200 recipes** locally so the list and
details work offline and the language toggle is instant.

### 6.1 Local store: Drift (SQLite)

| Engine | Why | Why not |
| --- | --- | --- |
| **Drift / sqflite** ✅ | Full text index, range queries, well-known on Flutter, supports both iOS and Android. | A bit more boilerplate than Hive. |
| Hive / Isar | Faster for pure key-value. | Weaker query story; `isar` ships native libs that complicate the build. |
| MongoDB Realm | Direct MongoDB sync would be ideal. | Pulls in Realm SDK, ties us to Atlas pricing, and the key is then on the phone — same A02 problem we're avoiding. |

We wrap Drift behind `RecipeRepository` so the upper layers don't see
the engine. If we ever switch to Realm Sync, only the repository is
touched.

### 6.2 Eviction policy

* Capacity: `kMaxLocalRecipes = 200` (rough envelope: 200 docs ×
  ~6 KB JSON + image URLs only ≈ 1.5 MB; images stay in the OS-level
  HTTP cache, not in SQLite).
* Order: LRU by `lastSeenAt` (updated every time the user opens the
  recipe in the list). Ties broken by `fetchedAt` ascending.

### 6.3 Sync algorithm

```
on app start (and every 15 minutes while in foreground):
  if !online: return
  let since = max(localFetchedAt, now - 30d)
  GET /recipes?lang=<currentLang>&since=since&limit=200
  upsert each into local store
  enforce kMaxLocalRecipes (drop LRU)
```

* `since` makes the response payload tiny on the steady state.
* The phone always asks in the **current** language; the OTHER
  language is fetched lazily when the user toggles. (Alternative:
  always fetch both — costs ~2× bytes but avoids the toggle latency
  spike. Pick once we have telemetry.)

### 6.4 Search flow

```
user types "arrabiata":
  1. Local prefix/contains match in current lang  → instant predictions
  2. On submit (or after 250 ms debounce w/ no local hits):
     GET /recipes/search?q=arrabiata&lang=ru
  3. Upsert returned recipes locally; show in the list
```

Local results win the race — server search is only consulted when
local has fewer than 5 matches, so we don't burn bandwidth on every
keystroke.

### 6.5 Details flow

```
user taps a card:
  1. If local doc has full body in current lang → render
  2. Else (lite or wrong lang or stale):
     GET /recipes/:id?lang=<currentLang>
     upsert locally, render
```

## 7. Pictures

Images stay on TheMealDB CDN. We store **only the URL** in MongoDB
and on the phone. The phone uses `cached_network_image` so the
binary itself is in the platform HTTP cache — no need to push JPEGs
through MongoDB. If we ever go offline-first for images too, we add
a worker that downloads `/medium` thumbnails into app docs and
swaps `imageUrl` → `file://...` in the local row.

## 8. Migration plan

1. **Static i18n** — introduce `flutter_localizations`, move `S` over
   to ARB. No backend dependency. Ships first.
2. **Server `/recipes` API** in mahallem_ist — minimal `GET /recipes`
   and `GET /recipes/:id`, MongoDB upsert. Translation goes through
   the existing `lib/utils/translation.js` helper that already wraps
   LibreTranslate + MyMemory; we add a thin `translateRecipe(meal)`
   on top that batches all string fields per recipe. No Flutter
   changes yet; verify with curl.
3. **Phone `RecipeRepository`** with Drift + LRU. Replace direct
   `RecipeApi` calls in `RecipeListLoader` and details navigation.
   TheMealDB code stays as a fallback during cutover, then is
   removed.
4. **Search** — point `SearchAppBar` predictions at the repository
   first, server next.
5. **Background sync** — `WorkManager` (Android) + BGProcessing task
   (iOS) every 15 min while app is active; foreground refresh on
   `AppLifecycleState.resumed` if `online`.

## 9. Open questions

1. **Auth on the new endpoints.** `recipe_list` has no user accounts.
   Minimum viable: App Check / Play Integrity gating per app build.
   Note: Play Integrity itself is a Google service. Acceptable here
   because it runs at install/attestation time on the device, not on
   the translation hot path; if Play Integrity is blocked, the app
   downgrades to a shared HMAC token baked at build time + per-IP
   rate limit.
2. **Capacity ceiling.** LibreTranslate is CPU-bound on the host;
   benchmark before going wide. mahallem currently sustains ~30
   req/s on a 4-vCPU container. At 25 fields per recipe and 2 000
   recipes total, the one-time translation pass is ~50 K calls →
   ~30 minutes wall time. After that, only deltas + glossary
   lookups, which are negligible.
3. **MongoDB hosting.** Reuse the existing mahallem_ist MongoDB
   instance vs. a dedicated database for recipes. Probably the
   former under `db: recipes`.
4. **Both-languages-or-one.** Either translate on demand
   per-language (cheaper, slower toggle) or always store both
   (instant toggle, ~2× translation cost). Recommended: store both
   at write time — LibreTranslate is free at the marginal call, so
   the only cost is CPU time we already pay for mahallem.
5. **Adding more languages.** The same pipeline scales to all 10
   mahallem languages with no code change — only new ARB files
   client-side and an entry per locale in the recipe `i18n.{lang}`
   sub-document. Recommended order if we ever go beyond `en/ru`:
   `tr` (mahallem core), `uk`, `es`, `fr`, `de`, `it`, then `fa`,
   `ar`, `ku` via MyMemory.
