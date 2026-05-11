// Unit test for [WebOrigin]. The constant is `String.fromEnvironment`,
// so this asserts the default value baked into the bundle when no
// `--dart-define=RECIPES_WEB_ORIGIN=...` is passed.
//
// To test an override:
//   flutter test --dart-define=RECIPES_WEB_ORIGIN=https://example.test \
//                test/config/web_origin_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/config/web_origin.dart';

void main() {
  test('WebOrigin.origin defaults to https://snackhack.app', () {
    expect(WebOrigin.origin, 'https://snackhack.app');
  });

  test('WebOrigin.origin has no trailing slash', () {
    expect(WebOrigin.origin.endsWith('/'), isFalse);
  });

  test('WebOrigin.origin is a valid absolute https URL', () {
    final uri = Uri.tryParse(WebOrigin.origin);
    expect(uri, isNotNull);
    expect(uri!.scheme, 'https');
    expect(uri.host, isNotEmpty);
  });
}
