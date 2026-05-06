import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/i18n.dart';
import 'package:recipe_list/i18n/strings.g.dart';
import 'package:recipe_list/models/recipe.dart';
import 'package:recipe_list/ui/recipe_card.dart';

void main() {
  const fullRecipe = Recipe(
    id: 1,
    name: 'Teriyaki Chicken Casserole',
    photo: 'https://example.com/photo.jpg',
    category: 'Chicken',
    area: 'Japanese',
    tags: ['Meat', 'Casserole'],
    instructions: 'Cook it.',
    ingredients: [
      RecipeIngredient(name: 'soy sauce', measure: '3/4 cup'),
      RecipeIngredient(name: 'water', measure: '1/2 cup'),
      RecipeIngredient(name: 'brown sugar', measure: '1/4 cup'),
    ],
  );

  const liteRecipe = Recipe(
    id: 2,
    name: 'Baked salmon',
    photo: 'https://example.com/lite.jpg',
  );

  Widget wrap(Widget child) => TranslationProvider(
    child: MaterialApp(
      supportedLocales: const [Locale('en')],
      locale: const Locale('en'),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  group('RecipeCard', () {
    testWidgets('full recipe shows name, badges, tags and ingredient count', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const RecipeCard(recipe: fullRecipe)));
      final s = S.of(tester.element(find.byType(RecipeCard)));
      expect(find.text('Teriyaki Chicken Casserole'), findsOneWidget);
      expect(find.text('Chicken'), findsOneWidget);
      expect(find.text('Japanese'), findsOneWidget);
      expect(find.text('#Meat'), findsOneWidget);
      expect(find.text('#Casserole'), findsOneWidget);
      expect(find.text(s.ingredientCount(3)), findsOneWidget);
    });

    testWidgets('lite recipe shows only photo + name', (tester) async {
      await tester.pumpWidget(wrap(const RecipeCard(recipe: liteRecipe)));
      expect(find.text('Baked salmon'), findsOneWidget);
      expect(find.textContaining('ingredient'), findsNothing);
      expect(find.text('Chicken'), findsNothing);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(RecipeCard(recipe: fullRecipe, onTap: () => taps++)),
      );
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(taps, 1);
    });
  });
}
