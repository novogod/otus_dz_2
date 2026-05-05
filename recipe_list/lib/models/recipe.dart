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

  // ---------------------------------------------------------------
  // Social-signal fields (chunk E of
  // docs/user-card-and-social-signals.md).
  //
  // These travel through the network model and the in-memory feed
  // but are intentionally NOT persisted in the local SQLite cache:
  // counts and "my rating" go stale immediately, so we always read
  // them from the server's lookup / page response. Cached rows
  // restore these as defaults (0 / null) and the loader refreshes
  // them on the next list fetch.
  // ---------------------------------------------------------------

  /// Server-side user_id of the recipe author. Null for TheMealDB
  /// recipes (id < 1_000_000) and for any user-added recipe whose
  /// creator metadata isn't yet projected by the server.
  final String? creatorUserId;

  /// Display name of the author, projected by the server alongside
  /// the recipe. See docs/user-card-and-social-signals.md §3.3.
  final String? creatorDisplayName;

  /// Avatar S3 path of the author. Composed via [imgproxyUrl] when
  /// rendered (we never store the full imgproxy URL on disk).
  final String? creatorAvatarPath;

  /// Total number of recipes added by the author (denormalised on
  /// the `recipes_users` table server-side). Used in the
  /// "Added by" footer and the optional card chip.
  final int? creatorRecipesAdded;

  /// Total favourites for this recipe across all users. Defaults to
  /// 0 when the server hasn't projected the count (e.g. TheMealDB
  /// recipes pre-population). Drives the favorite-count pill on the
  /// recipe card (chunk H).
  final int favoritesCount;

  /// Total number of ratings (chunk G). Defaults to 0.
  final int ratingsCount;

  /// Sum of star values across all ratings (chunk G). Defaults to 0.
  /// Average is computed on render as `ratingsSum / ratingsCount`.
  final int ratingsSum;

  /// Current user's rating, if logged in and rated. Null otherwise.
  final int? myRating;

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
    this.creatorUserId,
    this.creatorDisplayName,
    this.creatorAvatarPath,
    this.creatorRecipesAdded,
    this.favoritesCount = 0,
    this.ratingsCount = 0,
    this.ratingsSum = 0,
    this.myRating,
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
      // Social signals — projected by the mahallem-user-portal server
      // for user-added recipes (id ≥ 1_000_000). TheMealDB upstream
      // doesn't set them; tolerant parsing leaves defaults.
      creatorUserId: nullIfBlank(json['creatorUserId']),
      creatorDisplayName: nullIfBlank(json['creatorDisplayName']),
      creatorAvatarPath: nullIfBlank(json['creatorAvatarPath']),
      creatorRecipesAdded: _intOrNull(json['creatorRecipesAdded']),
      favoritesCount: _intOr(json['favoritesCount'], 0),
      ratingsCount: _intOr(json['ratingsCount'], 0),
      ratingsSum: _intOr(json['ratingsSum'], 0),
      myRating: _intOrNull(json['myRating']),
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
          other.sourceUrl == sourceUrl &&
          other.creatorUserId == creatorUserId &&
          other.creatorDisplayName == creatorDisplayName &&
          other.creatorAvatarPath == creatorAvatarPath &&
          other.creatorRecipesAdded == creatorRecipesAdded &&
          other.favoritesCount == favoritesCount &&
          other.ratingsCount == ratingsCount &&
          other.ratingsSum == ratingsSum &&
          other.myRating == myRating;

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
    Object.hash(
      creatorUserId,
      creatorDisplayName,
      creatorAvatarPath,
      creatorRecipesAdded,
      favoritesCount,
      ratingsCount,
      ratingsSum,
      myRating,
    ),
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

/// Tolerant int parser used by [Recipe.fromMealDb] for social-signal
/// fields. Accepts ints, num/double truncated to int, and strings;
/// returns `null` for missing / unparseable values.
int? _intOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

int _intOr(Object? v, int fallback) => _intOrNull(v) ?? fallback;
