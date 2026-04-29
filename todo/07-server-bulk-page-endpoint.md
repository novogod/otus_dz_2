# 07 — Server: bulk `/recipes/page` endpoint

**Refs:** [translation-buffer.md §5.2](../docs/translation-buffer.md),
[categories.md §9.1 (b)](../docs/categories.md).
**Priority:** P1. **Scope:** `[server]`.

## Goal

One HTTP call returns up to 500 already-translated recipes for a given
language, sorted by `last_hit_at DESC`. Replaces the 14-fan-out at cold
start.

## API

```
GET /recipes/page?lang=ru&offset=0&limit=500
→ 200
{
  "recipes": [ { id, name, category, instructions, ingredients, … } ],
  "nextOffset": 500,
  "total": 12345
}
```

* `limit` clamp `[1, RECIPES_BULK_PAGE_SIZE_MAX=500]`.
* `lang` whitelisted against existing `SUPPORTED_LANGS`.
* Same auth/rate-limit as `/recipes/filter`.

## Changes

* `local_user_portal/routes/recipes.js`:
  * New handler `getPage(req, res)`.
  * Source: `recipes_i18n` join `translation_cache`; if missing
    translations → run cascade synchronously per missing field (reuse
    `translateRecipeFields`) and persist.
  * Optionally short-circuit through Redis once chunk 09 lands.
* `local_user_portal/utils/translate-recipe.js`: expose
  `translateRecipeFields(recipe, lang)` if not already exported.
* `docker-compose.yml`: nginx upstream timeout for `/recipes/page` ≥ 240 s
  (already covered by `proxy_read_timeout 240s` on `/recipes/`).

## Acceptance

* `curl 'https://mahallem.ist/recipes/page?lang=ru&limit=10'` returns
  10 fully-translated recipes < 5 s on warm DB.
* Cold lang `tr` first call ≤ 90 s, subsequent ≤ 1 s.

## Tests

* `npm test --prefix local_user_portal` (extend existing
  `tests/recipes.spec.js`):
  * `GET /recipes/page returns N recipes for warm lang`.
  * `GET /recipes/page rejects unsupported lang with 400`.
  * `GET /recipes/page clamps limit > 500`.
* Smoke: `curl -w '%{time_total}\n' '…/recipes/page?lang=ru&limit=500'
  -o /tmp/page.json && jq '.recipes | length' /tmp/page.json` =500.
