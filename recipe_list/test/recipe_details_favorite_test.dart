import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/auth/admin_session.dart' show userLoggedInNotifier;
import 'package:recipe_list/data/local/recipe_db.dart';
import 'package:recipe_list/data/repository/favorites_store.dart';
import 'package:recipe_list/i18n.dart';
import 'package:recipe_list/models/recipe.dart';
import 'package:recipe_list/ui/recipe_card.dart' show FavoriteBadge;
import 'package:recipe_list/ui/recipe_details_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _recipe = Recipe(
  id: 7,
  name: 'Plov',
  photo: 'https://example.com/plov.jpg',
);

Future<Database> _openInMemoryDb() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: kRecipeDbSchemaVersion,
      onCreate: (db, _) => applyRecipeSchema(db),
    ),
  );
}

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecipeDetailsPage favorite badge', () {
    late Database db;
    late FavoritesStore store;

    setUp(() async {
      db = await _openInMemoryDb();
      store = FavoritesStore(db: db);
      favoritesStoreNotifier.value = store;
      appLang.value = AppLang.ru;
      // Тап по сердцу с тех пор, как `recipe_card.dart` стал
      // session-aware (commit 3d981d7), требует залогиненного
      // пользователя — иначе показывается «нужна регистрация»
      // SnackBar и `store.toggle` не вызывается. Тест проверяет
      // именно happy-path toggle, поэтому имитируем
      // авторизованного юзера.
      userLoggedInNotifier.value = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    });

    tearDown(() async {
      favoritesStoreNotifier.value = null;
      userLoggedInNotifier.value = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      await db.close();
    });

    testWidgets('hero image hosts FavoriteBadge top-right', (tester) async {
      await tester.pumpWidget(_wrap(const RecipeDetailsPage(recipe: _recipe)));
      await tester.pump();

      expect(find.byType(FavoriteBadge), findsOneWidget);
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(FavoriteBadge),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, Icons.favorite_border);
    });

    testWidgets('tap on details badge toggles persist & re-renders filled', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const RecipeDetailsPage(recipe: _recipe)));
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.byType(FavoriteBadge));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(await store.isFavorite(7, AppLang.ru), isTrue);
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(FavoriteBadge),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, Icons.favorite);
    });
  });
}
