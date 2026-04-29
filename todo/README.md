# Implementation TODO

Chunked plan to implement the recommendations in
[docs/categories.md](../docs/categories.md) (incl. §9 remedies) and
[docs/translation-buffer.md](../docs/translation-buffer.md).

Each chunk is sized to be **commit-and-push-able on its own** with a
green test gate. Order is dependency-aware: cheap, independent client
work first; server infra later; UX polish last.

Conventions:

* `[client]` = `recipe_list/` (Flutter).
* `[server]` = `mahallem_ist/local_user_portal/` (Express) +
  `local_docker_admin_backend/docker-compose.yml`.
* `[infra]` = compose / Redis / migrations.
* Each chunk has explicit **Acceptance** + **Tests** sections.
* Default test gate (client): `flutter analyze && flutter test --no-pub`.
* Default test gate (server): `npm test --prefix local_user_portal`
  (where applicable) + targeted `curl` smoke.

Files in this folder:

* `01-client-cap-bump.md` — P0, byteCap 5 MB → 64 MB.
* `02-offline-reload-guard.md` — P1, do not wipe feed when offline.
* `03-reload-button-affordance.md` — P2, rotation + linear progress.
* `04-feed-config-extraction.md` — P2, magic constants → config.
* `05-rng-no-repeat-categories.md` — P2, dedupe last picks.
* `06-streaming-feed-render.md` — P1, render as categories arrive.
* `07-server-bulk-page-endpoint.md` — P1, `/recipes/page`.
* `08-client-seed-from-bulk-page.md` — P1, use `/recipes/page` on cold start.
* `09-server-redis-l1.md` — P1, Redis L1 with `allkeys-lru` 1.5 GB.
* `10-server-warmup-job.md` — P1, prewarm cascade on boot.
* `11-client-lru-per-language.md` — P2, partition cache per lang.
* `12-blob-instructions-table.md` — P2, lazy-load HTML body.
* `13-app-reload-ticker.md` — P3, optional global refresh.
* `99-rollout-checklist.md` — final canary + rollback plan.
