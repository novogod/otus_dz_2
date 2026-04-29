# 09 — Server: Redis L1 buffer (1.5 GB, allkeys-lru)

**Refs:** [translation-buffer.md §5.1](../docs/translation-buffer.md),
[categories.md §9.1 (a)](../docs/categories.md).
**Priority:** P1. **Scope:** `[server]` + `[infra]`.

## Goal

In-memory L1 cache of fully-translated recipes in front of Postgres
`translation_cache`, with LRU eviction at 1.5 GB.

## Changes

### Compose

* `local_docker_admin_backend/docker-compose.yml`:
  ```yaml
  mahallem-redis:
    image: redis:7-alpine
    command: >
      redis-server
      --maxmemory ${RECIPES_REDIS_MAXMEMORY:-1500mb}
      --maxmemory-policy ${RECIPES_REDIS_POLICY:-allkeys-lru}
      --save ""           # disable RDB; pure cache
      --appendonly no
    networks: [mahallem]
    restart: unless-stopped
  ```
* `user-portal` env additions:
  * `REDIS_URL=redis://mahallem-redis:6379/4`
  * `RECIPES_REDIS_MAXMEMORY=1500mb`
  * `RECIPES_REDIS_POLICY=allkeys-lru`

### App

* `local_user_portal/lib/cache/redis-recipes.js` (new):
  * `getRecipe(id, lang)` / `setRecipe(id, lang, json, ttl?)` — keys
    `recipe:{id}:{lang}`, value JSON ≤ ~10 KB.
  * `getOrSet(id, lang, loader)` helper.
* `routes/recipes.js`: wrap `getById`, `filterByCategory`, and the new
  `getPage` (chunk 07) in `getOrSet`. On cache hit serve from Redis;
  on miss go through cascade and `setRecipe` afterwards.
* Postgres `translation_cache` untouched — still source of truth for
  individual translation strings.

## Acceptance

* `redis-cli -n 4 INFO memory` shows `maxmemory_human:1.50G`,
  `maxmemory_policy:allkeys-lru`.
* Hit-rate after 30 min of normal traffic ≥ 70 % (logged from
  `getOrSet` instrumentation).
* Cold path (Redis miss + Postgres hit) latency ≤ 1.5× baseline.

## Tests

* `npm test --prefix local_user_portal`:
  * Add `tests/cache/redis-recipes.spec.js` with `ioredis-mock`:
    * `getOrSet stores and retrieves`.
    * `respects allkeys-lru` (mock only — semantic test).
* Smoke (after deploy):
  ```bash
  ssh root@72.61.181.62 'docker exec mahallem-redis redis-cli -n 4 INFO memory | grep -E "maxmemory_human|maxmemory_policy"'
  curl -w '%{time_total}\n' 'https://mahallem.ist/recipes/page?lang=ru&limit=50' -o /dev/null  # warm
  curl -w '%{time_total}\n' 'https://mahallem.ist/recipes/page?lang=ru&limit=50' -o /dev/null  # cached → near-zero
  ```
