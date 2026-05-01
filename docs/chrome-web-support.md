# Chrome / Flutter web — конфигурация и фиксы

**Date:** 2026-05-01
**Цель:** запустить `recipe_list` через `flutter run -d chrome` и
получить тот же набор фич, что на native-таргете (iOS/Android/
desktop), не ломая mahallem-бэкенд.

Этот документ собирает все web-специфичные изменения, которые
пришлось внести: backend (CORS), client (sqflite, Image.network,
photo upload), и набор пакетов.

## TL;DR

| Проблема | Слой | Решение |
|---|---|---|
| `Access-Control-Allow-Origin` отсутствует у `/recipes/*` → fetch fails | backend | `cors({origin:'*', credentials:false})` на `/recipes` |
| `openDatabase()` падает/шумит на web (`unsupported result null`, global-factory warning) → favorites/owned пустые | client | `sqflite_common_ffi_web` + локальный factory `databaseFactoryFfiWebNoWebWorker` |
| `Image.network` рисует пусто на CanvasKit (CORS на decode) | client | `WebHtmlElementStrategy.fallback` |
| Сердце поверх фото не кликается на web | client | `PointerInterceptor` + вынос `FavoriteBadge` из subtree карточки `InkWell` |

## 1. Backend: CORS на `/recipes/*`

См. [`cors-recipes.md`](cors-recipes.md). Коротко:

```js
// local_user_portal/routes/recipes.js
const recipesCors = cors({
  origin: '*',
  credentials: false,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  maxAge: 86400,
});
app.use('/recipes', recipesCors);
app.options('/recipes/*', recipesCors); // preflight bypass auth
```

Native-клиенты не затронуты (CORS — браузерное правило). Cookies
сессии не пропускаются — пишущие ручки остаются защищены
`Authorization: Bearer`.

## 2. sqflite на web

`sqflite` не имеет web-канала. Любой вызов `openDatabase()` на
Chrome бросал ошибку, и весь UI, который зависит от локальной
БД (favorites, owned recipes, кэш ленты), молча отказывал.

Подключаем `sqflite_common_ffi_web` (sqlite3.wasm + IndexedDB):

```yaml
# recipe_list/pubspec.yaml
dependencies:
  sqflite: ^2.3.3
  sqflite_common_ffi_web: ^0.4.5
```

```dart
// recipe_list/lib/data/local/recipe_db.dart
final DatabaseFactory _webDbFactory = databaseFactoryFfiWebNoWebWorker;

Future<Database> openRecipeDatabase() async {
  if (kIsWeb) {
    return _webDbFactory.openDatabase(
      kRecipeDbFileName,
      options: OpenDatabaseOptions(
        version: kRecipeDbSchemaVersion,
        onCreate: (db, _) => applyRecipeSchema(db),
        onUpgrade: _onRecipeDbUpgrade,
      ),
    );
  }
  // ... native: getApplicationSupportDirectory() + openDatabase
}
```

### Почему именно так (Chrome)

На ранней версии web-фикса использовался глобальный свитч
`databaseFactory = databaseFactoryFfiWeb`. Это давало два побочных
эффекта:

1. Повторяющееся предупреждение sqflite: «You are changing sqflite default factory…».
2. Нестабильная инициализация worker-пути в Chrome с ошибкой
   `unsupported result null (null)`.

Финальная версия держит **приватный** factory только внутри
`openRecipeDatabase()` и не трогает глобальный `databaseFactory`.
Дополнительно выбран режим `databaseFactoryFfiWebNoWebWorker`, который
обходит flaky worker-message path и сохраняет persistency в IndexedDB.

### Fail-safe для избранного

Даже если bootstrap репозитория на старте не успел/упал, сердце больше
не остаётся «мёртвым». Добавлен lazy-bootstrap:

* `ensureFavoritesStoreInitialized()` в
  `recipe_list/lib/data/repository/favorites_store.dart`;
* первый тап по `FavoriteBadge` при `store == null` инициализирует БД
  и сразу делает `toggle`;
* `FavoritesPage.initState()` тоже триггерит bootstrap.

Это убирает сценарий «сердце контурное, тап открывает details, но не
добавляет в избранное».

## 2.1. Heart badge over HTML image: pointer-interception fix

После включения `WebHtmlElementStrategy.fallback` фото рендерится как
DOM `<img>` (platform view). На web такой элемент перехватывает pointer
events на уровне браузера. В результате Flutter-оверлеи сверху (heart,
owner-actions) могут не получать tap.

Финальный рабочий паттерн:

1. Обернуть интерактивные оверлеи в `PointerInterceptor`.
2. Для карточки списка вынести `FavoriteBadge` в **внешний `Stack`** как
   sibling поверх карточки (а не оставлять внутри subtree карточного
   `InkWell`), чтобы tap на сердце не конкурировал в gesture-arena с
   tap карточки.

YouTube-кнопка остаётся кликабельной внутри фото-стека с
`PointerInterceptor`, потому что у неё нет конфликта со state-toggle UI
и нет зависимости от `favoritesStoreNotifier`.

### Setup ассетов

`sqflite_common_ffi_web` поставляет sqlite3.wasm + воркер,
которые должны лежать рядом с `index.html`:

```bash
cd recipe_list
dart run sqflite_common_ffi_web:setup
# создаёт web/sqflite_sw.js (~250 KB) + web/sqlite3.wasm (~706 KB)
```

Оба файла закоммичены в репозиторий (см. коммит d1c30e7), чтобы
билд был воспроизводимым без локального запуска setup-скрипта.

