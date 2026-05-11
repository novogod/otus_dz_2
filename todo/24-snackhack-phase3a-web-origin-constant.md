# 24 — Snack Hack migration: Phase 3a — Centralise web origin

**Refs:** [migration-to-snackhack.app.md §3.1, §3.2](../docs/extensions_for_v2/migration-to-snackhack.app.md).
**Priority:** P0. **Scope:** `[client]`. **Owner:** TBD.
**Depends on:** [22-snackhack-phase1-parallel-hosting.md](22-snackhack-phase1-parallel-hosting.md).

## Goal

Replace every hard-coded `https://recipies.mahallem.ist` literal in Dart
source with a single `WebOrigin.origin` constant, defaulting to
`https://snackhack.app`, overridable via `--dart-define=RECIPES_WEB_ORIGIN`.

**Out of scope:** `mahallem.ist` literals (parent portal — see §1.2 of the plan).

## Changes

### New file `recipe_list/lib/config/web_origin.dart`

```dart
/// Single source of truth for the recipes app's public web origin.
///
/// Used by API base URL, share URLs, JSON-LD `@id`, canonical URLs,
/// sitemap entries, deep-link fallbacks.
///
/// Override at build time:
///   flutter build web --dart-define=RECIPES_WEB_ORIGIN=https://example.test
class WebOrigin {
  WebOrigin._();
  static const String origin = String.fromEnvironment(
    'RECIPES_WEB_ORIGIN',
    defaultValue: 'https://snackhack.app',
  );
}
```

### Edits

| File | Change |
|---|---|
| `recipe_list/lib/data/api/recipe_api_config.dart` line 23 | Default `mahallemBaseUrl` → `'${WebOrigin.origin}/recipes'` |
| `recipe_list/lib/ui/web_share/web_action_buttons.dart` lines 15–16 | `_kShareBaseUrl`/`_kShareOrigin` → derive from `WebOrigin.origin` |
| `recipe_list/lib/consent/startup_consent.dart` lines 166, 169 | Fallback `'https://recipies.mahallem.ist'` → `WebOrigin.origin` |
| `recipe_list/lib/ui/user_card_page.dart` lines 943, 945, 955 | Matcher also accepts `'snackhack.app'` host; canonical rewrite target stays `mahallem.ist` |
| `recipe_list/lib/utils/imgproxy.dart` line 45, 64 | Matcher also accepts `'snackhack.app'`; rewrite target stays `mahallem.ist` |
| `recipe_list/lib/main.dart` line 23, `lib/seo/seo_head.dart` line 10, `lib/seo/seo_head_stub.dart` line 3 | Update comments (cosmetic) |

## Acceptance

* `grep -rE 'recipies\.mahallem\.ist' recipe_list/lib` returns 0 hits.
* `grep -rE "'https://mahallem\.ist'" recipe_list/lib` still returns the
  imgproxy + admin_session constants (parent — must NOT change).
* All call sites that previously hard-coded `recipies.mahallem.ist` now
  reference `WebOrigin.origin` (verified by `grep -r WebOrigin recipe_list/lib`).

## Tests

```bash
cd recipe_list
flutter analyze
# Expect: 0 errors, 0 warnings introduced.

flutter test --no-pub test/
# Expect: all existing tests pass.
```

* Add `recipe_list/test/config/web_origin_test.dart`:
  ```dart
  test('defaults to snackhack.app', () {
    expect(WebOrigin.origin, 'https://snackhack.app');
  });
  ```
* Run share-button test (existing):
  `flutter test --no-pub test/ui/web_share/`.
  * Assert share URL prefix is `https://snackhack.app/`.

Origin override smoke:

```bash
flutter test --no-pub \
  --dart-define=RECIPES_WEB_ORIGIN=https://example.test \
  test/config/web_origin_test.dart
# Adjust the test to read the define and assert the override.
```
