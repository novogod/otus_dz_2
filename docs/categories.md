# Categories pipeline

> Status: 2026-04-29 — описывает текущее поведение `recipe_list_loader.dart`
> + кнопку «обновить ленту» из `AppPageBar`.

## TL;DR

* В коде зашит фиксированный список из 14 английских ключей-категорий
  (TheMealDB-совместимые имена).
* На каждом cold-start клиент случайно выбирает 10 из них и накапливает
  до 200 рецептов из mahallem-API через `/recipes/filter?c=<key>&lang=…`.
* Локальная sqflite-БД работает как L1-кэш: рецепты живут "вечно" под
  бюджетом 64 MB / 8000 строк, выкидывая LRU при переполнении.
* Кнопка ⟳ (Reload) в `AppPageBar.actions` рядом с языковой кнопкой
  принудительно перевыбирает 10 случайных категорий и тянет свежие
  рецепты **через тот же серверный путь, что и cold-start** — в
  `mahallem-user-portal` (`GET /recipes/filter?c=<key>&lang=<lang>&full=1`),
  где они проходят полный translation cascade и потом уже попадают в
  локальный sqflite-кэш. Короткий путь "≥ 50 рецептов в кэше — отдаём
  как есть" минуется (`forceReseed: true`).

## Data flow кнопки Reload

```
┌──────────┐  reloadFeedTicker  ┌──────────────────┐
│ Reload   │ ─────────────────► │ RecipeListLoader │
│ button   │                    │ ._onReloadReq.   │
└──────────┘                    └────────┬─────────┘
                                         │ _runLoad(forceReseed:true)
                                         ▼
                                ┌──────────────────┐
                                │ _seedFromCategor.│
                                └────────┬─────────┘
                                         │ /recipes/filter?c=<cat>&lang=<lang>&full=1
                                         ▼
                          ┌────────────────────────────┐
                          │   mahallem-user-portal     │
                          │   (Express, Docker)        │
                          ├────────────────────────────┤
                          │ 1. Redis L1 (см. план)     │
                          │ 2. translation_cache (PG)  │
                          │ 3. cascade:                │
                          │    glossary → MyMemory →   │
                          │    public LT → local LT →  │
                          │    Gemini (off)            │
                          └────────────┬───────────────┘
                                       │ JSON: переведённые рецепты
                                       ▼
                          ┌────────────────────────────┐
                          │ repo.upsertAll(batch, lang)│
                          │ sqflite (LRU, 64 MB / 8000)│
                          └────────────┬───────────────┘
                                       ▼
                          ┌────────────────────────────┐
                          │ setState(_recipes = …)     │
                          └────────────────────────────┘
```

Подробности слоёв и LRU-эвикции — в
[docs/translation-buffer.md](./translation-buffer.md). Список tier-ов
сервера и инвариант «переводы вечны» — в
[docs/translation-pipeline.md](./translation-pipeline.md).

---

## 1. Источник списка категорий