### Хранилище и квоты

Web-фабрика хранит БД в IndexedDB под именем `recipes.db`. Чтобы
очистить базу в Chrome во время отладки:

* DevTools → Application → IndexedDB → `recipes.db` → Delete database.

Браузеры дают ~10–20% от свободного места на диск под IndexedDB
для одного origin — для нашего датасета (200 рецептов в LRU,
≈5 МБ) это с большим запасом.

## 3. Image.network: cross-origin photos

CanvasKit-renderer (default на Chrome) декодирует `Image.network`
через `<canvas>`. canvas ⊆ same-origin policy: без CORS-ответа от
сервера картинки декод падает, виджет рисует пустой контейнер.

* **TheMealDB** не отдаёт `Access-Control-Allow-Origin` для
  своих картинок.
* **imgproxy v3.8.0** в нашем стэке тоже не отдаёт CORS-заголовки
  (это было бы единственно правильным фиксом, но требует
  пересборки контейнера и nginx-овых правок — больше риска для
  меньшего выигрыша).

Решение — попросить Flutter рисовать `<img>`-элемент вместо
canvas-decode, когда есть сомнения насчёт CORS:

```dart
Image.network(
  url,
  fit: BoxFit.cover,
  // На web без этого CanvasKit падает на CORS для cross-origin
  // картинок. <img>-элемент CORS не требует — это семантика DOM.
  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
  errorBuilder: (_, _, _) => Container(...),
)
```

Применено в:

* [recipe_list/lib/ui/recipe_card.dart](../recipe_list/lib/ui/recipe_card.dart) (primary thumb + fallback URL)
* [recipe_list/lib/ui/recipe_details_page.dart](../recipe_list/lib/ui/recipe_details_page.dart) (hero 1200×675)
* [recipe_list/lib/ui/add_recipe_page.dart](../recipe_list/lib/ui/add_recipe_page.dart) (preview в edit-mode)

Оговорка: `<img>` fallback не позволяет применять Flutter-шейдеры
(blur, ColorFilter и т.п.) — нам это не нужно, фото отображается
как есть.

## 4. Photo upload (создание рецепта)

`image_picker` на web возвращает `XFile` с blob-URL,
`File`-объект из `dart:io` недоступен. Текущий поток
(`AddRecipePage`) использует `dart:io.File` напрямую и
multipart-загрузку через Dio. Это работает только на native.

Для web включён URL-fallback (см. `_allowUrlFallback = kIsWeb` в
`add_recipe_page.dart`): пользователь может вставить публичный URL
в поле «Photo», и сервер сохранит его как `strMealThumb`. Это
обходное решение MVP — настоящий web-upload (XFile bytes →
multipart) запланирован, но не входит в минимальную версию.

Что работает на web сейчас:

* Создание рецепта с публичным URL картинки → 201, фото
  отображается на карточке (см. §3 — `<img>` fallback).
* Редактирование рецепта без замены фото → 200, фото остаётся.
* Удаление рецепта → 200.

Что НЕ работает на web:

* Camera/gallery → multipart upload. Кнопки выбора фото в
  bottom-sheet намеренно скрыты (see `_allowUrlFallback` branch
  в `_save`).

## 5. Запуск

```bash
cd recipe_list
flutter run -d chrome
```

* По умолчанию слушает `localhost:<random>`. Backend
  отвечает с `Access-Control-Allow-Origin: *`, преflight
  принимается без `Authorization`.
* Cookies session-id браузер всё равно не пошлёт
  (`credentials:false` на стороне сервера, fetch без
  `credentials:'include'` на стороне клиента).

### Production deploy

Web-build кладётся в `recipe_list/build/web/` после
`flutter build web --release`. Содержимое можно отдать с любого
статика (S3 / nginx / GitHub Pages); только убедитесь, что
`sqflite_sw.js` и `sqlite3.wasm` отдаются с MIME `application/javascript`
и `application/wasm` соответственно (Flutter web их грузит
относительными путями).

## 6. Что осталось в TODO

* True web-photo-upload через `XFile.readAsBytes()` + Dio
  `MultipartFile.fromBytes`.
* Webcam capture на web (через `image_picker` сейчас этого
  нет — нужен либо `camera` плагин, либо MediaRecorder API).
* CORS-заголовки от imgproxy: тогда можно убрать
  `WebHtmlElementStrategy.fallback` и вернуться к canvas-decode,
  что даёт более качественный рендер на retina.
* PWA-манифест (`manifest.json`) и service-worker для офлайна.

## Связанные документы

* [`cors-recipes.md`](cors-recipes.md) — полный design-doc CORS-паттерна A
* [`reload-no-network.md`](reload-no-network.md) — таймауты на reload (применимо и на web)
* [`translation-priority.md`](translation-priority.md) — RU-приоритет в каскаде перевода
* [`project_log.md`](project_log.md) — хронология изменений

## История коммитов (otus_dz_2)

| SHA | Описание |
|---|---|
| `f20b3809` (mahallem_ist) | CORS pattern A on `/recipes/*` |
| `578ecb4` | docs: CORS implemented |
| `d1c30e7` | sqflite_common_ffi_web on web |
| `2c735bf` | Image.network web fallback |
| `fd175fc` | PointerInterceptor for overlays above fallback `<img>` |
| `bf83a0c` | Move `FavoriteBadge` outside card InkWell subtree |
| `68f738f` | Lazy bootstrap favorites store on first heart tap |
| `1677e84` | Use private web db factory (`NoWebWorker`), no global sqflite switch |
