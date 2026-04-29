import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/recipe.dart';

/// Имя файла локальной БД.
const String kRecipeDbFileName = 'recipes.db';

/// Версия схемы. Любое изменение `_kSchema` требует bump-а и
/// миграции в `_onUpgrade`.
///
/// v2: invalidate cached recipes after switching to MyMemory-first
/// translation pipeline (oil → масло, etc.). Schema unchanged; the
/// upgrade simply DROPs and recreates the table to evict stale RU rows.
/// v3: add `byte_size` column so the cache can enforce a byte budget
/// (≈5 MB) instead of a fixed row count, evicting the least-recently
/// used heaviest cards first.
/// v4: evict cached rows that may have been poisoned during the
/// pre-`gemini-2.5-flash-lite` pipeline (notably Spanish content
/// stuck under `lang='de'` because the cascade had previously
/// echoed the wrong source language). Schema is unchanged; the
/// upgrade just DROPs and recreates the table so the loader
/// re-fetches every card via the corrected server.
/// v5: split `recipes.instructions` into a sibling table
/// `recipe_bodies` (todo/12). The list-row payload drops the
/// heaviest column; details screen lazy-loads it on demand.
const int kRecipeDbSchemaVersion = 5;

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
  youtube_url TEXT,
  source_url TEXT,
  ingredients_json TEXT,
  last_used_at INTEGER NOT NULL,
  byte_size INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id, lang)
);
''';

/// Sibling table for the heavy HTML `instructions` blob (todo/12).
/// Loaded only on the details screen; cascaded by the trigger below
/// when the parent `recipes` row is evicted by the LRU.
const String _kBodySchema = '''
CREATE TABLE recipe_bodies (
  id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  instructions TEXT,
  PRIMARY KEY (id, lang)
);
''';

const String _kBodyCascadeTrigger = '''
CREATE TRIGGER trg_recipes_after_delete
AFTER DELETE ON recipes
BEGIN
  DELETE FROM recipe_bodies
   WHERE id = OLD.id AND lang = OLD.lang;
END;
''';

const List<String> _kIndexes = [
  'CREATE INDEX idx_recipes_lang_name_lower ON recipes(lang, name_lower);',
  'CREATE INDEX idx_recipes_last_used_at ON recipes(last_used_at);',
];

Future<void> applyRecipeSchema(Database db) async {
  await db.execute(_kSchema);
  await db.execute(_kBodySchema);
  await db.execute(_kBodyCascadeTrigger);
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
    onUpgrade: (db, oldVersion, newVersion) async {
      // No additive migrations: drop everything and let the loader
      // re-fetch with the new translation pipeline.
      await db.execute('DROP TABLE IF EXISTS recipes');
      await db.execute('DROP TABLE IF EXISTS recipe_bodies');
      await applyRecipeSchema(db);
    },
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

/// Превращает sqflite-строку обратно в [Recipe]. Поле `instructions`
/// больше не хранится в `recipes` (todo/12); список читает рецепты
/// без тяжёлого HTML-блоба, и UI деталей лениво подтягивает его
/// через `RecipeRepository.getInstructions`.
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
    instructions: null,
    youtubeUrl: row['youtube_url'] as String?,
    sourceUrl: row['source_url'] as String?,
    ingredients: decodeIngredients(row['ingredients_json'] as String?),
  );
}

/// Готовит map для INSERT/UPDATE в `recipes`. Поле `instructions`
/// исключено: оно живёт в `recipe_bodies`, см. todo/12.
Map<String, Object?> writeRecipe(
  Recipe r, {
  required String lang,
  required int lastUsedAt,
}) {
  final tagsJoined = r.tags.join('\u0001');
  final ingredientsJson = encodeIngredients(r.ingredients);
  // UTF-16 length is a cheap, deterministic proxy for stored byte size.
  // Photos/URLs dominate; we don't fetch the image bytes themselves.
  // `instructions` is excluded — it lives in the sibling table.
  final byteSize =
      r.name.length +
      r.photo.length +
      (r.category?.length ?? 0) +
      (r.area?.length ?? 0) +
      tagsJoined.length +
      (r.youtubeUrl?.length ?? 0) +
      (r.sourceUrl?.length ?? 0) +
      ingredientsJson.length;
  return {
    'id': r.id,
    'lang': lang,
    'name': r.name,
    'name_lower': r.name.toLowerCase(),
    'photo': r.photo,
    'category': r.category,
    'area': r.area,
    'tags': tagsJoined,
    'youtube_url': r.youtubeUrl,
    'source_url': r.sourceUrl,
    'ingredients_json': ingredientsJson,
    'last_used_at': lastUsedAt,
    'byte_size': byteSize,
  };
}

/// Map for INSERT/UPDATE into `recipe_bodies` (todo/12).
Map<String, Object?> writeRecipeBody(Recipe r, {required String lang}) {
  return {'id': r.id, 'lang': lang, 'instructions': r.instructions};
}
