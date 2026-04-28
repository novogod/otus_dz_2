# Food API — интеграция в `recipe_list`

Документация по работе с публичным **Food API** автора курса (Дмитрий Золотов) и по приведению локальных моделей и UI к схемам OpenAPI.

- Spec: <https://app.swaggerhub.com/apis/dzolotov/foodapi/0.2.0>
- OpenAPI 3.0.0, версия `0.2.0`
- **Base URL**: `https://foodapi.dzolotov.tech`
- Формат: `application/json` (UTF-8)
- Авторизация: для чтения списка рецептов **не требуется**. Для пользовательских действий (`/favorite`, `/comment`, `/freezer`) используется JWT-токен из `PUT /user`.

---

## 1. Схемы API (что есть на сервере)

Условные обозначения: `(ro)` — read-only массив, заполняется сервером, в запросах не отправляется. Вложенные ссылки сериализуются как `{"id": 42}` — это только идентификатор, полные данные тянутся отдельным запросом.

### `Recipe` — **основная сущность**

- `id: int`
- `name: string`
- `duration: int` — минуты
- `photo: string` — URL
- `recipeIngredients: RecipeIngredient[]` (ro)
- `recipeStepLinks: RecipeStepLink[]` (ro)
- `favoriteRecipes: Favorite[]` (ro)
- `comments: Comment[]` (ro)

> ⚠️ Поля `description` в схеме **нет**.

### `RecipeStep` — шаг приготовления

- `id: int`
- `name: string`
- `duration: int`
- `recipeStepLinks: RecipeStepLink[]` (ro)

### `RecipeStepLink` — связь «рецепт → шаг» с порядком

- `id: int`
- `number: int` — порядковый номер шага
- `recipe: { id }`
- `step: { id }`

### `Ingredient`

- `id: int`
- `name: string`
- `caloriesForUnit: number`
- `measureUnit: { id }`
- `recipeIngredients: RecipeIngredient[]` (ro)
- `ingredientFreezer: Freezer[]` (ro)

### `RecipeIngredient` — ингредиент в составе рецепта

- `id: int`
- `count: int`
- `recipe: { id }`
- `ingredient: { id }`

### `MeasureUnit` — единица измерения с формами множественного числа

- `id: int`
- `one: string` — «1 ложка»
- `few: string` — «2 ложки»
- `many: string` — «5 ложек»
- `ingredients: Ingredient[]` (ro)

### `Comment`

- `id: int`
- `text: string`
- `photo: string`
- `datetime: string` (date-time)
- `user: { id }`
- `recipe: { id }`

### `Favorite`

- `id: int`
- `recipe: { id }`
- `user: { id }`

### `Freezer` — «холодильник» пользователя

- `id: int`
- `count: number`
- `user: { id }`
- `ingredient: { id }`

### `User`

- `id: int`
- `login: string`
- `password: string`
- `token: string`
- `avatar: string`
- `userFreezer: Freezer[]` (ro)
- `favoriteRecipes: Favorite[]` (ro)
- `comments: Comment[]` (ro)

### Вспомогательные

- `Status { status: string }`
- `Error  { error: string }`
- `Token  { token: string }`

### Пример `GET /recipe` (один элемент)

```json
{
  "id": 1,
  "name": "Лазанья",
  "duration": 60,
  "photo": "https://foodapi.dzolotov.tech/static/lasagna.jpg"
}
```

---

## 2. Сравнение: локальные модели ↔ API

### 2.1. `Recipe` ([recipe_list/lib/models/recipe.dart](recipe_list/lib/models/recipe.dart))

- `id: int` ↔ `id: int` — ✅ совпадает
- `name: String` ↔ `name: string` — ✅ совпадает
- `duration: int` ↔ `duration: int` — ✅ совпадает (минуты)
- `photo: String` ↔ `photo: string` — ⚠️ может прийти пустая строка / `null` → добавить `?? ''` в `fromJson`
- `description: String` ↔ **нет в API** — ❌ удалить из модели
- — ↔ `recipeIngredients[]` — ➕ добавить опционально как `List<RecipeIngredientRef>`
- — ↔ `recipeStepLinks[]` — ➕ добавить опционально как `List<RecipeStepLinkRef>`

### 2.2. `RecipeCard` ([recipe_list/lib/ui/recipe_card.dart](recipe_list/lib/ui/recipe_card.dart))

Карточка уже отображает **только** `photo`, `name`, `duration` — то есть на 100% совпадает с полями API. **Изменений не требуется.**

Если позже захочется показывать «N ингредиентов» или калории — нужны два дополнительных запроса (`/recipe_ingredient?recipe.id=…` + `/ingredient/{id}`).

