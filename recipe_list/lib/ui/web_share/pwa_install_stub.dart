// Stub for non-web builds: no PWA install prompt available.
import 'package:flutter/foundation.dart';

/// Whether the PWA install prompt is currently available. On
/// non-web builds it stays `false` forever; on web (see
/// `pwa_install_web.dart`) we poll
/// `window.isPwaInstallAvailable()` to keep this in sync with
/// the captured `beforeinstallprompt` event.
final ValueNotifier<bool> pwaInstallAvailable = ValueNotifier<bool>(false);

/// Trigger the captured `beforeinstallprompt` event. Returns
/// the user's outcome (`accepted` / `dismissed` / `unavailable`).
/// No-op on non-web.
Future<String> triggerPwaInstall() async => 'unavailable';

/// Start the periodic poller that updates [pwaInstallAvailable].
/// No-op on non-web.
void initPwaInstallWatcher() {}
