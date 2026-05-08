import 'dart:html' as html;

/// Returns browser-preferred language codes in priority order.
/// Example values: ['ru-RU', 'ru', 'en-US', 'en'].
List<String> browserPreferredLanguages() {
  final out = <String>[];
  try {
    final langs = html.window.navigator.languages;
    if (langs != null) {
      for (final raw in langs) {
        final code = raw.trim();
        if (code.isNotEmpty && !out.contains(code)) out.add(code);
      }
    }
    final single = html.window.navigator.language.trim();
    if (single.isNotEmpty && !out.contains(single)) {
      out.add(single);
    }
  } catch (_) {
    // Keep best-effort behavior.
  }
  return out;
}
