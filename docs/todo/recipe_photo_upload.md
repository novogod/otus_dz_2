# TODO: загрузка фото рецепта файлом

Чанкованный план внедрения подфичи «вместо URL — выбрать файл с
устройства / снять камерой» на стэке `mahallem_ist` storage-api +
imgproxy. Архитектура и обоснование — в
[`docs/recipe-photo-upload.md`](../recipe-photo-upload.md). Базовая
фича «+ рецепт» уже описана в
[`docs/add-recipe-feature.md`](../add-recipe-feature.md).

Конвенция: каждый чанк = один коммит. После каждого чанка локально
зелёное:

* `flutter analyze` — 0 issues;
* `flutter test --no-pub` — baseline 56 / 2;
* `node --test tests/recipes.test.js` — baseline 12 / 2 + новые
  тесты текущего чанка.

Репозитории затрагиваются оба:

* `mahallem_ist` — миграция, compose, серверный endpoint, тесты;
* `otus_dz_2` — клиент (pubspec, RecipeApi, AddRecipePage,
  i18n).

---

## Чанк 1 — DB-миграция: bucket `recipe-photos`

Репо: `mahallem_ist`.

- [ ] Создать
  `local_docker_admin_backend/database/migrations/20260429_create_recipe_photos_bucket.sql`:
  * `INSERT INTO storage.buckets (id, name, public, file_size_limit,
    allowed_mime_types) VALUES ('recipe-photos', 'recipe-photos',
    true, 5242880, ARRAY['image/jpeg','image/jpg','image/png',
    'image/webp']) ON CONFLICT (id) DO NOTHING;`
  * 3 RLS-политики: `Service role can upload to recipe-photos`,
    `Public can view recipe-photos`, `Service role can delete
    recipe-photos`.
- [ ] Зарегистрировать миграцию в
  `local_docker_admin_backend/docker-compose.yml` рядом со строкой
  185 (`09.74-storage-buckets.sql`):
  * `- ./database/migrations/20260429_create_recipe_photos_bucket.sql:/docker-entrypoint-initdb.d/09.75-recipe-photos-bucket.sql:Z`.
- [ ] Локальная проверка: `docker compose down -v && docker compose
  up -d db storage-api` → `docker exec -it mahallem-db psql -U
  postgres -c "SELECT id, file_size_limit, public FROM
  storage.buckets WHERE id = 'recipe-photos';"` → одна строка.

**Acceptance:** bucket виден в `storage.buckets`, политики
перечислены в `pg_policies WHERE schemaname = 'storage'`.

## Чанк 2 — Backup hook для go-clean

Репо: `mahallem_ist`. Чтобы файлы пережили полную пересборку.

- [ ] В `local_user_portal/utils/backup-service.js` добавить
  `backupRecipePhotoFile(buffer, storageUrl)` (по аналогии с
  `backupAvatarFile` / `backupJobPhotoFile`).
- [ ] В `local_user_portal/utils/storage-upload.js` (обе функции —
  `uploadToStorage` и `uploadBase64ToStorage`) добавить ветку:
  ```js
  } else if (bucket === 'recipe-photos') {
    backupRecipePhotoFile(fileBuffer, storageUrl);
  }
  ```
- [ ] Если backup использует таблицу `backup_storage_files` с
  enum-колонкой — расширить enum через миграцию (или допустить
  свободный текст).

**Acceptance:** загруженный файл появляется в backup-таблице с
`bucket_id='recipe-photos'`.

## Чанк 3 — `RecipeRepository.updateUserMealThumb`

Репо: `mahallem_ist`, файл `local_user_portal/routes/recipes.js`.

- [ ] Метод:
  ```js
  async updateUserMealThumb(id, thumbUrl) {
    // прочитать текущий en, подменить strMealThumb,
    // пересчитать content_hash, записать обратно
  }
  ```
- [ ] SQL: `UPDATE recipes SET i18n = jsonb_set(i18n,
  '{en,strMealThumb}', to_jsonb($2::text), true), content_hash = $3
  WHERE id = $1`.
- [ ] Покрыть юнит-тестом в `tests/recipes.test.js`: insert через
  `createUserMeal`, потом `updateUserMealThumb`, проверить
  `i18n.en.strMealThumb` и неизменность остальных полей + рост
  `content_hash`.

**Acceptance:** новый тест зелёный, остальные 12 продолжают
проходить.

