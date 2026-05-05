# Backend ingester и size-cap для таблицы `recipes`

Файл: `routes/recipes.js` в контейнере `mahallem-user-portal`
(исходник на сервере: `/root/mahallem/mahallem_ist/local_user_portal/routes/recipes.js`).

## Контекст

На 2026-05-05 production содержит **616 рецептов**, таблица `recipes`
занимает 11 MB при общем размере БД 423 MB. Капа задаётся переменной
`RECIPES_CACHE_CAP` (по умолчанию 2000 строк). Ингест строго
**ленивый**: новые англоязычные строки попадают в БД только когда
кто-то делает `/lookup/:id`, `/search`, `/random` или `/filter`.
Активного pull-а из TheMealDB нет.

При этом TheMealDB добавляет новые рецепты со временем (см.
[`docs/foodapi_alternative.md`](foodapi_alternative.md)) — без
активного ингеста они не попадают к нам, пока какой-нибудь клиент
случайно не запросит свежий id. И наоборот: 1.5 GB-капы по байтам
у нас нет, но пользователь хочет именно byte-budget — чтобы карточки
жили forever, пока хватает места, и только при переполнении вытеснять
самые старые.

## Что меняем

### 1. Daily-ingester

* Cron в процессе `local_user_portal` (`node-cron`, выражение
  `'0 4 * * *'` — 04:00 каждый день, серверная TZ).
* Шаги одной итерации:
  1. Найти `MAX(id)` в нашей таблице среди upstream-строк
     (`id < RECIPES_USER_MEAL_ID_FLOOR`, по умолчанию 1_000_000).
  2. Зондировать upstream `lookup.php?i=$max+1, $max+2, …` по одному
     id, **пропуская** «дыры» (TheMealDB возвращает `meals: null`),
     пока не наберётся **10 новых рецептов** или пока не пройдено
     `INGEST_MAX_PROBES` подряд впустую (по умолчанию 50).
  3. Каждый найденный meal проходит через существующий
     `upsertEnglish(...)` — только английский источник;
     остальные локали накатываются ленивым cascade на первом
     `/lookup/:id?lang=...`.
  4. По завершении вызвать `_evictIfOverSizeCap()` (см. ниже).
* Логирование: `[ingest] start`, `[ingest] probed N, ingested K,
  next=$max+N` в stdout. Этого достаточно для grep по логам контейнера.
* Защита от наложения: in-memory флаг `ingestRunning`. Если cron
  стрельнул, а предыдущий ещё не закончился — skip с warning.
* Защита от падения процесса: всё в `try/catch`, ошибки только
  логируются. Cron продолжит работать на следующий день.

ENV-переменные:

| Имя                         | По умолчанию | Назначение                                   |
| --------------------------- | ------------ | -------------------------------------------- |
| `RECIPES_INGEST_ENABLED`    | `true`       | Кill switch (`false` отключает cron)         |
| `RECIPES_INGEST_CRON`       | `0 4 * * *`  | cron-выражение                               |
| `RECIPES_INGEST_BATCH_SIZE` | `10`         | Сколько новых meals брать за один прогон     |
| `RECIPES_INGEST_MAX_PROBES` | `50`         | Сколько подряд 404-id допустимо пройти       |

### 2. Size-cap (1.5 GB)

* Заменяем `_evictIfOverCap()` на `_evictIfOverSizeCap()`:
  * Берём `pg_total_relation_size('recipes')` через `pg_catalog`.
  * Целевой максимум — `RECIPES_SIZE_CAP_BYTES`, по умолчанию
    `1.5 * 1024 ** 3 = 1610612736` байт.
  * Если размер ≤ капы — выходим (по сути no-op в нашем случае —
    11 MB сильно меньше 1.5 GB).
  * Если превышает — удаляем строки **по `fetched_at ASC`** (самые
    старые в нашей БД), **исключая** user-меалы (`id ≥
    RECIPES_USER_MEAL_ID_FLOOR`). Удаляем порциями по 50 строк, после
    каждой порции пересчитываем размер (`pg_total_relation_size`
    обновляется только после `VACUUM`, поэтому на практике один
    проход с делитом достаточно: PG сам реклеймит блоки на следующем
    autovacuum). Если за 10 итераций размер не сошёлся — выходим
    с warning, чтобы не уйти в бесконечный цикл.
* Старая количественная капа `RECIPES_CACHE_CAP` остаётся как
  **safety upper-bound** (защита от ошибки в byte-cap-логике).
  Если строк больше `cap`, доудаляем, как раньше.

ENV-переменные:

| Имя                            | По умолчанию      | Назначение                              |
| ------------------------------ | ----------------- | --------------------------------------- |
| `RECIPES_SIZE_CAP_BYTES`       | `1610612736` (1.5 GB) | Жёсткий потолок на таблицу `recipes` |
| `RECIPES_USER_MEAL_ID_FLOOR`   | `1000000`         | Граница user vs TheMealDB ids (как было) |
| `RECIPES_CACHE_CAP`            | `2000`            | Safety-row-cap (как было)               |

### 3. Совместимость

* Public API не меняется: те же эндпоинты, те же payload-shape.
* Ленивый ингест через `searchByName/lookup/filter` остаётся как
  есть — daily cron только дополняет его, не заменяет.
* Пользовательские meals не трогаются: floor-guard в eviction +
  отдельный счётчик идов `≥ FLOOR` в `createUserMeal`.

## Деплой

Изменения только в одном файле — `routes/recipes.js`. Источник на
сервере **не bind-mounted**, поэтому деплой:

```sh
scp -i ~/.ssh/mahallem_key_2 routes/recipes.js \
    root@72.61.181.62:/root/mahallem/mahallem_ist/local_user_portal/routes/recipes.js
ssh -i ~/.ssh/mahallem_key_2 root@72.61.181.62 \
    'docker cp /root/mahallem/mahallem_ist/local_user_portal/routes/recipes.js mahallem-user-portal:/app/routes/recipes.js && docker restart mahallem-user-portal'
```

Зависимость `node-cron` уже стоит в образе (используется в других
сервисах). Если `require('node-cron')` упадёт — падать на старте, не
рантайме. Smoke: `docker logs --tail=50 mahallem-user-portal | grep ingest`.

Чек после деплоя:

```sh
curl -s 'https://mahallem.ist/recipes/page?offset=0&limit=1' \
  | python3 -c "import json,sys;d=json.load(sys.stdin);print('total:',d['total'])"
```

После первого 04:00-прогона `total` должен подрасти, если в TheMealDB
есть новые id выше нашего MAX.
