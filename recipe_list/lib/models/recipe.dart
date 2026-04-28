/// Модель рецепта под TheMealDB
/// (https://www.themealdb.com/api/json/v1/1).
///
/// Эндпоинты возвращают данные двух «уровней детализации»:
///
/// * полные (`/search.php`, `/lookup.php`, `/random.php`) — содержат
///   все поля включая ингредиенты, инструкции, теги и видео;
/// * lite (`/filter.php?...`) — только `idMeal`, `strMeal`, `strMealThumb`.
///
/// Соответственно, [Recipe.fromMealDb] парсит полный объект,
/// а [Recipe.fromMealDbLite] — короткий.
class Recipe {
  final int id;
  final String name;

  /// URL фотографии (`strMealThumb`).
  final String photo;

  /// Категория блюда (`strCategory`), напр. «Seafood».
  final String? category;

  /// Кухня (`strArea`), напр. «Italian».
  final String? area;

  /// Список тегов (`strTags`, csv). Пустой, если не задан.
  final List<String> tags;

  /// Текст инструкции (`strInstructions`).
  final String? instructions;

  /// Ингредиенты с мерами (`strIngredient1..20` + `strMeasure1..20`,
  /// пропускаются пустые).
  final List<RecipeIngredient> ingredients;

  /// Ссылка на YouTube-видео (`strYoutube`), если задана.
  final String? youtubeUrl;

  /// Ссылка на исходный сайт (`strSource`), если задана.
  final String? sourceUrl;

  const Recipe({
    required this.id,
    required this.name,
    required this.photo,
    this.category,
    this.area,
    this.tags = const [],
    this.instructions,
    this.ingredients = const [],
    this.youtubeUrl,
    this.sourceUrl,
  });

  /// `true`, если у рецепта есть только базовые поля (ответ `filter.php`).
  bool get isLite =>
      category == null &&
      area == null &&
      tags.isEmpty &&
      ingredients.isEmpty &&
      instructions == null;

  /// Полный объект из `/lookup.php`, `/search.php`, `/random.php`.
  factory Recipe.fromMealDb(Map<String, dynamic> json) {
    final ingredients = <RecipeIngredient>[];
    for (var i = 1; i <= 20; i++) {
      final name = (json['strIngredient$i'] as String?)?.trim() ?? '';
      final measure = (json['strMeasure$i'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      ingredients.add(RecipeIngredient(name: name, measure: measure));
    }

    final rawTags = (json['strTags'] as String?)?.trim() ?? '';
    final tags = rawTags.isEmpty
        ? const <String>[]
        : rawTags
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList(growable: false);

    String? nullIfBlank(Object? v) {
      final s = (v as String?)?.trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return Recipe(
      id: int.parse(json['idMeal'] as String),
      name: json['strMeal'] as String,
      photo: json['strMealThumb'] as String,
      category: nullIfBlank(json['strCategory']),
      area: nullIfBlank(json['strArea']),
      tags: tags,
      instructions: nullIfBlank(json['strInstructions']),
      ingredients: ingredients,
      youtubeUrl: nullIfBlank(json['strYoutube']),
      sourceUrl: nullIfBlank(json['strSource']),
    );
  }

  /// Короткий объект из `/filter.php?...`.
  factory Recipe.fromMealDbLite(Map<String, dynamic> json) {
    return Recipe(
      id: int.parse(json['idMeal'] as String),
      name: json['strMeal'] as String,
      photo: json['strMealThumb'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Recipe &&
          other.id == id &&
          other.name == name &&
          other.photo == photo &&
          other.category == category &&
          other.area == area &&
          _listEquals(other.tags, tags) &&
          other.instructions == instructions &&
          _listEquals(other.ingredients, ingredients) &&
          other.youtubeUrl == youtubeUrl &&
          other.sourceUrl == sourceUrl;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    photo,
    category,
    area,
    Object.hashAll(tags),
    instructions,
    Object.hashAll(ingredients),
    youtubeUrl,
    sourceUrl,
  );
}

/// Один ингредиент с мерой (`strIngredientN` + `strMeasureN`).
class RecipeIngredient {
  final String name;
  final String measure;

  const RecipeIngredient({required this.name, required this.measure});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeIngredient &&
          other.name == name &&
          other.measure == measure;

  @override
  int get hashCode => Object.hash(name, measure);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
