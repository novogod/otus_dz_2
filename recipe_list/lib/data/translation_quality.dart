import '../i18n.dart';
import '../models/recipe.dart';

/// Heuristic: does this recipe still look like it has not been
/// translated to [lang]? Mirrors the server-side gate in
/// `local_user_portal/routes/recipes.js _isEchoTranslation` so the
/// client and server stay in sync. Returns false for English target.
bool recipeLooksUntranslated(Recipe r, AppLang lang) {
  if (lang == AppLang.en) return false;
  final inst = r.instructions ?? '';
  if (inst.isEmpty) return false;
  const nonLatin = {AppLang.ru, AppLang.ar, AppLang.fa, AppLang.ku};
  if (nonLatin.contains(lang)) {
    final latin = RegExp(r'[A-Za-z]').allMatches(inst).length;
    final nonAscii = RegExp(r'[^\u0000-\u007F]').allMatches(inst).length;
    final total = latin + nonAscii;
    if (total == 0) return true;
    return (latin / total) >= 0.15;
  }
  if (inst.length < 80) return false;
  final nonAscii = RegExp(r'[^\u0000-\u007F]').allMatches(inst).length;
  return nonAscii < 3;
}
