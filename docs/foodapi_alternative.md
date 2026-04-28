# Источник готовых рецептов: TheMealDB

Основной API курса ([docs/foodapi_dzolotov.md](docs/foodapi_dzolotov.md)) — пустая «песочница»: пока никто не залил рецепты, `GET /recipe` вернёт `[]`. Чтобы экран `RecipeListPage` сразу показывал реальные данные с фото, инструкциями и ингредиентами, подключаем публичный **TheMealDB**.

- Документация: <https://www.themealdb.com/api.php>
- Base URL: `https://www.themealdb.com/api/json/v1/1`
- Ключ: тестовый `1` (для разработки и учебных проектов; для публикации в сторах нужен платный апгрейд).
- Без авторизации, без CORS-ограничений.

---

## 1. Возможности и эндпоинты

### Полезные для нашего экрана

- `GET /search.php?s={name}` — поиск по названию (возвращает полные объекты `Meal`).
- `GET /search.php?f={letter}` — список блюд на букву.
- `GET /lookup.php?i={idMeal}` — полные детали одного блюда.
- `GET /random.php` — случайное блюдо (полный объект).
- `GET /filter.php?c={category}` — список по категории (**lite**: только `idMeal`, `strMeal`, `strMealThumb`).
- `GET /filter.php?a={area}` — по кухне.
- `GET /filter.php?i={ingredient}` — по основному ингредиенту.
- `GET /categories.php` — список категорий с описанием и иконкой.
- `GET /list.php?c=list` / `?a=list` / `?i=list` — справочники.

### Особенности

- Все ответы — JSON вида `{ "meals": [ ... ] }` или `{ "meals": null }`, если ничего не найдено.
- Поле длительности **отсутствует**.
- Ингредиенты лежат в плоских полях `strIngredient1..20` + `strMeasure1..20` — нужно собирать в список.
- Изображения поддерживают `?suffix`: `/preview`, `/small`, `/medium`, `/large` к URL `strMealThumb`.

---

## 2. Схема `Meal` (полный объект)

- `idMeal: string` — числовой id, но строкой
- `strMeal: string` — название
- `strDrinkAlternate: string?`
- `strCategory: string` — например, "Seafood"
- `strArea: string` — кухня (страна), "Italian"
- `strInstructions: string` — пошаговый текст, абзацы через `\r\n`
- `strMealThumb: string` — URL фото
- `strTags: string?` — теги через запятую: `"Pasta,Curry"`
- `strYoutube: string?` — ссылка на YouTube
- `strSource: string?` — ссылка на оригинальный рецепт
- `strImageSource: string?`
- `strCreativeCommonsConfirmed: string?`
- `dateModified: string?`
- `strIngredient1..20: string?` — ингредиент
- `strMeasure1..20: string?` — мера ("1 cup", "2 tbsp")

«Lite»-объект из `filter.php` содержит только `idMeal`, `strMeal`, `strMealThumb`.

### Пример (`/lookup.php?i=52772`, сокращённо)

```json
{
  "meals": [
    {
      "idMeal": "52772",
      "strMeal": "Teriyaki Chicken Casserole",
      "strCategory": "Chicken",
      "strArea": "Japanese",
      "strInstructions": "Preheat oven to 350°F...",
      "strMealThumb": "https://www.themealdb.com/images/media/meals/wvpsxx1468256321.jpg",
      "strTags": "Meat,Casserole",
      "strYoutube": "https://www.youtube.com/watch?v=4aZr5hZXP_s",
      "strIngredient1": "soy sauce",
      "strMeasure1": "3/4 cup"
    }
  ]
}
```

---

## 3. Сопоставление с локальной моделью `Recipe`

Карточка [recipe_list/lib/ui/recipe_card.dart](recipe_list/lib/ui/recipe_card.dart) **будет переработана** под максимум данных TheMealDB. Текущая модель в [recipe_list/lib/models/recipe.dart](recipe_list/lib/models/recipe.dart) устарела (`duration`, `description`).

### Новая локальная модель

