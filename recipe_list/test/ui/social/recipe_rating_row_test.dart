import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/i18n/strings.g.dart';
import 'package:recipe_list/ui/social/recipe_rating_row.dart';

void main() {
  Widget wrap(Widget child) => TranslationProvider(
    child: MaterialApp(home: Scaffold(body: child)),
  );

  group('RecipeRatingRow', () {
    testWidgets('shows 5 stars and avg + votes when count > 0', (tester) async {
      LocaleSettings.setLocale(AppLocale.en);
      await tester.pumpWidget(
        wrap(const RecipeRatingRow(count: 4, sum: 17, my: null, onRate: null)),
      );
      // 5 outline stars (no `my`).
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(5));
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      // Average rendered.
      expect(find.text('4.3 / 5'), findsOneWidget);
    });

    testWidgets('shows fill-in pattern matching `my`', (tester) async {
      LocaleSettings.setLocale(AppLocale.en);
      await tester.pumpWidget(
        wrap(const RecipeRatingRow(count: 1, sum: 3, my: 3, onRate: null)),
      );
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(2));
    });

    testWidgets('shows tooltip-only line when count == 0', (tester) async {
      LocaleSettings.setLocale(AppLocale.en);
      await tester.pumpWidget(
        wrap(RecipeRatingRow(count: 0, sum: 0, my: null, onRate: (_) {})),
      );
      expect(find.text('Tap a star to rate'), findsOneWidget);
    });

    testWidgets('compact variant renders nothing when count is 0', (
      tester,
    ) async {
      LocaleSettings.setLocale(AppLocale.en);
      await tester.pumpWidget(
        wrap(
          const RecipeRatingRow(
            count: 0,
            sum: 0,
            my: null,
            onRate: null,
            compact: true,
          ),
        ),
      );
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets(
      'compact variant renders single star + avg + count when count > 0',
      (tester) async {
        LocaleSettings.setLocale(AppLocale.en);
        await tester.pumpWidget(
          wrap(
            const RecipeRatingRow(
              count: 12,
              sum: 48,
              my: null,
              onRate: null,
              compact: true,
            ),
          ),
        );
        expect(find.byIcon(Icons.star_rounded), findsOneWidget);
        expect(find.text('4.0'), findsOneWidget);
        expect(find.text('(12)'), findsOneWidget);
      },
    );

    testWidgets('tap on a star fires onRate(value)', (tester) async {
      LocaleSettings.setLocale(AppLocale.en);
      int? lastTap;
      await tester.pumpWidget(
        wrap(
          RecipeRatingRow(
            count: 0,
            sum: 0,
            my: null,
            onRate: (v) => lastTap = v,
          ),
        ),
      );
      // Tap the third star.
      await tester.tap(find.byIcon(Icons.star_outline_rounded).at(2));
      await tester.pump();
      expect(lastTap, 3);
    });
  });
}
