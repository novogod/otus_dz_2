# Редактирование и удаление пользовательских рецептов + бэкап в mahallem

Документ описывает фичу «владелец рецепта может его отредактировать или
удалить» и связанную с ней инфраструктуру резервного копирования на
сервере `mahallem_ist`, без которой пользовательские записи не пережили
бы периодический `go-clean` (`docker compose down -v` + полная
пересборка из git).

Релевантные коммиты:

- Flutter (`otus_dz_2`, ветка `main`): `72f595f`
- Backend (`mahallem_ist`, ветка `main`):
  - `88074a61` — `PUT`/`DELETE /recipes/:id`
  - `d45c8c2b` — `RECIPES_USER_MEAL_ID_FLOOR` в `docker-compose.yml`
  - `ca7d3b04` — бэкап/рестор пользовательских рецептов

## 1. UX

На `RecipeDetailsPage` в левом верхнем углу фотографии рецепта
показываются две круглые кнопки на чёрной полупрозрачной подложке:

| Иконка    | Действие                                               |
|-----------|--------------------------------------------------------|
| 🗑 (trash)| Подтверждение через `AlertDialog` → удаление          |
| ✏ (edit)  | Открыть `AddRecipePage` в режиме редактирования       |

Кнопки видны **только** если `recipe.id` присутствует в локальной
таблице `owned_recipes`, то есть рецепт был создан с этого устройства.
Чужие рецепты (как из TheMealDB, так и созданные другими
пользователями) остаются в режиме read-only.

### Сценарий редактирования

1. Тап по карандашу → `Navigator.push(AddRecipePage(existing: recipe))`.
2. Поля формы предзаполняются: имя, фото, категория, регион,
   инструкции, ингредиенты (`measure` уходит в поле unit, qty пусто —
   так совпадает со схемой добавления).
3. На «Сохранить»: `RecipeApi.updateRecipeWithPhoto(...)` (multipart
   `PUT /recipes/:id`) либо `updateRecipe(...)` (JSON `PUT`).
4. После успеха:
   - локальный кэш чистится по id (`RecipeRepository.deleteById`,
     триггер `trg_recipes_after_delete` каскадирует `recipe_bodies`);
   - вставляются новые локали (`upsertAll`);
   - эмитится `recipeUpdatedNotifier.value = recipe`;
   - `RecipeListPage` и `FavoritesPage` обновляют свою копию рецепта
     по id, `RecipeDetailsPage` — через свой listener.

### Сценарий удаления

1. Тап по корзине → `AlertDialog` «Delete recipe?».
2. После подтверждения:
   - `RecipeApi.deleteRecipe(id)` → `DELETE /recipes/:id`.
   - `RecipeRepository.deleteById(id)` чистит локальный кэш.
   - `FavoritesStore.removeAcrossLangs(id)` снимает рецепт со всех
     языковых партиций избранного.
   - `OwnedRecipesStore.remove(id)` убирает id из набора владельца.
   - `recipeDeletedNotifier.value = id` — сигнал всем экранам.
   - `Navigator.pop()` — выходим со страницы деталей.
3. `RecipeListPage` фильтрует свой `_displayed`, `FavoritesPage`
   перестраивает `FutureBuilder`.

## 2. Архитектура (Flutter)

### Локальная таблица `owned_recipes`

Миграция схемы sqflite `v6 → v7`:

```sql
CREATE TABLE owned_recipes (
  id         INTEGER PRIMARY KEY,
  created_at INTEGER NOT NULL
);
```

Запись вставляется в `AddRecipePage._save()` сразу после успешного
создания рецепта на бэкенде, до перехода обратно к списку.

### `OwnedRecipesStore`

`lib/data/repository/owned_recipes_store.dart` — синглтон,
хранящийся в `ownedRecipesStoreNotifier: ValueNotifier<OwnedRecipesStore?>`.
Поднимается из `RecipeListLoader._defaultRepoBuilder` после
`FavoritesStore`. Внутри `ValueNotifier<Set<int>> ids` — на этот сет
подписан `_OwnerActions` в `RecipeDetailsPage`.