```dart
class Recipe {
  final int id;            // int.parse(idMeal)
  final String name;       // strMeal
  final String photo;      // strMealThumb
  final String category;   // strCategory
  final String area;       // strArea
  final List<String> tags; // strTags split by ","
  final String instructions;        // strInstructions (для деталей)
  final List<RecipeIngredient> ingredients; // собирается из strIngredientN/strMeasureN
  final String? youtubeUrl; // strYoutube
  final String? sourceUrl;  // strSource

  const Recipe({
    required this.id,
    required this.name,
    required this.photo,
    required this.category,
    required this.area,
    this.tags = const [],
    this.instructions = '',
    this.ingredients = const [],
    this.youtubeUrl,
    this.sourceUrl,
  });

  factory Recipe.fromMealDb(Map<String, dynamic> j) {
    final ingredients = <RecipeIngredient>[];
    for (var i = 1; i <= 20; i++) {
      final name = (j['strIngredient$i'] as String?)?.trim() ?? '';
      final measure = (j['strMeasure$i'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      ingredients.add(RecipeIngredient(name: name, measure: measure));
    }
    final rawTags = (j['strTags'] as String?)?.trim() ?? '';
    return Recipe(
      id: int.parse(j['idMeal'] as String),
      name: j['strMeal'] as String? ?? '',
      photo: j['strMealThumb'] as String? ?? '',
      category: j['strCategory'] as String? ?? '',
      area: j['strArea'] as String? ?? '',
      tags: rawTags.isEmpty
          ? const []
          : rawTags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      instructions: j['strInstructions'] as String? ?? '',
      ingredients: ingredients,
      youtubeUrl: (j['strYoutube'] as String?)?.trim().isEmpty == false
          ? j['strYoutube'] as String
          : null,
      sourceUrl: (j['strSource'] as String?)?.trim().isEmpty == false
          ? j['strSource'] as String
          : null,
    );
  }
}

class RecipeIngredient {
  final String name;
  final String measure;
  const RecipeIngredient({required this.name, required this.measure});
}
```

«Lite» вариант для `filter.php` (без категории/инструкций) собирается отдельной фабрикой `Recipe.fromMealDbLite` — заполняем только `id`, `name`, `photo`.

---

## 4. Редизайн `RecipeCard` под TheMealDB

Карточка должна вытягивать максимум доступной информации. Ориентировочный состав ячейки списка:

- Фото (`strMealThumb` через `/medium`-suffix для оптимизации трафика).
- Название (`strMeal`), 2 строки максимум.
- Бейдж категории (`strCategory`) + бейдж кухни/страны (`strArea`). Можно вывести флаг страны эмодзи только если потребуется (по умолчанию — текстом).
- Чипы тегов (`strTags`), до 3 штук, остальное скрывается.
- Счётчик ингредиентов: «N ингредиентов».
- Кнопка/иконка «play» поверх фото, если есть `strYoutube`.

Структура:

```text
+--------------------------------------------------+
| [ Image 16:9 ]                          [ play ] |
|                                                  |
| Teriyaki Chicken Casserole                       |
| [Chicken]  [Japanese]                            |
| #Meat  #Casserole                                |
| 9 ингредиентов                                   |
+--------------------------------------------------+
```

Ширина бейджей и чипов фиксированная по высоте, шрифты — из текущей темы Material 3, бренд-цвета из `main.dart` (`#2ECC71` / `#165932`) сохраняем.

«Lite» данные с `filter.php` дают только фото и название — в этом случае часть UI скрывается (`if (recipe.category.isNotEmpty) ...`).

---

## 5. Слой данных

```text
recipe_list/lib/data/
├── api/
│   ├── meal_db_client.dart  // Dio + baseUrl
│   └── recipe_api.dart      // методы поиска/листинга/детали
└── recipe_manager.dart      // удалить или превратить в фасад
```

### `meal_db_client.dart`

```dart
import 'package:dio/dio.dart';

class MealDbClient {
  static const String baseUrl = 'https://www.themealdb.com/api/json/v1/1';

  final Dio dio;

  MealDbClient([Dio? injected])
      : dio = injected ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));
}
```

### `recipe_api.dart`

