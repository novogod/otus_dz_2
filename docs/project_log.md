# Project Log

## Recipe photo upload (file picker → storage-api → imgproxy)

**Date:** 2026-05-13

Закрыта «следующая фаза» add-recipe: теперь форма принимает фото
файлом (камера/галерея), а не URL-строкой. План — все 14 чанков
из [`todo/recipe_photo_upload.md`](./todo/recipe_photo_upload.md);
prod-redeploy (chunk 15) откладывается до явного запроса.

**mahallem_ist (chunks 1–8):**

- Миграция `20260429_create_recipe_photos_bucket.sql` — `storage.buckets`
  row + 3 RLS-политики (public read, authenticated write/delete);
  смонтирована в `local_docker_admin_backend/docker-compose.yml`
  (`09.76-recipe-photos-bucket.sql`).
- `utils/storage-upload.js`, `utils/backup-service.js` — ветка
  `recipe-photos` в `backupStorageObjectEntry` + `backupRecipePhotoFile`,
  чтобы новые файлы попадали в backup-кэш go-clean.
- `routes/recipes.js`: `recipePhotoUpload` (multer disk-storage,
  10 MB, jpeg/png/webp), `RecipeRepository.updateUserMealThumb`,
  multipart-ветка `POST /recipes` (rollback-стратегия:
  insert → upload → patch; при провале upload — оставляем
  `pending://upload`-плейсхолдер и 502). `multipartLimiter` 5 req/min
  отдельно от общего limiter (он раздут до 1200 req/min под list-loader).
- DI-хук `opts.uploadToStorage` на `recipesRoute` — позволяет тестам
  подменять storage без сети. Tests suite 18 / 2 baseline.
- `lib/jobs/cleanup-orphan-recipe-photos.js` — еженедельный sweep
  файлов без ссылок из `recipes.i18n.en.strMealThumb` (старше 24 ч),
  hooked в `server.js` рядом с warmup. Disable
  `RECIPES_PHOTOS_CLEANUP_DISABLED=1`.

**otus_dz (chunks 9–13):**

- `pubspec.yaml`: `image_picker ^1.0.7`, `flutter_image_compress ^2.2.0`.
  iOS Info.plist + AndroidManifest permissions. `flutter pub get`.
- `lib/utils/photo_downscaler.dart` — `downscaleForUpload(XFile)`:
  1600×1600 q80 JPEG, EXIF strip; second pass 1280×1280 q60 если
  >5 MB; кидает `StateError('photo_too_large')`.
- `lib/data/api/recipe_api.dart` — `createRecipeWithPhoto(Recipe, File)`
  собирает `FormData{meal: jsonEncode(_mealToJson), photo: MultipartFile}`
  и слепит на тот же `''`-эндпоинт. JSON-only `createRecipe` остался
  как fallback.
- `lib/ui/add_recipe_page.dart` — `_PhotoPicker` (160×160 dp превью,
  bottom-sheet «Камера / Галерея», SnackBar при denied/too-large).
  `_save()` диспатчит на multipart, если `_pickedPhoto != null`. URL
  TextField остался только под `kIsWeb`.
- `lib/utils/imgproxy.dart` — `imgproxyUrl(src, w, h)`:
  `<origin>/imgproxy/insecure/resize:fit:w:h:0/<base64url(src)>`.
  Применён в `RecipeCard` (600×338) и `RecipeDetailsPage` (1200×675).
- 7 новых i18n-ключей + `a11y.addRecipePhotoPicker` × 10 локалей,
  slang regenerated. Tests `flutter test --no-pub`: 59 / 2 baseline,
  `flutter analyze` чистый.

## Add-recipe feature + Russian docs

**Date:** 2026-04-29

Добавлена пользовательская история «нажать `+` → заполнить форму →
сохранить рецепт». На главном экране вторая FAB-кнопка зеркально
прижата к левому нижнему углу (`Positioned(left:…)`), открывает
`AddRecipePage` (Form + 6 контроллеров, парсер ингредиентов
`name | measure` до 20 шт). После успеха клиент вызывает
`RecipeApi.createRecipe` (POST `/recipes` на mahallem-бэкенде; для
TheMealDB-бэкенда метод проваливает запрос с `StateError`),
зеркалит результат в sqflite через `RecipeRepository.upsertAll` и
вставляет рецепт в начало `_displayed` без полной перезагрузки
ленты.

### Клиент (`otus_dz_2`, main)

- **`5202acb`** — FAB `+` в `recipe_list_page.dart`, `AddRecipePage`,
  `RecipeApi.createRecipe`, `a11y.addRecipe` + 13 ключей формы во
  всех 10 локалях, slang regenerate, `docs/add-recipe-feature.md`,
  `docs/themealdb-add-recipe-investigation.md`.
- **`20064ae` / `fef22ff`** — переписаны оба doc-файла на русский
  для аудитории «преподаватель Flutter-школы Otus»; ASCII-диаграмма
  заменена на Mermaid `sequenceDiagram`.

### Сервер (`mahallem_ist`, main)

- **`ca6cd882`** — `RecipeRepository.createUserMeal(meal)`
  (id-floor `RECIPES_USER_MEAL_ID_FLOOR=1_000_000`, INSERT в
  `i18n.en`, eviction); `app.post('/recipes', …)` под существующим
  `limiter` + `authMiddleware`; 2 теста (id-allocation + reject
  without `strMeal`/`strMealThumb`).

### Исследование TheMealDB upstream

`docs/themealdb-add-recipe-investigation.md` — почему пользователь-
ские рецепты живут только в нашей Postgres + sqflite:

* у бесплатного v1 все эндпоинты GET-only;
* у v2 рекламная фраза «adding your own meals and images» без
  опубликованного контракта (PayPal-подписка + переписка);
* даже при наличии write-endpoint — не пытались бы (provenance,
  локали, юридика, обратимость);
* решение: `id ≥ 1_000_000`, отдаём через те же
  `/recipes/page|search|lookup`, перевод лениво через `_ensureLang`.

### Проверки

* `flutter analyze` — чисто.
* `flutter test --no-pub` — 56 / 2 (тот же baseline).
* `node --test tests/recipes.test.js` — 12 / 2 (тот же baseline +
  два новых теста зелёные).

### Что вынесено за рамки

Загрузка фото файлом (нужен object storage), edit/delete
(`POST /recipes` всегда выделяет новый id), премодерация,
production-redeploy mahallem.

---

## todo/01–13 + 99: full recipes-pipeline refactor

**Date:** 2026-04-29

Прошли все чанки из `todo/` последовательно (`flutter analyze` чисто
+ baseline тестов сохранён + push после каждого чанка). Базовые
pre-existing fails (`cache hit at threshold`, `network error empty
cache`, два English-residue теста на ноде) не трогались — они и были
в зелёной базе до серии.

### Клиент (`otus_dz_2`, ветка main)

- **todo/01 — `31d9a29`**: `RecipeRepository` defaults: byteCap
  64 MB, rowCap 8000.
- **todo/02 — `a849eba`**: `_runLoad` сохраняет предыдущую ленту
  при offline reload + SnackBar.
- **todo/03 — `b655b47`**: reload affordance — вращающаяся иконка
  + `LinearProgressIndicator` под `AppPageBar`.
- **todo/04 — `ad559f0`**: `FeedConfig` вынесен из
  `RecipeListLoader`, читает `--dart-define`.
- **todo/05 — `6b063c4`**: `pickCategoriesFor` помнит прошлый
  набор и избегает повторов между нажатиями reload.
- **todo/06 — `0411a10`**: streaming feed — `_publishPartialFeed`
  отдаёт переведённые порции по мере готовности.
- **todo/08 — `acabf46`**: `RecipeApi.fetchPage` + флаг
  `USE_BULK_PAGE` (по умолчанию выключено).
- **todo/11 — `8d6a0a4`**: per-language LRU partitioning — 60/40
  split active/others, batch=32.
- **todo/12 — `8404825`**: `recipes.instructions` вынесено в
  `recipe_bodies(id, lang)` + cascade trigger;
  `RecipeRepository.getInstructions(id, lang)`; `RecipeDetailsPage`
  лениво подгружает тело через `FutureBuilder` + shimmer.
  Schema v5.
- **todo/13 — `33812cb`**: опциональный `appReloadTicker` +
  `requestAppReload()`; `ReloadIconButton({bool global = false})`.

### Сервер (`mahallem_ist`, ветка main)

- **todo/07 — `901d8f7a`**: `GET /recipes/page?lang&offset&limit` —
  bulk endpoint поверх `RecipeRepository`.
