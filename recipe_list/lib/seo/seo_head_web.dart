// Web implementation of the SEO-head bridge — calls into the JS
// helpers `window.setRecipeSeo` / `window.clearRecipeSeo` defined in
// `web/index.html` (todo/20 chunk F).
//
// Uses `dart:js_interop` (the modern, sound JS interop available since
// Dart 3.x) — no `dart:html` / `package:js` dependency.
import 'dart:js_interop';

@JS('setRecipeSeo')
external void _setRecipeSeo(JSAny data);

@JS('clearRecipeSeo')
external void _clearRecipeSeo();

void setRecipeSeo(Map<String, Object?> data) {
  // jsify() turns a Dart Map / List tree into a JS object / array
  // recursively, which is exactly what the JS helper expects.
  _setRecipeSeo(data.jsify() as JSAny);
}

void clearRecipeSeo() {
  _clearRecipeSeo();
}
