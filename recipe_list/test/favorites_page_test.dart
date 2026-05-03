import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/auth/admin_session.dart';
import 'package:recipe_list/data/local/recipe_db.dart';
import 'package:recipe_list/data/repository/favorites_store.dart';
import 'package:recipe_list/data/repository/recipe_repository.dart';
import 'package:recipe_list/i18n.dart';
import 'package:recipe_list/models/recipe.dart';
import 'package:recipe_list/ui/favorites_page.dart';
import 'package:recipe_list/ui/lang_icon_button.dart';
import 'package:recipe_list/ui/recipe_card.dart';
import 'package:recipe_list/ui/reload_icon_button.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _ru1 = Recipe(id: 1, name: 'Borscht', photo: 'https://e/1.jpg');
const _ru2 = Recipe(id: 2, name: 'Plov', photo: 'https://e/2.jpg');
const _en1 = Recipe(id: 3, name: 'Pizza', photo: 'https://e/3.jpg');

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

Future<void> _seed(Database db, Recipe r, AppLang lang) async {
  await db.insert('recipes', writeRecipe(r, lang: lang.name, lastUsedAt: 0));
}

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FavoritesPage', () {
    late Database db;
    late FavoritesStore store;

    setUp(() async {
      db = await _openInMemoryDb();
      await _seed(db, _ru1, AppLang.ru);
      await _seed(db, _ru2, AppLang.ru);
      await _seed(db, _en1, AppLang.en);
      store = FavoritesStore(db: db);
      favoritesStoreNotifier.value = store;
      userLoggedInNotifier.value = true;
      appLang.value = AppLang.ru;
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

    testWidgets('empty state when nothing favorited', (tester) async {
      await tester.pumpWidget(_wrap(const FavoritesPage()));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.text('Пока ничего не добавлено'), findsOneWidget);
      expect(find.byType(RecipeCard), findsNothing);
    });

    testWidgets('lists only current-language favorites in saved order', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await store.add(_ru1.id, AppLang.ru);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await store.add(_ru2.id, AppLang.ru);
        await store.add(_en1.id, AppLang.en);
      });

      await tester.pumpWidget(_wrap(const FavoritesPage()));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.byType(RecipeCard, skipOffstage: false), findsNWidgets(2));
      expect(
        find.text('Pizza', skipOffstage: false),
        findsNothing,
      ); // EN — скрыто.
      // Самый свежий (_ru2) должен быть первым.
      final cards = tester
          .widgetList<RecipeCard>(find.byType(RecipeCard, skipOffstage: false))
          .toList();
      expect(cards[0].recipe.id, _ru2.id);
      expect(cards[1].recipe.id, _ru1.id);
    });

    testWidgets('local search filters favorites by case-fold substring', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await store.add(_ru1.id, AppLang.ru);
        await store.add(_ru2.id, AppLang.ru);
      });

      await tester.pumpWidget(_wrap(const FavoritesPage()));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.byType(RecipeCard, skipOffstage: false), findsNWidgets(2));

      await tester.enterText(find.byType(TextField), 'plo');
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.byType(RecipeCard, skipOffstage: false), findsOneWidget);
      expect(find.text('Plov', skipOffstage: false), findsOneWidget);
      expect(find.text('Borscht', skipOffstage: false), findsNothing);

      // Совпадений нет.
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(find.byType(RecipeCard, skipOffstage: false), findsNothing);
      expect(find.text('Совпадений не найдено'), findsOneWidget);
    });

    testWidgets('lang/reload buttons faded and not clickable', (tester) async {
      // Подсовываем lite-репозиторий, чтобы LangIconButton обнаружил
      // RecipeRepository (или нет — здесь нам важна только видимость
      // и IgnorePointer).
      await tester.pumpWidget(_wrap(const FavoritesPage()));
      await tester.pump();

      // Кнопка языка существует, но обёрнута IgnorePointer + Opacity.
      expect(find.byType(LangIconButton), findsOneWidget);
      // Reload-кнопка на favorites page не показывается (showReload=false).
      expect(find.byType(ReloadIconButton), findsNothing);

      final ignorePointer = tester.widget<IgnorePointer>(
        find
            .ancestor(
              of: find.byType(LangIconButton),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(ignorePointer.ignoring, isTrue);

      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byType(LangIconButton),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, lessThan(0.5));
    });
  });
}

// Помощник: компилятор должен видеть RecipeRepository, чтобы
// импорт не считался unused в случае правок.
// ignore: unused_element
RecipeRepository? _dummyRepo() => null;
