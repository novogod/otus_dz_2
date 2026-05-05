// Per-recipe SEO injection bridge (todo/20 chunk F).
//
// On web, calls into `window.setRecipeSeo({...})` defined in
// `web/index.html` to mutate document.head with title, description,
// canonical, hreflang × 10 + x-default, OG, Twitter, JSON-LD `Recipe`
// and the `<meta name="ssr-ready">` snapshot signal that the bot
// pre-renderer (todo/20 chunk E) waits for.
//
// On mobile / desktop (anything that's not web) it's a no-op — the
// search-engine surface lives at recipies.mahallem.ist only.
//
// Conditional import based on Flutter's standard pattern: stub
// implementation in `seo_head_stub.dart`, web implementation in
// `seo_head_web.dart`. Tests on the VM use the stub.
import 'seo_head_stub.dart'
    if (dart.library.js_interop) 'seo_head_web.dart' as impl;

class RecipeSeo {
  final int id;
  final String locale;
  final String title;
  final String? description;
  final String? image;
  final String? category;
  final String? area;
  final List<String> ingredients;
  final List<String> instructions;

  const RecipeSeo({
    required this.id,
    required this.locale,
    required this.title,
    this.description,
    this.image,
    this.category,
    this.area,
    this.ingredients = const [],
    this.instructions = const [],
  });

  /// Serialises the payload to a plain `Map<String, Object?>` so the
  /// web bridge can hand it straight to `window.setRecipeSeo`.
  ///
  /// Pure / side-effect free so we can unit-test it on the VM (where
  /// `dart:js_interop` isn't available).
  Map<String, Object?> toJson() => {
    'id': id,
    'locale': locale,
    'title': title,
    if (description != null) 'description': description,
    if (image != null) 'image': image,
    if (category != null) 'category': category,
    if (area != null) 'area': area,
    if (ingredients.isNotEmpty) 'ingredients': ingredients,
    if (instructions.isNotEmpty) 'instructions': instructions,
  };
}

/// Inject per-recipe SEO atoms into the document head. Web only;
/// no-op everywhere else.
void setRecipeSeo(RecipeSeo data) => impl.setRecipeSeo(data.toJson());

/// Remove the per-recipe SEO atoms (and the `ssr-ready` marker).
/// Called when the user leaves the details screen so home / list
/// pages don't keep a recipe canonical/hreflang stuck on the
/// document.
void clearRecipeSeo() => impl.clearRecipeSeo();
