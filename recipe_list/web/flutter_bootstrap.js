{{flutter_js}}
{{flutter_build_config}}

// Service worker is registered manually in index.html (pwa_sw.js).
// Do NOT pass serviceWorkerSettings here — that would make Flutter's loader
// wait 4000ms for flutter_service_worker.js which does not exist, printing
// "prepareServiceWorker took more than 4000ms" on every page load.
_flutter.loader.load();
