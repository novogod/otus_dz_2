// recipe_list/lib/auth/passkey_stub.dart
//
// Non-web implementation of the passkey API. Every call throws
// PasskeyUnsupportedException so a caller that forgets to gate
// on `kIsWeb` fails loud instead of silently doing nothing.
//
// Selected by the conditional import in passkey_api.dart on
// non-web targets (iOS / Android / desktop / VM).

import 'passkey_api.dart';

bool isPasskeySupported() => false;

Future<PasskeyAvailability> probePasskeyAvailability() async =>
    PasskeyAvailability.unsupported;

Future<void> registerPasskey({required String token}) async {
  throw const PasskeyUnsupportedException(
    'Passkey registration is only available on the web build',
  );
}

Future<PasskeyLoginResult> loginWithPasskey({String? email}) async {
  throw const PasskeyUnsupportedException(
    'Passkey login is only available on the web build',
  );
}
