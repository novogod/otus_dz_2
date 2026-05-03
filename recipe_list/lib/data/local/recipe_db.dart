import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../../models/recipe.dart';

/// Dedicated web sqflite factory for this app only.
///
/// Important: do NOT assign to global `databaseFactory` on web.
/// Changing the global default causes side effects for any other
/// sqflite consumer and emits runtime warnings. We keep a private
/// factory and call it explicitly.
///
/// We intentionally use `databaseFactoryFfiWebNoWebWorker` here.
/// In our Chrome runtime the worker message pipeline intermittently
/// returned `unsupported result null (null)`; no-web-worker mode
/// avoids that path and keeps IndexedDB-backed persistence.
final DatabaseFactory _webDbFactory = databaseFactoryFfiWebNoWebWorker;

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
/// v6: add `favorites` table for the per-language favorites feature
/// (todo/15). Additive migration — `recipes` / `recipe_bodies` are
/// preserved when upgrading from v5.
/// v7: add `owned_recipes` table — marks recipe ids that were
/// created on this device, so the details page can show
/// edit/delete buttons only to the creator (see
/// docs/owner-edit-delete.md).
/// v8: add `auth_credentials` table — stores mirrored login
/// credentials and active session flag for offline login.
/// v9: add `preferred_language` column to `auth_credentials` so the
/// app can restore the user's chosen language on next launch.
const int kRecipeDbSchemaVersion = 9;

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

/// v6: per-language favorites set. Only stores membership —
/// the displayable body lives in `recipe_bodies` (or is fetched
/// via `RecipeApi.lookup` if the cache row was evicted).
const String _kFavoritesSchema = '''
CREATE TABLE favorites (
  recipe_id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  saved_at INTEGER NOT NULL,
  PRIMARY KEY (recipe_id, lang)
);
''';

/// v7: device-local set of recipe ids the user created via
/// [AddRecipePage]. Persisted across reloads so edit/delete
/// buttons keep showing after the app restarts. We deliberately
/// don't store any per-user identity — this is a single-user
/// demo app, the server has no auth (see docs/owner-edit-delete.md).
const String _kOwnedRecipesSchema = '''
CREATE TABLE owned_recipes (
  id INTEGER PRIMARY KEY,
  created_at INTEGER NOT NULL
);
''';

/// v8: offline mirror of successful online auth.
/// One row per login; `active=1` marks current in-app session.
const String _kAuthCredentialsSchema = '''
CREATE TABLE auth_credentials (
  login TEXT PRIMARY KEY,
  password_hash TEXT NOT NULL,
  token TEXT,
  active INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL,
  preferred_language TEXT
);
''';

const List<String> _kIndexes = [
  'CREATE INDEX idx_recipes_lang_name_lower ON recipes(lang, name_lower);',
  'CREATE INDEX idx_recipes_last_used_at ON recipes(last_used_at);',
  'CREATE INDEX idx_favorites_lang_saved_at ON favorites(lang, saved_at DESC);',
  'CREATE INDEX idx_auth_credentials_active ON auth_credentials(active, updated_at DESC);',
];

Future<void> applyRecipeSchema(Database db) async {
  await db.execute(_kSchema);
  await db.execute(_kBodySchema);
  await db.execute(_kBodyCascadeTrigger);
  await db.execute(_kFavoritesSchema);
  await db.execute(_kOwnedRecipesSchema);
  await db.execute(_kAuthCredentialsSchema);
  for (final stmt in _kIndexes) {
    await db.execute(stmt);
  }
}

/// Idempotent v6 → v7 migration: only adds `owned_recipes`.
/// Existing favorites/recipes/recipe_bodies are preserved.
Future<void> applyOwnedRecipesSchema(Database db) async {
  await db.execute(
    'CREATE TABLE IF NOT EXISTS owned_recipes ('
    'id INTEGER PRIMARY KEY, '
    'created_at INTEGER NOT NULL)',
  );
}