## Чанк 4 — Multer-конфиг для recipe-photos

Репо: `mahallem_ist`, файл `local_user_portal/routes/recipes.js`.

- [ ] Импорты: `multer`, `os`, `fs`, `path`, `crypto`,
  `uploadToStorage` (из `../utils/storage-upload.js`).
- [ ] Создать `recipePhotoUpload = multer({ storage:
  multer.diskStorage(…), limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: … })`. Скопировать паттерн из
  `routes/post-job.js`. allowed mimes: `image/jpeg`, `image/jpg`,
  `image/png`, `image/webp`.
- [ ] Вспомогательный `cleanupTempFile(path)` (одна функция, общая
  с post-job — вытащить в `utils/temp-files.js` или продублировать
  локально).

**Acceptance:** конфиг компилится, отдельный rate-limit пока **не**
ставим (см. чанк 6).

## Чанк 5 — `POST /recipes` с двумя contract-ами

Репо: `mahallem_ist`, файл `local_user_portal/routes/recipes.js`.

- [ ] Подменить `app.post('/recipes', async (req, res) => {…})` на
  `app.post('/recipes', recipePhotoUpload.single('photo'), async
  (req, res) => {…})`.
- [ ] Дискриминатор: `req.file` присутствует ⇒ multipart-flow,
  иначе старый JSON-flow.
- [ ] Multipart-flow:
  1. `meal = JSON.parse(req.body.meal)` (multer кладёт строкой).
  2. `meal.strMealThumb = meal.strMealThumb || 'pending://upload'`.
  3. `stored = await repo.createUserMeal(meal)` — получили `id`.
  4. `key = recipes/${stored.id}/${randHex6}${ext}`.
  5. `publicUrl = await uploadToStorage(req.file, 'recipe-photos',
     key, executeQuery)`.
  6. `await repo.updateUserMealThumb(stored.id, publicUrl)`.
  7. `stored.meal.strMealThumb = publicUrl`.
  8. `cleanupTempFile(req.file.path)`.
- [ ] JSON-flow: без изменений.
- [ ] Новые ошибки: `413 payload_too_large` (multer `LIMIT_FILE_SIZE`
  → перехватить в catch и вернуть честный код), `400
  unsupported_mime` (multer fileFilter).
- [ ] Если шаг 5 упал, рецепт остаётся с `pending://upload` —
  логировать `console.error` и отдавать `502 upload_failed`
  (рецепт уже создан, клиент может re-upload отдельным эндпоинтом
  — за рамками MVP, см. recipe-photo-upload.md §3.1).

**Acceptance:** `curl -F meal='{"strMeal":"x","strMealThumb":""}'
-F photo=@./pic.jpg /recipes` отдаёт 201 с `strMealThumb`,
указывающим на `/storage/v1/object/public/recipe-photos/recipes/<id>/<hex>.jpg`.

## Чанк 6 — Rate limit для multipart

Репо: `mahallem_ist`. Защита от абуза, см. recipe-photo-upload.md §3.3.

- [ ] Поверх существующего `app.use('/recipes', limiter,
  authMiddleware)` поставить **узкий** лимит для multipart-загрузок:
  `multipartLimiter = rateLimit({ windowMs: 60_000, max: 5 })`.
- [ ] Применять только когда `Content-Type` начинается с
  `multipart/`. Реализуется как middleware-wrapper:
  ```js
  app.post('/recipes',
    (req, res, next) => req.is('multipart/*')
      ? multipartLimiter(req, res, next)
      : next(),
    recipePhotoUpload.single('photo'),
    async (req, res) => { … },
  );
  ```
- [ ] Тест-проброс: 6 multipart запросов за 60 секунд → 6-й
  получает 429.

**Acceptance:** интеграционный тест на 429 проходит, обычный JSON
flow не аффектится.

## Чанк 7 — Тесты сервера для multipart-flow

Репо: `mahallem_ist`, `local_user_portal/tests/recipes.test.js`.

- [ ] Mock storage-api через `nock` или ручной `http`-перехват
  (зависит от чем уже пользуется тест-сьют).
- [ ] Тест 1 «multipart upload персистит publicUrl»:
  multipart-payload (meal + photo), мок storage-api 200 OK,
  проверить что в `recipes.i18n.en.strMealThumb` записан
  `/storage/v1/object/public/recipe-photos/...`.
