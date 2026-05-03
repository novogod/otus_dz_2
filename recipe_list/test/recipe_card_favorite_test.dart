import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/auth/admin_session.dart';
import 'package:recipe_list/data/local/recipe_db.dart';
import 'package:recipe_list/data/repository/favorites_store.dart';
import 'package:recipe_list/i18n.dart';
import 'package:recipe_list/models/recipe.dart';
import 'package:recipe_list/ui/recipe_card.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _recipe = Recipe(
  id: 42,
  name: 'Borscht',
  photo: 'https://example.com/p.jpg',
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

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecipeCard favorite badge', () {
    late Database db;
    late FavoritesStore store;

    setUp(() async {
      db = await _openInMemoryDb();
      store = FavoritesStore(db: db);
      favoritesStoreNotifier.value = store;
      userLoggedInNotifier.value = true;
      appLang.value = AppLang.ru;
      // HapticFeedback.lightImpact() в карточке ходит в method
      // channel; в headless-тестах он висит без ответа платформы.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') return null;
            return null;
          });
    });

    tearDown(() async {
      favoritesStoreNotifier.value = null;
      userLoggedInNotifier.value = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      await db.close();
    });

    testWidgets('outlined heart visible when not in favorites', (tester) async {
      await tester.pumpWidget(_wrap(const RecipeCard(recipe: _recipe)));
      await tester.pump(); // ValueListenableBuilder initial frame

      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(FavoriteBadge),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, Icons.favorite_border);
      expect(icon.color, Colors.white);
    });

    testWidgets('tap toggles to filled green heart and persists', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const RecipeCard(recipe: _recipe)));
      await tester.pump();

      // Тапы в InkWell дёргают sqflite_ffi (real I/O), который
      // не прокручивается внутри fake_async-зоны testWidgets —
      // запускаем взаимодействие через runAsync, чтобы подждать
      // реальных microtasks БД.
      await tester.runAsync(() async {
        await tester.tap(find.byType(FavoriteBadge));
        // Даём время был и результату toggle разорваться.
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(await store.isFavorite(42, AppLang.ru), isTrue);
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(FavoriteBadge),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, Icons.favorite);

      await tester.runAsync(() async {
        await tester.tap(find.byType(FavoriteBadge));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(await store.isFavorite(42, AppLang.ru), isFalse);
      final icon2 = tester.widget<Icon>(
        find.descendant(
          of: find.byType(FavoriteBadge),
          matching: find.byType(Icon),
        ),
      );
      expect(icon2.icon, Icons.favorite_border);
    });

    testWidgets('switching language hides favorite from another lang', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await store.add(42, AppLang.en);
      });
      appLang.value = AppLang.en;

      await tester.pumpWidget(_wrap(const RecipeCard(recipe: _recipe)));
      await tester.pump();

      var icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(FavoriteBadge),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, Icons.favorite);

      // Смена языка → favorite по EN не виден в RU.
      appLang.value = AppLang.ru;
      await tester.pump();
      icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(FavoriteBadge),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, Icons.favorite_border);
    });

    testWidgets(
      'without store + guest: outlined heart and registration snackbar',
      (tester) async {
        favoritesStoreNotifier.value = null;
        userLoggedInNotifier.value = false;
        await tester.pumpWidget(_wrap(const RecipeCard(recipe: _recipe)));
        await tester.pump();

        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byType(FavoriteBadge),
            matching: find.byType(Icon),
          ),
        );
        expect(icon.icon, Icons.favorite_border);

        await tester.tap(find.byType(FavoriteBadge));
        await tester.pump();

        expect(
          find.text(
            'Для этой функции нужна регистрация, пожалуйста нажмите кнопку Sign Up',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
