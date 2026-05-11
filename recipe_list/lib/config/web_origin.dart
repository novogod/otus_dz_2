/// Single source of truth for the recipes app's public web origin.
///
/// Used wherever the app builds canonical URLs, share URLs, deep-link
/// fallbacks, JSON-LD `@id`s, sitemap entries, or other strings that
/// must agree with the hostname that serves the SPA.
///
/// **Not** the API origin — that is owned by
/// `RecipeApiConfig.mahallemBaseUrl`, which by default derives from
/// this constant (`${WebOrigin.origin}/recipes`).
///
/// **Not** the parent / storage origin — `mahallem.ist` hosts imgproxy,
/// storage, admin auth, and the WebAuthn RP-ID, and stays referenced
/// directly in [imgproxy.dart] and [admin_session.dart]. See
/// `docs/extensions_for_v2/migration-to-snackhack.app.md` §1.2.
///
/// Override at build time:
/// ```
/// flutter build web --release \
///   --dart-define=RECIPES_WEB_ORIGIN=https://example.test
/// ```
class WebOrigin {
  WebOrigin._();

  /// Public origin of the SPA, no trailing slash.
  static const String origin = String.fromEnvironment(
    'RECIPES_WEB_ORIGIN',
    defaultValue: 'https://snackhack.app',
  );
}
