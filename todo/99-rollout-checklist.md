# 99 — Rollout & rollback checklist

**Refs:** all chunks above.

## Order of deploy

1. **Client P0** (chunk 01) — ship in next TestFlight/internal track
   build. No server change.
2. **Client P1 / P2** (chunks 02–06) — bundle into one release once 01
   has soaked ≥ 48 h.
3. **Server P1** (chunks 07, 09, 10) — deploy in staging first if
   available, else canary on prod with `WARMUP_ON_START=0` then flip
   to `1`. Watch logs for cascade errors.
4. **Client uses bulk page** (chunk 08) — gated behind
   `--dart-define=USE_BULK_PAGE=1`; flip after 24 h of clean server
   logs.
5. **Client P2 polish** (chunks 11, 12) — independent of server.
6. **P3** (chunk 13) — only on product request.

## Pre-flight

* `git status` clean in both repos.
* `flutter analyze && flutter test --no-pub` green.
* `npm test --prefix local_user_portal` green.
* `docker compose config -q` validates compose changes.

## Smoke after deploy

```bash
# server health
curl -fsS https://mahallem.ist/health | jq .
# bulk endpoint
curl -fsS 'https://mahallem.ist/recipes/page?lang=ru&limit=10' | jq '.recipes | length'
# Redis
ssh root@72.61.181.62 'docker exec mahallem-redis redis-cli -n 4 INFO memory | grep maxmemory_human'
# warmup
ssh root@72.61.181.62 'docker logs --since 10m mahallem-user-portal 2>&1 | grep warmup'
```

## Rollback

* **Client:** revert single commit; previous release works against any
  server version (compose changes are additive).
* **Server:** `docker compose -f docker-compose.yml down user-portal &&
  git revert <sha> && docker compose up -d --no-deps user-portal`.
* **Redis:** to disable L1 without rebuild, set
  `REDIS_DISABLED=1` env var (add an `if (!process.env.REDIS_DISABLED)`
  guard in `getOrSet`); compose recreate.
* **Bulk page:** flip `USE_BULK_PAGE=0` in client build → fall back to
  category fan-out.

## Sign-off

Each chunk's PR description must:

* Link to its `todo/NN-*.md` file.
* Quote the **Acceptance** section.
* Paste test output (or CI link).
* Note any deviation from the plan.
