// Conditional facade for the Web Share API (`navigator.share`).
// Returns a no-op stub on non-web targets.
export 'web_share_api_stub.dart'
    if (dart.library.js_interop) 'web_share_api_web.dart';
