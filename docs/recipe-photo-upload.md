# Загрузка фотографии рецепта файлом

> Документ для преподавателя Flutter-школы (Otus). Сопроводительный
> к [`add-recipe-feature.md`](./add-recipe-feature.md). Здесь —
> разбор того, **как** добавить в фичу «+ рецепт» загрузку картинки
> файлом (а не URL-ом), используя уже существующую инфраструктуру
> хранилища `mahallem_ist`. В основном документе это было явно
> вынесено за рамки MVP — теперь даём конкретный план, как это
> поднять без переизобретений.

---

## TL;DR

В стеке `mahallem_ist` уже есть готовое file storage: контейнер
`mahallem-storage-api` (Supabase Storage v0.46.4), nginx-fallback
`mahallem-storage`, и `mahallem-imgproxy` для on-the-fly
трансформаций. Buckets `avatars` (2 МБ) и `job-photos` (5 МБ) уже
живут в Postgres-схеме `storage`, а user-portal умеет в них писать
через [`utils/storage-upload.js`](../../mahallem_ist/local_user_portal/utils/storage-upload.js)
(`uploadToStorage(file, bucket, filepath, executeQuery)`).

**Решение для фичи «+ рецепт»** — повторно использовать ту же
инфраструктуру:

1. SQL-миграцией завести третий bucket `recipe-photos` (5 МБ,
   те же mime-types, тот же набор RLS-политик).
2. В `routes/recipes.js` принимать `multipart/form-data` через
   `multer` (тот же конфиг, что в `routes/post-job.js`).
3. После `INSERT` рецепта вызвать `uploadToStorage(file,
   'recipe-photos', 'recipes/<id>/<hash>.<ext>', executeQuery)` и
   вернуть публичный URL клиенту в `meal.strMealThumb`.
4. В клиенте `recipe_list` заменить поле «URL фотографии» на
   `image_picker` + `MultipartFile.fromPath(...)`. На превью
   подключить imgproxy для эконом-байтов на мобильнике.

Никакого внешнего S3 / DigitalOcean Spaces / signed-URL flow —
всё это уже инкапсулировано в storage-api.

---

## 1. Что есть в инфраструктуре прямо сейчас

### 1.1. Контейнеры

Из [`local_docker_admin_backend/docker-compose.yml`](../../mahallem_ist/local_docker_admin_backend/docker-compose.yml):

- **`mahallem-storage-api`** (`supabase/storage-api:v0.46.4`)
  - `STORAGE_BACKEND=file`,
    `FILE_STORAGE_BACKEND_PATH=/var/lib/storage`;
  - `FILE_SIZE_LIMIT=52_428_800` (50 МБ глобально, дальше каждый
    bucket режет своим лимитом);
  - использует Postgres-схему `storage` для метаданных
    (`storage.buckets` + `storage.objects`);
  - том `storage_data:/var/lib/storage` персистит файлы между
    рестартами;
  - порт `5002:5000` наружу, внутри сети — `http://storage-api:5000`.
- **`mahallem-storage`** (`nginx:1.24-alpine`) — read-only фолбек
  для прямой раздачи файлов с того же тома (`storage_data`),
  слушает `5005:80`. Используется когда storage-api лежит /
  перегружен.
- **`mahallem-imgproxy`** (`darthsim/imgproxy:v3.8.0`) — on-the-fly
  ресайз/конверсия PNG→WebP/AVIF; URL формата
  `/imgproxy/.../resize:fit:120:120:0/<base64-encoded-source>`.
  Уже зашит в `getImgproxyUrl(url, w, h)` в нескольких местах
  user-portal.

### 1.2. Существующие buckets

[`database/migrations/20251108_create_storage_buckets.sql`](../../mahallem_ist/local_docker_admin_backend/database/migrations/20251108_create_storage_buckets.sql)
создаёт:

- `avatars` — `public=true`, лимит 2 МБ, `image/jpeg|jpg|png|webp`;
- `job-photos` — `public=true`, лимит 5 МБ, тот же набор mime-ов.

Для каждого ставит RLS-политики типа:

- `Public can view <bucket>` на `SELECT`,
- `Service role can upload to <bucket>` на `INSERT`,
- `Authenticated users can update/delete <bucket>` на UPDATE/DELETE.

### 1.3. Утилита загрузки

[`utils/storage-upload.js`](../../mahallem_ist/local_user_portal/utils/storage-upload.js)
экспортирует `uploadToStorage(file, bucket, filepath, executeQuery)`.
Что делает:

1. Читает файл с диска (multer кладёт его в `os.tmpdir()`).
2. Шлёт `POST` на `${STORAGE_API_URL}/object/<bucket>/<filepath>`
   с `Authorization: Bearer ${SERVICE_ROLE_KEY}` (внутренний канал).
3. Возвращает публичный URL вида
   `/storage/v1/object/public/<bucket>/<filepath>`.
4. **Бэкап** для Go Clean: бинарник + строка из `storage.objects`
   копируются в `backup-service.js`, чтобы пережить полный
   re-seed Postgres.

Контейнер `user-portal` в compose-е уже получает оба нужных env-а:

```yaml
STORAGE_API_URL: http://storage-api:5000
SERVICE_ROLE_KEY: ${SERVICE_ROLE_KEY}
```

### 1.4. Где это уже работает

`routes/post-job.js` принимает фото через
`multer({ limits: { fileSize: 10 * 1024 * 1024 } })`, кладёт во
временную папку, потом

```js
const filename = `jobs/${userId}/${Date.now()}-${crypto.randomBytes(4).toString('hex')}.jpg`;
const publicUrl = await uploadToStorage(file, 'job-photos', filename, executeQuery);
```

и сохраняет URL в `jobs.problem_photos`. Аватары — аналогично через
`routes/edit-profile.js` и bucket `avatars`.

## 2. Дизайн фичи

### 2.1. Новый bucket `recipe-photos`

Новая миграция
`database/migrations/20260429_create_recipe_photos_bucket.sql`:

```sql
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'recipe-photos',
  'recipe-photos',
  true,
  5242880, -- 5 МБ, как у job-photos
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Service role can upload to recipe-photos"
  ON storage.objects FOR INSERT
  TO service_role, supabase_storage_admin
  WITH CHECK (bucket_id = 'recipe-photos');

CREATE POLICY "Public can view recipe-photos"
  ON storage.objects FOR SELECT
  TO PUBLIC USING (bucket_id = 'recipe-photos');

CREATE POLICY "Service role can delete recipe-photos"
  ON storage.objects FOR DELETE
  TO service_role, supabase_storage_admin
  USING (bucket_id = 'recipe-photos');
```

Подключается в compose-е тем же приёмом, что и
`20251108_create_storage_buckets.sql` — через
`/docker-entrypoint-initdb.d/...` (см. строки 184–185
`docker-compose.yml`).

Heuristics:

- 5 МБ — оптимальный лимит для блюда «один ракурс с iPhone-камеры»
  с учётом того, что HEIC-конверт идёт ещё на клиенте.
- `public=true` — рецепт публичный, signed-URL не нужен.
- HEIC оставляем серверу (через imgproxy) или конвертим на клиенте
  (см. §2.4).

### 2.2. Серверный endpoint

В [`routes/recipes.js`](../../mahallem_ist/local_user_portal/routes/recipes.js)
расширяем `POST /recipes` так, чтобы он умел и **JSON-only**
(нынешний контракт — `meal.strMealThumb` уже URL), и
**multipart/form-data** (новый — payload с файлом). Discriminator —
`Content-Type` запроса.

```js
import multer from 'multer';
import path from 'path';
import os from 'os';
import fs from 'fs';
import crypto from 'crypto';
import { uploadToStorage } from '../utils/storage-upload.js';

const recipePhotoUpload = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => {
      const dir = path.join(os.tmpdir(), 'user-portal-recipe-uploads');
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
      cb(null, dir);
    },
    filename: (req, file, cb) => {
      const suffix = `${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;
      cb(null, `recipe-photo-${suffix}${path.extname(file.originalname)}`);
    },
  }),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const ok = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
      .includes(file.mimetype);
    cb(ok ? null : new Error('unsupported_mime'), ok);
  },
});

