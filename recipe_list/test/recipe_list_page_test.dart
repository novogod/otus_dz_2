import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/models/recipe.dart';
import 'package:recipe_list/ui/recipe_card.dart';
import 'package:recipe_list/ui/recipe_list_page.dart';

void main() {
  List<Recipe> sample(int n) => [
    for (var i = 1; i <= n; i++)
      Recipe(
        id: i,
        name: 'Recipe $i',
        duration: 10 * i,
        photo: 'https://example.com/$i.jpg',
        description: 'desc $i',
      ),
  ];

  Widget wrap(Widget child) => MaterialApp(home: child);

  group('RecipeListPage', () {
    testWidgets('renders one RecipeCard per recipe', (tester) async {
      // Make the surface tall enough so that lazy ListView.builder
      // materialises all 3 cards.
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap(RecipeListPage(recipes: sample(3))));
      expect(find.byType(RecipeCard), findsNWidgets(3));
    });

    testWidgets('shows empty state when list is empty', (tester) async {
      await tester.pumpWidget(wrap(const RecipeListPage(recipes: [])));
      expect(find.text('Нет рецептов'), findsOneWidget);
      expect(find.byType(RecipeCard), findsNothing);
    });

    testWidgets('uses a scrollable ListView', (tester) async {
      await tester.pumpWidget(wrap(RecipeListPage(recipes: sample(10))));
      expect(find.byType(Scrollable), findsWidgets);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('AppBar shows "Рецепты"', (tester) async {
      await tester.pumpWidget(wrap(RecipeListPage(recipes: sample(2))));
      expect(find.widgetWithText(AppBar, 'Рецепты'), findsOneWidget);
    });
  });
}
