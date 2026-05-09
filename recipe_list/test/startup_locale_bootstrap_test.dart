import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/i18n.dart';

void main() {
  group('startup locale bootstrap', () {
    test('appLangFromLanguageCode handles regional variants', () {
      expect(appLangFromLanguageCode('ru-RU'), AppLang.ru);
      expect(appLangFromLanguageCode('en_US'), AppLang.en);
      expect(appLangFromLanguageCode('tr'), AppLang.tr);
      expect(appLangFromLanguageCode('pt-BR'), isNull);
      expect(appLangFromLanguageCode(null), isNull);
    });

    test('main awaits startup bootstrap before runApp', () {
      final src = File(
        '${Directory.current.path}/lib/main.dart',
      ).readAsStringSync();

      expect(src, contains('Future<void> main() async'));
      expect(src, contains('final detected = detectDeviceAppLang();'));
      expect(src, contains('appLang.value = detected;'));
      expect(src, contains('final db = await openRecipeDatabase();'));
      expect(src, contains('await bootstrapAdminSession(db: db);'));

      final detectIndex = src.indexOf(
        'final detected = detectDeviceAppLang();',
      );
      final assignIndex = src.indexOf('appLang.value = detected;');
      final bootstrapIndex = src.indexOf(
        'final db = await openRecipeDatabase();',
      );
      final runAppIndex = src.indexOf(
        'runApp(TranslationProvider(child: const RecipeApp()));',
      );

      expect(detectIndex, greaterThanOrEqualTo(0));
      expect(assignIndex, greaterThan(detectIndex));
      expect(bootstrapIndex, greaterThan(assignIndex));
      expect(runAppIndex, greaterThan(bootstrapIndex));
    });
  });
}
