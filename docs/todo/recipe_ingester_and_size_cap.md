# TODO: backend ingester + size-cap для `recipes`

См. контекст и обоснование в [`docs/recipe-ingester-and-size-cap.md`](../recipe-ingester-and-size-cap.md).

Цель: на production добавить ежедневный (04:00) ингест 10 свежих
рецептов из TheMealDB и заменить count-cap (2000 строк) на
byte-cap (1.5 GB), сохранив save-forever-policy для всего, что
влезает.

Все правки — в `routes/recipes.js` контейнера `mahallem-user-portal`
(сервер: `/root/mahallem/mahallem_ist/local_user_portal/routes/recipes.js`).

---

## 1. Подготовка

- [ ] `git pull` на dev-машине, скопировать актуальный `recipes.js` с
      сервера через `docker cp` для diff-base.
- [ ] Убедиться, что `node-cron` уже есть в `package.json` контейнера
      (`docker exec mahallem-user-portal node -e "require('node-cron')"`).
      Если нет — добавить в `package.json` и поднять образ.

## 2. Eviction → byte-cap

- [ ] В классе `Recipes` ввести константы:
      ```js
      const SIZE_CAP_BYTES = Number(process.env.RECIPES_SIZE_CAP_BYTES || 1.5 * 1024 ** 3);
      const USER_MEAL_FLOOR = Number(process.env.RECIPES_USER_MEAL_ID_FLOOR || 1_000_000);
      ```
- [ ] Реализовать `async _tableSizeBytes()` — `SELECT pg_total_relation_size('recipes')::bigint AS s`.
- [ ] Реализовать `async _evictIfOverSizeCap()`:
      * до 10 итераций;
      * каждая: если `size <= SIZE_CAP_BYTES` — break;
      * `DELETE FROM recipes WHERE id IN (SELECT id FROM recipes WHERE id < $1 ORDER BY fetched_at ASC LIMIT 50)` с `[USER_MEAL_FLOOR]`;
      * после цикла — старая count-cap-проверка как safety upper-bound.
- [ ] Заменить все вызовы `_evictIfOverCap()` на `_evictIfOverSizeCap()`
      (в `upsertEnglish`, `createUserMeal`).
- [ ] Старый `_evictIfOverCap` оставить (вызывается из `_evictIfOverSizeCap` в конце как fallback) либо вкомпилировать туда же.

## 3. Daily ingester

- [ ] В верхней части файла добавить `const cron = require('node-cron');`.
- [ ] Добавить ENV-настройки рядом с `MEALDB_BASE`:
      ```js
      const INGEST_ENABLED = (process.env.RECIPES_INGEST_ENABLED || 'true') !== 'false';
      const INGEST_CRON = process.env.RECIPES_INGEST_CRON || '0 4 * * *';
      const INGEST_BATCH = Number(process.env.RECIPES_INGEST_BATCH_SIZE || 10);
      const INGEST_MAX_PROBES = Number(process.env.RECIPES_INGEST_MAX_PROBES || 50);
      ```
- [ ] В классе `Recipes` добавить метод
      `async runDailyIngest({ batch = INGEST_BATCH, maxProbes = INGEST_MAX_PROBES } = {})`:
      * `if (this._ingestRunning) { console.warn('[ingest] skip — previous run still active'); return; }`
      * `this._ingestRunning = true; try { … } finally { this._ingestRunning = false; }`
      * `const max = await this.q(\`SELECT COALESCE(MAX(id), 52000)::bigint AS m FROM recipes WHERE id < $1\`, [USER_MEAL_FLOOR]);`
      * Зондировать `id = max+1, max+2, …`:
        - `await this.fetchUpstream(\`${MEALDB_BASE}/lookup.php?i=${id}\`)`;
        - если `data?.meals?.[0]` — `await this.upsertEnglish(meal)`, `ingested++`;
        - иначе — `consecutive404++`;
        - выход: `ingested >= batch || consecutive404 >= maxProbes` или прошли 5×batch попыток.
      * Логировать `[ingest] start max=…`, `[ingest] hit id=… "<strMeal>"`, `[ingest] done ingested=K probed=N`.
      * В конце — `await this._evictIfOverSizeCap()`.
- [ ] В нижней части файла, после регистрации route-handlers, добавить:
      ```js
      if (INGEST_ENABLED) {
        cron.schedule(INGEST_CRON, () => {
          recipesInstance.runDailyIngest()
            .catch((err) => console.error('[ingest] failed', err));
        }, { timezone: process.env.TZ || 'Europe/Istanbul' });
        console.log(`[ingest] scheduled "${INGEST_CRON}"`);
      }
      ```
      Hook нужно прицепить к тому же объекту `Recipes`, что обслуживает
      route-handlers — добавить ему имя или вынести в module-scope const.

## 4. Smoke + ручной триггер (опционально, dev-only)

- [ ] Добавить **только если `NODE_ENV !== 'production'`** маршрут
      `POST /recipes/_admin/ingest-now` с auth-check (existing
      admin token middleware) — чтобы вручную дёрнуть `runDailyIngest`
      без ожидания 04:00. Логи проверять через `docker logs`.

## 5. Деплой

- [ ] Локально — лёгкий smoke: `node -e "require('./routes/recipes.js')"`
      из директории сервиса (или Docker-build).
- [ ] `scp` → `docker cp` → `docker restart mahallem-user-portal`.
- [ ] `docker logs --tail=80 mahallem-user-portal | grep ingest` —
      должно быть `[ingest] scheduled "0 4 * * *"`.
- [ ] (Опционально) дёрнуть admin-эндпоинт из п.4, проверить, что
      `total` в `/recipes/page?limit=1` подрос (ожидаемо: текущий 616 → ≤ 626).

## 6. Проверки безопасности

- [ ] Eviction **никогда** не должен трогать `id >= USER_MEAL_FLOOR`
      (юнит-тест: вставить фейковый user-meal, искусственно занизить
      `RECIPES_SIZE_CAP_BYTES` до 1024, прогнать `_evictIfOverSizeCap`,
      проверить что user-meal жив).
- [ ] Cron-handler оборачивает всё в try/catch — падение HTTP к
      TheMealDB не должно ронять процесс.
- [ ] Rate-limit: между upstream-зондами вставить `await sleep(150)`
      (TheMealDB free tier — без жёстких лимитов, но 50 параллельных
      запросов всё равно лишние).

## 7. Документация

- [x] [`docs/recipe-ingester-and-size-cap.md`](../recipe-ingester-and-size-cap.md) — спека.
- [ ] После деплоя — короткая запись в [`docs/project_log.md`](../project_log.md):
      «Backend: daily 04:00 ingester + 1.5 GB byte-cap (commit ...)».
