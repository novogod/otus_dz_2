// recipe_list/test/passkey_stub_test.dart
//
// Chunk 24 regression test for passkey_api.dart on the non-web
// (VM) target. The conditional import in passkey_api.dart resolves
// to passkey_stub.dart when `dart.library.js_interop` is false,
// which is the case under `flutter test` (it uses the Dart VM).
//
// We assert:
//   * isPasskeySupported() returns false
//   * probePasskeyAvailability() returns the unsupported sentinel
//   * registerPasskey / loginWithPasskey both throw
//     PasskeyUnsupportedException with a useful message
//
// On the web build, login_page.dart will gate on isPasskeySupported
// before invoking either of those — so this test pins the contract
// that an accidental non-web invocation fails loudly.

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/auth/passkey_api.dart';

void main() {
  group('passkey_api on non-web (VM)', () {
    test('isPasskeySupported returns false', () {
      expect(isPasskeySupported, isFalse);
    });

    test('probePasskeyAvailability returns unsupported', () async {
      final a = await probePasskeyAvailability();
      expect(a.supported, isFalse);
      expect(a.platformAvailable, isFalse);
      expect(a.conditionalUI, isFalse);
    });

    test('registerPasskey throws PasskeyUnsupportedException', () async {
      expect(
        () => registerPasskey(token: 'ignored'),
        throwsA(isA<PasskeyUnsupportedException>()),
      );
    });

    test('loginWithPasskey throws PasskeyUnsupportedException', () async {
      expect(
        () => loginWithPasskey(),
        throwsA(isA<PasskeyUnsupportedException>()),
      );
    });

    test('PasskeyUnsupportedException carries a message', () {
      const ex = PasskeyUnsupportedException('foo');
      expect(ex.message, 'foo');
      expect(ex.toString(), contains('foo'));
    });
  });
}