/// Idempotent v7 → v8 migration: adds mirrored auth table.
Future<void> applyAuthCredentialsSchema(Database db) async {
  await db.execute(
    'CREATE TABLE IF NOT EXISTS auth_credentials ('
    'login TEXT PRIMARY KEY, '
    'password_hash TEXT NOT NULL, '
    'token TEXT, '
    'active INTEGER NOT NULL DEFAULT 0, '
    'updated_at INTEGER NOT NULL, '
    'preferred_language TEXT)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_auth_credentials_active '
    'ON auth_credentials(active, updated_at DESC)',
  );
}

/// Идемпотентное создание `favorites` (+ индекса) для миграции
/// v5 → v6: апгрейд не трогает `recipes` / `recipe_bodies`,
/// только добавляет новую таблицу.
Future<void> applyFavoritesSchema(Database db) async {
  await db.execute(
    'CREATE TABLE IF NOT EXISTS favorites ('
    'recipe_id INTEGER NOT NULL, '
    'lang TEXT NOT NULL, '
    'saved_at INTEGER NOT NULL, '
    'PRIMARY KEY (recipe_id, lang))',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_favorites_lang_saved_at '
    'ON favorites(lang, saved_at DESC)',
  );
}

/// Открывает persistent БД в `getApplicationSupportDirectory()`.
/// На web вместо файловой системы используется
/// `sqflite_common_ffi_web` (IndexedDB-backed sqlite3.wasm) — см.
/// docs/web-favorites.md. Тесты вместо этого передают `Database`
/// напрямую через `RecipeRepository(db: ...)`.
Future<Database> openRecipeDatabase() async {
  if (kIsWeb) {
    // На web нет файловой системы — sqflite_common_ffi_web хранит
    // БД в IndexedDB. Имя играет роль ключа в indexedDB-сторадже.
    // Используем локальный factory (без изменения глобального
    // `databaseFactory`) и без web-worker пути, который на текущем
    // Chrome окружении даёт `unsupported result null (null)`.
    return _webDbFactory.openDatabase(
      kRecipeDbFileName,
      options: OpenDatabaseOptions(
        version: kRecipeDbSchemaVersion,
        onCreate: (db, _) => applyRecipeSchema(db),
        onUpgrade: _onRecipeDbUpgrade,
      ),
    );
  }
  final dir = await getApplicationSupportDirectory();
  final path = p.join(dir.path, kRecipeDbFileName);
  return openDatabase(
    path,
    version: kRecipeDbSchemaVersion,
    onCreate: (db, _) => applyRecipeSchema(db),
    onUpgrade: _onRecipeDbUpgrade,
  );
}

Future<void> _onRecipeDbUpgrade(
  Database db,
  int oldVersion,
  int newVersion,
) async {
  // v<5 апгрейды по-прежнему destructive: новый перевод-пайплайн
  // делает старые кэшированные строки невалидными. Избранного
  // там ещё не существовало, терять нечего.
  if (oldVersion < 5) {
    await db.execute('DROP TABLE IF EXISTS recipes');
    await db.execute('DROP TABLE IF EXISTS recipe_bodies');
    await db.execute('DROP TABLE IF EXISTS favorites');
    await applyRecipeSchema(db);
    return;
  }
  // v5 → v6: только дополняем схему таблицей favorites,
  // существующие кэши не трогаем.
  if (oldVersion < 6) {
    await applyFavoritesSchema(db);
  }
  // v6 → v7: добавляем owned_recipes — избранное и кэш
  // сохраняются.
  if (oldVersion < 7) {
    await applyOwnedRecipesSchema(db);
  }
  // v7 → v8: добавляем auth_credentials для офлайн-логина.
  if (oldVersion < 8) {
    await applyAuthCredentialsSchema(db);
  }
    // v8 → v9: добавляем preferred_language в auth_credentials.
    if (oldVersion < 9) {
      try {
        await db.execute(
          'ALTER TABLE auth_credentials ADD COLUMN preferred_language TEXT',
        );
      } catch (_) {
        // Column may already exist (idempotent).
      }
    }
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