- [ ] Тест 2 «multipart upload с упавшим storage оставляет
  pending placeholder»: мок storage-api 500, ответ 502, рецепт в
  БД c `strMealThumb='pending://upload'`.
- [ ] Тест 3 «JSON-only flow без изменений»: проверка что старый
  путь по-прежнему возвращает 201.
- [ ] Тест 4 «mime filter rejects pdf»: multipart с `application/pdf`
  → 400 + `unsupported_mime`.
- [ ] Прогон: 16 / 2 (12 baseline + 4 новых, 2 echo-gate baseline-fail).

**Acceptance:** все 4 теста зелёные.

## Чанк 8 — Cron-job уборки orphan-файлов

Репо: `mahallem_ist`. Эвикция в `recipes` оставляет файлы без
ссылок.

- [ ] Файл `local_user_portal/jobs/cleanup-orphan-recipe-photos.js`:
  ```sql
  WITH refs AS (
    SELECT i18n->'en'->>'strMealThumb' AS url FROM recipes
    WHERE i18n->'en'->>'strMealThumb' LIKE '%/recipe-photos/%'
  )
  SELECT name FROM storage.objects
  WHERE bucket_id = 'recipe-photos'
    AND created_at < NOW() - INTERVAL '24 hours'
    AND '/storage/v1/object/public/recipe-photos/' || name NOT IN (SELECT url FROM refs);
  ```
- [ ] Удалять найденные через
  `DELETE FROM storage.objects WHERE bucket_id='recipe-photos' AND name = ANY($1)`.
- [ ] Расписание: один раз в неделю, через `setInterval` в
  `server.js` либо через системный cron в `Dockerfile`.
- [ ] Env-флаг `RECIPE_PHOTOS_CLEANUP_DISABLED=1` для отключения
  без редеплоя.
- [ ] Лог: `cleaned <N> orphan recipe photos`.

**Acceptance:** скрипт прогоняется руками `node jobs/cleanup-…js`
без ошибок; при отсутствии orphans — логирует 0.

## Чанк 9 — Клиент: зависимости

Репо: `otus_dz_2`, файл `recipe_list/pubspec.yaml`.

- [ ] Добавить:
  ```yaml
  image_picker: ^1.0.7
  flutter_image_compress: ^2.2.0
  path: ^1.9.0
  ```
- [ ] iOS — в `recipe_list/ios/Runner/Info.plist`:
  * `NSPhotoLibraryUsageDescription` — «Нужен доступ к
    фотогалерее, чтобы прикрепить фото к рецепту».
  * `NSCameraUsageDescription` — «Нужен доступ к камере, чтобы
    сфотографировать блюдо».
- [ ] Android — `AndroidManifest.xml`: разрешения
  `READ_EXTERNAL_STORAGE` (под API ≤ 32) и `READ_MEDIA_IMAGES`
  (API ≥ 33). `image_picker` подсказывает что добавить.
- [ ] `cd recipe_list && flutter pub get`.

**Acceptance:** `flutter analyze` чисто, билд проходит на iOS и
Android.

## Чанк 10 — Клиент: `RecipeApi.createRecipeWithPhoto`

Репо: `otus_dz_2`, файл `recipe_list/lib/data/api/recipe_api.dart`.

- [ ] Метод:
  ```dart
  Future<Recipe> createRecipeWithPhoto(Recipe draft, File photo) async {
    if (_client.backend != RecipeBackend.mahallem) {
      throw StateError('createRecipeWithPhoto requires the mahallem backend');
    }
    final form = FormData.fromMap({
      'meal': jsonEncode(_mealToJson(draft)),
      'photo': await MultipartFile.fromFile(
        photo.path, filename: p.basename(photo.path),
      ),
    });
    final res = await _client.dio.post<Map<String, dynamic>>(
      '', data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return Recipe.fromMealDb(res.data!['meal']);
  }
  ```
- [ ] Вынести `_mealToJson(Recipe)` в приватный helper, чтобы и
  `createRecipe` (JSON-only), и `createRecipeWithPhoto` шли через
  один сериализатор.
- [ ] Юнит-тест в `recipe_list/test/data/api/recipe_api_test.dart`
  (mock dio adapter): multipart-форма содержит поле `meal`
  (JSON-строка) и `photo` (binary part).

**Acceptance:** новый юнит-тест проходит, `flutter test --no-pub`
по-прежнему 57 / 2 (56 baseline + 1 новый).

