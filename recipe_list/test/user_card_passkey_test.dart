// recipe_list/test/user_card_passkey_test.dart
//
// Source-shape assertions for the "Add passkey" button added to
// UserCardPage as part of the passkey-on-profile feature.
//
// Verifies:
//   * user_card_page.dart imports passkey_api.
//   * _addPasskey() method is present and calls passkey_api.registerPasskey
//     on web and saveCurrentSessionForBiometricLogin on native.
//   * _buildPasskeyButton() widget is present and uses Icons.fingerprint.
//   * The button is wired into the build() column (call site).

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File(
    '${Directory.current.path}/lib/ui/user_card_page.dart',
  ).readAsStringSync();

  group('UserCardPage — passkey button', () {
    test('imports passkey_api', () {
      expect(
        src,
        contains("import '../auth/passkey_api.dart'"),
        reason: 'user_card_page.dart must import passkey_api.dart',
      );
    });

    test('imports kIsWeb via flutter/foundation.dart', () {
      expect(
        src,
        contains("import 'package:flutter/foundation.dart'"),
        reason:
            'user_card_page.dart must import foundation.dart for kIsWeb check',
      );
    });

    test('_passkeyBusy state variable is declared', () {
      expect(
        src,
        contains('bool _passkeyBusy = false'),
        reason: 'must have a dedicated busy flag for the passkey action',
      );
    });

    test('_addPasskey calls passkey_api.registerPasskey on web', () {
      expect(
        src,
        contains('passkey_api.registerPasskey'),
        reason:
            '_addPasskey() must call passkey_api.registerPasskey in the kIsWeb branch',
      );
    });

    test('_addPasskey calls saveCurrentSessionForBiometricLogin on native', () {
      expect(
        src,
        contains('saveCurrentSessionForBiometricLogin'),
        reason:
            '_addPasskey() must call saveCurrentSessionForBiometricLogin in the native branch',
      );
    });

    test('_buildPasskeyButton is declared', () {
      expect(
        src,
        contains('Widget _buildPasskeyButton()'),
        reason: 'must have a _buildPasskeyButton() method',
      );
    });

    test('_buildPasskeyButton uses fingerprint icon', () {
      expect(
        src,
        contains('Icons.fingerprint'),
        reason: 'passkey button must use Icons.fingerprint as its icon',
      );
    });

    test('_buildPasskeyButton is called from build()', () {
      expect(
        src,
        contains('_buildPasskeyButton()'),
        reason: '_buildPasskeyButton() must be called from the build column',
      );
    });
  });
}
