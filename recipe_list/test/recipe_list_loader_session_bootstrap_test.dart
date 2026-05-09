import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecipeListLoader session bootstrap guard', () {
    test('loader rehydrates auth only when no live session exists', () {
      final src = File(
        '${Directory.current.path}/lib/ui/recipe_list_loader.dart',
      ).readAsStringSync();

      expect(src, contains('final hasLiveSession ='));
      expect(src, contains('if (!hasLiveSession) {'));
      expect(src, contains('await bootstrapAdminSession(db: db);'));
      expect(
        src,
        contains('currentRecipeAdminTokenNotifier.value?.isNotEmpty'),
      );
      expect(
        src,
        contains('currentUserLoginNotifier.value?.trim().isNotEmpty'),
      );
    });
  });
}