### Шина событий рецептов

`lib/data/recipe_events.dart`:

- `newRecipeCreatedNotifier: ValueNotifier<Recipe?>` (был раньше)
- `recipeDeletedNotifier:    ValueNotifier<int?>`
- `recipeUpdatedNotifier:    ValueNotifier<Recipe?>`

Подписчики:

| Notifier                  | Слушают                                  |
|---------------------------|------------------------------------------|
| `recipeDeletedNotifier`   | RecipeListPage, FavoritesPage, others    |
| `recipeUpdatedNotifier`   | RecipeListPage, FavoritesPage, RecipeDetailsPage |

### `RecipeApi`

Три новых метода в `lib/data/api/recipe_api.dart`:

- `updateRecipe(Recipe draft)` — `PUT /recipes/:id` JSON.
- `updateRecipeWithPhoto(Recipe draft, File? photo)` — multipart `PUT`,
  откатывается на JSON, если фото не выбрано.
- `deleteRecipe(int id)` — `DELETE /recipes/:id`.

Все три бросают `StateError`, если backend не `mahallem` (на
TheMealDB этих ручек нет).

## 3. Backend (`mahallem_ist`)

### Маршруты

`local_user_portal/routes/recipes.js`:

- `PUT /recipes/:id` — multipart или JSON. Парсит `meal`, валидирует
  через тот же канонизатор, что и `POST`. На multipart-пути после
  `repo.updateUserMeal` грузит фото в bucket `recipe-photos` по ключу
  `recipes/<id>/photo_<ts>_<rand>.<ext>` и патчит `strMealThumb`.
- `DELETE /recipes/:id` — `204` если строка удалена.

Repo-методы `RecipeRepository.updateUserMeal` и `deleteUserMeal`
содержат floor-id guard:

```sql
WHERE id = $1 AND id >= $2  -- $2 = RECIPES_USER_MEAL_ID_FLOOR
```

То есть редактировать или удалять рецепты TheMealDB через эти ручки
нельзя — клиент получит `404`/`forbidden_id`.

### Переменная окружения

`local_docker_admin_backend/docker-compose.yml`:

```yaml
RECIPES_USER_MEAL_ID_FLOOR: ${RECIPES_USER_MEAL_ID_FLOOR:-1000000}
```

Это значение используется и в Postgres-сиквенсе `recipes_id_seq`
(стартовое значение `1_000_000`), и в guard'ах PUT/DELETE.

## 4. Резервное копирование (выживание `go-clean`)

`mahallem_ist` периодически выполняет `go-clean`:
`docker compose down -v && docker compose up --build -d`. Всё, чего
нет в git и в `/app/backups/` (bind-mount на хост
`/root/mahallem/mahallem_ist/backups/`), пропадает. Поэтому
пользовательские рецепты должны иметь явные хуки бэкапа и
обработчики восстановления — точно так же, как `users`, `jobs`,
`reviews`, `wallets` и т. п.

Архитектура бэкапа в `mahallem` двухуровневая:

1. **Realtime JSONL** — в `/app/backups/realtime/<table>.jsonl`
   дописывается строка на каждое создание/обновление/удаление.
   Восстанавливается админом при старте.
2. **Снапшоты раз в 3 часа** — `tar.gz` со всей нужной БД и файлами,
   складываются отдельно от контейнеров. Создаются
   `snapshot-export-service.js` в admin-контейнере.

### 4.1 Realtime: `backupRecipe`

`local_user_portal/utils/backup-service.js` — добавлена функция:

```js
export async function backupRecipe(recipe, action = 'create') {
  if (!recipe || recipe.id == null) return;
  const floor = Number(process.env.RECIPES_USER_MEAL_ID_FLOOR || 1_000_000);
  if (Number(recipe.id) < floor) return; // TheMealDB не бэкапим
  await backupRecord('recipes', recipe, action);
}
```

Вызывается из `routes/recipes.js`:

| Эндпоинт                 | Action     |
|--------------------------|------------|
| `POST /recipes` (success)| `'create'` |
| `PUT  /recipes/:id`      | `'update'` |
| `DELETE /recipes/:id`    | `'delete'` |

