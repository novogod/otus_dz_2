// Chunk F of docs/user-card-and-social-signals.md.
//
// Widget tests for [AddedByRow]. We avoid hitting the network by
// pumping with HttpOverrides that return an empty response — the
// avatar Image.network will fall through to errorBuilder, which is
// fine for these tests (we assert text + presence/absence, not
// pixel-perfect image rendering; that's the golden test's job).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/i18n/strings.g.dart';
import 'package:recipe_list/ui/social/added_by_row.dart';

Widget _harness(Widget child) => TranslationProvider(
  child: MaterialApp(
    supportedLocales: const [Locale('en')],
    locale: const Locale('en'),
    home: Scaffold(body: child),
  ),
);

void main() {
  group('AddedByRow', () {
    testWidgets('renders name + recipes count', (tester) async {
      await tester.pumpWidget(
        _harness(
          const AddedByRow(
            name: 'Alice',
            avatarPath: null,
            recipesAdded: 12,
          ),
        ),
      );

      expect(find.textContaining('Alice'), findsOneWidget);
      expect(find.text('12 recipes'), findsOneWidget);
    });

    testWidgets('shrinks completely when name is null', (tester) async {
      await tester.pumpWidget(
        _harness(
          const AddedByRow(
            name: null,
            avatarPath: 'food-avatars/u/1.jpg',
            recipesAdded: 5,
          ),
        ),
      );

      // No avatar, no text — just the Scaffold body's empty space.
      expect(find.byType(Image), findsNothing);
      expect(find.textContaining('by'), findsNothing);
    });

    testWidgets('hides count line when recipesAdded is null', (tester) async {
      await tester.pumpWidget(
        _harness(
          const AddedByRow(
            name: 'Bob',
            avatarPath: null,
            recipesAdded: null,
          ),
        ),
      );

      expect(find.textContaining('Bob'), findsOneWidget);
      // Count text uses "{n} recipes" pattern; no count means no
      // such text exists.
      expect(find.textContaining('recipes'), findsNothing);
    });

    testWidgets('hides count line when recipesAdded is 0', (tester) async {
      await tester.pumpWidget(
        _harness(
          const AddedByRow(
            name: 'Carol',
            avatarPath: null,
            recipesAdded: 0,
          ),
        ),
      );

      expect(find.textContaining('Carol'), findsOneWidget);
      expect(find.textContaining('recipes'), findsNothing);
    });

    testWidgets('renders person icon when avatarPath is null', (tester) async {
      await tester.pumpWidget(
        _harness(
          const AddedByRow(
            name: 'Dave',
            avatarPath: null,
            recipesAdded: 1,
          ),
        ),
      );

      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('singular form for recipesAdded == 1', (tester) async {
      await tester.pumpWidget(
        _harness(
          const AddedByRow(
            name: 'Eve',
            avatarPath: null,
            recipesAdded: 1,
          ),
        ),
      );

      expect(find.text('1 recipe'), findsOneWidget);
    });
  });
}