## Чанк 11 — Клиент: ImagePicker в `AddRecipePage`

Репо: `otus_dz_2`, файл `recipe_list/lib/ui/add_recipe_page.dart`.

- [ ] Удалить TextField «URL фотографии» (или оставить как fallback
  когда picker недоступен — например, в web-сборке).
- [ ] Добавить виджет-превью + 2 кнопки:
  * «Из галереи» → `picker.pickImage(source: ImageSource.gallery,
    maxWidth: 2048, maxHeight: 2048, imageQuality: 85)`.
  * «Сделать снимок» → `ImageSource.camera`.
- [ ] HEIC → JPEG конверт + downscale делает единый
  `downscaleForUpload(XFile)` из чанка 11.5 — не дублируем
  вызовы `flutter_image_compress` по экрану.
- [ ] Хранить выбранный `File` в `_pickedPhoto`, рендерить через
  `Image.file(_pickedPhoto)` 120×120 с borderRadius.
- [ ] Валидация: `_pickedPhoto != null` ⇒ ok; иначе показать
  ошибку «Добавьте фотографию».
- [ ] В `_save()`:
  * если `_pickedPhoto != null` → `api.createRecipeWithPhoto(draft,
    _pickedPhoto!)`;
  * иначе fallback `api.createRecipe(draft)` (требует URL в форме).

**Acceptance:** в эмуляторе/симуляторе можно выбрать фото и
сохранить рецепт; `Recipe.photo` содержит URL вида
`/storage/v1/object/public/recipe-photos/...`.

## Чанк 11.5 — Клиент: единый downscaler

Репо: `otus_dz_2`. `image_picker` **не является** надёжным
resizer-ом: `maxWidth/maxHeight` на Android иногда игнорируется
(выбор через SAF/Photo Picker), `imageQuality` работает только
для JPEG, и 12 МП-фото с iPhone/Pixel прилетает в 5–10 МБ
— упираясь в лимит 5 МБ в bucket’е `recipe-photos`.
Пропускаем любой выбранный файл через единую функцию
сжатия — и только потом рендерим превью и шлём на сервер.

- [ ] `recipe_list/lib/utils/photo_downscaler.dart`:
  ```dart
  Future<File> downscaleForUpload(XFile src) async {
    final tmp = await getTemporaryDirectory();
    final out = File(p.join(tmp.path, 'rcp_${DateTime.now().microsecondsSinceEpoch}.jpg'));
    final r1 = await FlutterImageCompress.compressAndGetFile(
      src.path, out.path,
      minWidth: 1600, minHeight: 1600,
      quality: 80, format: CompressFormat.jpeg,
      keepExif: false, // privacy: режем GPS/timestamp
    );
    if (r1 == null) throw StateError('compress_failed');
    if (await out.length() <= 5 * 1024 * 1024) return out;
    // Ультра-огромная съёмка (panorama, RAW-derived) — второй проход.
    final r2 = await FlutterImageCompress.compressAndGetFile(
      out.path, out.path,
      minWidth: 1280, minHeight: 1280,
      quality: 60, format: CompressFormat.jpeg, keepExif: false,
    );
    if (r2 == null || await out.length() > 5 * 1024 * 1024) {
      throw StateError('photo_too_large');
    }
    return out;
  }
  ```
- [ ] `image_picker` вызывается без `maxWidth/maxHeight/imageQuality`
  — сжатие делает `flutter_image_compress` (одна точка
  EXIF-strip, predictable JPEG output, без SAF-багов).
- [ ] `AddRecipePage._save()` хранит путь к *сжатому*
  файлу, оригинал не удерживается. Сжатый файл
  удаляется в `finally` после успеха/ошибки
  `createRecipeWithPhoto`.
- [ ] Показываем `LinearProgressIndicator` на время сжатия
  (может занять 0.5–2 с на старых устройствах).
- [ ] Юнит-тест `test/utils/photo_downscaler_test.dart`:
  вход — fixture-PNG 4096×3072, выход — JPEG ≤ 5 МБ и ширина
  ≤ 1600. (На CI flutter_image_compress работает только в
  integration-tests; если хост unit-test не поддерживает
  — подменить через abstract `PhotoCodec` + fake.)

**Acceptance:** фото c iPhone (HEIC, 4032×3024, ~3 МБ) после
выбора превращается в JPEG 1600×1200, ~250–450 КБ, EXIF
пустой; multipart-запрос улетает быстро даже на 3G.

