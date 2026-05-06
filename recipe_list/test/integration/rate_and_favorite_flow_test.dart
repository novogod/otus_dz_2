// Chunk J of docs/user-card-and-social-signals.md.
//
// Lightweight integration sweep for the rating widget:
// renders RecipeRatingRow with a stub onRate, taps the 4th
// star, asserts the callback fires with stars=4. The full
// "snackbar + favorite pill" round-trip exists in
// recipe_card_favorite_test and recipe_details_favorite_test;
// this test glues the rating row to the same harness pattern
// so chunks G+I share an integration cover.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/i18n/strings.g.dart';
import 'package:recipe_list/ui/social/recipe_rating_row.dart';

void main() {
  testWidgets('tapping the 4th star fires onRate(4)', (tester) async {
    int? captured;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          supportedLocales: const [Locale('en')],
          locale: const Locale('en'),
          home: Scaffold(
            body: Center(
              child: RecipeRatingRow(
                count: 0,
                sum: 0,
                my: null,
                onRate: (v) => captured = v,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // The widget renders 5 GestureDetectors (one per star). Tap the 4th.
    final stars = find.byWidgetPredicate(
      (w) => w is GestureDetector && w.onTap != null,
    );
    expect(stars, findsNWidgets(5));
    await tester.tap(stars.at(3));
    await tester.pump();
    expect(captured, 4);
  });

  testWidgets('renders read-only when onRate is null', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          supportedLocales: const [Locale('en')],
          locale: const Locale('en'),
          home: const Scaffold(
            body: Center(
              child: RecipeRatingRow(
                count: 12,
                sum: 48,
                my: null,
                onRate: null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byWidgetPredicate((w) => w is GestureDetector && w.onTap != null),
      findsNothing,
    );
  });
}
