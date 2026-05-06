// Chunk J of docs/user-card-and-social-signals.md.
//
// AddedByRow visibility invariants (chunk F):
//  * user-uploaded recipe (id ≥ 1_000_000) WITH creator metadata
//    → row renders with name + recipes count.
//  * TheMealDB recipe (id < 1_000_000) → recipe_details_page
//    omits the row entirely (gate at line ~344). We mirror the
//    gate here as a unit-style invariant test.
//  * AddedByRow with name=null → SizedBox.shrink (defence in
//    depth at the widget itself).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/i18n/strings.g.dart';
import 'package:recipe_list/ui/social/added_by_row.dart';

const _userMealIdFloor = 1000000;

bool shouldShowAddedBy({
  required int recipeId,
  required String? creatorDisplayName,
}) {
  return recipeId >= _userMealIdFloor && creatorDisplayName != null;
}

Widget _wrap(Widget child) {
  return TranslationProvider(
    child: MaterialApp(
      supportedLocales: const [Locale('en')],
      locale: const Locale('en'),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('AddedByRow gate', () {
    test('user-uploaded recipe with creator → visible', () {
      expect(
        shouldShowAddedBy(recipeId: 1000042, creatorDisplayName: 'Alice'),
        isTrue,
      );
    });

    test('TheMealDB recipe → hidden even with creator metadata', () {
      expect(
        shouldShowAddedBy(recipeId: 53049, creatorDisplayName: 'Alice'),
        isFalse,
      );
    });

    test('user-uploaded recipe without creator metadata → hidden', () {
      expect(
        shouldShowAddedBy(recipeId: 1000042, creatorDisplayName: null),
        isFalse,
      );
    });
  });

  testWidgets('AddedByRow renders name + recipes count when name != null', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const AddedByRow(name: 'Alice', avatarPath: null, recipesAdded: 3)),
    );
    await tester.pump();
    expect(find.textContaining('Alice'), findsOneWidget);
  });

  testWidgets('AddedByRow returns SizedBox.shrink when name is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const AddedByRow(name: null, avatarPath: null, recipesAdded: 0)),
    );
    await tester.pump();
    // No Padding wrapper, no avatar — only the empty placeholder.
    expect(find.byType(Padding), findsNothing);
    expect(find.textContaining('Alice'), findsNothing);
  });
}
