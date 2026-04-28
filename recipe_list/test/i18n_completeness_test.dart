import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/i18n.dart';
import 'package:recipe_list/i18n/strings.g.dart';

/// Гарантирует, что каждый поддерживаемый язык содержит **все** ключи
/// из базовой английской локали и ни одно значение не пустое. Если
/// `tool/translate_strings.dart` (Gemini) что-то пропустил, тест упадёт
/// до того, как сборка попадёт пользователю.
void main() {
  // ignore: avoid_print
  final repo = Directory.current;
  final base =
      jsonDecode(File('${repo.path}/lib/i18n/en.i18n.json').readAsStringSync())
          as Map<String, dynamic>;

  test('all 10 AppLang values map to existing AppLocale', () {
    for (final l in AppLang.values) {
      expect(l.locale, isA<AppLocale>(), reason: 'AppLang.${l.name}');
    }
  });

  for (final lang in AppLang.values) {
    test('${lang.name} JSON has every key from base, no empty leaves', () {
      final file = File('${repo.path}/lib/i18n/${lang.name}.i18n.json');
      expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final problems = <String>[];
      _walk(base, json, '', problems, lang.name);
      expect(
        problems,
        isEmpty,
        reason: 'i18n issues in ${lang.name}:\n  ${problems.join('\n  ')}',
      );
    });
  }

  test('non-EN locales differ from EN for at least 80% of leaf strings', () {
    final enLeaves = _flatten(base);
    for (final lang in AppLang.values) {
      if (lang == AppLang.en) continue;
      final json = jsonDecode(
        File('${repo.path}/lib/i18n/${lang.name}.i18n.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final leaves = _flatten(json);
      // Brand strings allowed to match.
      const brand = {'appTitle', 'youtube'};
      var same = 0;
      var total = 0;
      for (final key in enLeaves.keys) {
        if (brand.contains(key.split('.').last)) continue;
        final en = enLeaves[key];
        final tr = leaves[key];
        if (en == null || tr == null) continue;
        total++;
        if (en == tr) same++;
      }
      expect(
        total > 0 && same / total < 0.2,
        isTrue,
        reason:
            '${lang.name}: $same/$total leaves match EN (suggests untranslated)',
      );
    }
  });
}

void _walk(
  Map<String, dynamic> expected,
  Map<String, dynamic> actual,
  String prefix,
  List<String> problems,
  String code,
) {
  for (final k in expected.keys) {
    final path = prefix.isEmpty ? k : '$prefix.$k';
    if (!actual.containsKey(k)) {
      problems.add('missing key: $path');
      continue;
    }
    final ev = expected[k];
    final av = actual[k];
    if (ev is Map<String, dynamic>) {
      if (av is! Map<String, dynamic>) {
        problems.add('expected object at $path');
        continue;
      }
      _walk(ev, av, path, problems, code);
    } else if (ev is String) {
      if (av is! String) {
        problems.add('expected string at $path');
      } else if (av.trim().isEmpty) {
        problems.add('empty value at $path');
      } else {
        for (final m in RegExp(r'\$\{[a-zA-Z_][a-zA-Z0-9_]*\}').allMatches(ev)) {
          if (!av.contains(m.group(0)!)) {
            problems.add('lost placeholder ${m.group(0)} at $path');
          }
        }
      }
    }
  }
}

Map<String, String> _flatten(Map<String, dynamic> m, [String prefix = '']) {
  final out = <String, String>{};
  for (final e in m.entries) {
    final path = prefix.isEmpty ? e.key : '$prefix.${e.key}';
    final v = e.value;
    if (v is Map<String, dynamic>) {
      out.addAll(_flatten(v, path));
    } else if (v is String) {
      out[path] = v;
    }
  }
  return out;
}