- **todo/09 — `2640d8b1`**: L1 Redis cache
  (`lib/cache/redis-recipes.js`) — `getOrSet` cache-aside,
  fail-open; `recipeKey` / `filterKey` / `pageKey`; обёрнуты
  `/recipes/lookup/:id`, `/recipes/filter`, `/recipes/page`.
  Compose: `redis` сервис с
  `--maxmemory ${RECIPES_REDIS_MAXMEMORY:-1500mb}
  --maxmemory-policy allkeys-lru`, БД `/4`.
- **todo/10 — `a88083d9`**: `lib/jobs/warmup-recipes.js` —
  `runWarmup` (popularity DESC, concurrency=16) +
  `scheduleWarmupOnStart` запускается из `server.js` (skip при
  `WARMUP_ON_START=0`).
- **todo/99 — `ec1ddedf`**: rollback escape hatch —
  `REDIS_DISABLED=1` в `getOrSet` форсирует bypass без redeploy;
  `docs/recipes-rollout.md` для оператора.

### Проверки

```bash
# client
cd recipe_list && flutter analyze        # No issues
flutter test --no-pub                    # 53 pass, 2 baseline fail

# server
cd local_user_portal && node --test tests/**/*.test.js
                                         # 24 pass, 2 baseline fail
docker compose -f local_docker_admin_backend/docker-compose.yml config -q
                                         # ok
```

### Rollback levers (без redeploy)

- **`REDIS_DISABLED=1`** — `getOrSet` обходит Redis на каждом
  запросе.
- **`WARMUP_ON_START=0`** — пропускает прогрев при следующем
  рестарте.
- **`--dart-define=USE_BULK_PAGE=0`** — клиент возвращается на
  category fan-out.

---

## Reload button + categories/translation-buffer docs

**Date:** 2026-04-29

### Что сделано

1. В `AppPageBar.actions` появилась кнопка ⟳ «обновить ленту» слева от
   языковой кнопки. Соответствует дизайн-системе (40 dp,
   `CircleBorder`, фон `surfaceMuted`, иконка `Icons.refresh` цвета
   `primaryDark`). Видна только на экране списка
   (`SearchAppBar(showReload: true)` в `recipe_list_page.dart`); на
   деталях не показывается.
2. В `i18n.dart` добавлены глобальный `ValueNotifier<int>
   reloadFeedTicker` и хелпер `requestFeedReload()`. Кнопка
   инкрементирует тикер; `RecipeListLoader` слушает и зовёт
   `_runLoad(forceReseed: true)`, который пропускает ранний выход «в
   локальной БД ≥ 50 рецептов — отдай как есть» и снова прогоняет
   `_seedFromCategories(...)` со свежим случайным отбором 10 категорий.
   Запросы `/recipes/filter?c=<cat>&lang=…&full=1` идут к
   `mahallem-user-portal`, который дальше работает по штатному
   cascade `cache → glossary → MyMemory → public LT → local LT →
   Gemini` (Gemini сейчас отключён через `DISABLE_GEMINI=1`).
3. Локализация ключа `a11y.reloadFeed` для всех 10 локалей; slang
   перегенерирован (`dart run slang`).
4. Документация:
   - `docs/categories.md` — как сейчас собирается список категорий
     и что именно делает кнопка «обновить».
   - `docs/translation-buffer.md` — слой кэшей сейчас (Postgres
     `translation_cache` без ограничений + клиентский sqflite 5 MB / 2000
     строк) и рекомендации по запрошенному 1–1.5 GB FILO-буферу
     (Redis `allkeys-lru`, новый bulk endpoint `/recipes/page`,
     поднятие клиентского `byteCap` до 64 MB).

### Comprehensive check

- `flutter analyze` → no issues.
- `flutter test` → проходит 35/37; падают те же два теста, что были
  и до правок (`cache hit at threshold`, `network error empty cache
  offline=true`). К новой кнопке отношения не имеют.

### Файлы

- `recipe_list/lib/i18n.dart`
- `recipe_list/lib/i18n/*.i18n.json` (10 файлов)
- `recipe_list/lib/i18n/strings*.g.dart` (regenerated)
- `recipe_list/lib/ui/app_page_bar.dart`
- `recipe_list/lib/ui/search_app_bar.dart`
- `recipe_list/lib/ui/recipe_list_page.dart`
- `recipe_list/lib/ui/recipe_list_loader.dart`
- `recipe_list/lib/ui/reload_icon_button.dart` (новый)
- `docs/categories.md` (новый)
- `docs/translation-buffer.md` (новый)

### Сопутствующие правки (server-side, mahallem)

В этот же rev попадают (в отдельном репозитории `mahallem_ist`):

- `local_user_portal/utils/translate-recipe.js`: kill-switch
  `DISABLE_GEMINI=1` — пропускает Gemini-tier и Gemini fallback,
  оставляя `cache → glossary → MyMemory → public LT → local LT`.
- `local_docker_admin_backend/docker-compose.yml`: env-переменная
  `DISABLE_GEMINI: "1"` для контейнера `mahallem-user-portal`.

---

## i18n plural resolvers, Android back-callback, details lookup timeout, server rate-limit raise

**Date:** 2026-04-29

### Симптомы

1. `Resolver for <lang = tr> not specified!` (и аналогично для `ku`/`fa`/`ar`) —
   slang не имеет встроенных plural-резолверов для этих локалей, и приложение
   шумело предупреждениями при каждом форматировании множественного числа.
2. Android logcat: `OnBackInvokedCallback is not enabled for the application`.
3. На холодном языке детали рецепта не успевали приехать —
   `DioException [receive timeout] ... 0:01:00.000000`. Полная инструкция через
   Gemini не укладывалась в дефолтный `receiveTimeout=60s`.
4. После переключения языка списка `/lookup` отвечал `429 Too Many Requests` —
   серверный `express-rate-limit` пускал только 60 req/min/IP, а
   `recipe_list_loader` (8 параллельных воркеров × ~213 рецептов) выжигал
   окно до того, как пользователь открывал детали.

### Что сделано

- `lib/i18n.dart`: новая `_registerPluralResolvers()` зовётся один раз перед
  `LocaleSettings.setLocaleSync` и регистрирует `setPluralResolverSync` для
  `tr`/`ku` (oneOrOther), `fa` (`n<=1?one:other`) и полный CLDR-набор для
  `ar` (zero/one/two/few/many/other по `n%100`).
- `android/app/src/main/AndroidManifest.xml`: добавлен
  `android:enableOnBackInvokedCallback="true"` на `<application>` —
  системная подсветка свайпа «назад» теперь работает корректно и без шума.
- `lib/ui/recipe_details_page.dart`: `_onLangChanged` зовёт
  `api.lookup(..., timeout: const Duration(seconds: 120))` вместо дефолтных
  60s, чтобы холодный full-instructions перевод через Gemini успевал доехать.
- Сервер `mahallem-user-portal` (`local_user_portal/routes/recipes.js`):
  default `RECIPES_RATE_LIMIT` поднят с **60 → 1200 req/min/IP** и
  снабжён комментарием почему. Переменная окружения по-прежнему может
  переопределить значение. Файл задеплоен в контейнер
  (`docker cp` + `docker restart`); nginx upstream-таймауты на `/recipes/`
  уже были 240s, так что менять их не пришлось.

### Проверка

- Hot-restart на iOS-симуляторе: цикл по всем 10 локалям проходит без
  «Resolver for <lang ...> not specified!» и без 429 на `/lookup`.
- `docker logs mahallem-user-portal`: контейнер `healthy`, активные
  `translateBest [en→fa] via gemini`, кэш заполняется.
- `flutter test --no-pub`: остаются только два предсуществующих
  fail-теста (`cache hit at threshold`, `network error empty cache offline=true`),
  не связанные с этой задачей.

### Файлы

- `recipe_list/lib/i18n.dart`
- `recipe_list/android/app/src/main/AndroidManifest.xml`
- `recipe_list/lib/ui/recipe_details_page.dart`
- `mahallem_ist/local_user_portal/routes/recipes.js` (отдельный репозиторий)

---

## RTL/long-translation overflow on the list & details pages — added `AppMetrics` from `MediaQuery`

**Date:** 2026-04-29

### Симптом

На курдском (и в меньшей мере немецком) Flutter ругался
`A RenderFlex overflowed by 125/136 pixels on the right`:

- В карточке списка `_Badges` рендерился через `Row` с явным
  `SizedBox(width: AppSpacing.sm)` между чипами категории и кухни.
  Длинная курдская комбинация (например, «خواردن لە دەریا» +
  «ئیتالیایی») не помещалась в ширину карточки.