app.post(
  '/recipes',
  recipePhotoUpload.single('photo'), // допускает 0 или 1 файл
  async (req, res) => {
    try {
      // multipart кладёт JSON-поле в строку, JSON-only — сразу объект
      const meal = typeof req.body.meal === 'string'
        ? JSON.parse(req.body.meal)
        : req.body.meal;
      if (!meal) return res.status(400).json({ error: 'missing_meal' });

      // Если файла нет — фолбек на старый flow (strMealThumb URL).
      let stored;
      if (req.file) {
        // 1) сначала вставляем рецепт без strMealThumb — нам нужен id
        meal.strMealThumb = meal.strMealThumb || 'pending://upload';
        stored = await repo.createUserMeal(meal);
        // 2) аплоадим файл по пути recipes/<id>/<hash>.<ext>
        const ext = path.extname(req.file.originalname).toLowerCase() || '.jpg';
        const hash = crypto.randomBytes(6).toString('hex');
        const key = `recipes/${stored.id}/${hash}${ext}`;
        const publicUrl = await uploadToStorage(
          req.file, 'recipe-photos', key, executeQuery,
        );
        // 3) обновляем strMealThumb через прицельный update
        stored.meal.strMealThumb = publicUrl;
        await repo.updateUserMealThumb(stored.id, publicUrl);
      } else {
        if (!meal.strMealThumb) {
          return res.status(400).json({ error: 'missing_required_fields' });
        }
        stored = await repo.createUserMeal(meal);
      }

      res.status(201).json(stored);
    } catch (err) {
      if (err.message === 'invalid_meal') {
        return res.status(400).json({ error: 'invalid_meal' });
      }
      console.error('POST /recipes failed:', err);
      res.status(500).json({ error: 'internal' });
    }
  },
);
```

И один маленький новый метод в `RecipeRepository`:

```js
async updateUserMealThumb(id, thumbUrl) {
  await this.q(
    `UPDATE recipes
        SET i18n = jsonb_set(i18n, '{en,strMealThumb}', to_jsonb($2::text), true),
            content_hash = $3
      WHERE id = $1`,
    [id, thumbUrl, contentHash({ ...this._readEn(id), strMealThumb: thumbUrl })],
  );
}
```

(Альтернатива — отложить вставку до получения публичного URL и
делать единственный INSERT. Но тогда теряется атомарность относительно
`createUserMeal` и его id-allocation; делить логику на два шага
проще и надёжнее.)

### 2.3. Контракт `POST /recipes` после изменений

| Заголовок | Тело | Поведение |
|---|---|---|
| `Content-Type: application/json` | `{ "meal": { "strMeal": "...", "strMealThumb": "https://...", ... } }` | старый JSON-only flow, без изменений |
| `Content-Type: multipart/form-data` | поле `meal` — JSON-строка с метаданными; поле `photo` — файл | новый flow с загрузкой файла, `strMealThumb` подставляется сервером |

Ответ в обоих случаях один и тот же: `201 {id, meal: {...}}`.
Дополнительные коды ошибок:

- `413 payload_too_large` — multer сам режет на `fileSize` лимите;
- `400 unsupported_mime` — файл не из allow-list;
- `400 upload_failed` — `uploadToStorage` бросил после успешной
  вставки рецепта (рецепт остаётся в БД с `strMealThumb=
  'pending://upload'`, оператор может позже подменить — это
  сознательная trade-off, см. §3.2).

### 2.4. Клиент

В [`add_recipe_page.dart`](../recipe_list/lib/ui/add_recipe_page.dart):

1. Заменить поле «URL фотографии» на компонент-выбор:
   ```dart
   final picker = ImagePicker();
   final XFile? picked = await picker.pickImage(
     source: ImageSource.gallery, // и/или camera
     // Без maxWidth/maxHeight/imageQuality — эти параметры
     // ненадёжны на Android (игнорятся частью SAF-провайдеров).
     // Ресайз делает единый client-side downscaler (см. §2.4.1).
   );
   ```
   Пакеты: `image_picker: ^1.x` + `flutter_image_compress: ^2.x`
   (обязательный, не опциональный). `image_cropper`
   опционален.

#### 2.4.1. Client-side downscaler

`image_picker` не гарантирует ни размер, ни предсказуемый
format: c iPhone приходит HEIC, с Pixel/Samsung — 4096-пиксельный
JPEG на 6–10 МБ. Один путь `downscaleForUpload(XFile) -> File`
([см. todo чанк 11.5](./todo/recipe_photo_upload.md#chunk-115)):

* `flutter_image_compress.compressAndGetFile(...)` с
  `minWidth: 1600, minHeight: 1600, quality: 80,
  format: CompressFormat.jpeg, keepExif: false`.
* Результат гарантированно JPEG (однородный
  storage-api MIME), с верхней границей ~600 КБ
  (хорошо лежит в 5 МБ бакет-лимит и быстро улетает на 3G).
* `keepExif: false` — ranged GPS/serial/timestamps стрипаем
  одной точкой (не полагаемся ни на image_picker, ни на imgproxy).
* Fallback вторым проходом при > 5 МБ: `1280×1280, q=60`.
* Без client-side resize multipart-запрос вырождается в
  413 payload_too_large или просто «dead-висит» на слабом
  канале — схема неприемлема.

2. `AddRecipePage._save()` берёт результат downscaler-а,
   не оригинал из `image_picker`.
3. В `RecipeApi.createRecipe` добавить альтернативную сигнатуру:
   ```dart
   Future<Recipe> createRecipeWithPhoto(Recipe draft, File photo) async {
     final form = FormData.fromMap({
       'meal': jsonEncode(_mealToJson(draft)), // тот же 49-fields shape
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
   Старый `createRecipe(Recipe)` остаётся для случая «у пользователя
   уже есть готовый URL».
4. В превью-аватаре и в `RecipeCard` использовать imgproxy:
   ```
   /imgproxy/resize:fit:600:400:0/.../<base64(strMealThumb)>
   ```
   Это даст и кэш на CDN, и ленивый ресайз под экран — без
   тяжёлой 5-мегабайтной фотографии в каждом скролл-фрейме.

### 2.5. i18n / a11y

Добавятся новые ключи в каждой из 10 локалей (en, ru, es, fr,
de, it, tr, ar, fa, ku):

- `addRecipePhotoFromGallery` — кнопка  «Выбрать из галереи».
- `addRecipePhotoFromCamera` — кнопка  «Сделать снимок».
- `addRecipePhotoRequired` —  «Прикрепите фотографию» (валидация).
- `addRecipePhotoRemove` — tooltip крестика и пункт в bottom-sheet.
- `addRecipePhotoSourceTitle` — заголовок bottom-sheet  «Откуда
  взять фото?».
- `addRecipePhotoErrorAccessDenied` и `addRecipePhotoErrorTooLarge`
  — SnackBar-ы при PlatformException и при провале downscaler-а.
- `a11y.addRecipePhotoPicker` — для `Semantics(button: true, …)`
  на превью.

Старый ключ `addRecipePhoto` (URL) остаётся как fallback-режим
для случая когда `image_picker` недоступен (web-сборка).

## 3. Trade-offs и пограничные случаи

### 3.1. Транзакционность

`storage-api` и Postgres — два разных хранилища. Атомарной
транзакции «вставка рецепта + загрузка файла» нет. Поэтому в §2.2
описана 3-шаговая последовательность:

1. INSERT в `recipes` → получили `id`.
2. Upload в storage-api → получили публичный URL.
3. UPDATE `recipes.i18n.en.strMealThumb`.

Если упал шаг 2 — рецепт остался в БД с placeholder-ом
`pending://upload`. Это лучше, чем «потерять рецепт после успешной
загрузки файла»: оператор видит pending-записи скриптом
`SELECT … WHERE i18n->'en'->>'strMealThumb' = 'pending://upload'`
и может либо подчистить, либо повторно загрузить файл.

Если упал шаг 3 — файл уже залит, но рецепт всё равно ссылается на
placeholder. Здесь спасает `backup-service.js`: бинарник
заскриптован в backup-таблицу, можно восстановить.

### 3.2. Eviction

Eviction-политика рецепта (LRU по `popularity asc, fetched_at asc`)
остаётся как есть. **Но** если LRU вытесняет ряд из `recipes`,
файл в storage остаётся ничейным — это утечка. Решения:

- **Минимум**: периодический cron-job (раз в неделю) сравнивает
  `storage.objects.name` с `i18n->'en'->>'strMealThumb'` и удаляет
  файлы, на которые никто не ссылается, в bucket `recipe-photos`.
  10 строк SQL + `DELETE FROM storage.objects`.
- **Подвинуть пол id**: для пользовательских рецептов eviction
  можно отключить (`id ≥ 1_000_000` исключать из `_evictIfOverCap`).
  Это спорно — пользователь будет ожидать что его рецепт всегда
  жив, но тогда таблица растёт неограниченно. **Рекомендую**: ввести
  отдельный cap для user-meals (например, 50 000 строк) и
  eviction-ить только их хвост.

### 3.3. Авторизация

Сейчас `POST /recipes` гейтится через `authMiddleware` (опциональный
`x-recipes-token` если выставлен `RECIPES_API_SECRET`). С файлами
это становится более чувствительно — анонимная загрузка картинок
открывает дешёвый канал для абуза (мусорный контент, возможно
нелегальный). Минимальные меры:

- **Обязательно**: выставить `RECIPES_API_SECRET` в продакшене.
- **Желательно**: rate limit отдельно для multipart endpoint,
  например `5 req/min/IP` против общего `1200 req/min`.
- **Желательно**: image-content sanity (storage-api сам проверяет
  mime + magic-bytes; этого достаточно для MVP).

### 3.4. Бэкап Go Clean

`uploadToStorage` уже зеркалит загруженные файлы через
`backup-service.js` (`backupAvatarFile`/`backupJobPhotoFile`). Для
recipe-photos нужно добавить аналогичный `backupRecipePhotoFile` и
ветку:

```js
} else if (bucket === 'recipe-photos') {
  backupRecipePhotoFile(fileBuffer, storageUrl);
}
```

Backup-таблица та же (`backup_storage_files`), просто новый
`bucket_id`. Это нужно для GO_CLEAN — иначе при полной перестройке
БД пользовательские картинки потеряются.

### 3.5. Прод vs локал

Прод mahallem.ist использует тот же compose-стек (через
`hostinger-deployment/`). Никаких external storage backends (S3,
Spaces) сейчас не подключено. Если когда-то понадобится — у
storage-api есть `STORAGE_BACKEND=s3` режим, его можно будет
переключить без изменения путей URL.

## 4. Чек-лист внедрения

> **Статус:** все пункты ниже реализованы (chunks 1–14 в
> [`todo/recipe_photo_upload.md`](./todo/recipe_photo_upload.md)).
> Прод-redeploy (chunk 15) — отдельным шагом, см. там же.

| ✓ | Слой | Файл | Что добавить |
|---|---|---|---|
| ✅ | DB | `local_docker_admin_backend/database/migrations/20260429_create_recipe_photos_bucket.sql` | INSERT в `storage.buckets` + 3 RLS-политики |
| ✅ | DB | `local_docker_admin_backend/docker-compose.yml` (≈строка 185) | `- ./database/migrations/20260429_create_recipe_photos_bucket.sql:/docker-entrypoint-initdb.d/09.76-recipe-photos-bucket.sql:Z` |
| ✅ | Server | `local_user_portal/routes/recipes.js` | `multer` + `recipePhotoUpload.single('photo')` + ветка multipart в `app.post('/recipes', …)` |
| ✅ | Server | `local_user_portal/routes/recipes.js` (`RecipeRepository`) | метод `updateUserMealThumb(id, url)` |
| ✅ | Server | `local_user_portal/utils/storage-upload.js` | ветка `bucket === 'recipe-photos'` в `backupStorageObjectEntry` |
| ✅ | Server | `local_user_portal/utils/backup-service.js` | `backupRecipePhotoFile(buffer, url)` |
| ✅ | Server | `local_user_portal/tests/recipes.test.js` | 4 multipart-теста + repo-тест `updateUserMealThumb` |
| ✅ | Cron | `local_user_portal/lib/jobs/cleanup-orphan-recipe-photos.js` | раз в неделю чистит файлы без ссылок из `recipes.i18n.en.strMealThumb` |
| ✅ | Client | `recipe_list/pubspec.yaml` | `image_picker: ^1.0.7` + `flutter_image_compress: ^2.2.0` |
| ✅ | Client | `recipe_list/lib/utils/photo_downscaler.dart` | `downscaleForUpload(XFile)` — 1600×1600, q80, EXIF strip |
| ✅ | Client | `recipe_list/lib/utils/imgproxy.dart` | `imgproxyUrl(src, w, h)` — превью через imgproxy |
| ✅ | Client | `recipe_list/lib/data/api/recipe_api.dart` | новый метод `createRecipeWithPhoto(Recipe, File)` (multipart) |
| ✅ | Client | `recipe_list/lib/ui/add_recipe_page.dart` | `_PhotoPicker` + предпросмотр + multipart-вызов |
| ✅ | Client | `recipe_list/lib/ui/recipe_card.dart`, `recipe_details_page.dart` | thumbnails через `imgproxyUrl` |
| ✅ | Client i18n | `recipe_list/lib/i18n/*.i18n.json` (10 шт.) | `addRecipePhotoFromGallery`, `addRecipePhotoFromCamera`, `addRecipePhotoRequired`, `addRecipePhotoRemove`, `addRecipePhotoSourceTitle`, `addRecipePhotoErrorAccessDenied`, `addRecipePhotoErrorTooLarge`, `a11y.addRecipePhotoPicker` |
| ✅ | Docs | `otus_dz/docs/recipe-photo-upload.md` | этот файл |
| ✅ | Docs | `otus_dz/docs/add-recipe-feature.md` (§3.2, §9, §10) | секция «загрузка фото файлом» больше не вне рамок |

## 5. Что осознанно оставлено за рамками этой проработки

- **Cropping/rotate UI на клиенте** — отдельная UX-задача, не
  влияет на серверный контракт.
- **Multiple photos per recipe** — TheMealDB-shape допускает только
  один `strMealThumb`. Если понадобится галерея — нужна будет
  параллельная таблица `recipe_photos(recipe_id, url, sort_order)`,
  это отдельный шаг.
- **CDN перед storage-api** — у проекта есть imgproxy, его более
  чем достаточно для учебного MVP. CloudFront/Cloudflare не нужен.
- **EXIF-чистка / privacy** — для учебного MVP можно положиться на
  `image_picker` (он по умолчанию срезает геолокацию), серверное
  exif-strip через imgproxy включается флагом `IMGPROXY_STRIP_METADATA=1`.

## 6. Источники

- Существующая утилита загрузки:
  [`mahallem_ist/local_user_portal/utils/storage-upload.js`](../../mahallem_ist/local_user_portal/utils/storage-upload.js).
- Существующие buckets:
  [`mahallem_ist/local_docker_admin_backend/database/migrations/20251108_create_storage_buckets.sql`](../../mahallem_ist/local_docker_admin_backend/database/migrations/20251108_create_storage_buckets.sql).
- Compose-стек:
  [`mahallem_ist/local_docker_admin_backend/docker-compose.yml`](../../mahallem_ist/local_docker_admin_backend/docker-compose.yml)
  (см. сервисы `storage-api`, `storage`, `imgproxy`,
  `user-portal`).
- Пример рабочего multipart-апплоада:
  [`mahallem_ist/local_user_portal/routes/post-job.js`](../../mahallem_ist/local_user_portal/routes/post-job.js)
  (multer-конфиг + `uploadToStorage(file, 'job-photos', …)`).
- Сопроводительные документы:
  [`add-recipe-feature.md`](./add-recipe-feature.md),
  [`themealdb-add-recipe-investigation.md`](./themealdb-add-recipe-investigation.md).
