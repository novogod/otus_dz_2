// Web-only PWA install prompt bridge. Talks to the JS shim added in
// `web/index.html` that captures `beforeinstallprompt`.
import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('isPwaInstallAvailable')
external bool _jsIsPwaInstallAvailable();

@JS('triggerPwaInstall')
external JSPromise<JSString> _jsTriggerPwaInstall();

@JS('isIosBrowser')
external bool _jsIsIosBrowser();

@JS('isPwaStandalone')
external bool _jsIsPwaStandalone();

final ValueNotifier<bool> pwaInstallAvailable = ValueNotifier<bool>(false);

Timer? _watcher;

void initPwaInstallWatcher() {
  _watcher?.cancel();
  void sync() {
    try {
      pwaInstallAvailable.value = _jsIsPwaInstallAvailable();
    } catch (_) {
      pwaInstallAvailable.value = false;
    }
  }

  // Initial probe (the JS event may already have fired before
  // Flutter mounted), then poll. Polling is cheap — a single
  // null-check on `window.deferredPwaPrompt`.
  sync();
  _watcher = Timer.periodic(const Duration(seconds: 2), (_) => sync());
}

Future<String> triggerPwaInstall() async {
  try {
    final result = await _jsTriggerPwaInstall().toDart;
    pwaInstallAvailable.value = false;
    return result.toDart;
  } catch (_) {
    return 'error';
  }
}

bool isIosBrowserWeb() {
  try {
    return _jsIsIosBrowser();
  } catch (_) {
    return false;
  }
}

bool isPwaStandaloneWeb() {
  try {
    return _jsIsPwaStandalone();
  } catch (_) {
    return false;
  }
}