Файл: [recipe_list/lib/ui/recipe_list_loader.dart](../recipe_list/lib/ui/recipe_list_loader.dart#L249-L266)

```dart
static const _allCategories = <String>[
  'Beef', 'Breakfast', 'Chicken', 'Dessert', 'Goat', 'Lamb',
  'Miscellaneous', 'Pasta', 'Pork', 'Seafood', 'Side', 'Starter',
  'Vegan', 'Vegetarian',
];
static const int _seedPickCount = 10;
```

Английские ключи — стабильные имена категорий TheMealDB. Локализация
названий выполняется на лету через `S.of(context).localizedCategory(key)`
([i18n.dart §`_categoryNames`](../recipe_list/lib/i18n.dart)) — это
исключает сетевой round-trip ради подписи прогресс-бара.

## 2. Случайный отбор

```dart
static List<String> _pickCategories() {
  final pool = [..._allCategories]..shuffle();
  return pool.take(_seedPickCount).toList(growable: false);
}
```

Каждый вызов `_runLoad()` (cold start, language switch fall-through и
forced reload) пересеивает выбор. Раньше можно было увидеть на главной
"Сикен / Сикен / Сикен" — теперь 10 разных тегов почти всегда.

## 3. Cold-start пайплайн (`_seedFromCategories`)

Файл: [recipe_list/lib/ui/recipe_list_loader.dart](../recipe_list/lib/ui/recipe_list_loader.dart#L340-L411)

1. **Cache-first проход.** Для каждого выбранного `cat` забираем из
   sqflite до 50 уже сохранённых рецептов нужного языка
   (`repo.listCachedByCategory(cat, lang, limit: 50)`).
2. **Network fill.** Для категории, у которой локально лежит меньше
   `_categoryCacheThreshold = 10` рецептов, дёргаем
   `widget.api.filterByCategory(cat)` (под капотом —
   `GET /recipes/filter?c=<cat>&lang=<lang>` к
   `mahallem-user-portal`). Прогресс-бар обновляется до и после каждой
   категории, чтобы не "замирал".
3. **Persist.** Каждый отбатченный `filterByCategory` сразу пишется в
   локальную БД через `repo.upsertAll(batch, lang)`.
4. **Cap + shuffle.** Как только накопилось `_seedTarget = 200` рецептов
   (`accumulator.length`), цикл рвётся, и финальный список перетасуется,
   чтобы карточки не шли строго по категориям.

Дедупликация: ключ `accumulator` — `recipe.id`. Если несколько категорий
вернули один и тот же рецепт, в ленту он попадёт ровно один раз.

## 4. Ранний кэш-выход (`/_runLoad` short-circuit)

Если для текущего языка в локальной БД уже лежит ≥ 50 рецептов и
`forceReseed == false`, `_runLoad` возвращает кэшированные строки без
сетевых запросов. Это та оптимизация, которая должна *не* мешать
обновлению — отсюда `forceReseed`-флаг.

## 5. Кнопка «обновить ленту» (Reload)

Размещение: [recipe_list/lib/ui/app_page_bar.dart](../recipe_list/lib/ui/app_page_bar.dart)
— `AppBar.actions`, слева от `LangIconButton`, форма-в-форму с языковой
кнопкой (40 dp, `CircleBorder`), но цвета вторичного действия:

| Свойство   | Значение                              |
|------------|---------------------------------------|
| Размер     | 40 × 40 dp                            |
| Форма      | `CircleBorder()` (`Material` + `InkWell`) |
| Фон        | `AppColors.surfaceMuted` (`#ECECEC`)   |
| Иконка     | `Icons.refresh`, 22 dp                 |
| Цвет икoн. | `AppColors.primaryDark` (`#165932`)    |
| Отступы    | `AppSpacing.xs` снаружи, `_trailingGap` справа сохранён |
| A11y       | `Semantics(button: true, label: s.reloadFeed)` + `Tooltip` |

Поведение: тап вызывает
[`requestFeedReload()`](../recipe_list/lib/i18n.dart) → инкремент
`reloadFeedTicker`. `RecipeListLoader._onReloadRequested` слушает
этот `ValueNotifier<int>`, монотонным `_translateSeq` отбрасывает гонки
с предыдущим запросом и зовёт `_runLoad(forceReseed: true)`. На время
обновления показывается стандартный progress-stage из `_LoadingScreen`.

Куда уходит запрос. `_runLoad(forceReseed: true)` идёт в тот же
`_seedFromCategories`, что и cold-start: для каждой из 10 свежевыбранных
категорий вызывает `widget.api.filterByCategory(cat)` →
`GET https://mahallem.ist/recipes/filter?c=<cat>&lang=<lang>&full=1`. На
сервере (`mahallem-user-portal`) запрос проходит штатный путь:

1. Redis L1-буфер (когда §5 [translation-buffer.md](./translation-buffer.md)
   будет внедрён) — сейчас отсутствует, миссы идут дальше.
2. Postgres `translation_cache` — `getCachedTranslation` для каждого
   поля карточки.
3. Translation cascade `glossary → MyMemory → public LT → local LT →
   Gemini` (Gemini временно off через `DISABLE_GEMINI=1`,
   см. [translation-pipeline.md](./translation-pipeline.md)).
4. Готовые переводы записываются в `translation_cache`
   (`INSERT … ON CONFLICT DO NOTHING` — переводы вечны).

Клиент получает уже переведённые JSON-карточки и сразу же кладёт их в
sqflite через `repo.upsertAll(batch, lang)`. Локальный кэш не чистится:
категории, у которых уже > порога рецептов, обслуживаются из БД, а
недостающие догружаются по сети. Поэтому кнопка дешевле «сбросить и
перезагрузить с нуля», но всё равно гарантирует свежий рандомный набор
и подмешивает новые рецепты.

## 6. Почему зашитый список, а не `/recipes/categories`

* Endpoint `/recipes/categories` существует на сервере, но его ответ
  меняется редко (TheMealDB-категории стабильны годами).
* Зашитый список даёт детерминированную локализацию названий через
  slang-словарь. Сервер-API возвращает английские ключи.
* На split-brain (сервер добавил/удалил категорию) клиент попросту
  получит пустой `/filter?c=<key>&lang=…` или 404 — пайплайн уже
  устойчив к "одна категория не приехала, идём к следующей".

## 7. Соответствие docs/translation-pipeline.md

Cold-start через категории остаётся в рамках спецификации: каждый
отдельный рецепт проходит серверный cascade `cache → glossary → MyMemory
→ public LT → local LT → Gemini`. Принудительный reload не нарушает
"бессмертие" `translation_cache` — клиент пишет в свою sqflite, сервер
переиспользует уже накопленные строки.

## 8. Параметры конфигурации

| Параметр                  | Где                          | Значение |
|---------------------------|------------------------------|----------|
| `_allCategories`          | `recipe_list_loader.dart`    | 14 имён  |
| `_seedPickCount`          | то же                        | 10       |
| `_seedTarget`             | то же                        | 200      |
| `_categoryCacheThreshold` | то же                        | 10       |
| `_translateConcurrency`   | то же                        | 8        |
| Sqflite cap (rows / bytes)| `recipe_repository.dart`     | 8000 / 64 MB |

## 9. Известные ограничения / TODO + remedies

### 9.1 Холодный язык: 30–90 с на первом запросе

**Приоритет:** P1.

**Проблема.** Сервер `mahallem-user-portal` обслуживает первый запрос
на новый язык 30–90 с — клиент видит только полосу прогресса.

**Remedies:**

- (a) Redis L1 (`allkeys-lru`, 1.5 GB) перед `translation_cache` —
  см. [translation-buffer.md §5.1](./translation-buffer.md).
- (b) Bulk endpoint `/recipes/page?lang=&offset=&limit=500` вместо
  14 параллельных `/filter?c=…` — один HTTP, миссы cascade
  распараллелены (там же §5.2).
- (c) Прогрев: фоновый job запускает cascade на топ-200 рецептов
  сразу после `npm start` для каждого активного языка.
- (d) Потоковая отрисовка в UI: показывать карточки по мере приезда
  первой категории, не ждать `_seedTarget=200`.

---

### 9.2 Клиентский `byteCap = 5 MB`

**Приоритет:** P0 для (a), P2 для (b)/(c).

**Проблема.** 200 × 10 языков ≈ 50 MB не помещается; эвиктор начинает
выкидывать LRU уже на 4-м языке.

**Remedies:**

- (a) Поднять дефолты `RecipeRepository` до `byteCap = 64 * 1024 *
  1024`, `cap = 8000` — комфортно ~600 рецептов × 10 языков.
- (b) Партиционировать LRU per-language (отдельный budget на текущий
  + soft-budget на остальные), чтобы свитч языка не выкидывал
  «домашний» язык целиком.
- (c) Не хранить большие поля (HTML инструкций) inline — отдельная
  таблица + lazy-load в `getById`.

---

### 9.3 Reload не задевает SourcePage / FavoritesPage

**Приоритет:** P3 (по запросу продакта).

**Проблема.** Тап обновляет только ленту; избранное и источник не
перечитываются. Это намеренно, но если понадобится глобальный refresh:

**Remedy:** завести `appReloadTicker` (или вынести `reloadFeedTicker`
на корневой `InheritedNotifier`) и подписать остальные страницы.

---

### 9.4 Магические константы `_seedTarget=200`, `_seedPickCount=10`

**Приоритет:** P2.

**Проблема.** Привязаны к коду, не к фактическому объёму API.

**Remedy:** вынести в `lib/config/feed_config.dart` (или
`--dart-define`); в перспективе — читать из remote-config.

---

### 9.5 RNG может повторить тот же набор категорий

**Приоритет:** P2.

**Проблема.** Подряд-нажатие Reload иногда возвращает почти тот же
набор категорий.

**Remedy:** хранить `_lastPickedCategories` в loader-state и
исключать их из пула при следующем reload
(`pool.removeWhere(_lastPickedCategories.contains)` до `shuffle()`).

---

### 9.6 Offline + Reload стирает текущую ленту

**Приоритет:** P1.

**Проблема.** При отсутствии сети `forceReseed: true` уходит в ошибку
и показывает пустой стейт, перетерев старую ленту.

**Remedy:** в `_onReloadRequested` проверять `connectivity.isOnline`
(или ловить `DioException.connectionError`) и при offline показывать
`SnackBar(s.offlineReloadUnavailable)`, оставляя текущую ленту.

---

### 9.7 Нет лёгкой обратной связи на тап Reload

**Приоритет:** P2.

**Проблема.** `_LoadingScreen` перекрывает всю ленту целиком — для
короткого «обновить» это слишком тяжёлый стейт.

**Remedy:**

- `AnimatedRotation` 360° на иконке `Icons.refresh` пока
  `_translating == true`.
- `LinearProgressIndicator` в `AppPageBar.bottom` вместо full-screen
  overlay (соответствует design-system token `motion.medium`).
