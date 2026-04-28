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
2. Only one translation provider, reused from `mahallem_ist`: Google
   Gemini via the existing `GEMINI_API_KEY`.
3. Phone-side storage for recipes is a small, capped MongoDB-backed
   cache — both as a "buffer" so we don't translate the same recipe
   twice, and as the source of the list / details / images while
   online or offline.
4. The phone always shows the freshest data when connected. If the
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

## 4. Dynamic content — Gemini, server-side only

We reuse the `GEMINI_API_KEY` already provisioned in
`/Volumes/Working_MacOS_Extended/mahallem/mahallem_ist/local_docker_admin_backend/.env`.
**The key never reaches the Flutter binary.** That is OWASP A02
(Cryptographic Failures) / A07 (Authentication Failures): a key
shipped in an APK/IPA can be extracted by anyone who unzips the
bundle and used until the quota is exhausted at our expense.

```
   Flutter app
       │  HTTPS
       ▼
   Recipes API   ──Gemini API── (translation)
   (Node, in
    mahallem_ist
    docker stack)
       │
       ▼
   MongoDB (recipes + translations)
       ▲
       │  scheduled refresh
   TheMealDB (upstream)
```

The same Node service that already holds `GEMINI_API_KEY` exposes a
new namespace `/recipes/*`. Endpoints (Section 5).

### 4.1 Provider: `gemini-1.5-flash`

* Endpoint:
  `POST https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$GEMINI_API_KEY`
* Prompt is **batched** per recipe — name, category, area, tags,
  ingredient names, and instructions are sent as one numbered list
  and parsed back. Roughly 25 fields → 1 round-trip.
* Why Gemini over Google Translate / DeepL: the only translation-
  capable key already provisioned is for Gemini. No new contracts.
  Quality on cooking text is on par with DeepL for `ru`↔`en`.

### 4.2 What to translate, what not

| Field | Translate? | Notes |
| --- | --- | --- |
| `name`, `category`, `area`, `tags`, `ingredients[].name`, `instructions` | yes | Stored bilingually. |
| `ingredients[].measure` | no | "1 cup", "200 g" — formatting risk outweighs benefit. |
| `youtubeUrl`, `sourceUrl`, `imageUrl` | no | URLs. |

### 4.3 Failure modes

* Network error / 5xx → fall back to source language; show a small
  "translation unavailable" hint, never crash.
* 429 → exponential backoff on the server; client treats it as a
  transient network error.
* Echo bug (Gemini sometimes returns the source unchanged) → cheap
  heuristic: if output equals input, retry once with a stricter
  prompt.

## 5. MongoDB as the recipe buffer

MongoDB lives in the `mahallem_ist` docker stack. The phone never
talks to MongoDB directly — only through the Node API.

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
   and `GET /recipes/:id`, MongoDB upsert, Gemini translation. No
   client changes yet; verify with curl.
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
2. **Cost ceiling.** Gemini Flash is cheap (~$0.075 per 1M input
   tokens at time of writing) but daily caps must exist server-side;
   on cap, return source language only.
3. **MongoDB hosting.** Reuse the existing mahallem_ist MongoDB
   instance vs. a dedicated database for recipes. Probably the
   former under `db: recipes`.
4. **Both-languages-or-one.** Either translate on demand
   per-language (cheaper, slower toggle) or always store both
   (instant toggle, ~2× translation cost). Decide after first week
   of telemetry.