- На странице рецепта блок ингредиентов держал колонку «мера»
  фиксированной шириной `89` (`SizedBox(width: 89)`). Курдские
  меры («کاشوویەک»/«قاشوویەک نان…») вылазили за правую границу.

### Что нарушалось

Дизайн-система задавала размеры константами в пикселях («Figma 428»),
без учёта реальной ширины экрана и текстового масштабирования. Любой
длинный перевод (RTL, немецкий, французский) ломал лэйаут.

### Решение

1. Добавил класс **`AppMetrics`** в `recipe_list/lib/ui/app_theme.dart`.
   Источник правды — `MediaQuery.of(context)`. Поля:
   - `screenWidth`, `screenHeight`, `textScale`, `viewPadding` (raw);
   - `scale = screenWidth / 428` — коэффициент vs Figma-базовой;
   - `pagePadding = (screenWidth * 0.0374).clamp(12, 24)`;
   - `contentWidth = screenWidth - pagePadding * 2`;
   - `measureColumnWidth = (contentWidth * 0.26).clamp(72, 140)`
     — заменил магическое `89`. На 428-экране даёт ~96 px (с запасом),
     на узких сжимается, на широких — расширяется;
   - `iconSm/iconMd/iconLg` — пропорциональные доли с clamp.
2. **`recipe_card.dart`** `_Badges`: `Row` → `Wrap`
   (`spacing: sm`, `runSpacing: xs`). Длинные пары категория+кухня
   переносятся на вторую строку вместо overflow.
3. **`recipe_details_page.dart`** `_IngredientsBlock`:
   `SizedBox(width: 89)` → `SizedBox(width: AppMetrics.of(context).measureColumnWidth)`,
   `softWrap: true` на `Text(ing.measure)`. Курдские меры теперь
   переносятся внутри своей колонки.
4. **`test/recipe_repository_test.dart`** `_FakeApi.lookup`:
   обновил сигнатуру до `{AppLang? lang, Duration? timeout}` под
   текущий `RecipeApi.lookup` (стало required по invalid_override).

### Гарантии

- Все размеры, способные переполниться при длинных переводах,
  читаются через `AppMetrics.of(context)`, а не магические числа.
- `Wrap` гарантирует, что бейджи никогда не вызовут `RenderFlex
  overflow`.
- `clamp` ограничивает измерения разумными min/max — на iPad/больших
  экранах ничего не «разъедется», на iPhone SE ничего не схлопнется
  до нечитаемого.

### Файлы

- `recipe_list/lib/ui/app_theme.dart` — добавлен `AppMetrics`.
- `recipe_list/lib/ui/recipe_card.dart` — `_Badges` через `Wrap`.
- `recipe_list/lib/ui/recipe_details_page.dart` — `measureColumnWidth`.
- `recipe_list/test/recipe_repository_test.dart` — fake-сигнатура.

---

## Language switch hung minutes/forever — removed client residue retry, server read-side purge, added worker pool + deadline

**Date:** 2026-04-29

### Симптом

При переключении языка лоадер мог висеть 19+ минут (особенно `it`,
иногда `es`). Иногда показывал 100% и не уходил в список. Иногда
оставался в предыдущем языке (стейл-контент).

### Причины (несколько слоёв нарушений `docs/translation-pipeline.md`)

1. **Клиентский unbounded residue-retry** в `recipe_list_loader.dart`
   и `recipe_details_page.dart` — `while (true)` с эвристикой
   `recipeLooksUntranslated` (latin/total ≥0.15 и т.п.). Док
   утверждает что серверный `_isEchoTranslation` авторитетен;
   клиентская повторная валидация не сходилась для легитимных
   переводов с латиницей (имена собственные, единицы измерения).
2. **Wave-batches вместо worker pool**: `Future.wait` на батч из 8
   ждал самый медленный запрос — 7 воркеров простаивали. Один
   медленный `/lookup` стопорил всю фазу.
3. **Нет per-call timeout**: dio receiveTimeout = 60 с.
4. **Нет общего deadline** на фазу перевода.
5. **Серверный read-side purge** в `routes/recipes.js _ensureLang`:
   на каждом чтении пере-валидировал `i18n[lang]` через
   `_isEchoTranslation` и удалял "плохие" блобы. Это нарушает
   контракт «No cache rewrites. Server-side translation_cache is
   immutable; client-side recipes is functionally immutable». Для
   итальянского (а часть рецептов — `Pasta Carbonara`, `Tiramisu`
   с byte-equal `strMeal/strCategory` к английскому → ECHO_RATIO_SHORT_MAX)
   и для любого языка где LT-вывод оставлял English-marker слова
   (`the|and|with|until|...`) кэш постоянно вытирался: каждый
   тап языка → re-translate с нуля.

### Фикс

**Клиент** (`recipe_list/lib/`):
- `ui/recipe_list_loader.dart`: убран `while (true)` residue-retry;
  убран импорт `translation_quality.dart`. Wave-batches заменены
  на worker-pool из `_translateConcurrency=8` воркеров с общей
  курсорной очередью. Добавлен общий deadline на фазу перевода —
  120 с. Per-call timeout — 12 с. Добавлены `_translateSeq` cancel
  token и `.catchError` чтобы `_translating=false` всегда сбрасывался.
- `ui/recipe_details_page.dart`: убран retry-loop, оставлен один
  `/lookup` за переключение, по доку «If `/lookup` fails, the
  previous-language copy stays on screen».
- `data/api/recipe_api.dart`: `lookup` принимает опциональный
  `Duration? timeout` → прокидывается в `dio.get` как `Options(receiveTimeout: ...)`.
- `data/repository/recipe_repository.dart`: `lookup` принимает и
  пробрасывает `timeout`.

**Сервер** (`mahallem_ist/local_user_portal/routes/recipes.js`):
- `_ensureLang`: read-path возвращает `row.i18n[lang]` без
  ре-валидации. Гейт остаётся только при write (после translate).
  Это восстанавливает «stored forever, never overwritten» из доков.

### Результат

- Холодный язык: bounded ~120 с (worst-case, обычно гораздо быстрее).
- Тёплый язык: bulk-SELECT из локального sqflite, sub-50 ms.
- Любой переведённый и сохранённый рецепт остаётся в кэше навсегда —
  и на сервере, и на клиенте.

---

## German page showed Spanish — sqflite cache schema bump v3→v4

**Date:** 2026-04-29

### Симптом

Пользователь сообщил, что на странице деталей при переключении на
немецкий показывается испанский текст. На сервере данные чистые —
полный скан `recipes.i18n.de` (12 самых длинных строк + regex по
fingerprint-словам `añad/horno/también/ñ/¡/¿/aceite/cucharad/sartén`)
не нашёл ни одной испанской строки под `lang='de'`; в `translation_cache`
для `target_lang='de'` тоже только одна легитимная запись с испанским
заимствованием (`arroz al horno`).

### Причина

Отравленный **локальный sqflite-кэш на устройстве**: строки, попавшие
туда во время предыдущих итераций пайплайна (до перехода на
`gemini-2.5-flash-lite`), хранились под `(id, lang='de')` и
`lookupManyCached` возвращал их напрямую без переsanity-чека.
`recipeLooksUntranslated` не ловит испанский-как-немецкий, потому что
испанский — латиница и проходит эвристику.

### Фикс

`recipe_list/lib/data/local/recipe_db.dart`: `kRecipeDbSchemaVersion`
3 → 4. Существующий `onUpgrade` дропает и пересоздаёт таблицу
`recipes`, поэтому при следующем запуске приложения кэш выбрасывается
и каждая карточка перекачивается с уже исправленного сервера. Тот же
паттерн, что использовался на границах v1→v2 и v2→v3.

Коммит: `recipe_list@5d4b49e`.

Дополнительно: `recipe_list/lib/data/translation_quality.dart` —
заглушены `// ignore: deprecated_member_use` для двух конструкторов
`RegExp(...)` (deprecation касается будущего `final`-запечатывания
класса, не самого конструктора).

## translation pipeline — gemini-2.5-flash-lite, cache purge, details lang switch

**Date:** 2026-04-29

### Контекст

После канонизации 6-tier каскада (cache → glossary → MyMemory →
public LibreTranslate → self-hosted LibreTranslate → Gemini) Gemini
постоянно отдавал HTTP 429 на `gemini-2.5-flash` (RPM-капнут даже на
платном плане). Параллельно поломалась смена языка на экране деталей —
кнопка «не работала», а кэш `translation_cache` оказался отравлен
сотнями echo-строк (English-for-French/Spanish/German/Italian/Turkish),
которые держали страницу на исходном языке.