## Чанк 12 — Клиент: imgproxy для превью

Репо: `otus_dz_2`. Чтобы 5 МБ-картинка не грузилась целиком на
каждый scroll-фрейм.

- [ ] Helper `String imgproxyUrl(String src, int w, int h)` в
  `recipe_list/lib/utils/imgproxy.dart`:
  * собирать URL вида
    `${baseUrl}/imgproxy/resize:fit:${w}:${h}:0/.../${base64UrlEncode(utf8.encode(src))}`;
  * для локальных тестов / TheMealDB-бэкенда возвращать `src`
    без обёртки.
- [ ] Применить в `RecipeCard`, `RecipeDetailsPage` (как уже
  сделано на серверной стороне в `getImgproxyUrl`).
- [ ] Документация: добавить пример в
  [`docs/recipe-photo-upload.md`](../recipe-photo-upload.md) §2.4.

**Acceptance:** карточки рецепта подгружают thumbnail-версию (60–80 КБ)
вместо оригинала; в DevTools видно меньший Content-Length.

## Чанк 13 — Клиент: i18n новых ключей

Репо: `otus_dz_2`, 10 файлов `recipe_list/lib/i18n/*.i18n.json`.

- [ ] `addRecipePhotoFromGallery` — «Из галереи».
- [ ] `addRecipePhotoFromCamera` — «Сделать снимок».
- [ ] `addRecipePhotoRequired` — «Прикрепите фотографию».
- [ ] `a11y.addRecipePhotoPicker` — для `Semantics(button: true,
  label: …)`.
- [ ] Удалить (или пометить deprecated) `addRecipePhoto` если
  поле URL убрано.
- [ ] `dart run slang` → регенерировать
  `lib/i18n/strings*.g.dart`.
- [ ] Дописать геттеры в `recipe_list/lib/i18n.dart`.

**Acceptance:** `flutter analyze` 0 issues, переключение языка в
runtime показывает новые лейблы.

## Чанк 14 — Документация и CHANGELOG

Репо: `otus_dz_2`.

- [ ] Обновить `docs/add-recipe-feature.md` §3.2 (форма) и §9
  (что вне рамок) — фото-URL заменено на ImagePicker, «загрузка
  файлом» больше не «вне рамок».
- [ ] Обновить `docs/add-recipe-feature.md` §10 — добавить файлы
  `imgproxy.dart`, миграцию `20260429_create_recipe_photos_bucket.sql`.
- [ ] В `docs/project_log.md` сверху новая запись «Recipe photo
  upload» с тем же форматом (date + bullet-list per repo).
- [ ] В `docs/recipe-photo-upload.md` §4 (чек-лист) проставить
  галочки рядом с каждым выполненным пунктом.

**Acceptance:** документы консистентны, в чек-листах нет смешения
«сделано» и «планируется».

## Чанк 15 — Production redeploy mahallem (отдельным шагом)

- [ ] Step 0 sync prod uncommitted state на хост.
- [ ] `git pull` на хосте.
- [ ] Применить миграцию на проде:
  ```sh
  docker exec -i mahallem-db psql -U postgres < \
    local_docker_admin_backend/database/migrations/20260429_create_recipe_photos_bucket.sql
  ```
  (либо через rebuild compose с `--force-recreate db` если допустимо).
- [ ] `docker compose up -d --build user-portal storage-api`.
- [ ] Smoke-test:
  ```sh
  curl -X POST https://mahallem.ist/recipes \
    -F meal='{"strMeal":"Smoke","strMealThumb":""}' \
    -F photo=@/path/to/test.jpg
  ```
  → 201 с `strMealThumb` на `/storage/v1/object/public/recipe-photos/...`.
- [ ] Открыть URL картинки в браузере — отдаётся 200.
- [ ] Удалить smoke-рецепт через `DELETE` (отдельный admin-flow)
  или оставить с пометкой.

**Acceptance:** прод принимает multipart-загрузки, картинки
доступны публично.

---

## Не входит

- Edit / delete рецепта (отдельная фича, требует UI и `PUT`/`DELETE` ручек).
- Multiple photos per recipe (нужна табл. `recipe_photos`).
- Server-side EXIF strip (через `IMGPROXY_STRIP_METADATA=1` при
  необходимости).
- Premoderation queue (нужна админ-панель).
