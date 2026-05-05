// Web-only bridge to `navigator.share` / `navigator.canShare`.
//
// When supported (iOS/iPadOS Safari, Android Chrome, recent Edge,
// Safari macOS) this opens the OS-level share sheet which lists
// every installed app — so tapping our share buttons can hand off
// to the real Instagram / WhatsApp / Facebook / Messages app
// instead of opening yet another browser tab.
import 'dart:js_interop';

@JS('navigator.share')
external JSFunction? _navigatorShare;

@JS('navigator')
external _Navigator get _navigator;

extension type _Navigator._(JSObject _) implements JSObject {
  external JSPromise share(JSObject data);
}

extension type _ShareData._(JSObject _) implements JSObject {
  external factory _ShareData({String? title, String? text, String? url});
}

bool canWebShare() {
  try {
    return _navigatorShare != null;
  } catch (_) {
    return false;
  }
}

/// Triggers the system share sheet. Returns `true` if the call was
/// dispatched successfully (user may still cancel — that resolves
/// to `false`). Returns `false` if the API is unavailable or the
/// browser threw synchronously.
Future<bool> webShare({String? title, String? text, String? url}) async {
  if (!canWebShare()) return false;
  final data = _ShareData(title: title, text: text, url: url);
  try {
    await _navigator.share(data).toDart;
    return true;
  } catch (_) {
    // User cancelled, or browser blocked (requires user activation,
    // https-only, etc.). Caller will fall back to a web sharer URL.
    return false;
  }
}
