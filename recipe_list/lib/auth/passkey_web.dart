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

bool isPasskeySupported() {
  // Two requirements: the JS bridge has been loaded (window.
  // recipeAppPasskey exists) AND the browser has WebAuthn at all
  // (window.PublicKeyCredential exists). Either one missing means
  // the surface is unusable.
  return _recipeAppPasskey != null && _publicKeyCredential != null;
}

Future<PasskeyAvailability> probePasskeyAvailability() async {
  final bridge = _recipeAppPasskey;
  if (bridge == null || _publicKeyCredential == null) {
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
  await bridge.register(token.toJS).toDart;
}

Future<PasskeyLoginResult> loginWithPasskey({String? email}) async {
  final bridge = _recipeAppPasskey;
  if (bridge == null || _publicKeyCredential == null) {
    throw const PasskeyUnsupportedException(
      'WebAuthn is not available in this browser',
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
