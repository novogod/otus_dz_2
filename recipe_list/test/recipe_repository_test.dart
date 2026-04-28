import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/data/api/recipe_api.dart';
import 'package:recipe_list/data/local/recipe_db.dart';
import 'package:recipe_list/data/repository/recipe_repository.dart';
import 'package:recipe_list/i18n.dart';
import 'package:recipe_list/models/recipe.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Тестовый `RecipeApi`, считающий вызовы и возвращающий заранее
/// заданные рецепты. Никакого Dio.
class _FakeApi implements RecipeApi {
  final List<Recipe> Function(String prefix) onSearch;
  final List<({String prefix, AppLang lang})> calls = [];

  _FakeApi(this.onSearch);

  @override
  Future<List<Recipe>> searchByName({
    required String query,
    AppLang? lang,
  }) async {
    calls.add((prefix: query, lang: lang ?? AppLang.en));
    return onSearch(query);
  }

  @override
  Future<Recipe?> lookup(int id, {AppLang? lang}) async => null;

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

class _ThrowingApi extends _FakeApi {
  _ThrowingApi() : super((_) => throw StateError('offline'));

  @override
  Future<List<Recipe>> searchByName({
    required String query,
    AppLang? lang,
  }) async {
    calls.add((prefix: query, lang: lang ?? AppLang.en));
    throw StateError('network down');
  }
}

Recipe _r(int id, String name) =>
    Recipe(id: id, name: name, photo: 'https://x/p.jpg');

Future<Database> _openInMemoryDb() async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  final db = await factory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: kRecipeDbSchemaVersion,
      onCreate: (db, _) => applyRecipeSchema(db),
    ),
  );
  return db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecipeRepository', () {
    late Database db;

    setUp(() async {
      db = await _openInMemoryDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('cache miss -> hits API and persists results', () async {
      final api = _FakeApi((_) => [_r(1, 'Apple Pie'), _r(2, 'Apricot Tart')]);
      final repo = RecipeRepository(db: db, api: api);

      final res = await repo.searchByName('ap', AppLang.en);

      expect(res.fromCache, isFalse);
      expect(res.offline, isFalse);
      expect(res.recipes.map((r) => r.name), ['Apple Pie', 'Apricot Tart']);
      expect(api.calls, hasLength(1));
      expect(await repo.count(), 2);
    });

    test('cache hit at threshold -> no API call', () async {
      final api = _FakeApi(
        (_) => List.generate(6, (i) => _r(100 + i, 'Banana $i')),
      );
      final repo = RecipeRepository(db: db, api: api, cacheHitThreshold: 5);

      // Прогрев: первый запрос наполнит кэш и считается как "miss".
      await repo.searchByName('ban', AppLang.en);
      expect(api.calls, hasLength(1));

      // Тот же префикс — теперь >= threshold локальных совпадений.
      final res = await repo.searchByName('ban', AppLang.en);
      expect(res.fromCache, isTrue);
      expect(res.offline, isFalse);
      expect(res.recipes, hasLength(6));
      // API вызван по-прежнему один раз.
      expect(api.calls, hasLength(1));
    });

    test('different lang is a separate cache partition', () async {
      final api = _FakeApi((_) => [_r(1, 'Apple')]);
      final repo = RecipeRepository(db: db, api: api);

      await repo.upsertAll([_r(1, 'Яблоко')], AppLang.ru);
      final res = await repo.searchByName('ap', AppLang.en);

      // ru-кэш не должен закрывать en-запрос.
      expect(res.fromCache, isFalse);
      expect(api.calls, hasLength(1));
    });

    test('LRU eviction respects cap by last_used_at', () async {
      var clock = DateTime(2026, 1, 1);
      final api = _FakeApi((_) => const []);
      final repo = RecipeRepository(db: db, api: api, cap: 3, now: () => clock);

      // Вставляем 4 рецепта, каждый со своим временем.
      for (var i = 0; i < 4; i++) {
        clock = clock.add(const Duration(minutes: 1));
        await repo.upsertAll([_r(i, 'R$i')], AppLang.en);
      }
      expect(await repo.count(), 3);

      // Самый старый (id=0) был вытеснен.
      final remaining = await db.query('recipes', columns: ['id']);
      final ids = remaining.map((r) => r['id'] as int).toSet();
      expect(ids, isNot(contains(0)));
      expect(ids, containsAll([1, 2, 3]));
    });

    test('cache hit refreshes last_used_at (LRU touch)', () async {
      var clock = DateTime(2026, 1, 1);
      final api = _FakeApi((_) => const []);
      final repo = RecipeRepository(
        db: db,
        api: api,
        cap: 2,
        cacheHitThreshold: 1,
        now: () => clock,
      );

      await repo.upsertAll([_r(1, 'Alpha'), _r(2, 'Beta')], AppLang.en);

      // Пользуем "Alpha" чуть позже.
      clock = clock.add(const Duration(minutes: 5));
      final hit = await repo.searchByName('alp', AppLang.en);
      expect(hit.fromCache, isTrue);

      // Вставляем третий — должен вытесниться "Beta",
      // потому что у "Alpha" свежее last_used_at.
      clock = clock.add(const Duration(minutes: 5));
      await repo.upsertAll([_r(3, 'Gamma')], AppLang.en);

      final remaining = await db.query('recipes', columns: ['id']);
      final ids = remaining.map((r) => r['id'] as int).toSet();
      expect(ids, {1, 3});
    });

    test(
      'network error with cached hits returns cached and offline=false',
      () async {
        final api = _ThrowingApi();
        final repo = RecipeRepository(db: db, api: api, cacheHitThreshold: 5);

        await db.insert(
          'recipes',
          writeRecipe(_r(1, 'Apricot'), lang: 'en', lastUsedAt: 1),
        );

        final res = await repo.searchByName('ap', AppLang.en);
        expect(res.recipes.map((r) => r.name), ['Apricot']);
        expect(res.fromCache, isTrue);
        expect(res.offline, isFalse);
      },
    );

    test('network error with empty cache returns offline=true', () async {
      final api = _ThrowingApi();
      final repo = RecipeRepository(db: db, api: api);

      final res = await repo.searchByName('zzz', AppLang.en);
      expect(res.recipes, isEmpty);
      expect(res.offline, isTrue);
    });
  });
}
