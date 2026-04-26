import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/models/recipe.dart';

void main() {
  const sampleJson = <String, dynamic>{
    'id': 42,
    'name': 'Test Dish',
    'duration': 30,
    'photo': 'https://example.com/photo.jpg',
    'description': 'Description text',
  };

  group('Recipe', () {
    test('fromJson parses all fields', () {
      final r = Recipe.fromJson(sampleJson);
      expect(r.id, 42);
      expect(r.name, 'Test Dish');
      expect(r.duration, 30);
      expect(r.photo, 'https://example.com/photo.jpg');
      expect(r.description, 'Description text');
    });

    test('toJson serialises all fields', () {
      final r = Recipe.fromJson(sampleJson);
      expect(r.toJson(), sampleJson);
    });

    test('round-trip fromJson/toJson preserves equality', () {
      final r = Recipe.fromJson(sampleJson);
      final r2 = Recipe.fromJson(r.toJson());
      expect(r, equals(r2));
      expect(r.hashCode, equals(r2.hashCode));
    });
  });
}