### 2.3. `RecipeManager` ([recipe_list/lib/data/recipe_manager.dart](recipe_list/lib/data/recipe_manager.dart))

Сейчас возвращает константный список. После интеграции:

- стать тонким фасадом над `RecipeApi`, или
- быть удалённым полностью, а `RecipeListPage` напрямую получать `RecipeApi`.

### 2.4. Тесты

- [recipe_list/test/recipe_test.dart](recipe_list/test/recipe_test.dart) — убрать `description` из ожиданий `fromJson`.
- [recipe_list/test/recipe_card_test.dart](recipe_list/test/recipe_card_test.dart) — фикстуры обновить (убрать `description`).
- [recipe_list/test/recipe_manager_test.dart](recipe_list/test/recipe_manager_test.dart) — основан на типе `Future<List<Recipe>>`, останется зелёным.
- [recipe_list/test/recipe_list_page_test.dart](recipe_list/test/recipe_list_page_test.dart) — фикстуры обновить.

---

## 3. Рекомендуемая итоговая модель

```dart
// lib/models/recipe.dart
class Recipe {
  final int id;
  final String name;
  final int duration; // минуты
  final String photo;

  /// Рендерится только если сервер прислал nested-массив (read-only).
  /// На странице списка обычно пуст.
  final List<RecipeIngredientRef> recipeIngredients;
  final List<RecipeStepLinkRef> recipeStepLinks;

  const Recipe({
    required this.id,
    required this.name,
    required this.duration,
    required this.photo,
    this.recipeIngredients = const [],
    this.recipeStepLinks = const [],
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        duration: json['duration'] as int? ?? 0,
        photo: json['photo'] as String? ?? '',
        recipeIngredients: (json['recipeIngredients'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(RecipeIngredientRef.fromJson)
                .toList() ??
            const [],
        recipeStepLinks: (json['recipeStepLinks'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(RecipeStepLinkRef.fromJson)
                .toList() ??
            const [],
      );

  /// Только writable-поля — read-only массивы сервер игнорирует.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'duration': duration,
        'photo': photo,
      };
}

class RecipeIngredientRef {
  final int id;
  final int count;
  final int ingredientId;
  const RecipeIngredientRef({
    required this.id,
    required this.count,
    required this.ingredientId,
  });
  factory RecipeIngredientRef.fromJson(Map<String, dynamic> j) =>
      RecipeIngredientRef(
        id: j['id'] as int,
        count: j['count'] as int? ?? 0,
        ingredientId: (j['ingredient'] as Map<String, dynamic>?)?['id'] as int? ?? 0,
      );
}

class RecipeStepLinkRef {
  final int id;
  final int number;
  final int stepId;
  const RecipeStepLinkRef({
    required this.id,
    required this.number,
    required this.stepId,
  });
  factory RecipeStepLinkRef.fromJson(Map<String, dynamic> j) =>
      RecipeStepLinkRef(
        id: j['id'] as int,
        number: j['number'] as int? ?? 0,
        stepId: (j['step'] as Map<String, dynamic>?)?['id'] as int? ?? 0,
      );
}
```

---

## 4. Эндпоинты для текущего экрана

| Метод | Путь | Что делает |
|---|---|---|
| `GET` | `/recipe` | Список (для `RecipeListPage`) |
| `GET` | `/recipe/{id}` | Детали |
| `POST` | `/recipe` | Создать (тело — `Recipe`-схема) |
| `PUT` | `/recipe/{id}` | Обновить |
| `DELETE` | `/recipe/{id}` | Удалить |

Параметры `GET /recipe`: `count`, `offset`, `pageBy`, `pageAfter`, `pagePrior`, `sortBy[]`. Коды: `200`, `400`, `404`, `409`.

---

## 5. План интеграции

### 5.1. Зависимости в [recipe_list/pubspec.yaml](recipe_list/pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.7.0
```

```bash
cd recipe_list && flutter pub get
```

### 5.2. Слои

```
lib/
├── data/
│   ├── api/
│   │   ├── food_api_client.dart   # Dio + base URL
│   │   └── recipe_api.dart        # CRUD /recipe
│   └── recipe_manager.dart        # фасад (или удалить)
├── models/
│   └── recipe.dart                # см. §3
└── ui/
    ├── recipe_card.dart           # без изменений
    └── recipe_list_page.dart      # подключение FutureBuilder
```

### 5.3. HTTP-клиент

`lib/data/api/food_api_client.dart`:

```dart
import 'package:dio/dio.dart';

class FoodApiClient {
  static const String baseUrl = 'https://foodapi.dzolotov.tech';

  final Dio dio;

  FoodApiClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {'Content-Type': 'application/json'},
          ),
        );
}
```

### 5.4. `RecipeApi`

`lib/data/api/recipe_api.dart`:

```dart
import '../../models/recipe.dart';
import 'food_api_client.dart';

class RecipeApi {
  final FoodApiClient client;
  RecipeApi(this.client);

  Future<List<Recipe>> fetchAll({int? count, int? offset}) async {
    final response = await client.dio.get<List<dynamic>>(
      '/recipe',
      queryParameters: {
        if (count != null) 'count': count,
        if (offset != null) 'offset': offset,
      },
    );
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Recipe.fromJson)
        .toList(growable: false);
  }

  Future<Recipe> fetchById(int id) async {
    final res = await client.dio.get<Map<String, dynamic>>('/recipe/$id');
    return Recipe.fromJson(res.data!);
  }

  Future<Recipe> create(Recipe recipe) async {
    final res = await client.dio.post<Map<String, dynamic>>(
      '/recipe',
      data: recipe.toJson(),
    );
    return Recipe.fromJson(res.data!);
  }

  Future<Recipe> update(Recipe recipe) async {
    final res = await client.dio.put<Map<String, dynamic>>(
      '/recipe/${recipe.id}',
      data: recipe.toJson(),
    );
    return Recipe.fromJson(res.data!);
  }

  Future<void> delete(int id) => client.dio.delete<void>('/recipe/$id');
}
```

### 5.5. Подключение к `RecipeListPage`

[recipe_list/lib/ui/recipe_list_page.dart](recipe_list/lib/ui/recipe_list_page.dart) — два варианта:

**Вариант A — грузить в родителе, страница остаётся `Stateless`:**

```dart
// lib/main.dart
home: FutureBuilder<List<Recipe>>(
  future: RecipeApi(FoodApiClient()).fetchAll(),
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

**Вариант B — страница `Stateful` + pull-to-refresh:**

```dart
class _RecipeListPageState extends State<RecipeListPage> {
  late Future<List<Recipe>> _future;
  final _api = RecipeApi(FoodApiClient());

  @override
  void initState() {
    super.initState();
    _future = _api.fetchAll();
  }

  Future<void> _refresh() async {
    setState(() => _future = _api.fetchAll());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Рецепты'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Recipe>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Ошибка: ${snap.error}'));
            }
            final items = snap.data ?? const <Recipe>[];
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) => RecipeCard(recipe: items[i]),
            );
          },
        ),
      ),
    );
  }
}
```

### 5.6. `POST /recipe`

```dart
final created = await RecipeApi(FoodApiClient()).create(
  const Recipe(
    id: 0, // сервер присвоит свой
    name: 'Тыквенный крем-суп',
    duration: 30,
    photo: 'https://example.com/pumpkin.jpg',
  ),
);
```

`409 Conflict` → объект с такой парой полей уже существует.

---

## 6. Сетевые разрешения

### Android — [recipe_list/android/app/src/main/AndroidManifest.xml](recipe_list/android/app/src/main/AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### iOS — без правок (HTTPS).

### macOS — `recipe_list/macos/Runner/DebugProfile.entitlements` и `Release.entitlements`:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

---

## 7. Тестирование

- Юнит-тесты: подменять `Dio` через `dio_test_adapter` или передавать `RecipeApi` через DI.
- Smoke-проверка через curl:

```bash
curl https://foodapi.dzolotov.tech/recipe | jq '.[0]'
curl https://foodapi.dzolotov.tech/recipe/1 | jq
```

---

## 8. Чек-лист изменений

- [ ] Удалить `description` из `Recipe`, обновить `fromJson`/`toJson`.
- [ ] (Опц.) Добавить `RecipeIngredientRef`, `RecipeStepLinkRef`.
- [ ] Обновить фикстуры в 4 тестах — убрать `description`.
- [ ] Убрать `description` из `RecipeManager._recipes` (либо удалить менеджер).
- [ ] Добавить `dio` в pubspec, запустить `pub get`.
- [ ] Создать `FoodApiClient` и `RecipeApi`.
- [ ] Подключить к `RecipeListPage` через `FutureBuilder`.
- [ ] Включить `INTERNET` и macOS network entitlement.
- [ ] `flutter analyze` + `flutter test` — должно остаться зелёным.

---

## 9. Что дальше

1. Экран детали рецепта → `GET /recipe/{id}` + `GET /recipe_step` + `GET /recipe_step_link`.
2. Список ингредиентов → `GET /recipe_ingredient` + `GET /ingredient` + `GET /measure_unit` (для склонения через `one/few/many`).
3. Авторизация (`POST /user`, `PUT /user`) — для `/favorite`, `/comment`, `/freezer`.
