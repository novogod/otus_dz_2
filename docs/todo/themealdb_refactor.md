# TODO: рефакторинг `recipe_list` под TheMealDB

Цель: подключить `recipe_list` к публичному API `https://www.themealdb.com/api/json/v1/1` и переработать модель и карточку, чтобы вытащить максимум данных. Контракт `RecipeListPage(recipes: List<Recipe>)` сохраняем. Подробное обоснование — [docs/foodapi_alternative.md](docs/foodapi_alternative.md).

---

## 1. Зависимости

- [x] В [recipe_list/pubspec.yaml](recipe_list/pubspec.yaml) добавить:

  ```yaml
  dependencies:
    flutter:
      sdk: flutter
    dio: ^5.7.0
    url_launcher: ^6.3.0   # для перехода на YouTube/source-страницу
  ```

- [x] `cd recipe_list && flutter pub get`

## 2. Сетевые разрешения

- [x] [recipe_list/android/app/src/main/AndroidManifest.xml](recipe_list/android/app/src/main/AndroidManifest.xml) — добавить `<uses-permission android:name="android.permission.INTERNET"/>`.
- [x] `recipe_list/macos/Runner/DebugProfile.entitlements` и `Release.entitlements` — установить `com.apple.security.network.client = true`.
- [x] iOS — без правок (HTTPS).

## 3. Модель `Recipe`

Файл: [recipe_list/lib/models/recipe.dart](recipe_list/lib/models/recipe.dart)

- [x] Удалить поля `duration` и `description`.
- [x] Ввести новые поля: `category`, `area`, `tags: List<String>`, `instructions`, `ingredients: List<RecipeIngredient>`, `youtubeUrl?`, `sourceUrl?`.
- [x] Завести класс `RecipeIngredient { name, measure }`.
- [x] Реализовать `Recipe.fromMealDb(Map)` — парсит полный объект, собирает `ingredients` из `strIngredient1..20`/`strMeasure1..20`, разбивает `strTags` по запятой.
- [x] Реализовать `Recipe.fromMealDbLite(Map)` — только `id`, `name`, `photo` для ответов `filter.php`.
- [x] Обновить `==`/`hashCode` под новый набор полей.
- [x] `toJson` сделать симметричным к новой схеме (или удалить, если не используется).

## 4. Слой данных

Создать структуру:

```text
recipe_list/lib/data/
├── api/
│   ├── meal_db_client.dart
│   └── recipe_api.dart
└── recipe_manager.dart   ← удалить либо превратить в фасад
```

- [x] `meal_db_client.dart` — `Dio` с `baseUrl: 'https://www.themealdb.com/api/json/v1/1'`, таймауты 10 сек.
- [x] `recipe_api.dart` — методы:
  - `Future<List<Recipe>> searchByName({String query})` — `/search.php?s=`
  - `Future<List<Recipe>> filterByCategory(String category)` — `/filter.php?c=` (lite)
  - `Future<List<Recipe>> filterByArea(String area)` — `/filter.php?a=` (lite)
  - `Future<List<Recipe>> filterByIngredient(String ingredient)` — `/filter.php?i=` (lite)
  - `Future<Recipe> lookup(int id)` — `/lookup.php?i=`
  - `Future<Recipe> random()` — `/random.php`
  - `Future<List<MealCategory>> categories()` — `/categories.php` (опционально)
- [x] [recipe_list/lib/data/recipe_manager.dart](recipe_list/lib/data/recipe_manager.dart) — удалить, если в проекте не используется напрямую UI; иначе — фасад над `RecipeApi`.

## 5. Редизайн `RecipeCard`

Файл: [recipe_list/lib/ui/recipe_card.dart](recipe_list/lib/ui/recipe_card.dart). Карточка не финальная — переписываем под максимум данных TheMealDB.

