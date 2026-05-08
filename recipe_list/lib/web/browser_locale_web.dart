import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Returns browser-preferred language codes in priority order.
/// Example values: ['ru-RU', 'ru', 'en-US', 'en'].
List<String> browserPreferredLanguages() {
  final out = <String>[];
  try {
    final langs = web.window.navigator.languages.toDart;
    for (final raw in langs) {
      final code = raw.toDart.trim();
      if (code.isNotEmpty && !out.contains(code)) out.add(code);
    }

    final single = web.window.navigator.language.trim();
    if (single.isNotEmpty && !out.contains(single)) {
      out.add(single);
    }
  } catch (_) {
    // Keep best-effort behavior.
  }
  return out;
}
