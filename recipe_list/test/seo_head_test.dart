// Unit tests for the per-recipe SEO payload builder (todo/20 chunk F).
//
// These tests run on the Dart VM (no browser) and exercise the
// `RecipeSeo.toJson()` shape that ships across the JS-interop bridge
// to `window.setRecipeSeo` defined in `web/index.html`. The web /
// stub implementations themselves are platform-conditional and are
// covered by the prerender e2e (chunk E) on prod.
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/seo/seo_head.dart';

void main() {
  test('RecipeSeo.toJson includes the canonical fields', () {
    final seo = RecipeSeo(
      id: 52772,
      locale: 'en',
      title: 'Pasta',
      description: 'Boil water; add pasta.',
      image: 'https://recipies.mahallem.ist/img/pasta.jpg',
      category: 'Italian',
      area: 'Italian',
      ingredients: ['100g pasta', '1L water'],
      instructions: ['Boil water', 'Add pasta'],
    );
    final m = seo.toJson();
    expect(m['id'], 52772);
    expect(m['locale'], 'en');
    expect(m['title'], 'Pasta');
    expect(m['description'], 'Boil water; add pasta.');
    expect(m['image'], 'https://recipies.mahallem.ist/img/pasta.jpg');
    expect(m['category'], 'Italian');
    expect(m['area'], 'Italian');
    expect(m['ingredients'], ['100g pasta', '1L water']);
    expect(m['instructions'], ['Boil water', 'Add pasta']);
  });

  test('RecipeSeo.toJson omits null and empty-list fields', () {
    final seo = RecipeSeo(id: 1, locale: 'ru', title: 'X');
    final m = seo.toJson();
    expect(m.containsKey('description'), false);
    expect(m.containsKey('image'), false);
    expect(m.containsKey('category'), false);
    expect(m.containsKey('area'), false);
    expect(m.containsKey('ingredients'), false);
    expect(m.containsKey('instructions'), false);
  });

  test('setRecipeSeo / clearRecipeSeo are no-ops on the VM', () {
    // Stub implementation; nothing to assert beyond "doesn't throw".
    setRecipeSeo(RecipeSeo(id: 1, locale: 'en', title: 'X'));
    clearRecipeSeo();
  });
}