- [x] Изображение `recipe.photo`, AspectRatio 16:9. URL дополнять суффиксом `/medium` для оптимизации трафика, fallback — оригинал.
- [x] Поверх изображения — индикатор YouTube (иконка play в правом нижнем углу), если `recipe.youtubeUrl != null`. По тапу — `url_launcher`.
- [x] Заголовок `recipe.name`, до 2 строк.
- [x] Бейдж `recipe.category` и бейдж `recipe.area` рядом, бренд-цвет `#2ECC71` для рамки, текст `#165932`.
- [x] Чипы тегов `recipe.tags`, до 3 штук, после — «+N» если больше.
- [x] Строка «N ингредиентов» (`recipe.ingredients.length`), скрывать, если `0` (lite-режим).
- [x] Lite-данные: если пусто `category`/`area`/`ingredients` — рендерить компактный вид (только фото и название).
- [x] Сохранить `onTap` и текущий `Material/InkWell` ripple.

## 6. UI: список и детали

- [x] [recipe_list/lib/ui/recipe_list_page.dart](recipe_list/lib/ui/recipe_list_page.dart): контракт `List<Recipe>` сохраняем; на тап lite-карточки догружать детали через `RecipeApi.lookup(recipe.id)` и пушить экран деталей.
- [x] (Опц.) Добавить `lib/ui/recipe_details_page.dart` с фото, категорией, кухней, тегами, инструкцией, ингредиентами, кнопками «Открыть на YouTube», «Источник». Это отдельная задача — не блокирует основной рефакторинг.
- [x] [recipe_list/lib/main.dart](recipe_list/lib/main.dart): обернуть `RecipeListPage` в `FutureBuilder<List<Recipe>>(future: RecipeApi().searchByName(query: 'a'), …)` с обработкой loading / error / empty.

## 7. Тесты

- [x] [recipe_list/test/recipe_test.dart](recipe_list/test/recipe_test.dart) — переписать под новый `Recipe`. Тесты:
  - `Recipe.fromMealDb` парсит полный объект (фикстура — реальный JSON `lookup.php?i=52772`, сокращённый).
  - `Recipe.fromMealDb` собирает только заполненные ингредиенты (пропуск пустых `strIngredient`).
  - `Recipe.fromMealDb` нормально парсит пустые `strTags`.
  - `Recipe.fromMealDbLite` заполняет только `id`/`name`/`photo`.
- [x] [recipe_list/test/recipe_card_test.dart](recipe_list/test/recipe_card_test.dart) — обновить фикстуры; добавить кейсы:
  - полный рецепт показывает категорию, кухню, теги, счётчик ингредиентов;
  - lite-рецепт показывает только фото и название;
  - тап вызывает `onTap`.
- [x] [recipe_list/test/recipe_list_page_test.dart](recipe_list/test/recipe_list_page_test.dart) — обновить фикстуры под новые поля.
- [x] [recipe_list/test/recipe_manager_test.dart](recipe_list/test/recipe_manager_test.dart) — удалить, если убираем `RecipeManager`.
- [x] Добавить `test/recipe_api_test.dart` — мок `Dio` через адаптер; проверить парсинг `/search.php`, `/filter.php`, `/lookup.php`.
- [x] Целевое состояние: `flutter analyze` — 0 issues, `flutter test` — 100% pass.

## 8. Контроль качества

- [x] `cd recipe_list && flutter analyze`
- [x] `cd recipe_list && flutter test`
- [x] Smoke-запуск:

  ```bash
  curl -s 'https://www.themealdb.com/api/json/v1/1/search.php?s=Arrabiata' | jq '.meals[0].strMeal'
  curl -s 'https://www.themealdb.com/api/json/v1/1/filter.php?c=Seafood' | jq '.meals | length'
  ```

- [x] Ручной запуск приложения на эмуляторе/симуляторе: список загружается, карточки показывают категорию/кухню/теги, фото грузятся.

## 9. Коммит

- [x] `git add -A`
- [x] `git commit -m "feat(recipe_list): integrate TheMealDB and redesign card"`
- [x] `git push origin main`

---

## Расширения (отдельными задачами)

- Экран деталей с инструкцией, списком ингредиентов с мерами, видео и источником.
- Поиск (`searchByName`) с `TextField` и debounce.
- Список категорий через `/categories.php` (горизонтальный скроллер сверху).
- Кэш ответов (`dio_cache_interceptor`) и оффлайн-режим.
- Параметризация `baseUrl` через `--dart-define`, чтобы переключаться между TheMealDB и `foodapi.dzolotov.tech`, когда последний наполнится.
