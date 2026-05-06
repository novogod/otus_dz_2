// Chunk H of docs/user-card-and-social-signals.md.
//
// Widget tests for the refactored FavoriteBadge.
//
// FavoriteBadge listens to two ValueNotifiers (favoritesStoreNotifier
// and appLang) plus userLoggedInNotifier on tap. To test purely the
// view layer (square vs pill, icon state, count rendering) we keep
// `favoritesStoreNotifier` at null — the badge then renders its
// "store == null" branch which produces a stable view with the
// supplied isFavorite=false. That is enough to exercise the four
// scenarios spelled out in the chunk-H doc.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/i18n/strings.g.dart';
import 'package:recipe_list/ui/recipe_card.dart';

Widget _harness(Widget child) => TranslationProvider(
  child: MaterialApp(
    supportedLocales: const [Locale('en')],
    locale: const Locale('en'),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('FavoriteBadge layout', () {
    testWidgets(
      'default — pill with "0" and outline heart even when count is zero',
      (tester) async {
        await tester.pumpWidget(_harness(const FavoriteBadge(recipeId: 1)));

        // Spec: heart is ALWAYS a pill with a visible count, including 0.
        expect(find.text('0'), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      },
    );

    testWidgets('showCount = false → legacy 32×32 square, no number', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const FavoriteBadge(recipeId: 2, showCount: false)),
      );

      // No number text.
      expect(find.text('0'), findsNothing);
      // Outline heart (logged-out / not favorited path).
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      // Square: a circular DecoratedBox with the legacy black-65 color.
      final decoratedBoxes = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final squareCount = decoratedBoxes.where((d) {
        final dec = d.decoration;
        return dec is BoxDecoration && dec.shape == BoxShape.circle;
      }).length;
      expect(squareCount, greaterThanOrEqualTo(1));
    });

    testWidgets(
      'showCount = true, favoritesCount = 0 → pill with "0" + outline heart',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            const FavoriteBadge(
              recipeId: 3,
              favoritesCount: 0,
              showCount: true,
            ),
          ),
        );

        expect(find.text('0'), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      },
    );

    testWidgets(
      'showCount = true, favoritesCount = 7 → pill with "7" + outline heart',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            const FavoriteBadge(
              recipeId: 4,
              favoritesCount: 7,
              showCount: true,
            ),
          ),
        );

        // Number rendered.
        expect(find.text('7'), findsOneWidget);
        // Outline heart (not yet favorited; store=null in this harness).
        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
        expect(find.byIcon(Icons.favorite), findsNothing);
        // Pill is dark-translucent: number is white.
        final text = tester.widget<Text>(find.text('7'));
        expect(text.style!.color, Colors.white);
      },
    );

    testWidgets('large count renders verbatim', (tester) async {
      await tester.pumpWidget(
        _harness(
          const FavoriteBadge(
            recipeId: 5,
            favoritesCount: 1234,
            showCount: true,
          ),
        ),
      );
      expect(find.text('1234'), findsOneWidget);
    });
  });
}
