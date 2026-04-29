# 10 — Server: warm-up job after `npm start`

**Refs:** [categories.md §9.1 (c)](../docs/categories.md).
**Priority:** P1. **Scope:** `[server]`. **Depends on:** 07, 09.

## Goal

After container start, prewarm Redis (chunk 09) and Postgres
`translation_cache` for the top-200 most-hit recipes per active language,
so the first user-visible request in a fresh language doesn't pay the
30–90 s tier-cascade tax.

## Changes

* `local_user_portal/lib/jobs/warmup-recipes.js` (new):
  * Picks `SUPPORTED_LANGS` from env.
  * For each lang, runs `SELECT id FROM recipes ORDER BY popularity DESC
    LIMIT 200` (or fall back to `recipes_i18n.last_hit_at DESC` if no
    `popularity` column), then calls the same `translateRecipeFields`
    used by `getById`.
  * Concurrency: 4 langs × 4 recipes in parallel = 16 concurrent
    cascades (configurable `WARMUP_CONCURRENCY=16`).
  * Logs `warmup: lang=ru done in 27s, hits=180/200`.
* `local_user_portal/index.js`: invoke after Postgres pool is ready,
  guarded by `WARMUP_ON_START !== '0'`.

## Acceptance

* Cold container restart → `warmup` log lines for each active lang
  within ~5 min total wall clock.
* Subsequent user request `/recipes/page?lang=ru` ≤ 1 s.

## Tests

* `npm test --prefix local_user_portal`:
  * Add `tests/jobs/warmup-recipes.spec.js`:
    * `warmup translates each id once per lang`.
    * `warmup is no-op when WARMUP_ON_START=0`.
* Smoke:
  ```bash
  ssh root@72.61.181.62 'docker logs mahallem-user-portal 2>&1 | grep warmup | tail -20'
  ```