### Что сделано

#### Сервер (`mahallem_ist@0b32a998`)

- `local_user_portal/utils/gemini-client.js` line 204: `TRANSLATE_URL`
  переключён с `gemini-2.5-flash` на `gemini-2.5-flash-lite`.
  Flash-lite имеет существенно более высокий RPD-потолок (на платном
  ключе фактически unlimited) и в smoke-тесте на длинных рецептных
  блоках выдаёт чистый персидский/арабский/курдский.
- `docs/translation-pipeline.md`: модель в таблице engine assignment
  обновлена.
- Образ user-portal **пересобран** через `docker compose up -d --build
  user-portal`. Без `--build` контейнер запускался от старого образа,
  потому что исходники запекаются в image (а не bind-mount). Прежние
  деплои с `--force-recreate` не подхватывали изменения.

#### Чистка отравленного `translation_cache`

```sql
DELETE FROM translation_cache
WHERE length(source_text) > 60
  AND length(translated_text) > 60
  AND left(translated_text, 40) = left(source_text, 40)
  AND target_lang IN ('fr','es','de','it','tr','ru','ar','fa','ku');
-- DELETE 235  (193 fr, 13 es, 12 de, 9 tr, 8 it)
```

После чистки рецепты заново прошли через flash-lite-каскад и
страница `/recipes/lookup/52772?lang=fr` стала отдавать французский
текст вместо английского эха.

#### Клиент (`otus_dz@12baa67`)

- `recipe_list/lib/data/translation_quality.dart` (новый): вынесена
  shared-эвристика `recipeLooksUntranslated`, ровно ту же используют
  и лоадер, и экран деталей — клиент и сервер видят одинаковый
  «echo»-критерий.
- `recipe_list/lib/ui/recipe_details_page.dart`:
  - При смене `appLang` поверх контента поднимается полупрозрачный
    `CircularProgressIndicator` overlay — пользователь видит, что
    переключение реально идёт, и не наблюдает «застывший» текст
    старого языка пока сервер фолбэчит между движками.
  - Bounded retry (3 раунда) на `RecipeApi.lookup`, если ответ всё
    ещё проходит `recipeLooksUntranslated`. Совпадает с
    `_residueRetryRounds = 3` в `RecipeListLoader`.
  - Монотонный `_translateSeq` отбрасывает поздние ответы старого
    языка — двойной/быстрый клик по флагу больше не «возвращает»
    предыдущий перевод.
- `recipe_list/lib/ui/recipe_list_loader.dart`: убран приватный
  `_looksUntranslated`, теперь делегирует в shared-helper.

### Эмпирическая проверка

| Шаг | Результат |
| --- | --- |
| `curl /recipes/lookup/52772?lang=fa` | `فر را روی دمای ۱۷۵ درجه سانتیگراد گرم کنید…` |
| `curl /recipes/lookup/52772?lang=ar` | `سخن کردن فر تا دمای ۳۵۰ درجه فارنهایت…` |
| `curl /recipes/lookup/52772?lang=ku` | `سەردانەکە گەرم بکە بۆ ٣٥٠° فهرنهایت…` |
| `curl /recipes/lookup/52772?lang=fr` (после purge) | `préchauffer le four à 350° f…` |
| 22 параллельных flash-lite-вызова | 0 × HTTP 429, все 200 OK |
| Тап по флагу на details | overlay → текст в новом языке за ≤2 раунда |

### Предупреждение для будущих деплоев

`docker compose up -d --force-recreate user-portal` **не достаточен**:
исходники запечены в `local_docker_admin_backend-user-portal:latest`,
mount-ятся только `backups/` и `avatars/`. Любое изменение JS-кода
требует `docker compose up -d --build user-portal`.

## translation pipeline — strict sequential 4-tier contract + docs

**Date:** 2026-04-28

### Что сделано

Канонизирован сквозной контракт перевода `app ↔ mahallem` ровно по
схеме «in-app DB → mahallem.recipes.i18n → translation_cache →
engines», без каскадов и без перезаписей.

- На стороне сервера (`mahallem_ist@7fe530b8`):
  - `cacheTranslation`: `INSERT … ON CONFLICT DO NOTHING` —
    переводы пишутся ровно один раз и живут вечно.
  - `translateBest`: 6-уровневый каскад схлопнут в 2 движка
    (primary + Gemini fallback). MyMemory и публичный LibreTranslate
    выкинуты — оба заквочены 429.
  - Engine assignment: `ar/fa/ku → Gemini`, остальные →
    локальный LibreTranslate, fallback Gemini только если primary
    его уже не использовал.
- На стороне приложения (`recipe_list/main`) дополнительных правок
  не потребовалось — `RecipeRepository.lookupManyCached` + `lookup` +
  `_LoadingScreen` уже соответствуют контракту.

### Документация

- [docs/translation-pipeline.md](translation-pipeline.md) —
  end-to-end контракт «1→2→3→4» с ASCII-диаграммой и file-map.
- [docs/translation-pipeline-analysis.md](translation-pipeline-analysis.md) —
  пошаговый аудит реализации; deferred P3 hygiene items
  (никакие из них не блокируют контракт).

### Эмпирическая проверка

| Шаг | Результат |
| --- | --- |
| iOS (iPhone 16e), cold install, lang=ru | `recipes.db` 884 KB, 219 ru-строк |
| Android (Pixel 8 API 34), cold install, lang=ru | `recipes.db` 780 KB, 200 ru-строк |
| 1-й `/recipes/lookup/52764?lang=ku` (нет `i18n.ku`) | HTTP 200 за 26.5 s, 34 Gemini-вызова, `i18n.ku` записан |
| 2-й тот же запрос (должен взять `recipes.i18n.ku` напрямую) | HTTP 200 за **6.6 ms**, нулевые движки в логах |
| Лог-доказательство движка | `🍳 translateBest [en→ku] via gemini: "olive oil" → "ڕۆنی زەیتوون"` |

## recipe_list — лоадер на смене языка + параллельный fetch промахов

**Date:** 2026-04-28

### Что было не так

При тапе по языковой кнопке UI оставался на старой ленте и постепенно
подменял карточки по мере прихода переводов из mahallem (`api.lookup`).
Для языков с холодным кэшем (de, it, tr, fa, ku) это выглядело как
«кнопка не работает» — новые карточки приезжали по одной за секунду
и часть лежала старым языком минуту-другую.

### Что сделано (Flutter, `lib/ui/recipe_list_loader.dart`)

- Добавлен флаг `_translating`. Он включается в `_onLangChanged` и
  выключается, когда `_retranslate` целиком резолвится. Пока
  `_translating == true`, `build` принудительно возвращает
  `_LoadingScreen` с прогресс-баром — никакой «частично переведённой»
  ленты пользователь не видит.
- `_retranslate` больше не публикует промежуточные `_lastResult` через
  `setState` (это и было источником мигания). Прогресс отдаётся только
  в `_stage` и считывается лоадером.
- Промахи кэша добиваются батчами по `_translateConcurrency = 8` через
  `Future.wait`. Сервер LibreTranslate капнут на 6 параллельных
  переводов (`local_user_portal/utils/lt-limit.js`), 8 клиентских
  запросов держат ровно «один в очереди» и не валят LT.

### Серверный fallback (status check)

`local_user_portal/utils/translate-recipe.js::translateBest` уже
реализует цепочку:

1. `getCachedTranslation` — `translation_cache` в Postgres.
2. `getGlossaryTranslation` — ручная глоссарий-таблица.
3. `Promise.allSettled([translateWithMyMemory, translateLT])` —
   MyMemory параллельно с локальным LibreTranslate (LT-капнутый
   контейнер `mahallem-translate`).
4. `evaluateCandidate` + round-trip score; победитель кешируется,
   проигравший выбраковывается.
5. Echo-guard на `translateField` — если оба движка «эхом»
   возвращают source (или для non-Latin target оставляют > 15 %
   латиницы), вызывается `geminiTranslateText` как last-resort
   fallback (gemini-2.5-flash).

TODO (не делается этим коммитом, но просили): добавить
`libretranslate.com` (публичный SaaS) между MyMemory и локальным LT,
чтобы при exhausted MyMemory лимите сначала пробовать публичный
SaaS, а локальный контейнер использовать как третью ступень.
Сейчас локальный контейнер и MyMemory идут параллельно.

## recipe_list — mahallem по умолчанию + UX-полировка поиска и деталей

**Date:** 2026-04-28

### Бэкенд по умолчанию

