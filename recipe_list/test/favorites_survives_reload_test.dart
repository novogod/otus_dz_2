import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:recipe_list/data/local/recipe_db.dart';
import 'package:recipe_list/data/repository/favorites_store.dart';
import 'package:recipe_list/i18n.dart';
import 'package:recipe_list/models/recipe.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Регрессия для todo/15: избранное живёт в `favorites` отдельно
/// от `recipes`, поэтому полный сброс / перезаливка ленты (reload)
/// и переоткрытие БД не должны его терять. Тест:
/// 1) открываем БД на временный файл, кладём рецепт + favorite;
/// 2) закрываем БД (имитируем «выход из приложения»);
/// 3) открываем заново — таблица favorites та же, и список
///    избранного восстанавливается;
/// 4) даже если из `recipes` строка удалена (типичный LRU-evict
///    при reload), в `favorites` остаётся id и `orphanIds` его
///    видит.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fav_survives_');
    dbPath = p.join(tempDir.path, 'recipe.db');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('favorite сохраняется при переоткрытии БД', () async {
    // 1. Первый запуск: схема v6, рецепт + favorite.
    var db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: kRecipeDbSchemaVersion,
        onCreate: (db, _) => applyRecipeSchema(db),
      ),
    );
    const recipe = Recipe(id: 99, name: 'Solyanka', photo: 'https://e/x.jpg');
    await db.insert(
      'recipes',
      writeRecipe(recipe, lang: AppLang.ru.name, lastUsedAt: 0),
    );
    var store = FavoritesStore(db: db);
    await store.add(99, AppLang.ru);
    expect(await store.isFavorite(99, AppLang.ru), isTrue);
    await db.close();

    // 2. Перезапуск: БД переоткрывается, FavoritesStore заново
    //    читает таблицу.
    db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: kRecipeDbSchemaVersion,
        onCreate: (db, _) => applyRecipeSchema(db),
      ),
    );
    store = FavoritesStore(db: db);
    expect(await store.isFavorite(99, AppLang.ru), isTrue);
    final list = await store.list(AppLang.ru);
    expect(list, hasLength(1));
    expect(list.single.name, 'Solyanka');
    await db.close();
  });

  test(
    'reload-style удаление recipe из ленты не затрагивает favorites',
    () async {
      final db = await factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: kRecipeDbSchemaVersion,
          onCreate: (db, _) => applyRecipeSchema(db),
        ),
      );
      const recipe = Recipe(id: 7, name: 'Plov', photo: 'https://e/p.jpg');
      await db.insert(
        'recipes',
        writeRecipe(recipe, lang: AppLang.ru.name, lastUsedAt: 0),
      );
      final store = FavoritesStore(db: db);
      await store.add(7, AppLang.ru);

      // Имитация LRU-eviction при reload: вычищаем recipes, но
      // не трогаем favorites (так и работает RecipeRepository).
      await db.delete('recipes');

      // Favorites не пострадало.
      expect(await store.isFavorite(7, AppLang.ru), isTrue);
      // INNER JOIN в list() ничего не вернёт без recipes-строки,
      // но id остаётся в favorites и виден через orphanIds.
      expect(await store.list(AppLang.ru), isEmpty);
      expect(await store.orphanIds(AppLang.ru), [7]);

      await db.close();
    },
  );
}
