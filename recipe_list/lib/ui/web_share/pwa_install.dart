// Conditional facade: re-exports the web implementation when
// compiling for web (dart:js_interop is available), otherwise the
// no-op stub. Consumers depend on this file only.
export 'pwa_install_stub.dart'
    if (dart.library.js_interop) 'pwa_install_web.dart';
