# Translation buffer & cache topology

> Status: 2026-04-29 — снимок текущей реализации + рекомендации по
> расширению до запрошенного «1–1.5 GB LRU буфера» на сервере и его
> прозрачной репликации в телефонную память на 500+ рецептов.

## 1. Что есть сейчас

### 1.1. Серверная сторона (`mahallem-user-portal`)

Файлы:

* [`utils/translation.js`](../../mahallem/mahallem_ist/local_user_portal/utils/translation.js)
  — `getCachedTranslation`, `cacheTranslation`, `getGlossaryTranslation`.
* [`utils/translate-recipe.js`](../../mahallem/mahallem_ist/local_user_portal/utils/translate-recipe.js)
  — каскад tier-ов и обогащение карточек.

Хранилище: одна таблица `translation_cache` в Postgres `mahallem-db`.

| Колонка          | Описание                                                 |
|------------------|----------------------------------------------------------|
| `source_text`    | оригинал                                                 |
| `source_lang`    | напр. `en`                                               |
| `target_lang`    | `ru`/`fa`/…                                              |
| `translated_text`| итоговый перевод (победитель cascade)                    |
| `hit_count`      | инкрементируется на каждом cache-HIT                     |
| `last_hit_at`    | `now()` на каждом HIT                                    |

Constraints:

* Уникальный индекс `(source_text, source_lang, target_lang)`.
* `cacheTranslation` использует `INSERT … ON CONFLICT DO NOTHING` —
  переводы **никогда** не перезаписываются. Это явная инвариантa из
  `docs/translation-pipeline.md`.
* Эвикции **нет**. Таблица растёт.
* Echo-guard: запись с `translated_text === source_text` отбрасывается на
  чтении и удаляется (см. `getCachedTranslation` lines 100-130).

In-memory буфера перед БД нет. Каждый HIT — это `SELECT` + `UPDATE` к
Postgres.

### 1.2. Клиентская сторона (Flutter, recipe_list)

Файлы:

* [`recipe_list/lib/data/local/recipe_db.dart`](../recipe_list/lib/data/local/recipe_db.dart)
  — sqflite, единственная таблица `recipes`.
* [`recipe_list/lib/data/repository/recipe_repository.dart`](../recipe_list/lib/data/repository/recipe_repository.dart)
  — wrapper, который применяет LRU-эвикцию.

Схема:

```
PRIMARY KEY (id, lang)
INDEX idx_recipes_lang_name_lower (lang, name_lower)
INDEX idx_recipes_last_used_at    (last_used_at)
```

Полный переведённый рецепт (`name`, `instructions`, `tags`,
`ingredientsJson`, …) хранится единой строкой по `(id, lang)`. Отдельной
"таблицы переводов" на клиенте нет — переводы зашиты в строки рецептов.

Бюджет:

| Параметр              | Значение                  |
|-----------------------|---------------------------|
| `cap`                 | 8000 строк                |
| `byteCap`             | 64 MB (`64 * 1024 * 1024`)|
| `cacheHitThreshold`   | 5 (для `searchByName`)    |
| Эвикция               | LRU по `last_used_at`, batches по 32, сначала под byte budget, затем под row cap |

## 2. Что просили

> The buffer memory for translation in mahallem (with following fetching
> the phone app memory (of 500+ recipes translated) from this mahallem
> buffer memory) may be 1 - 1.5 Gb, with LRU eviction when limit is
> exceeded.

Расшифровка:

* На сервере появляется **именованный буфер 1–1.5 GB**, в котором
  лежат уже-переведённые рецепты (а не отдельные строки переводов!).
* При переполнении буфер вытесняет **LRU** — давно не читавшиеся
  ключи. Это семантика `maxmemory-policy allkeys-lru` в Redis и
  совпадает с тем, что уже делает клиент.
* Телефон тянет 500+ рецептов из этого буфера — то есть протокол
  «один HTTP-запрос → пачка готовых переводов».

## 3. Compliance check vs текущая реализация

| Требование                                          | Статус сейчас           | Что не так                                                |
|------------------------------------------------------|-------------------------|-----------------------------------------------------------|
| Серверный буфер 1–1.5 GB                            | ❌ нет                  | `translation_cache` без cap, плюс это БД, а не «буфер».   |
| LRU eviction серверного буфера                      | ❌ нет                  | Только echo-guard удаляет.                                 |
| Bulk endpoint «дай мне 500 рецептов одним выстрелом»| ⚠ частично             | `GET /recipes/filter?c=<cat>&lang=…&full=1` — по категориям; нет «отдай всё под язык». |
| Клиентская память 500+ рецептов                     | ✅ проходит по бюджету | 64 MB / 8000 строк (~600 рецептов х 10 языков). |
| Eviction политика клиента                           | ✅ LRU                  | соответствует спеку.                                      |
| Соответствие `docs/translation-pipeline.md`         | ✅ для cascade          | каскад остаётся: cache → glossary → MyMemory → public LT → local LT → Gemini. |

## 4. Где сейчас «горит»

1. Клиентский `byteCap = 5 MB` — слишком жёсткий: один полный рецепт с
   инструкциями и тегами весит 5–15 KB; 500 рецептов × 10 языков ≈ 50 MB.
   Эвиктор начинает выкидывать LRU уже на 4-м языке.
