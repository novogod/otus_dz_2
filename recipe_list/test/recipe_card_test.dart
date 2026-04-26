import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/models/recipe.dart';
import 'package:recipe_list/ui/recipe_card.dart';

void main() {
  const recipe = Recipe(
    id: 1,
    name: 'Лазанья',
    duration: 60,
    photo: 'https://example.com/photo.jpg',
    description: 'Описание',
  );

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('RecipeCard', () {
    testWidgets('shows recipe name', (tester) async {
      await tester.pumpWidget(wrap(const RecipeCard(recipe: recipe)));
      expect(find.text('Лазанья'), findsOneWidget);
    });

    testWidgets('shows duration in "XX мин" format', (tester) async {
      await tester.pumpWidget(wrap(const RecipeCard(recipe: recipe)));
      expect(find.text('60 мин'), findsOneWidget);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(RecipeCard(recipe: recipe, onTap: () => taps++)),
      );
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });
}
