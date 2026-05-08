// recipe_list/lib/auth/passkey_api.dart
//
// Public Dart surface for the recipe-app web biometric (passkey)
// flow. Calls into a tiny JS bridge (web/passkey_bridge.js) on web
// and throws PasskeyUnsupportedException everywhere else.
//
// On web the JS bridge POSTs to /recipes/auth/passkey/{register,
// login}/{start,complete}; the Dart wrapper just hands the result
// dict back. On iOS / Android / desktop we keep the existing
// local_auth-based flow (Chunks 1-7) — passkeys are only a
// fallback for browsers that don't have a native biometric API.
//
// The conditional import follows the standard Flutter pattern:
//   * `passkey_stub.dart`     — non-web, throws.
//   * `passkey_web.dart`      — web, calls JS bridge.
// Selection is by the `dart.library.js_interop` library check
// (true on dart2js / dart2wasm web, false on VM / native).
//
// Deployed as part of Chunk 24 of
// todo/auth-session-401-recurrence-2026-05-08.md.

import 'passkey_stub.dart'
    if (dart.library.js_interop) 'passkey_web.dart'
    as impl;

class PasskeyUnsupportedException implements Exception {
  const PasskeyUnsupportedException([this.message = 'Passkey not supported']);
  final String message;
  @override
  String toString() => 'PasskeyUnsupportedException: $message';
}

class PasskeyLoginResult {
  const PasskeyLoginResult({
    required this.token,
    required this.userId,
    required this.email,
    required this.fullName,
    required this.isAdmin,
    this.preferredLanguage,
    this.avatarUrl,
  });

  final String token;
  final String userId;
  final String email;
  final String? fullName;
  final bool isAdmin;
  final String? preferredLanguage;
  final String? avatarUrl;
}

class PasskeyAvailability {
  const PasskeyAvailability({
    required this.supported,
    required this.platformAvailable,
    required this.conditionalUI,
  });

  final bool supported;
  final bool platformAvailable;
  final bool conditionalUI;

  static const PasskeyAvailability unsupported = PasskeyAvailability(
    supported: false,
    platformAvailable: false,
    conditionalUI: false,
  );
}

/// True iff the current build is the web build *and* the browser
/// exposes `window.PublicKeyCredential`. Cheap & synchronous —
/// safe to call from `build()` to gate UI.
bool get isPasskeySupported => impl.isPasskeySupported();

/// Async feature-detect: returns `platformAvailable=true` when the
/// device has a built-in authenticator (Touch ID / Windows Hello /
/// Android biometric). Throws [PasskeyUnsupportedException] on
/// non-web platforms.
Future<PasskeyAvailability> probePasskeyAvailability() =>
    impl.probePasskeyAvailability();

/// Register a new passkey for the currently-authenticated recipe-app
/// user. Caller must pass the existing `x-recipes-user-token` so
/// the backend can attach the new credential to the right account.
///
/// Throws [PasskeyUnsupportedException] when not on web, or when
/// `window.PublicKeyCredential` is missing.
Future<void> registerPasskey({required String token}) =>
    impl.registerPasskey(token: token);

/// Sign in with a passkey. Optional [email] scopes the
/// authenticator allow-list to that user; omitting it lets the
/// browser pick a discoverable credential.
///
/// On success the backend mints a fresh `x-recipes-user-token` —
/// the caller must drop it into `currentUserTokenNotifier` and
/// reflect the resulting `isAdmin` flag in `adminLoggedInNotifier`.
///
/// Throws [PasskeyUnsupportedException] when not on web.
Future<PasskeyLoginResult> loginWithPasskey({String? email}) =>
    impl.loginWithPasskey(email: email);