```dart
import '../../models/recipe.dart';
import 'meal_db_client.dart';

class RecipeApi {
  final MealDbClient client;
  RecipeApi([MealDbClient? c]) : client = c ?? MealDbClient();

  /// Полные объекты по запросу. Если запрос пустой — берём 'a' как сид.
  Future<List<Recipe>> searchByName({String query = 'a'}) async {
    final res = await client.dio.get<Map<String, dynamic>>(
      '/search.php',
      queryParameters: {'s': query},
    );
    final list = (res.data?['meals'] as List?) ?? const [];
    return list
        .cast<Map<String, dynamic>>()
        .map(Recipe.fromMealDb)
        .toList(growable: false);
  }

  /// Lite-список по категории (только id/name/photo).
  Future<List<Recipe>> filterByCategory(String category) async {
    final res = await client.dio.get<Map<String, dynamic>>(
      '/filter.php',
      queryParameters: {'c': category},
    );
    final list = (res.data?['meals'] as List?) ?? const [];
    return list
        .cast<Map<String, dynamic>>()
        .map(Recipe.fromMealDbLite)
        .toList(growable: false);
  }

  Future<Recipe> lookup(int id) async {
    final res = await client.dio.get<Map<String, dynamic>>(
      '/lookup.php',
      queryParameters: {'i': id},
    );
    final list = (res.data?['meals'] as List?) ?? const [];
    if (list.isEmpty) throw StateError('Meal $id not found');
    return Recipe.fromMealDb(list.first as Map<String, dynamic>);
  }

  Future<Recipe> random() async {
    final res = await client.dio.get<Map<String, dynamic>>('/random.php');
    final list = (res.data?['meals'] as List?) ?? const [];
    return Recipe.fromMealDb(list.first as Map<String, dynamic>);
  }
}
```

---

## 6. Подключение к `RecipeListPage`

[recipe_list/lib/ui/recipe_list_page.dart](recipe_list/lib/ui/recipe_list_page.dart) принимает `List<Recipe>`. В [recipe_list/lib/main.dart](recipe_list/lib/main.dart):

```dart
home: FutureBuilder<List<Recipe>>(
  future: RecipeApi().searchByName(query: 'a'),
  builder: (context, snap) {
    if (snap.connectionState != ConnectionState.done) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (snap.hasError) {
      return Scaffold(body: Center(child: Text('Ошибка: ${snap.error}')));
    }
    return RecipeListPage(recipes: snap.data ?? const []);
  },
),
```

Альтернатива: загрузить категорию через `filterByCategory('Seafood')`. В этом случае при тапе на карточку нужно догружать детали через `lookup(id)`.

---

## 7. Сетевые разрешения

- **Android**: `<uses-permission android:name="android.permission.INTERNET"/>` в [recipe_list/android/app/src/main/AndroidManifest.xml](recipe_list/android/app/src/main/AndroidManifest.xml).
- **iOS**: HTTPS, правок не нужно.
- **macOS**: `com.apple.security.network.client` = `true` в `DebugProfile.entitlements` и `Release.entitlements`.

---

## 8. Smoke-проверки

```bash
curl -s 'https://www.themealdb.com/api/json/v1/1/search.php?s=Arrabiata' | jq '.meals[0] | {idMeal,strMeal,strCategory,strArea,strTags,strMealThumb}'
curl -s 'https://www.themealdb.com/api/json/v1/1/filter.php?c=Seafood' | jq '.meals | length'
curl -s 'https://www.themealdb.com/api/json/v1/1/lookup.php?i=52772' | jq '.meals[0].strInstructions[:120]'
```

---

## 9. Стратегия переключения на foodapi.dzolotov.tech

Контракт `RecipeApi.searchByName/filterByCategory/lookup`-`Future<List<Recipe>>` — единственная точка коммуникации со списком/деталью. Когда курсовой API наполнится, достаточно:

1. Поменять `MealDbClient` на `FoodApiClient` (другой `baseUrl`).
2. Добавить альтернативную фабрику `Recipe.fromDzolotovJson` под укороченную схему (`id`, `name`, `duration`, `photo`).
3. UI и тесты остаются прежними.