2. Серверная таблица растёт без верхнего предела — на условных 100k
   уникальных строк × 10 языков = миллион строк. Postgres переваривает
   спокойно, но у нас нет стратегии «холодные строки сбрасываем».
3. У клиента нет endpoint-а «дай мне свежие 500 для языка X» — только
   per-category. Поэтому при свежей установке нужно просеивать 14
   категорий, что мы сейчас и делаем (см. `docs/categories.md`).

## 5. Recommendations

### 5.1. Сервер: новый Redis-буфер 1.5 GB перед Postgres

```
┌─────────────────┐      ┌────────────┐       ┌────────────┐
│ /recipes/filter │ ───> │ Redis LRU  │ miss> │ Postgres   │
│ /recipes/lookup │      │ recipes:*  │       │ recipes_i18n│
└─────────────────┘      │ + i18n:*   │       │ translation_cache │
                         └────────────┘       └────────────┘
                          eviction: allkeys-lru
                          maxmemory: 1500mb
```

* Ключи `recipe:{id}:{lang}` хранят полный JSON одного рецепта на нужном
  языке (~10 KB). 1.5 GB / 10 KB ≈ 150 000 готовых рецептов.
* `maxmemory-policy allkeys-lru` обеспечивает «давно не читали — на
  выход». Та же семантика, что у клиента.
* Postgres-таблица `translation_cache` остаётся источником правды для
  отдельных переводов (echo-guard + бессмертие). Redis — это
  «материализованный вид» уровня готовых рецептов.
* `routes/recipes.js`: на каждом ответе `filterByCategory` пишем в
  Redis батчем; на запросе сначала ищем в Redis, затем уже идём в
  Postgres + cascade.

### 5.2. Сервер: bulk endpoint `/recipes/page`

```
GET /recipes/page?lang=ru&offset=0&limit=500
→ { recipes: [ …500 готовых, отсортированных по last_hit_at DESC… ],
    nextOffset: 500 }
```

* Клиент тянет одну страницу вместо 14 запросов по категориям.
* Источник — Redis (если есть hit), иначе fall-back на текущий пайплайн
  по категориям (тот же, что в `recipe_list_loader._seedFromCategories`).
* Снимает нагрузку с client-side fan-out 8 × `/lookup` при language
  switch (см. `recipe_list_loader._retranslate`).

### 5.3. Клиент: поднять bytecap до 64 MB и cap до 8000

* В `RecipeRepository` дефолты `byteCap = 64 * 1024 * 1024`,
  `cap = 8000` дают комфортные ~600 рецептов на каждый из 10 языков.
* Эвикция LRU остаётся прежняя — батчем по 32.
* Это допустимо без отдельного opt-in: 64 MB sqflite — норма для
  Android/iOS.

### 5.4. Клиент: использовать `/recipes/page` при cold-start

* `_seedFromCategories` остаётся как fallback и для кнопки «обновить» с
  `forceReseed: true` (рандомный набор категорий — UX feature).
* Параллельно появляется `_seedFromBulkPage` для cold-start: тянет 500
  рецептов первым же запросом, exact LRU-проход на сервере. Это
  заметно ускоряет первый запуск.

### 5.5. Конфигурируемые env-параметры

```
REDIS_URL=redis://mahallem-redis:6379/4
RECIPES_REDIS_MAXMEMORY=1500mb       # docker compose настройка
RECIPES_REDIS_POLICY=allkeys-lru
RECIPES_BULK_PAGE_SIZE=500
```

### 5.6. Соответствие docs/translation-pipeline.md

* Pipeline cascade не меняется (Redis — это L1 перед `getCachedTranslation`).
* «Translations live forever» соблюдается: Redis LRU выкидывает только
  агрегаты (готовые рецепты), сами строки переводов в Postgres вечны.
* Echo-guard остаётся в `cacheTranslation`/`getCachedTranslation`.

## 6. Eviction policy

Единая политика на обоих уровнях кэша — **LRU** (least-recently-used):

| Уровень  | Реализация                                                  |
|----------|-------------------------------------------------------------|
| Сервер   | Redis `maxmemory 1500mb` + `maxmemory-policy allkeys-lru`.  |
| Клиент   | `RecipeRepository._evict()` сортирует по `last_used_at ASC` и удаляет батчем по 32 до попадания в `byteCap`/`cap`. |

Постгрес-таблица `translation_cache` остаётся **без эвикции** —
единственный источник правды для отдельных переводов.

## 7. План внедрения (можно частично)

1. (P0, без сервера) Поднять клиентский `byteCap` до 64 MB и `cap` до
   8000. Один patch в `RecipeRepository`.
2. (P1, сервер) Завести `mahallem-redis` сервис в docker-compose и
   обернуть `routes/recipes.js` в L1-cache (`getOrSet(recipe:{id}:{lang})`)
   с `allkeys-lru`.
3. (P1, сервер) Добавить `/recipes/page` endpoint поверх Redis.
4. (P1, клиент) `_seedFromBulkPage` в `recipe_list_loader.dart` под
   feature flag.
5. (P2, наблюдаемость) Логи hit-rate Redis в Prometheus / docker logs.

## 8. Текущая UX-кнопка «Reload»

См. [`docs/categories.md`](./categories.md). Кнопка не зависит от
описанных выше доработок — она работает уже сейчас на текущей
архитектуре, поскольку server cascade и client LRU-кэш уже на месте.
После внедрения §5 кнопка автоматически выиграет от bulk endpoint.
