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
}
