/// Lightweight formatter for the recipe `strInstructions` blob.
///
/// The TextField in `add_recipe_page.dart` accepts multi-line input,
/// but on iOS PWA the soft keyboard sometimes hides the Enter key —
/// users end up typing a single long line with their own list
/// markers ("1/", "2)", "3.", "- ", "• ", "* "). They expect those
/// markers to render as separate paragraphs, the same way they
/// would in a notes app.
///
/// This helper:
/// 1. Normalises CRLF to LF.
/// 2. If the text already contains explicit line breaks, preserves
///    them as-is (only trims trailing whitespace per line).
/// 3. If the text is a single line, splits it on common list-marker
///    patterns so each step becomes its own paragraph.
/// 4. Hashtags ("#tag") and existing bullets are preserved verbatim.
///
/// Pure: returns the formatted display string, never mutates the
/// original recipe data. Storage stays exactly as the user typed.
String formatInstructions(String? raw) {
  if (raw == null) return '';
  final lf = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  // If the user already inserted newlines, just clean up trailing
  // whitespace and collapse runs of >2 blank lines.
  if (lf.contains('\n')) {
    final lines = lf
        .split('\n')
        .map((l) => l.trimRight())
        .toList(growable: false);
    return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
  // Single-line fallback: break before numeric or bullet list
  // markers so "1/ Buy Cheese 2/ Unload" renders as two paragraphs.
  // Pattern: a digit run followed by `/`, `.`, `)`, or `:`, OR a
  // bullet glyph (`-`, `*`, `•`) appearing mid-sentence after a
  // space. Keep the marker glued to the next chunk.
  final marker = RegExp(
    r'(?<=\S)\s+(?=(?:\d{1,3}\s*[/.\):]|[-*•]\s))',
    multiLine: false,
  );
  final pieces = lf.split(marker);
  if (pieces.length <= 1) return lf.trim();
  return pieces.map((p) => p.trim()).where((p) => p.isNotEmpty).join('\n');
}
