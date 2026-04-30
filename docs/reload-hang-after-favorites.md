# Reload «висит навсегда» после добавления в избранное

**Дата:** 2026-04-30
**Статус:** исправлено
**Связанные файлы:** `recipe_list/lib/ui/recipe_list_loader.dart`,
`recipe_list/lib/data/repository/recipe_repository.dart`

## Симптом

После релиза фичи «избранное» (`docs/favorites.md`, чанки A–E)
пользователь сообщил: «добавляю рецепт в избранное, нажимаю
кнопку reload в шапке — спиннер крутится 5+ минут и не
останавливается». До favorites reload отрабатывал за <1 минуты.

## Анализ

### Виновата ли фича favorites?

Сравнение диффа `7b478ec..27b862e` (всё, что вошло вместе с
favorites) против reload-пайплайна показало: **сама фича
favorites не трогает код reload**. Единственное изменение в
`recipe_list_loader.dart` — одна строка в `_defaultRepoBuilder`:

```dart
favoritesStoreNotifier.value ??= FavoritesStore(db: db);
```

`FavoritesStore.add()` — это простой `INSERT` + локальное обновление
`ValueNotifier`. Транзакций не открывает, sqflite-сериализация
ничего не блокирует.

### Что реально изменилось

Вместе с favorites в `recipe_db.dart` миграция стала **аддитивной**:

```dart
// Было: каждый bump схемы дропал всё.
await db.execute('DROP TABLE IF EXISTS recipes');
await db.execute('DROP TABLE IF EXISTS recipe_bodies');
await applyRecipeSchema(db);

// Стало:
if (oldVersion < 5) { /* destructive — favorites ещё не было */ }
if (oldVersion < 6) { await applyFavoritesSchema(db); }
```

Локальный кэш рецептов теперь не сбрасывается при апгрейде и
**живёт постоянно**, разрастаясь до LRU-капов. Раньше каждое
обновление приложения чистило БД, и при следующем reload путь
шёл через быстрый `/page` bulk-эндпоинт. Теперь:

1. Кнопка reload вызывает `_runLoad(forceReseed: true)`.
2. `forceReseed == true` пропускает `/page` и `listCached(...)`
   и проваливается в `_seedFromCategories`.
3. `_seedFromCategories` идёт по ~14 категориям **последовательно**.
4. Гейт пропуска сети — `localCount >= categoryCacheThreshold (=10)`.
   Если LRU-эвикция «съела» часть рецептов выбранной категории,
   гейт не срабатывает и идёт сетевой запрос
   `/filter/c?lang=ru&full=1`.
5. У `filterByCategory` **не было клиентского таймаута** (только
   дефолтный dio `receiveTimeout: 60s`), у всего reload — **не было
   общего deadline**, а в `_onReloadRequested`
   `reloadingFeed.value = false` сбрасывался только в
   `.then`/`.catchError`, **но не в `.whenComplete`** — поэтому если
   `_runLoad` вообще не разрешался, спиннер крутился сколь угодно.

### Почему именно сейчас «висит»

Логи production-сервера `mahallem-user-portal`:

```
⚠️ Gemini API timeout, retrying (attempt 1/2)
🌐 publicLT [en→ru] exhausted: HTTP 429
⚠️ translateBest [en→ru] tiers exhausted (no cache write)
```

Сервер-side per-token перевод деградировал: `/filter/c?lang=ru`
отвечает 30–60 c. При 14 категориях последовательно это **5–14
минут**, и UI не имеет способа выйти из ожидания.

### Почему это совпало с favorites

Совпадение по времени:

* Фича favorites поехала в продакшн.
* Одновременно сервер начал тормозить с переводами (Gemini
  timeout, LibreTranslate 429).
* Переключение миграции на аддитивную раскрыло «холодные дыры»
  в локальном кэше после LRU-эвикции — путь по категориям стал
  частым, а не «один раз после установки».

Тап «добавить в избранное» — это `INSERT` в `favorites` и
обновление in-memory `Set`. Никакого взаимодействия с
`mahallem`-API он не запускает, и сетевой обмен застрять
из-за него не может. Эффект «положил в избранное → reload
повис» — это просто временная корреляция.

## Фикс

### 1. Жёсткий бюджет и `whenComplete` на reload

`recipe_list/lib/ui/recipe_list_loader.dart`:

* `_runLoad(forceReseed: true).timeout(Duration(seconds: 60))` —
  общий бюджет на всё перезагрузочное окно. По истечении
  показывается snackbar «offline reload unavailable» и остаётся
  предыдущая лента.
* `.whenComplete(() => reloadingFeed.value = false)` — спиннер
  гарантированно тухнет в любом исходе: success, error,
  stale-seq, `!mounted`. Раньше сброс был дублирован в `.then` /
  `.catchError`, и если future вообще не разрешался — сброс не
  выполнялся.

### 2. Per-category client timeout

`_seedFromCategories`:

```dart
final batch = await widget.api
    .filterByCategory(cat)
    .timeout(const Duration(seconds: 12));
```

Одна медленная категория не утаскивает весь 60-секундный
бюджет — она пропускается, а лента собирается из тех, что
ответили вовремя.

### 3. Расширенные кэш-капы

`recipe_list/lib/data/repository/recipe_repository.dart`:

* `kDefaultByteCap`: 64 MB → **256 MB**
* `cap` (rows): 8000 → **20 000**

После favorites кэш не сбрасывается между релизами, поэтому
старый бюджет 64 MB слишком быстро вытаскивает LRU-эвикция —
результат: дыры в `recipes`-таблице ниже `categoryCacheThreshold`
и проваливание в дорогой fan-out по сети при reload. С 256 MB
полная лента в 10 языках с инструкциями + хвост ранее
просмотренных рецептов и избранное укладываются с запасом, и
большинство reload в активном языке отвечает 100% из кэша.

## Верификация

* `test/favorites_survives_reload_test.dart` — 5 тестов зелёные.
* `test/recipe_repository_test.dart` `default caps` обновлён под
  новые значения.
* В production-логах после фикса: при недоступности
  `/filter/c` reload завершается за ≤60 c с offline-snackbar
  вместо бесконечного спиннера.
