// recipe_list/lib/auth/passkey_web.dart
//
// Web implementation of the passkey API. Calls into the
// `window.recipeAppPasskey` global exposed by
// recipe_list/web/passkey_bridge.js (Chunk 23).
//
// We intentionally keep the JS surface tiny — three async
// methods, plain JSON in / plain JSON out — so the Dart side does
// no ArrayBuffer wrangling and is bullet-proof under dart2js and
// dart2wasm alike. All WebAuthn binary encoding happens in the JS
// bridge.
//
// Selected by the conditional import in passkey_api.dart when
// `dart.library.js_interop` is true.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'passkey_api.dart';

@JS('recipeAppPasskey')
external _RecipeAppPasskeyJS? get _recipeAppPasskey;

@JS()
extension type _RecipeAppPasskeyJS._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> register(JSString token);
  external JSPromise<JSAny?> login(JSString? email);
  external JSPromise<JSAny?> available();
}

@JS('window.PublicKeyCredential')
external JSAny? get _publicKeyCredential;

@JS('window.location.hostname')
external String get _hostname;

/// WebAuthn RP-ID for this app. Passkeys are bound to this host
/// (or any subdomain of it) and CANNOT be used from another
/// origin such as `snackhack.app`. Keep in sync with the backend
/// configuration — see docs/login-auth.md.
const String _passkeyRpId = 'mahallem.ist';

bool _hostMatchesRpId() {
  final h = _hostname.toLowerCase();
  return h == _passkeyRpId || h.endsWith('.$_passkeyRpId');
}

bool isPasskeySupported() {
  // Three requirements: the JS bridge has been loaded (window.
  // recipeAppPasskey exists), the browser exposes WebAuthn
  // (window.PublicKeyCredential), AND the current origin matches
  // the RP-ID under which passkeys were registered. WebAuthn
  // ceremonies will hard-fail with SecurityError on a mismatched
  // origin, so we hide the affordance instead of letting the user
  // burn cycles re-tapping a button that can never succeed.
  return _recipeAppPasskey != null &&
      _publicKeyCredential != null &&
      _hostMatchesRpId();
}

Future<PasskeyAvailability> probePasskeyAvailability() async {
  final bridge = _recipeAppPasskey;
  if (bridge == null || _publicKeyCredential == null || !_hostMatchesRpId()) {
    return PasskeyAvailability.unsupported;
  }
  final result = await bridge.available().toDart;
  if (result == null) return PasskeyAvailability.unsupported;
  final obj = result as JSObject;
  return PasskeyAvailability(
    supported: _readBool(obj, 'supported'),
    platformAvailable: _readBool(obj, 'platformAvailable'),
    conditionalUI: _readBool(obj, 'conditionalUI'),
  );
}

Future<void> registerPasskey({required String token}) async {
  final bridge = _recipeAppPasskey;
  if (bridge == null || _publicKeyCredential == null) {
    throw const PasskeyUnsupportedException(
      'WebAuthn is not available in this browser',
    );
  }
  if (!_hostMatchesRpId()) {
    throw const PasskeyUnsupportedException(
      'Passkey sign-in is only available on recipies.mahallem.ist. '
      'Open the app on that domain to register or use a passkey.',
    );
  }
  await bridge.register(token.toJS).toDart;
}

Future<PasskeyLoginResult> loginWithPasskey({String? email}) async {
  final bridge = _recipeAppPasskey;
  if (bridge == null || _publicKeyCredential == null) {
    throw const PasskeyUnsupportedException(
      'WebAuthn is not available in this browser',
    );
  }
  if (!_hostMatchesRpId()) {
    throw const PasskeyUnsupportedException(
      'Passkey sign-in is only available on recipies.mahallem.ist. '
      'Open the app on that domain to sign in with your passkey.',
    );
  }
  final result = await bridge.login(email?.toJS).toDart;
  if (result == null) {
    throw Exception('Passkey login returned no result');
  }
  final obj = result as JSObject;
  if (!_readBool(obj, 'success')) {
    final err = _readString(obj, 'error') ?? 'Passkey login failed';
    throw Exception(err);
  }
  final token = _readString(obj, 'token');
  if (token == null || token.isEmpty) {
    throw Exception('Passkey login missing token');
  }
  final user = obj.getProperty<JSObject?>('user'.toJS);
  if (user == null) {
    throw Exception('Passkey login missing user');
  }
  return PasskeyLoginResult(
    token: token,
    userId: _readString(user, 'id') ?? '',
    email: _readString(user, 'email') ?? '',
    fullName: _readString(user, 'fullName'),
    isAdmin: _readBool(user, 'isAdmin'),
    preferredLanguage: _readString(user, 'preferredLanguage'),
    avatarUrl: _readString(user, 'avatarUrl'),
  );
}

bool _readBool(JSObject obj, String key) {
  final v = obj.getProperty<JSAny?>(key.toJS);
  if (v == null) return false;
  if (v.isA<JSBoolean>()) return (v as JSBoolean).toDart;
  return false;
}

String? _readString(JSObject obj, String key) {
  final v = obj.getProperty<JSAny?>(key.toJS);
  if (v == null) return null;
  if (v.isA<JSString>()) return (v as JSString).toDart;
  return null;
}
