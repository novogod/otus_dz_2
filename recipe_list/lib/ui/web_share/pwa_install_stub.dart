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

/// True when the host is iOS Safari/Chrome (browser tab, not the
/// installed PWA). Used to fall back to the manual "Add to Home
/// Screen" instructions modal because iOS doesn't fire the
/// `beforeinstallprompt` event. Always `false` off-web.
bool isIosBrowserWeb() => false;

/// True when the page is already running as an installed PWA — in
/// that case the install button must not surface.
bool isPwaStandaloneWeb() => false;

/// True when the browser exposes `navigator.share` (Web Share API).
/// On non-web targets returns `true` because share_plus has a real
/// platform sheet there.
bool canWebShareWeb() => true;
