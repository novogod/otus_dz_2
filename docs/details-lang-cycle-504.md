# Details-page language cycle: 504 hang and Italian residue

**Date:** 2026-04-30. **Status:** investigation → fix in progress.

## Symptom

User opens "Borscht" recipe details with UI in Italian (cached, instant),
then taps the language button to switch to Turkish on the details page.
Spinner runs ~3–4 minutes, then the page renders with the Turkish UI
chrome but **Italian recipe content** (title, ingredients, instructions
unchanged). Flutter logs show:

```
[lang] details lookup failed: DioException [bad response]:
  status code 504 — server failed to fulfil an apparently valid request
```

Reproduces reliably for any recipe whose target-language translation is
not yet cached. Borscht specifically has all 10 locales cached (verified
by direct curl: `/recipes/lookup/53078?lang=tr` returns 200 in ~400 ms),
but the request still 504s when it travels through the saturated server.

## Root cause: list-page `_retranslate` saturates the server

When the user clicks the language button **anywhere in the app**, the
global `appLang` ValueNotifier fires. Two listeners react:

1. **Details page** (`recipe_details_page.dart::_onLangChanged`) issues
   one `GET /recipes/lookup/<id>?lang=tr` — a fast, focused request.
2. **List page loader** (`recipe_list_loader.dart::_onLangChanged` →
   `_retranslate`) is **still mounted underneath** in the Navigator
   stack and ALSO reacts. It iterates the entire ~200-recipe feed and
   fires up to 8 parallel `/recipes/lookup/<id>?lang=tr` requests for
   every uncached recipe in the new language.

Both flows go to the same `mahallem-user-portal` Node process, which
funnels uncached translations through `translateLongField` →
`Promise.all(sentences, translateBest)` → cascade tiers 3..6.

When MyMemory and public LibreTranslate are in their typical 429 burst
(both seen continuously in production logs), every sentence falls
through ~22 s of timeouts to the self-hosted local LibreTranslate
container, which is currently CPU-saturated and emits ~170 s per
sentence under contention:

```
⚠️ Slow translation en->tr: 171141ms for "tofu, greens & cashew stir-fry..."
⚠️ Slow translation en->it: 169817ms for "If skinless beans are unavaila..."
```

With ~100 list-feed translation requests in flight, the Node event
loop and the local LT container are both saturated, so the *details*
`/lookup` — which would normally return in 400 ms from the DB cache —
sits in the connection queue. **nginx aborts the upstream connection
at `proxy_read_timeout` (~3–4 minutes) and returns 504.**

## Why "Italian residue"

The details page's `_onLangChanged` catches the 504, logs it, and
**leaves the previous-language `_recipe` on screen** (per
`docs/translation-pipeline.md` §"Offline tolerance" — "the previous-
language copy stays visible"). This is the correct contract for offline
fallback, but it is misleading when the cause was a *load-induced 504*
rather than genuine offline.

## Why Borscht-from-the-list works

When the user lands on the list in Turkish first and *then* taps the
Borscht card, the details page opens with `_recipe` already populated
from the list result (Turkish), and `_onLangChanged` never fires. No
network call, no server pressure, no 504.

## Fixes — see `todo/14`

Seven coordinated changes across server and client:

1. **Hard deadline (25 s) on `translateLongField`.** Bounds `/lookup`
   worst case to <30 s; on timeout return source uncached so a later
   call retries when external tiers recover.
2. **English fallback on details-page lookup.** Mirror the list-page
   behavior added in `47c942c`: on 504/timeout, retry `lang=en` so the
   user sees coherent content under the new flag instead of stale
   residue from the previous language.
3. **60 s cool-down on MyMemory and publicLT after a 429.** Skip those
   tiers for one minute after a 429 so the cascade stops wasting
   ~22 s/sentence walking known-dead engines.
4. **`pLimit(2)` on local LibreTranslate fan-out.** `Promise.all` over
   30 sentences hammers a single self-hosted container; capping
   in-flight at 2 keeps its CPU healthy and drops per-sentence latency
   from ~170 s back to ~3–8 s.
5. **nginx `proxy_read_timeout` → 300 s** as defense in depth. With (1)
   in place this is unused headroom, but prevents a regression if (1)
   is bypassed for any reason.
6. **Skip list-page `_retranslate` when a details page is on top of
   the Navigator stack.** The user can't see the list, so spending the
   feed's parallelism on translating it now is pure waste — defer
   until they pop back to the list.
7. **Reduce list-page `_retranslate` concurrency 8 → 2** when the list
   is in the background (route stack > 1). 8-way blast was tuned for
   "user staring at the list waiting for it to fill", not "user
   reading details".

## Expected outcome

- **Cached recipe (Borscht):** 504 → ~500 ms ✅
- **Cold recipe (TR not cached):** 504 → ~5 s with Turkish content ✅
- **Worst case (cascade fully degraded):** ≤30 s with English content
  fallback rather than 504 / previous-language residue ✅

## What is NOT addressed

- TheMealDB upstream outages (no new ingest)
- Gemini quota fully exhausted (cold recipes echo source until recovery)
- Local LT container OOM/crash
- Postgres connection pool exhaustion
- Per-id race condition: two simultaneous lookups for the same cold
  recipe both run the cascade independently (would need a mutex)

These remain latent and will be addressed if/when they surface.
