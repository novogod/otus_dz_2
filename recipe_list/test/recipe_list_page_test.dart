import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/i18n.dart';
import 'package:recipe_list/i18n/strings.g.dart';
import 'package:recipe_list/models/recipe.dart';
import 'package:recipe_list/ui/recipe_card.dart';
import 'package:recipe_list/ui/recipe_list_page.dart';

void main() {
  List<Recipe> sample(int n) => [
    for (var i = 1; i <= n; i++)
      Recipe(
        id: i,
        name: 'Recipe $i',
        photo: 'https://example.com/$i.jpg',
        category: 'Cat $i',
        area: 'Area $i',
      ),
  ];

  Widget wrap(Widget child) => TranslationProvider(
    child: MaterialApp(
      supportedLocales: const [Locale('en')],
      locale: const Locale('en'),
      home: child,
    ),
  );

  group('RecipeListPage', () {
    testWidgets('renders one RecipeCard per recipe', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(RecipeListPage(recipes: sample(3))));
      expect(find.byType(RecipeCard), findsNWidgets(3));
    });

    testWidgets('shows empty state when list is empty', (tester) async {
      await tester.pumpWidget(wrap(const RecipeListPage(recipes: [])));
      final s = S.of(tester.element(find.byType(RecipeListPage)));
      expect(find.text(s.emptyList), findsOneWidget);
      expect(find.byType(RecipeCard), findsNothing);
    });

    testWidgets('uses a scrollable collection view', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(RecipeListPage(recipes: sample(10))));
      expect(find.byType(Scrollable), findsWidgets);
      expect(
        find.byType(ListView).evaluate().length +
            find.byType(GridView).evaluate().length,
        greaterThan(0),
      );
    });

    testWidgets('does not show a global "Рецепты" header', (tester) async {
      await tester.pumpWidget(wrap(RecipeListPage(recipes: sample(2))));
      // У экрана есть AppBar с поиском (см. SearchAppBar), но в нём
      // не должно быть текстового заголовка «Рецепты» — это слово
      // зарезервировано за нижним навбаром (см. design_system §6).
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Рецепты'), findsNothing);
    });

    testWidgets('search field filters list on submit', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(RecipeListPage(recipes: sample(3))));
      expect(find.byType(RecipeCard), findsNWidgets(3));

      await tester.enterText(find.byType(TextField), 'Recipe 2');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.byType(RecipeCard), findsOneWidget);
    });
  });
}
