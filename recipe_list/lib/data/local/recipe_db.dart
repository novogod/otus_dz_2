import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/recipe.dart';

/// Имя файла локальной БД.
const String kRecipeDbFileName = 'recipes.db';

/// Версия схемы. Любое изменение `_kSchema` требует bump-а и
/// миграции в `_onUpgrade`.
const int kRecipeDbSchemaVersion = 1;

/// SQL-схема локального кэша рецептов.
///
/// Один рецепт = одна строка `(id, lang)` — один и тот же рецепт
/// в разных языках хранится отдельно (после mahallem-перевода).
/// `name_lower` нужен для быстрого `name LIKE 'prefix%'` без
/// `COLLATE NOCASE`. `last_used_at` — для LRU-вытеснения.
const String _kSchema = '''
CREATE TABLE recipes (
  id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  name TEXT NOT NULL,
  name_lower TEXT NOT NULL,
  photo TEXT NOT NULL,
  category TEXT,
  area TEXT,
  tags TEXT,
  instructions TEXT,
  youtube_url TEXT,
  source_url TEXT,
  ingredients_json TEXT,
  last_used_at INTEGER NOT NULL,
  PRIMARY KEY (id, lang)
);
''';

const List<String> _kIndexes = [
  'CREATE INDEX idx_recipes_lang_name_lower ON recipes(lang, name_lower);',
  'CREATE INDEX idx_recipes_last_used_at ON recipes(last_used_at);',
];

Future<void> applyRecipeSchema(Database db) async {
  await db.execute(_kSchema);
  for (final stmt in _kIndexes) {
    await db.execute(stmt);
  }
}

/// Открывает persistent БД в `getApplicationSupportDirectory()`.
/// Тесты вместо этого передают `Database` напрямую через
/// `RecipeRepository(db: ...)`.
Future<Database> openRecipeDatabase() async {
  final dir = await getApplicationSupportDirectory();
  final path = p.join(dir.path, kRecipeDbFileName);
  return openDatabase(
    path,
    version: kRecipeDbSchemaVersion,
    onCreate: (db, _) => applyRecipeSchema(db),
  );
}

/// Сериализация ингредиентов в JSON-строку — sqflite не умеет
/// массивы. Парсинг в обратную сторону — [readRecipe].
String encodeIngredients(List<RecipeIngredient> list) => jsonEncode(
  list
      .map((i) => {'name': i.name, 'measure': i.measure})
      .toList(growable: false),
);

List<RecipeIngredient> decodeIngredients(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  final data = jsonDecode(raw);
  if (data is! List) return const [];
  return data
      .whereType<Map<String, dynamic>>()
      .map(
        (m) => RecipeIngredient(
          name: (m['name'] as String?) ?? '',
          measure: (m['measure'] as String?) ?? '',
        ),
      )
      .toList(growable: false);
}

/// Превращает sqflite-строку обратно в [Recipe].
Recipe readRecipe(Map<String, Object?> row) {
  final tagsRaw = row['tags'] as String?;
  final tags = (tagsRaw == null || tagsRaw.isEmpty)
      ? const <String>[]
      : tagsRaw.split('\u0001'); // delim не пересекается с CSV-тегами
  return Recipe(
    id: row['id']! as int,
    name: row['name']! as String,
    photo: row['photo']! as String,
    category: row['category'] as String?,
    area: row['area'] as String?,
    tags: tags,
    instructions: row['instructions'] as String?,
    youtubeUrl: row['youtube_url'] as String?,
    sourceUrl: row['source_url'] as String?,
    ingredients: decodeIngredients(row['ingredients_json'] as String?),
  );
}

/// Готовит map для INSERT/UPDATE.
Map<String, Object?> writeRecipe(
  Recipe r, {
  required String lang,
  required int lastUsedAt,
}) => {
  'id': r.id,
  'lang': lang,
  'name': r.name,
  'name_lower': r.name.toLowerCase(),
  'photo': r.photo,
  'category': r.category,
  'area': r.area,
  'tags': r.tags.join('\u0001'),
  'instructions': r.instructions,
  'youtube_url': r.youtubeUrl,
  'source_url': r.sourceUrl,
  'ingredients_json': encodeIngredients(r.ingredients),
  'last_used_at': lastUsedAt,
};
