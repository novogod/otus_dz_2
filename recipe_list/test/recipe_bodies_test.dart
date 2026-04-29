import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/data/api/recipe_api.dart';
import 'package:recipe_list/data/local/recipe_db.dart';
import 'package:recipe_list/data/repository/recipe_repository.dart';
import 'package:recipe_list/i18n.dart';
import 'package:recipe_list/models/recipe.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _NopApi implements RecipeApi {
  @override
  Future<List<Recipe>> searchByName({required String query, AppLang? lang}) async => const [];
  @override
  Future<Recipe?> lookup(int id, {AppLang? lang, Duration? timeout}) async => null;
  @override
  Future<Recipe?> random({AppLang? lang}) async => null;
  @override
  Future<List<Recipe>> filterByCategory(String category) async => const [];
  @override
  Future<List<Recipe>> filterByArea(String area) async => const [];
  @override
  Future<List<Recipe>> filterByIngredient(String ingredient) async => const [];
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Recipe _r(int id, {String? instructions}) => Recipe(
      id: id,
      name: 'r$id',
      photo: 'https://x/$id.jpg',
      instructions: instructions,
    );

Future<Database> _openInMemoryDb() async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  return factory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: kRecipeDbSchemaVersion,
      onCreate: (db, _) => applyRecipeSchema(db),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecipeRepository.getInstructions (todo/12)', () {
    late Database db;
    setUp(() async => db = await _openInMemoryDb());
    tearDown(() async => db.close());

    test('persists instructions in sibling table on upsert', () async {
      final repo = RecipeRepository(db: db, api: _NopApi());
      await repo.upsertAll([
        _r(1, instructions: 'Cook well.'),
        _r(2),
      ], AppLang.en);

      expect(await repo.getInstructions(1, AppLang.en), 'Cook well.');
      expect(await repo.getInstructions(2, AppLang.en), isNull);
    });

    test('listCached returns recipes without instructions blob', () async {
      final repo = RecipeRepository(db: db, api: _NopApi());
      await repo.upsertAll([_r(1, instructions: 'XYZ')], AppLang.en);

      final cached = await repo.listCached(AppLang.en);
      expect(cached, hasLength(1));
      expect(cached.first.instructions, isNull,
          reason: 'list-row payload must not carry the heavy blob');
    });

    test('eviction cascades to recipe_bodies via trigger', () async {
      final repo = RecipeRepository(db: db, api: _NopApi());
      await repo.upsertAll([_r(1, instructions: 'A')], AppLang.en);
      // Manually delete the parent row to fire the trigger; eviction
      // path uses the same `DELETE FROM recipes WHERE rowid IN ...`
      // statement.
      await db.rawDelete('DELETE FROM recipes WHERE id = ? AND lang = ?',
          [1, 'en']);
      expect(await repo.getInstructions(1, AppLang.en), isNull);
      final orphans = await db.rawQuery(
          'SELECT COUNT(*) AS c FROM recipe_bodies WHERE id = ?', [1]);
      expect(orphans.first['c'], 0);
    });

    test('byte_size of recipes row excludes instructions length', () async {
      final repo = RecipeRepository(db: db, api: _NopApi());
      // Same recipe with and without a long body. Their row byte_size
      // must match because instructions live elsewhere.
      await repo.upsertAll([_r(1, instructions: 'x' * 5000)], AppLang.en);
      final rowsA = await db.query('recipes',
          columns: ['byte_size'], where: 'id = ? AND lang = ?',
          whereArgs: [1, 'en']);
      await repo.upsertAll([_r(2)], AppLang.en);
      final rowsB = await db.query('recipes',
          columns: ['byte_size'], where: 'id = ? AND lang = ?',
          whereArgs: [2, 'en']);
      expect(rowsA.first['byte_size'], rowsB.first['byte_size']);
    });
  });
}