- `lib/data/api/recipe_api_config.dart`: mahallem (`https://mahallem.ist/recipes`)
  теперь дефолт для всех платформ. Запуск `flutter run` без
  `--dart-define` сразу получает переводы. Передача
  `--dart-define=MAHALLEM_RECIPES_BASE=` (пустая строка) форсит
  fallback на TheMealDB; кастомный URL — переопределение того же define.

### Поиск: кэш + API параллельно, без short-circuit

- `lib/data/repository/recipe_repository.dart`: `searchByName` запускает
  локальный `name_lower LIKE 'prefix%'` и `RecipeApi.searchByName`
  одновременно, мерджит по id (кэш — первым, API-добор — после),
  upsert-ит новинки. Прежнее правило «≥5 локальных совпадений → сеть
  не дёргать» убрано: пользователь всегда видит максимум совпадений,
  включая свежие с сервера.

### Поисковая выпадашка: на весь экран и скроллится

- `lib/ui/search_app_bar.dart`: убран `BoxConstraints(maxHeight: 320)`
  у `SearchPredictions`, `ListView.separated` без `shrinkWrap` —
  список нормально прокручивается.
- `lib/ui/recipe_list_page.dart`: оверлей подсказок теперь
  `Positioned.fill` (раньше `top:0`), занимает всю высоту тела
  страницы, пока поле поиска в фокусе.

### Деталка рецепта: таблица ингредиентов

- `lib/ui/recipe_details_page.dart`: первый столбец оставлен на
  фиксированных 89px; во втором столбце `Text` теперь начинается
  с трёх неразрывных пробелов `'   ${ing.name}'`, чтобы длинные
  переведённые названия (особенно RU/AR/FA) не наезжали на
  колонку с количеством.

## docs — Production endpoints для перевода (mahallem.ist)

**Date:** 2026-04-29

### Что было не так

В `docs/i18n_proposal.md` фигурировал URL
`http://mahallem-translate:5000/translate` — это адрес контейнера
**внутри docker-сети разработческой машины**. С телефона на
мобильной сети туда не достучаться.

### Что в проде на самом деле (проверено по
`mahallem_ist/project_docs` и `hostinger-deployment/`)

- **Public Node API gateway:** `https://mahallem.ist` — Nginx :443
  (Frankfurt, IP `72.61.181.62`, Let's Encrypt wildcard
  `*.mahallem.ist`) → `127.0.0.1:4001` (`local_user_portal`).
- **Admin:** `https://admin.mahallem.ist` → `127.0.0.1:3000`.
- **LibreTranslate:** `http://mahallem-translate:5000` — **только
  internal docker network**, нет host-port mapping, нет DNS.
  Источник: `DOCKER_NETWORK_AND_ROUTING_ARCHITECTURE.md` раздел
  "Internal-Only Services". `LIBRETRANSLATE_URL` env-override.
- **MyMemory:** outbound HTTPS из Node-процесса к
  `api.mymemory.translated.net`, подпись
  `de=support@mahallem.ist`.

Телефон **никогда** не вызывает LibreTranslate напрямую.

### Что обновлено

- [docs/i18n_proposal.md](i18n_proposal.md): §4 переписан под
  production-топологию — добавлена таблица "что где живёт", блок-
  схема с Nginx Frankfurt → Node :4001 → docker-internal
  LibreTranslate. §5.2 endpoints теперь абсолютные URL под
  `https://mahallem.ist/recipes/...`.
- [docs/todo/search_api_deploy.md](todo/search_api_deploy.md): §B
  ставит `RecipeApi.baseUrl` на `https://mahallem.ist/recipes/...`,
  предлагает переключение через `--dart-define`. §C добавляет
  пункт "mount routes inside `local_user_portal` под /recipes",
  Nginx-блок `location /recipes/`, проверку
  `LIBRETRANSLATE_URL` и порта (5000 vs 5050) на live-хосте.

### Решение по доменам

* Стартуем с `https://mahallem.ist/recipes/...` — переиспользуем
  существующий vhost, TLS-серт, фаервол. Нулевые расходы.
* Переезд на `https://api.mahallem.ist/recipes/...` — опционально,
  когда recipe-API получит свои зависимости. Это +1 server block
  Nginx + 1 DNS A-запись, серт уже покрыт wildcard'ом.

---

## docs — Перевод без Google: LibreTranslate + MyMemory

**Date:** 2026-04-29

### Описание

Приложение нацелено на Россию, где сервисы Google (включая Gemini /
Cloud Translation) работают нестабильно и часто блокируются. Мы
полностью убрали Google из path перевода и переехали на стек,
который уже крутится в `mahallem_ist` Docker (см. их
`TRANSLATION_SYSTEM_IMPLEMENTATION.md`,
`DYNAMIC_TRANSLATION_SYSTEM.md`,
`SMART_BACKGROUND_TRANSLATION.md`):

- **Primary:** LibreTranslate (self-hosted, контейнер
  `mahallem-translate:5000`, open-source, без обращения к Google).
  Поддерживает 8 из 10 платформенных языков mahallem (`en, ru, tr,
  es, fr, de, it, uk`) — нам сейчас нужно только `en/ru`.
- **Fallback:** MyMemory (`api.mymemory.translated.net`), free tier
  с почтой `support@mahallem.ist`. Также основной провайдер для
  `fa, ar, ku`, если когда-либо понадобятся.
- **Glossary** + **permanent translation_cache** в Postgres —
  скопировано один-в-один с mahallem.
- **Background retry cron** (10 мин), как в mahallem
  `SMART_BACKGROUND_TRANSLATION`: подбирает рецепты с NULL-полями,
  до 10 повторов.

### Что обновлено

- [docs/i18n_proposal.md](i18n_proposal.md): §1 цели — добавлено
  "no Google services". §4 целиком переписан с Gemini на
  LibreTranslate + MyMemory, добавлены §4.4 glossary и §4.5
  permanent cache. §8 migration plan обновлён. §9 open questions —
  цена и Play Integrity переосмыслены под self-hosted MT.
- [docs/todo/search_api_deploy.md](todo/search_api_deploy.md): §D
  Translation pipeline переписан под LT + MyMemory, добавлены
  заметки про lowercase quirk, echo-guard через fallback, glossary
  и явное "do not introduce any Google product".
- [docs/search_predictions.md](search_predictions.md): упоминание
  Gemini заменено на LibreTranslate + MyMemory.

### Почему именно так

1. **Russia-friendly:** ни один HTTP-запрос на горячем пути не
   уходит к google.com / generativelanguage.googleapis.com.
   LibreTranslate физически крутится у нас, MyMemory — итальянский
   сервис, доступный из RU.
2. **Zero new infra:** контейнер `mahallem-translate` уже есть.
   Postgres-таблицы `translation_cache` и `translation_glossary`
   уже существуют в `mahallem_ist`. Мы только добавляем
   `translateRecipe(meal)` поверх существующего
   `lib/utils/translation.js`.
3. **Цена:** marginal cost = CPU mahallem-translate, который мы и
   так платим. MyMemory — free tier 50K chars/day, для 2 000
   рецептов одноразовый прогон ~50K вызовов в LT, MyMemory
   практически не задействован.
4. **Масштабируется на 10 языков mahallem:** изменений в коде
   приложения не требуется — только новые ARB-файлы и
   подколлекции `i18n.<lang>.*` в MongoDB.

### Что НЕ менялось

- Сама архитектура MongoDB-буфера 2000/200, eviction policy,
  endpoints `/recipes/*`, sync 15 мин, образ Drift на телефоне —
  всё как раньше. Поменялась только реализация переводящего
  модуля внутри Node-сервиса.

---

## recipe_list — Online prefix-предсказания + filter-by-pick

**Date:** 2026-04-29

### Описание

Авто-подсказки в `SearchAppBar` теперь дёргают онлайн API
(TheMealDB), а не фильтруют то, что уже в памяти страницы. Дропдаун
скроллится, показывает только рецепты, чьи имена **начинаются** с
введённого префикса (case-insensitive). Тап по подсказке — а равно и
keyboard submit — заменяет основной список загруженными совпадениями
(работает как фильтр с дозагрузкой). Очистка поля возвращает базовый
список.

### Что сделано

- [recipe_list/lib/ui/recipe_list_page.dart](recipe_list/lib/ui/recipe_list_page.dart):
  состояние переписано — `_runPredictionQuery(prefix)` дёргает
  `RecipeApi.searchByName`, фильтрует по `startsWith`, защищается
  от race condition через `_lastQueryInFlight`. Тап по подсказке
  подставляет имя в поле и подменяет `_displayed`. Очистка через ✕
  возвращает `widget.recipes`. Если `api == null` (тесты) — фолбэк
  локальный startsWith-фильтр.
