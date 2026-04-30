# 14 — Details-page lang cycle: bound latency, fall back to English, throttle list

**Refs:** [details-lang-cycle-504.md](../docs/details-lang-cycle-504.md),
[translation-pipeline.md](../docs/translation-pipeline.md).
**Priority:** P0. **Scope:** `[server][client]`.

## Goal

Eliminate the 3–4 minute spinner + 504 + previous-language residue when
the user cycles languages on the recipe details page.

## Changes

### Server (`mahallem_ist`)

* `local_user_portal/utils/translate-recipe.js`:
  * `translateLongField(text, src, tgt)`: wrap the whole function in a
    25 s `Promise.race` deadline. On timeout, return source uncached.
  * `translateLongField`: replace `Promise.all(sentences.map(...))`
    with a `pLimit(2)` queue when the cascade falls through to
    `local-libretranslate`. Local LT is the only tier that benefits
    from parallel requests but it CPU-saturates at >2 in flight.
* `local_user_portal/utils/libretranslate-public.js` and
  `utils/translation.js` (or wherever MyMemory call lives):
  * Module-level `lastErrorAt` timestamp. After a 429, skip the tier
    for 60 s. `getCooldownState()` exposed for tests.

### nginx (`mahallem_ist`)

* `local_docker_admin_backend/nginx/conf.d/*.conf` for the
  `user-portal` upstream: `proxy_read_timeout 300s;` (was default 60 s
  or 4 min depending on stanza). Defense-in-depth backstop.

### Client (`recipe_list`)

* `lib/ui/recipe_details_page.dart::_onLangChanged`:
  * On `lookup(id, lang=target)` failure, retry `lookup(id, lang=en)`
    before giving up. Mirrors `_retranslate` in the list loader
    (commit `47c942c`).
* `lib/ui/recipe_list_loader.dart::_onLangChanged`:
  * Track whether the loader's route is currently on top
    (`ModalRoute.of(context)?.isCurrent` or a GlobalKey on the
    Navigator with `_canPop` heuristic).
  * If NOT on top: skip `_retranslate` entirely — record `lang` as
    pending and run `_retranslate` only when the route returns to top
    (use `RouteObserver.didPopNext`).
  * If a `_retranslate` is in progress and the user pushes details:
    abort current sequence (set `_translateSeq` so old workers exit)
    and enter background mode.
* `lib/config/feed_config.dart`:
  * Add `translateConcurrencyBackground` (default 2). Used by
    `_retranslate` when `RouteObserver` reports a deeper route is
    active.

### Tests

* `mahallem_ist/local_user_portal/tests/recipes.test.js`:
  * `translateLongField` returns uncached source after 25 s.
  * Cool-down: second call within 60 s of a 429 does not invoke the
    tier.
* `recipe_list/test/`:
  * `_onLangChanged` on details page issues fallback to `en` after
    target-lang `lookup` throws.
  * Skip `_retranslate` when details route is on top.

## Acceptance

* Manual: open Borscht in IT, cycle to TR. Page renders Turkish
  content in <2 s. No 504 in server logs for the details lookup.
* Manual: open a cold recipe (no TR i18n key in DB), cycle to TR.
  Page renders ≤30 s with Turkish content if cascade succeeds, or
  English content if the deadline fires.
* `flutter analyze` clean. `node --test tests/` baseline pass count
  preserved (currently 18/20).
