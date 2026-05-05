import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_list/data/local/recipe_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Воспроизводит схему v5 (без таблицы `favorites`) для проверки
/// миграции v5 → v6: апгрейд должен ДОБАВИТЬ таблицу, не задевая
/// `recipes` / `recipe_bodies`.
const String _kV5Recipes = '''
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

const String _kV5Bodies = '''
CREATE TABLE recipe_bodies (
  id INTEGER NOT NULL,
  lang TEXT NOT NULL,
  instructions TEXT,
  PRIMARY KEY (id, lang)
);
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('recipe_db migration v5 → v6', () {
    test(
      'upgrade adds favorites table without touching cached recipes',
      () async {
        sqfliteFfiInit();
        final factory = databaseFactoryFfi;
        final tmp = await Directory.systemTemp.createTemp('recipe_db_mig_');
        final path = p.join(tmp.path, 'recipes.db');

        // 1. Открываем БД как v5 и подсаживаем строку в `recipes`.
        final db = await factory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 5,
            onCreate: (db, _) async {
              await db.execute(_kV5Recipes);
              await db.execute(_kV5Bodies);
            },
          ),
        );
        await db.insert('recipes', {
          'id': 1,
          'lang': 'en',
          'name': 'Borscht',
          'name_lower': 'borscht',
          'photo': 'https://x/1.jpg',
          'last_used_at': 0,
          'byte_size': 100,
        });
        await db.close();

        // 2. Повторно открываем со свежей версией схемы — должен
        //    отработать onUpgrade(5 → 6).
        final upgraded = await factory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: kRecipeDbSchemaVersion,
            onCreate: (db, _) => applyRecipeSchema(db),
            onUpgrade: (db, oldVersion, newVersion) async {
              if (oldVersion < 5) {
                await db.execute('DROP TABLE IF EXISTS recipes');
                await db.execute('DROP TABLE IF EXISTS recipe_bodies');
                await db.execute('DROP TABLE IF EXISTS favorites');
                await applyRecipeSchema(db);
                return;
              }
              if (oldVersion < 6) {
                await applyFavoritesSchema(db);
              }
            },
          ),
        );

        // recipes row должна остаться.
        final recipes = await upgraded.query('recipes');
        expect(recipes, hasLength(1));
        expect(recipes.single['name'], 'Borscht');

        // favorites должна быть создана и пуста.
        final fav = await upgraded.query('favorites');
        expect(fav, isEmpty);

        // Индекс на `(lang, saved_at DESC)` должен присутствовать.
        final indexes = await upgraded.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND tbl_name='favorites'",
        );
        expect(
          indexes.map((r) => r['name']),
          contains('idx_favorites_lang_saved_at'),
        );

        await upgraded.close();
        await tmp.delete(recursive: true);
      },
    );

    test('fresh install (onCreate) creates favorites table', () async {
      sqfliteFfiInit();
      final factory = databaseFactoryFfi;
      final db = await factory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: kRecipeDbSchemaVersion,
          onCreate: (db, _) => applyRecipeSchema(db),
        ),
      );
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "ORDER BY name",
      );
      expect(
        tables.map((r) => r['name']),
        containsAll(<String>['favorites', 'recipe_bodies', 'recipes']),
      );
      await db.close();
    });
  });

  group('recipe_db migration v11 → v12', () {
    // Reuses applyRecipeSchema for older tables, then drops the v12
    // tables to simulate a v11 snapshot. This avoids hand-coding the
    // entire pre-v12 schema string.
    test('upgrade adds user_profile + recipe_creator_cache without '
        'touching favorites / recipes', () async {
      sqfliteFfiInit();
      final factory = databaseFactoryFfi;
      final tmp = await Directory.systemTemp.createTemp('recipe_db_v12_');
      final path = p.join(tmp.path, 'recipes.db');

      // 1. Bring up the DB at v11 by applying the current schema and
      //    then dropping the two v12 tables.
      final db = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 11,
          onCreate: (db, _) async {
            await applyRecipeSchema(db);
            await db.execute('DROP TABLE IF EXISTS user_profile');
            await db.execute('DROP TABLE IF EXISTS recipe_creator_cache');
          },
        ),
      );
      await db.insert('recipes', {
        'id': 42,
        'lang': 'en',
        'name': 'Pasta',
        'name_lower': 'pasta',
        'photo': 'https://x/42.jpg',
        'last_used_at': 0,
        'byte_size': 100,
      });
      await db.insert('favorites', {
        'recipe_id': 42,
        'lang': 'en',
        'saved_at': 1700000000,
      });
      await db.close();

      // 2. Re-open at v12 — onUpgrade(11 → 12) must create both
      //    new tables.
      final upgraded = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: kRecipeDbSchemaVersion,
          onCreate: (db, _) => applyRecipeSchema(db),
          onUpgrade: (db, oldVersion, _) async {
            if (oldVersion < 12) {
              await applyUserProfileAndCreatorCacheSchema(db);
            }
          },
        ),
      );

      // Existing data preserved.
      final recipes = await upgraded.query('recipes');
      expect(recipes, hasLength(1));
      expect(recipes.single['name'], 'Pasta');
      final favs = await upgraded.query('favorites');
      expect(favs, hasLength(1));

      // New tables exist + are queryable + empty.
      final profiles = await upgraded.query('user_profile');
      expect(profiles, isEmpty);
      final creators = await upgraded.query('recipe_creator_cache');
      expect(creators, isEmpty);

      // Round-trip insert + select on each.
      await upgraded.insert('user_profile', {
        'user_id': 'u1',
        'display_name': 'John',
        'language': 'en',
        'avatar_path': 'food-avatars/u1/1.jpg',
        'member_since': 1700000000,
        'recipes_added': 3,
        'cached_at': 1700000005,
      });
      await upgraded.insert('recipe_creator_cache', {
        'creator_user_id': 'u2',
        'display_name': 'Jane',
        'avatar_path': 'food-avatars/u2/9.jpg',
        'recipes_added': 12,
        'cached_at': 1700000010,
      });
      expect(
        (await upgraded.query('user_profile')).single['display_name'],
        'John',
      );
      expect(
        (await upgraded.query('recipe_creator_cache')).single['display_name'],
        'Jane',
      );

      await upgraded.close();
      await tmp.delete(recursive: true);
    });

    test('fresh install at v12 creates both new tables', () async {
      sqfliteFfiInit();
      final factory = databaseFactoryFfi;
      final db = await factory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: kRecipeDbSchemaVersion,
          onCreate: (db, _) => applyRecipeSchema(db),
        ),
      );
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      expect(
        tables.map((r) => r['name']),
        containsAll(<String>[
          'favorites',
          'recipe_bodies',
          'recipe_creator_cache',
          'recipes',
          'user_profile',
        ]),
      );

      // Column shape sanity.
      final profileCols = await db.rawQuery("PRAGMA table_info(user_profile)");
      expect(
        profileCols.map((r) => r['name']),
        containsAll(<String>[
          'user_id',
          'display_name',
          'language',
          'avatar_path',
          'member_since',
          'recipes_added',
          'cached_at',
        ]),
      );
      final creatorCols = await db.rawQuery(
        "PRAGMA table_info(recipe_creator_cache)",
      );
      expect(
        creatorCols.map((r) => r['name']),
        containsAll(<String>[
          'creator_user_id',
          'display_name',
          'avatar_path',
          'recipes_added',
          'cached_at',
        ]),
      );
      await db.close();
    });

    test('schema version constant is 12', () {
      expect(kRecipeDbSchemaVersion, 12);
    });
  });
}
