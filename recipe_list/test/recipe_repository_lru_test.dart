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

/// Build a recipe whose persisted byte_size will be ~`bytes`. The
/// repository computes byte_size from the JSON length of the row, so
/// padding the instructions field controls the size predictably.
Recipe _bigRecipe(int id, {int bytes = 1024}) {
  final pad = 'x' * bytes;
  return Recipe(
    id: id,
    name: 'r$id',
    photo: 'https://x/$id.jpg',
    instructions: pad,
  );
}

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

  group('RecipeRepository per-language LRU (todo/11)', () {
    late Database db;
    setUp(() async => db = await _openInMemoryDb());
    tearDown(() async => db.close());

    test('eviction prefers non-active lang first', () async {
      // 10 KB byte cap → active budget 6 KB, others 4 KB.
      final repo = RecipeRepository(
        db: db,
        api: _NopApi(),
        byteCap: 10 * 1024,
      );

      // Seed 8 KB into RU (the future "other") and 2 KB into TR (active).
      await repo.upsertAll(
        List.generate(8, (i) => _bigRecipe(100 + i, bytes: 800)),
        AppLang.ru,
      );
      await repo.upsertAll(
        List.generate(2, (i) => _bigRecipe(200 + i, bytes: 800)),
        AppLang.tr,
      );

      // Adding more TR rows should evict RU rows first, not TR.
      await repo.upsertAll(
        List.generate(4, (i) => _bigRecipe(210 + i, bytes: 800)),
        AppLang.tr,
      );

      final ruCount = await repo.countFor(AppLang.ru);
      final trCount = await repo.countFor(AppLang.tr);
      expect(trCount, greaterThanOrEqualTo(6),
          reason: 'active TR rows must not be evicted while others over budget');
      expect(ruCount, lessThan(8),
          reason: 'non-active RU rows should be trimmed first');
    });

    test('falls through to active lang when only it overflows', () async {
      final repo = RecipeRepository(
        db: db,
        api: _NopApi(),
        byteCap: 100 * 1024,
      );

      // Only TR rows. 60 % budget = 60 KB; push 80 rows × 1 KB = 80 KB.
      // After one batch (32 rows) we drop to ~48 KB < budget, so the
      // loop stops with some active rows trimmed but not wiped.
      await repo.upsertAll(
        List.generate(80, (i) => _bigRecipe(i, bytes: 1024)),
        AppLang.tr,
      );

      final trCount = await repo.countFor(AppLang.tr);
      expect(trCount, lessThan(80));
      expect(trCount, greaterThan(0));
    });
  });
}