Все вызовы fire-and-forget с `console.error` в catch — провал
бэкапа не должен ломать пользовательский запрос.

В `/app/backups/realtime/recipes.jsonl` пишутся строки вида:

```json
{"timestamp":"2026-04-30T...","action":"create","table":"recipes","data":{"id":1000042,"i18n":{...},"category":"...","area":"..."}}
```

Файлы фотографий уже бэкапились существующей `backupRecipePhotoFile`
(дерево `/app/backups/recipe_photos/recipes/<id>/<file>`).

### 4.2 Restore: `restoreRecipes` + `restoreRecipePhotos`

`local_docker_admin_backend/frontend-admin/utils/restore-service.js`:

- `restoreRecipes(executeQuery)` — приватная, по образцу
  `restoreReviews`. Читает `recipes.jsonl`, прогоняет через
  `parseLogFile` + `deduplicateLog` (стейт-машина create/update/delete
  по timestamp), затем для каждой записи делает `SELECT id`, после
  чего `UPDATE` или `INSERT`. `i18n` сериализуется в JSONB через
  `$2::jsonb`.
- `restoreRecipePhotos()` — экспортируется, по образцу
  `restoreJobPhotos`. Рекурсивно обходит
  `/app/backups/recipe_photos/`, заливает каждый
  `.jpg/.jpeg/.png/.webp` в bucket `recipe-photos` через
  `uploadFile(...)`.

Обе подключены в `restoreAll(executeQuery)` после
`restoreTranslationSuggestions` и `restoreJobPhotos` соответственно,
а также добавлены в `default export`.

### 4.3 Снапшоты раз в 3 часа

`exportStorageObjects` в `snapshot-export-service.js` теперь включает
bucket `recipe-photos`, чтобы метаданные `storage.objects` для фото
рецептов попадали в `tar.gz`:

```js
WHERE bucket_id IN ('avatars', 'job-photos', 'recipe-photos')
```

Сами строки таблицы `recipes` восстанавливаются в первую очередь из
realtime JSONL — это предсказуемее, чем экспорт всей таблицы (которая
включает и кэшированные TheMealDB-записи).

## 5. Поток данных «как пережить go-clean»

```
Пользователь → POST/PUT/DELETE /recipes
  → Postgres (recipes)               ← теряется при go-clean
  → /app/backups/realtime/recipes.jsonl  ← на хосте, переживает
  → /app/backups/recipe_photos/...       ← на хосте, переживает
  → /app/backups/realtime/storage_objects.jsonl ← уже было

go-clean → docker compose down -v && up --build -d
  → пустой Postgres, пустой storage-api

Старт админ-контейнера → restoreAll(executeQuery):
  ... users, jobs, reviews, ...
  restoreRecipes()         ← вставляет строки обратно
  ... avatars, job photos
  restoreRecipePhotos()    ← заливает файлы в bucket recipe-photos
```

## 6. Что проверять при ревью

- В `routes/recipes.js` все три обработчика (POST/PUT/DELETE) на путях
  как multipart, так и JSON, заканчиваются вызовом `backupRecipe(...)`
  до `res.send(...)`/`res.status(...)`.
- В `restoreAll` порядок зависимостей: `restoreRecipes` после `users`
  не нужен (FK нет), но **до** `restoreRecipePhotos` рекомендуется
  не ставить — фото идут параллельно метаданным `storage.objects`.
- `RECIPES_USER_MEAL_ID_FLOOR` совпадает между:
  - `docker-compose.yml`,
  - стартовым значением sequence `recipes_id_seq` в инициализационных
    SQL,
  - guard'ами в `RecipeRepository.updateUserMeal/deleteUserMeal`.
- На клиенте `OwnedRecipesStore` не сетится для рецептов, импортированных
  из других источников (например, через share-ссылку), — иначе у юзера
  появятся owner-кнопки на рецепте, которым он не владеет на бэкенде, и
  PUT/DELETE вернёт `404 forbidden_id`.
