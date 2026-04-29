import '../i18n.dart';
import '../models/recipe.dart';

// Pre-compiled patterns. Hoisted to top-level finals so they are
// constructed once at startup instead of on every call, and so the
// `RegExp(...)` constructor reference appears in a single place
// (silences the "RegExp will become final" deprecation hint when
// using newer Dart SDKs in the IDE).
// ignore: deprecated_member_use
final Pattern _latinLetters = RegExp(r'[A-Za-z]');
// ignore: deprecated_member_use
final Pattern _nonAscii = RegExp(r'[^\u0000-\u007F]');

/// Heuristic: does this recipe still look like it has not been
/// translated to [lang]? Mirrors the server-side gate in
/// `local_user_portal/routes/recipes.js _isEchoTranslation` so the
/// client and server stay in sync. Returns false for English target.
bool recipeLooksUntranslated(Recipe r, AppLang lang) {
  if (lang == AppLang.en) return false;
  final inst = r.instructions ?? '';
  if (inst.isEmpty) return false;
  const nonLatinLangs = {AppLang.ru, AppLang.ar, AppLang.fa, AppLang.ku};
  if (nonLatinLangs.contains(lang)) {
    final latin = _latinLetters.allMatches(inst).length;
    final nonAscii = _nonAscii.allMatches(inst).length;
    final total = latin + nonAscii;
    if (total == 0) return true;
    return (latin / total) >= 0.15;
  }
  if (inst.length < 80) return false;
  final nonAscii = _nonAscii.allMatches(inst).length;
  return nonAscii < 3;
}
