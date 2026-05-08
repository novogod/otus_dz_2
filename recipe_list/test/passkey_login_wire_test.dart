// recipe_list/test/passkey_login_wire_test.dart
//
// Chunk 25 regression test. Source-shape assertions that verify:
//   * login_page.dart imports passkey_api (conditional web surface).
//   * The kIsWeb branch in _saveCurrentSessionForBiometric() calls
//     passkey_api.registerPasskey, NOT the old snackbar.
//   * The kIsWeb branch in _loginWithBiometrics() calls
//     passkey_api.loginWithPasskey, NOT the old snackbar.
//   * applyPasskeyLoginResult is defined in admin_session.dart.
//
// We read the source files as strings; no widget rendering needed.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final loginPageSrc = File(
    '${Directory.current.path}/lib/ui/login_page.dart',
  ).readAsStringSync();

  final adminSessionSrc = File(
    '${Directory.current.path}/lib/auth/admin_session.dart',
  ).readAsStringSync();

  group('Chunk 25 — passkey UI wiring', () {
    test('login_page.dart imports passkey_api', () {
      expect(
        loginPageSrc,
        contains("import '../auth/passkey_api.dart'"),
        reason: 'login_page.dart must import passkey_api.dart',
      );
    });

    test(
      '_saveCurrentSessionForBiometric calls passkey_api.registerPasskey on web',
      () {
        expect(
          loginPageSrc,
          contains('passkey_api.registerPasskey'),
          reason:
              'web kIsWeb branch must call passkey_api.registerPasskey, '
              'not show the old unsupported snackbar',
        );
      },
    );

    test('_loginWithBiometrics calls passkey_api.loginWithPasskey on web', () {
      expect(
        loginPageSrc,
        contains('passkey_api.loginWithPasskey'),
        reason:
            'web kIsWeb branch must call passkey_api.loginWithPasskey, '
            'not show the old unsupported snackbar',
      );
    });

    test(
      '_loginWithBiometrics calls applyPasskeyLoginResult after passkey login',
      () {
        expect(
          loginPageSrc,
          contains('applyPasskeyLoginResult'),
          reason:
              'login_page.dart must call applyPasskeyLoginResult to persist '
              'the new token+isAdmin into the session notifiers',
        );
      },
    );

    test('admin_session.dart defines applyPasskeyLoginResult', () {
      expect(
        adminSessionSrc,
        contains('Future<void> applyPasskeyLoginResult'),
        reason:
            'admin_session.dart must export applyPasskeyLoginResult for '
            'login_page.dart to call',
      );
    });

    test('old "not supported in web mode" snackbar text is removed', () {
      expect(
        loginPageSrc,
        isNot(contains('not supported in web mode')),
        reason:
            'The old hard-coded "not supported" snackbar text must be '
            'replaced by the passkey flow on web',
      );
    });

    test('login_page.dart renders the translated trust-device checkbox', () {
      expect(
        loginPageSrc,
        contains('CheckboxListTile.adaptive'),
        reason: 'LoginPage should render a checkbox for trusted-device opt-in',
      );
      expect(
        loginPageSrc,
        contains('s.loginTrustThisDevice'),
        reason: 'The trust-device checkbox label must come from i18n',
      );
    });

    test('password and passkey login both pass trustDevice state through', () {
      expect(
        loginPageSrc,
        contains('trustDevice: _trustThisDevice'),
        reason:
            'LoginPage must forward trust-device state to the login/persist layer',
      );
    });

    test('admin_session.dart exposes trustDevice-aware login helpers', () {
      expect(adminSessionSrc, contains('bool trustDevice = false'));
      expect(adminSessionSrc, contains('_persistTrustedSession'));
      expect(adminSessionSrc, contains('_clearPersistedSession'));
    });
  });
}