- [recipe_list/lib/ui/search_app_bar.dart](recipe_list/lib/ui/search_app_bar.dart):
  у `SearchPredictions` появился флаг `loading`, `maxHeight` поднят
  до 320, добавлен `Scrollbar` поверх `ListView.separated` —
  длинные списки прокручиваются.
- Документ
  [docs/search_predictions.md](docs/search_predictions.md): описание
  state machine, race-handling, связи с MongoDB-буфером и Gemini.
- Чек-лист
  [docs/todo/search_api_deploy.md](docs/todo/search_api_deploy.md):
  что осталось сделать на клиенте, что — в `mahallem_ist` (API,
  Mongo, перевод, auth, тесты, rollout).

### Проверки

- `flutter analyze` — 0 issues.
- `flutter test` — 17/17 passed (тест "search field filters list on
  submit" продолжает проходить через локальный фолбэк).

---

## recipe_list — Search AppBar и language toggle в шапке

**Date:** 2026-04-29

### Описание

Заменили глобальный `LangFab` на полноценный AppBar у списка рецептов.
Шапка содержит back-кнопку слева, поле поиска с выпадающими подсказками
по центру и круглый переключатель `RU` / `EN` справа. На splash-экране
AppBar нет, поэтому переключатель языка появляется ровно после анимации
перехода с splash на список — раньше FAB был виден поверх splash.

### Что сделано

- Удалён [recipe_list/lib/ui/lang_fab.dart](recipe_list/lib/ui/lang_fab.dart)
  и `Positioned`-обёртка в `main.dart`.
- Новый
  [recipe_list/lib/ui/lang_icon_button.dart](recipe_list/lib/ui/lang_icon_button.dart):
  40×40 круг, `AppColors.primary`, текст Roboto 800/14 белым, для
  `AppBar.actions`.
- Новый
  [recipe_list/lib/ui/search_app_bar.dart](recipe_list/lib/ui/search_app_bar.dart):
  `SearchAppBar` (`PreferredSizeWidget`) — leading back, title `TextField`
  с иконкой 🔍 и кнопкой ✕, actions `LangIconButton`. Дополнительно
  `SearchPredictions` — `Material(elevation: 4)` dropdown под шапкой с
  топ-5 совпадений, fallback `S.searchNoMatches`.
- [recipe_list/lib/ui/recipe_list_page.dart](recipe_list/lib/ui/recipe_list_page.dart)
  переведён на `StatefulWidget`. Локальный фильтр по `recipe.name`,
  debounce 250 мс на live-подсказки, submit (Enter / IME search) или тап
  по подсказке применяют фильтр / открывают экран деталей.
- В [recipe_list/lib/ui/recipe_details_page.dart](recipe_list/lib/ui/recipe_details_page.dart)
  добавлен `LangIconButton` в `actions`. Back-кнопка приходит из
  `AppBar.automaticallyImplyLeading`.
- Расширен `S`: `searchHint`, `searchClear`, `searchNoMatches`.
- Документ
  [docs/search_appbar.md](docs/search_appbar.md) описывает компоненты,
  состояние, поведение и направления развития (remote-предсказания,
  история поиска, переход на Material 3 `SearchAnchor`).

### Проверки

- `flutter analyze` — 0 issues.
- `flutter test` — 17/17 passed (новый кейс «search field filters list
  on submit»).

---

## recipe_list — Переключатель языка RU/EN + предложение по live-переводам

**Date:** 2026-04-29

### Описание

Введён первичный i18n-каркас: `AppLang { ru, en }`, глобальный
`ValueNotifier`, обёртка `AppLangScope` поверх `MaterialApp.home`,
объект `S.of(context)` со всеми статическими строками UI. В верхнем
левом углу появилась круглая FAB-кнопка `LangFab` (56×56, фон
`AppColors.primary`, текст `RU`/`EN` Roboto 900/18 белым) — поверх
любого экрана, цикл RU↔EN по тапу.

### Что сделано

- [recipe_list/lib/i18n.dart](recipe_list/lib/i18n.dart): enum,
  `appLang`, `cycleAppLang`, `AppLangScope`, `S` со всеми текущими
  строками (навбар, snackbar, empty/error, экран деталей, плюрализация
  ингредиентов RU/EN).
- [recipe_list/lib/ui/lang_fab.dart](recipe_list/lib/ui/lang_fab.dart):
  круглый FAB с `Material(shape: CircleBorder)` + `InkWell`.
- [recipe_list/lib/main.dart](recipe_list/lib/main.dart): `home`
  обёрнут в `AppLangScope`, `LangFab` помещён `Positioned(top:0,left:0)`
  внутрь корневого `Stack` с `SafeArea` и `EdgeInsets.all(AppSpacing.md)`.
- Все hard-coded русские строки в `app_bottom_nav_bar.dart`,
  `recipe_list_page.dart`, `recipe_list_loader.dart`,
  `recipe_details_page.dart`, `recipe_card.dart` заменены на вызовы `S`.
- [docs/i18n_proposal.md](docs/i18n_proposal.md): план перехода к
  живым переводам через Gemini API. Ключ берём из `mahallem_ist`
  (`local_docker_admin_backend/.env` → `GEMINI_API_KEY`), но **не**
  встраиваем в клиент — только через тонкий прокси (OWASP A02/A07).
  Описаны кэш по sha256, батчинг, какие поля переводить, fallback при
  ошибках, и миграция статических строк на штатный `gen-l10n` потом.

### Проверки

- `flutter analyze` — 0 issues.
- `flutter test` — 16/16 passed.

---

## recipe_list — Нижний навбар (logIn-вариант)

**Date:** 2026-04-29

### Описание

Добавлен bottom navbar по `docs/design_system.md` §6, которого не было
в текущей реализации.

### Что сделано

- Новый виджет [recipe_list/lib/ui/app_bottom_nav_bar.dart](recipe_list/lib/ui/app_bottom_nav_bar.dart):
  4 вкладки `logIn`-варианта (Рецепты / Холодильник / Избранное / Профиль),
  высота 60 dp, белый фон, тень `AppShadows.navBar`, активная вкладка
  `#2ECC71`, неактивные `#C2C2C2`, подписи Roboto 400/10/23, иконки 24 dp.
- Иконки временно из Material-набора (`local_pizza_outlined`,
  `kitchen_outlined`, `favorite_border`, `person_outline`) — SVG-ассеты
  `assets/icons/nav/` ещё не добавлены (см. §10 design_system).
- `RecipeListPage` теперь рендерит `AppBottomNavBar(current: recipes)`;
  тап по неактивной вкладке показывает SnackBar «в разработке».
- Тест `does not show a global "Рецепты" header` уточнён: теперь проверяет
  только отсутствие `AppBar` (текст «Рецепты» легитимно приходит из
  навбара).

### Контроль качества

- `flutter analyze` — 0 issues.
- `flutter test` — 16/16 passed.

---

## recipe_list — Страница рецепта по гайдлайну и чистка анализа

**Date:** 2026-04-29

### Описание

Привели экран деталей рецепта в соответствие с `docs/design_system.md` §9l
после жалобы «серый текст на сером фоне нечитаем».

### Что сделано

- **`RecipeDetailsPage`** переписан под спеку §9l:
  - фон `#FFFFFF` вместо `#ECECEC`;
  - hero-фото 396×220 (`AspectRatio 396/220`), радиус 5 dp;
  - AppBar `«Рецепт»` Roboto 400/20 `#165932` (§9a);
  - заголовок страницы — Roboto 500/24 `#000` (`AppTextStyles.pageTitle`);
  - подзаголовки секций — Roboto 500/16 `#165932`
    (`AppTextStyles.sectionTitle`);
  - блок ингредиентов — белый контейнер с обводкой `#797676` w=3, две
    колонки: меры (89 dp, Roboto 400/13/27 `#797676`) и названия
    (Roboto 500/14/27 `#000`);
  - кнопки YouTube / Источник — primary filled и outline w=3, радиус 25
    (§9g).
- **Дизайн-токены**: в `app_theme.dart` добавлены
  `AppColors.textSecondary` (`#797676`) и текстовые стили `pageTitle`,
  `sectionTitle`, `ingredientName`, `ingredientQty`.
- **Причина бага**: на странице деталей использовался стиль
  `AppTextStyles.inputHint` (`#C2C2C2` — токен плейсхолдера логин-формы)
  поверх `AppColors.surfaceMuted` (`#ECECEC`). На white-фоне с правильным
  `textSecondary` текст контрастен.
- **Анализатор**: в `recipe_list/analysis_options.yaml` добавлен
  `analyzer.exclude: [docs/**, ../docs/**]`, чтобы общая папка `docs/` не
  попадала в анализ пакета.
- **Форматирование**: автоформаттер ужал `SlideTransition` в `main.dart`.

### Контроль качества

- `flutter analyze` — 0 issues.
- `flutter test` — 16/16 passed.

---

## recipe_list — Интеграция с TheMealDB и редизайн карточки

**Date:** 2026-04-29

### Описание

Подключили `recipe_list` к публичному API `https://www.themealdb.com/api/json/v1/1`
вместо локального `RecipeManager`. Полностью переработали модель `Recipe` и
карточку, чтобы вытащить максимум доступных данных. Добавлен экран деталей.

### Сделано

- **Зависимости**: добавлены `dio: ^5.7.0` и `url_launcher: ^6.3.0`. Прописано
  разрешение `INTERNET` в `AndroidManifest.xml`.
- **Модель `Recipe`**: удалены `duration`/`description`. Введены
  `category`, `area`, `tags: List<String>`, `instructions`,
  `ingredients: List<RecipeIngredient>`, `youtubeUrl?`, `sourceUrl?`. Класс
  `RecipeIngredient { name, measure }` с `==`/`hashCode`.
  Фабрики `Recipe.fromMealDb` (полный объект, ходит по `strIngredient1..20`/
  `strMeasure1..20`, разбивает `strTags` по запятой) и `Recipe.fromMealDbLite`
  (только id/name/photo для ответов `filter.php`). Геттер `isLite` —
  определяет, нужно ли догружать детали.
- **Слой данных**: `lib/data/api/meal_db_client.dart` — `Dio` с baseUrl и
  таймаутами 10 сек; `lib/data/api/recipe_api.dart` — методы `searchByName`,
  `filterByCategory/Area/Ingredient`, `lookup(id)`, `random()`.
  `RecipeManager` и его тест удалены.
- **`RecipeCard`**: фото 16:9 с авто-добавлением суффикса `/medium`; оверлей
  YouTube (открывается через `url_launcher`); бейджи category/area; чипы
  `#tag` (до 3 + `+N`); счётчик ингредиентов с русской плюрализацией. Lite
  — только фото и название.
- **`RecipeDetailsPage`** (новый): фото, бейджи, теги, ингредиенты с мерами,
  инструкция, кнопки «Открыть на YouTube» и «Источник».
- **`RecipeListPage`**: при тапе на lite-карточку догружает детали через
  `RecipeApi.lookup(id)` и пушит детали.
- **`RecipeListLoader`**: stateful, грузит `searchByName(query: 'a')` по
  умолчанию, показывает progress / retry-button по ошибке.

### Тесты

- `recipe_test.dart` — фабрики на реальной фикстуре `lookup.php?i=52772`
  (полный + lite, пропуск пустых ингредиентов, парсинг тегов).
- `recipe_card_test.dart` — full и lite режимы, onTap.
- `recipe_list_page_test.dart` — обновлены фикстуры под новые поля.
- `recipe_api_test.dart` (новый) — мок `Dio.httpClientAdapter`, проверка
  `searchByName`, `filterByCategory`, `lookup`.
- Итог: `flutter analyze` — 0 issues, `flutter test` — 16/16 pass.

---

## recipe_list — Splash 1:1 с Figma-прототипом

**Date:** 2026-04-28

### Описание

Точная подгонка splash-экрана и перехода в список рецептов под прототип Figma
(frame `135:691` → `102:3`).

### Что исправлено

- **Градиент**: был `top → bottom` сплошной — заменён на точные значения
  `GRADIENT_LINEAR` из Figma. Handle-точки `(0.7266, 0.2068) → (0.5643, 1.0)`,
  стопы `[0.188, 1.0]`, цвета `#2ECC71 → #165932`. В Flutter переведено в
  `Alignment(0.4533, -0.5864) → Alignment(0.1285, 1.0)` —
  яркий верхне-правый угол, тёмный низ.
- **Логотип «OTUS / FOOD»**: был сплошной чёрный текст. По макету `TEXT`
  имеет `isMask=true, maskType=ALPHA` поверх 283×283 `IMAGE`-прямоугольника.
  Скачана исходная фотография по `imageRef` из Figma, уменьшена до 800px
  (`assets/images/splash_food.jpg`, 127 КБ) и применена через
  `ShaderMask` + `BlendMode.srcIn` + `ImageShader` — буквы стали «окнами»
  в фотографию поверх градиента.
- **Переход splash → список**: был `AnimatedSwitcher` + `FadeTransition` 600 мс.
  В Figma interaction: `AFTER_TIMEOUT 1.5с → MOVE_IN / TOP, 0.7с,
  EASE_IN_AND_OUT`. Реализовано как `Stack` со splash-фоном и
  `SlideTransition` (`Offset(0, -1) → Offset.zero`, `Curves.easeInOut`,
  700 мс), запускаемый по `Future.delayed(1500ms)`.

### Файлы

- `recipe_list/lib/ui/app_theme.dart` — точные значения `kSplashGradient`,
  `AppDurations.splash = 1500ms`, новая `AppDurations.splashTransition = 700ms`.
- `recipe_list/lib/ui/splash_page.dart` — `StatefulWidget`, загрузка
  `AssetImage` в `ui.Image`, `ShaderMask` с `ImageShader` (cover-матрица).
- `recipe_list/lib/main.dart` — `_AppRoot` на `AnimationController` +
  `SlideTransition`, splash остаётся под списком во время переезда.
- `recipe_list/assets/images/splash_food.jpg` — фото-подложка для маски.
- `recipe_list/pubspec.yaml` — регистрация ассета.

### Проверка

- `flutter analyze` — 0 issues.
- `flutter test` — 14/14 passed.

---

## vertical_layout — Размещение объектов по вертикали

**Date:** 2026-03-20

### Описание

Домашнее задание: реализация простого менеджера размещения объектов по вертикали
с использованием `dart:ui`.

### Что реализовано

- **BoxConstraints** — модель ограничений (min/max), передаётся от родителя к
  ребёнку; метод `constrain()` для вычисления допустимого размера.
- **LayoutObject** — абстрактный класс с методами `layout()`, `paint()`,
  `hitTest()`, `onTap()`.
- **VerticalLayoutManager** — управляющий класс: раскладывает детей сверху вниз,
  левый край выровнен по одной линии. При изменении размеров любого объекта все
  позиции пересчитываются автоматически.
- **ColoredRectangle** — цветной прямоугольник с закруглёнными углами; тап
  циклически переключает пресеты (цвет + размер).
- **GradientEllipse** — эллипс с градиентом; тап переключает обычный / увеличенный
  размер.
- **Application** — привязка к `dart:ui` через
  `WidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first`;
  обработка `onMetricsChanged`, `onPointerDataPacket`, рендеринг через
  `SceneBuilder`.
- Внешние ограничения: `(0, 0)` — минимум, `physicalSize / devicePixelRatio` —
  максимум.
- Юнит-тесты: BoxConstraints, VerticalLayoutManager, ColoredRectangle.

### Критерии оценки

| Критерий | Баллы | Статус |
|---|---|---|
| Механизм оценки размера объекта | 3 | ✅ |
| Управляющий класс вертикального позиционирования | 2 | ✅ |
| Автопересчёт позиций при изменении размеров | 2 | ✅ |
| Структурный объект + изменение свойств при взаимодействии | 2 | ✅ |
| Форматирование кода по правилам Dart | 1 | ✅ |

### Изменения (2026-03-20, update 2)

- **Рефакторинг `main()`**: вся логика привязки к `dart:ui` перенесена
  непосредственно в функцию `main()` — `WidgetsFlutterBinding.ensureInitialized()`,
  получение `platformDispatcher.views.first`, создание объектов, подключение
  коллбеков (`onMetricsChanged`, `onPointerDataPacket`), запуск первого кадра.
  Класс `Application` теперь принимает `view` и `manager` как параметры.
- **Android-эмулятор**: установлен ARM64 system image
  (`system-images;android-34;google_apis_playstore;arm64-v8a`), создан AVD
  `Pixel_8_API_34_arm64`, обновлён эмулятор до v36.4.10 с нативными
  `darwin-aarch64` бинарниками — приложение успешно запущено на эмуляторе.
- **Git remote**: обновлён URL на `https://github.com/novogod/otus_dz_2.git`.

### Структура

```
vertical_layout/
├── lib/
│   └── main.dart          # Всё приложение: constraints, layout objects,
│                           # vertical layout manager, Application, main()
└── test/
    └── widget_test.dart   # Юнит-тесты для BoxConstraints,
                           # VerticalLayoutManager, ColoredRectangle
```

---

## recipe_list — Создание страницы списка рецептов

**Date:** 2026-04-26

### Цель

Прокручиваемый виджет со списком рецептов в стиле Otus Food App
([Figma эскизы](https://www.figma.com/file/alUTMeT3w9XlbNf3orwyFA/Otus-Food-App?node-id=135%3A691),
[Figma прототип](https://www.figma.com/proto/alUTMeT3w9XlbNf3orwyFA/Otus-Food-App?node-id=102%3A3&scaling=scale-down&page-id=0%3A1&starting-point-node-id=135%3A691)).
Схема данных — [Swagger foodapi 0.2.0](https://app.swaggerhub.com/apis/dzolotov/foodapi/0.2.0).

### План реализации (тестируемые чанки)

Каждый чанк — независимая, тестируемая единица. Чанки можно реализовывать и
коммитить по очереди.

#### Чанк 1 — модель `Recipe` (соответствует схеме Swagger foodapi)

Поля по схеме `Recipe` из foodapi:

- `id: int`
- `name: String`
- `duration: int` (мин)
- `photo: String` (URL)
- `description: String`

**Тесты:**

- `Recipe.fromJson` корректно парсит валидный JSON.
- `Recipe.toJson` сериализует все поля.
- Round-trip: `fromJson(toJson(r)) == r`.

#### Чанк 2 — `RecipeManager` (источник данных)

- Класс с методом `Future<List<Recipe>> getRecipes()`.
- Возвращает константный список (>= 5 рецептов) с тестовыми данными.
- В будущем будет заменён на HTTP-клиент → возвращаемый тип `Future` уже сейчас.
- Реализован как простой класс (не singleton) — будет внедряться через конструктор
  виджета.

**Тесты:**

- `getRecipes()` возвращает непустой список.
- Все элементы имеют непустые `name` и валидные `id` (> 0).
- `id` уникальны.
- Возвращаемое значение — `Future<List<Recipe>>`.

#### Чанк 3 — виджет `RecipeCard`

`StatelessWidget`, отображает один рецепт по дизайну Figma:

- Фотография (через `Image.network`, со скруглением углов).
- Название рецепта.
- Длительность приготовления с иконкой часов.
- Скруглённая карточка с тенью.

**Тесты (widget tests):**

- При передаче `Recipe` карточка содержит текст с названием.
- Отображается длительность в формате `XX мин`.
- При тапе вызывается `onTap` (через `InkWell`).

#### Чанк 4 — виджет `RecipeListPage`

`StatelessWidget`, принимает `List<Recipe>` через конструктор:

- Прокручиваемый список (`ListView.builder`).
- Заголовок «Рецепты» в `AppBar`.
- Каждый элемент — `RecipeCard`.
- Поддержка пустого состояния («Нет рецептов»).

**Тесты:**

- Передан список из 3 рецептов → отображаются 3 `RecipeCard`.
- Пустой список → отображается заглушка «Нет рецептов».
- Список прокручивается (используется `Scrollable`).

#### Чанк 5 — `MaterialApp` + тема

- Точка входа `main()` → `runApp(const RecipeApp())`.
- `RecipeApp` — `StatefulWidget` (или `FutureBuilder` обёртка), который вызывает
  `RecipeManager.getRecipes()` и передаёт результат в `RecipeListPage`.
- Тема: цвета, шрифты, скругления — по Figma (основной цвет `#2ECC71`,
  фон `#FFFFFF`, акцентный текст `#165932`).
- `Scaffold` с `AppBar`.

**Тесты:**

- Smoke test: приложение собирается и стартовый экран — `RecipeListPage`.
- Тема имеет ожидаемый primary color.

### Критерии оценки

| Критерий | Баллы | Статус |
|---|---|---|
| Менеджер и коллекция тестовых данных | 3 | ⏳ |
| Виджет списка рецептов | 3 | ⏳ |
| MaterialApp + Scaffold + настроенная тема | 3 | ⏳ |
| Форматирование по правилам Dart | 1 | ⏳ |

Минимум для зачёта: 6 баллов.

### Структура

```
recipe_list/
├── pubspec.yaml               # зависимости и метаданные пакета
├── analysis_options.yaml      # правила линтера (flutter_lints)
├── lib/
│   ├── main.dart              # точка входа, MaterialApp + тема (Чанк 5)
│   ├── models/
│   │   └── recipe.dart        # модель Recipe (Чанк 1)
│   ├── data/
│   │   └── recipe_manager.dart # менеджер с константным списком (Чанк 2)
│   └── ui/
│       ├── recipe_card.dart   # карточка одного рецепта (Чанк 3)
│       └── recipe_list_page.dart # страница со списком (Чанк 4)
├── test/
│   ├── recipe_test.dart       # тесты модели Recipe (3 теста)
│   ├── recipe_manager_test.dart # тесты RecipeManager (4 теста)
│   ├── recipe_card_test.dart  # widget-тесты RecipeCard (3 теста)
│   └── recipe_list_page_test.dart # widget-тесты RecipeListPage (4 теста)
├── android/                   # сгенерировано flutter create
├── ios/                       # сгенерировано flutter create
└── web/                       # сгенерировано flutter create
```

### Запуск

```bash
cd recipe_list
flutter pub get
flutter analyze            # 0 issues
flutter test               # 14/14 passed
flutter run -d emulator-5554   # Android
flutter run -d chrome          # web
```

## recipe_list — Дизайн-система и splash из Figma

**Date:** 2026-04-28

### Описание

Применены 4 замечания ревьюера к `recipe_list` и проведён полный рефакторинг
под дизайн-систему, выгруженную напрямую из Figma REST API
(file `alUTMeT3w9XlbNf3orwyFA`, frames `135:691`, `102:3`, `116:33`,
`118:76`, `121:584` и компонент-сеты `121:443`, `121:169`, `145:551`,
`145:579`).

### Замечания ревьюера

1. Имитированная сетевая задержка `RecipeManager` уменьшена до 400 мс
   (было 1 200 мс).
2. Тема разделена: `app_theme.dart` экспортирует `AppTheme.light` и
   токены (`AppColors`, `AppTextStyles`, `AppRadii`, `AppSpacing`,
   `AppShadows`, `AppDurations`, `kSplashGradient`).
3. Карточка рецепта переверстана 1:1 по Figma — фото `149×136` слева
   на всю высоту, скруглены только левые углы (5 dp), цвет названия
   `#000000`, длительность `#2ECC71`.
4. На экране списка убран глобальный заголовок «Рецепты» — на макете
   его нет; добавлен соответствующий тест.

### Дизайн-система

- [docs/design_system.md](../docs/design_system.md) — единый источник
  правды (палитра, типографика Roboto, сетка 428×926 dp, навбар в двух
  раскладках logIn/logOut, шаг рецепта 3 состояния, чекбокс, like,
  бейдж «Закладка», экраны login/register/profile/favorites/recipe
  details/cooking/list+FAB).
- Сырые Figma JSON-дампы в репозитории не хранятся (
  `docs/figma/` и `recipe_list/docs/figma/` добавлены в `.gitignore`),
  скрипт воспроизведения выгрузки в `mktemp` приведён в §13 документа.
- Токен Figma хранится локально в `.figma_env`
  (`chmod 600`, в `.gitignore`).

### Splash-экран

- `lib/ui/splash_page.dart` — full-screen `LinearGradient`
  `#2ECC71 → #165932`, центрированный логотип «OTUS\nFOOD»
  Roboto w900 95/82.
- `lib/main.dart` управляет переходом: 2 с splash → `AnimatedSwitcher`
  с `FadeTransition` 600 мс на `RecipeListLoader`.

### Структура (изменения)

```
recipe_list/
└── lib/
    ├── main.dart                  # _AppRoot со splash → list переходом
    └── ui/
        ├── app_theme.dart         # NEW: токены DS + AppTheme.light
        ├── splash_page.dart       # NEW: splash 1:1 по frame 135:691
        ├── recipe_list_loader.dart # NEW: FutureBuilder + loading/error
        ├── recipe_list_page.dart  # без AppBar, surfaceMuted фон
        └── recipe_card.dart       # фото слева 149×136, типографика DS

docs/
├── design_system.md               # NEW: дизайн-система (~330 строк)
├── foodapi_alternative.md         # NEW
├── foodapi_dzolotov.md            # NEW
└── todo/                          # NEW: рабочие заметки
```

### Запуск и проверки

```bash
cd recipe_list
flutter analyze    # No issues found
flutter test       # 14/14 passed
```
