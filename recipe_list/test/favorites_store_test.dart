import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/data/local/recipe_db.dart';
import 'package:recipe_list/data/repository/favorites_store.dart';
import 'package:recipe_list/i18n.dart';
import 'package:recipe_list/models/recipe.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Recipe _r(int id, {String name = 'r'}) =>
    Recipe(id: id, name: '$name$id', photo: 'https://x/$id.jpg');

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

Future<void> _seedRecipe(Database db, Recipe r, AppLang lang) async {
  await db.insert(
    'recipes',
    writeRecipe(r, lang: lang.name, lastUsedAt: 0),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FavoritesStore', () {
    late Database db;
    setUp(() async => db = await _openInMemoryDb());
    tearDown(() async => db.close());

    test('add → isFavorite → remove round-trip', () async {
      final store = FavoritesStore(db: db);
      expect(await store.isFavorite(42, AppLang.en), isFalse);

      await store.add(42, AppLang.en);
      expect(await store.isFavorite(42, AppLang.en), isTrue);
      expect(store.snapshotForLang(AppLang.en), {42});

      await store.remove(42, AppLang.en);
      expect(await store.isFavorite(42, AppLang.en), isFalse);
      expect(store.snapshotForLang(AppLang.en), isEmpty);
    });

    test('toggle flips state and reports new value', () async {
      final store = FavoritesStore(db: db);
      expect(await store.toggle(7, AppLang.ru), isTrue);
      expect(await store.isFavorite(7, AppLang.ru), isTrue);
      expect(await store.toggle(7, AppLang.ru), isFalse);
      expect(await store.isFavorite(7, AppLang.ru), isFalse);
    });

    test('per-language isolation: add in EN does not surface in TR', () async {
      final store = FavoritesStore(db: db);
      await store.add(1, AppLang.en);
      expect(await store.isFavorite(1, AppLang.en), isTrue);
      expect(await store.isFavorite(1, AppLang.tr), isFalse);
      expect(store.snapshotForLang(AppLang.tr), isEmpty);
    });

    test('idsForLang notifier rebuilds on add/remove', () async {
      final store = FavoritesStore(db: db);
      final notifier = store.idsForLang(AppLang.en);
      await store.ensureLoaded(AppLang.en); // ленивая инициализация

      var fired = 0;
      notifier.addListener(() => fired++);

      await store.add(1, AppLang.en);
      expect(notifier.value, {1});
      expect(fired, 1);

      await store.add(2, AppLang.en);
      expect(notifier.value, {1, 2});
      expect(fired, 2);

      await store.remove(1, AppLang.en);
      expect(notifier.value, {2});
      expect(fired, 3);
    });

    test('list(lang) returns recipes in saved_at DESC order', () async {
      // Подсаживаем три рецепта в `recipes`, потом отмечаем их в
      // разном порядке — JOIN должен отдать по `saved_at DESC`.
      await _seedRecipe(db, _r(1, name: 'first'), AppLang.en);
      await _seedRecipe(db, _r(2, name: 'second'), AppLang.en);
      await _seedRecipe(db, _r(3, name: 'third'), AppLang.en);

      var t = 1000;
      final store = FavoritesStore(
        db: db,
        now: () => DateTime.fromMillisecondsSinceEpoch(t++),
      );
      await store.add(1, AppLang.en); // saved_at=1000
      await store.add(2, AppLang.en); // 1001
      await store.add(3, AppLang.en); // 1002

      final got = await store.list(AppLang.en);
      expect(got.map((r) => r.id), [3, 2, 1]);
    });

    test('list(lang) filters by language', () async {
      await _seedRecipe(db, _r(1), AppLang.en);
      await _seedRecipe(db, _r(2), AppLang.tr);
      final store = FavoritesStore(db: db);
      await store.add(1, AppLang.en);
      await store.add(2, AppLang.tr);

      final en = await store.list(AppLang.en);
      final tr = await store.list(AppLang.tr);
      expect(en.map((r) => r.id), [1]);
      expect(tr.map((r) => r.id), [2]);
    });

    test('add is idempotent (same PK, no duplicates)', () async {
      final store = FavoritesStore(db: db);
      await store.add(5, AppLang.en);
      await store.add(5, AppLang.en);
      final rows = await db.query('favorites');
      expect(rows, hasLength(1));
    });

    test('orphanIds returns favorites without a `recipes` row', () async {
      // recipes row есть только для 1; 2 — orphan
      await _seedRecipe(db, _r(1), AppLang.en);
      final store = FavoritesStore(db: db);
      await store.add(1, AppLang.en);
      await store.add(2, AppLang.en);

      expect(await store.orphanIds(AppLang.en), [2]);
    });
  });
}
