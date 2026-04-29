// One-shot CLI: read base English JSON (lib/i18n/en.i18n.json), call Gemini
// 2.5 Flash for each missing locale, write `lib/i18n/<code>.i18n.json`.
// Reads `recipe_list/.env_gemini` for `GEMINI_API_KEY`. Never commits or
// transmits the key elsewhere.
//
// Usage:
//   dart run tool/translate_strings.dart           # writes 8 files
//   dart run tool/translate_strings.dart --force   # overwrite even if exists
//   dart run tool/translate_strings.dart --only=ar # one locale
//
// The tool refuses to write if Gemini's reply has missing keys, extra keys,
// or empty values — you'll see a diagnostic and the file stays untouched.

import 'dart:convert';
import 'dart:io';

const Map<String, String> _targets = {
  'es': 'Spanish',
  'fr': 'French',
  'de': 'German',
  'it': 'Italian',
  'tr': 'Turkish',
  'ar': 'Arabic',
  'fa': 'Persian (Farsi)',
  'ku': 'Kurdish (Sorani / Kurmanji — pick the most common variant)',
};

const String _model = 'gemini-2.5-flash';
const String _apiBase =
    'https://generativelanguage.googleapis.com/v1beta/models';

Future<void> main(List<String> argv) async {
  final repo = Directory.current;
  final envFile = File('${repo.path}/.env_gemini');
  if (!envFile.existsSync()) {
    stderr.writeln('error: .env_gemini not found at ${envFile.path}');
    exit(2);
  }
  final apiKey = _parseEnv(envFile.readAsStringSync())['GEMINI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('error: GEMINI_API_KEY missing in .env_gemini');
    exit(2);
  }

  final force = argv.contains('--force');
  final only = argv
      .firstWhere((a) => a.startsWith('--only='), orElse: () => '')
      .replaceFirst('--only=', '');

  final baseFile = File('${repo.path}/lib/i18n/en.i18n.json');
  final baseJson =
      jsonDecode(baseFile.readAsStringSync()) as Map<String, dynamic>;

  final targets = only.isEmpty
      ? _targets
      : <String, String>{only: _targets[only] ?? only};

  final client = HttpClient();
  try {
    for (final entry in targets.entries) {
      final code = entry.key;
      final name = entry.value;
      final outPath = '${repo.path}/lib/i18n/$code.i18n.json';
      if (!force && File(outPath).existsSync()) {
        stdout.writeln('skip $code (exists; pass --force to overwrite)');
        continue;
      }
      stdout.writeln('translating → $code ($name)…');
      final translated = await _translateOnce(
        client: client,
        apiKey: apiKey,
        targetName: name,
        base: baseJson,
      );
      final problems = _validateShape(baseJson, translated);
      if (problems.isNotEmpty) {
        stderr.writeln('  ✗ shape mismatch for $code:');
        for (final p in problems) {
          stderr.writeln('    - $p');
        }
        stderr.writeln('  refusing to write $outPath');
        exit(1);
      }
      File(outPath).writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(translated)}\n',
      );
      stdout.writeln('  ✓ wrote $outPath');
    }
  } finally {
    client.close(force: true);
  }
}

Map<String, String> _parseEnv(String raw) {
  final out = <String, String>{};
  for (final line in raw.split('\n')) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#')) continue;
    final eq = t.indexOf('=');
    if (eq < 0) continue;
    out[t.substring(0, eq).trim()] = t.substring(eq + 1).trim();
  }
  return out;
}

Future<Map<String, dynamic>> _translateOnce({
  required HttpClient client,
  required String apiKey,
  required String targetName,
  required Map<String, dynamic> base,
}) async {
  final prompt =
      '''
Translate the JSON values below into $targetName.

Strict rules:
- Output ONLY a valid JSON object — no markdown fences, no commentary.
- Keep every key (including nested keys) exactly as in the input.
- Keep every \${placeholder} token byte-for-byte unchanged.
- For plural blocks (objects with keys like "one"/"few"/"many"/"other"/"two"/"zero"),
  emit the CLDR plural categories required by the target language and remove
  unused ones. The "${'\$'}{n}" placeholder must remain.
- "appTitle" stays "Otus Food" (brand name).
- "youtube" stays "YouTube" (brand name).
- Use natural, idiomatic register for a cooking app. No transliteration.

INPUT JSON:
${const JsonEncoder.withIndent('  ').convert(base)}
''';

  final body = jsonEncode({
    'contents': [
      {
        'role': 'user',
        'parts': [
          {'text': prompt},
        ],
      },
    ],
    'generationConfig': {
      'temperature': 0.2,
      'responseMimeType': 'application/json',
    },
  });

  final uri = Uri.parse('$_apiBase/$_model:generateContent?key=$apiKey');
  final req = await client.postUrl(uri);
  req.headers.contentType = ContentType.json;
  req.add(utf8.encode(body));
  final resp = await req.close();
  final raw = await resp.transform(utf8.decoder).join();
  if (resp.statusCode != 200) {
    throw HttpException('Gemini ${resp.statusCode}: $raw');
  }
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final candidates = decoded['candidates'] as List?;
  if (candidates == null || candidates.isEmpty) {
    throw StateError('Gemini returned no candidates: $raw');
  }
  final parts = ((candidates.first as Map)['content'] as Map)['parts'] as List;
  final text = parts.map((p) => (p as Map)['text'] ?? '').join();
  return jsonDecode(text) as Map<String, dynamic>;
}

List<String> _validateShape(
  Map<String, dynamic> expected,
  Map<String, dynamic> actual, [
  String prefix = '',
]) {
  final problems = <String>[];
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
      problems.addAll(_validateShape(ev, av, path));
    } else if (ev is String) {
      if (av is! String) {
        problems.add('expected string at $path');
      } else if (av.trim().isEmpty) {
        problems.add('empty value at $path');
      } else {
        // Check placeholders preserved.
        // ignore: deprecated_member_use
        for (final m in RegExp(
          r'\$\{[a-zA-Z_][a-zA-Z0-9_]*\}',
        ).allMatches(ev)) {
          if (!av.contains(m.group(0)!)) {
            problems.add('lost placeholder ${m.group(0)} at $path');
          }
        }
      }
    }
  }
  for (final k in actual.keys) {
    if (!expected.containsKey(k)) {
      // For plural blocks: extra CLDR categories are allowed (one/few/many/other).
      // We allow extras only inside plural maps where parent had at least one of
      // the CLDR plural keys.
      final path = prefix.isEmpty ? k : '$prefix.$k';
      const pluralKeys = {'zero', 'one', 'two', 'few', 'many', 'other'};
      if (prefix.isNotEmpty && pluralKeys.contains(k)) continue;
      problems.add('extra key: $path');
    }
  }
  return problems;
}
