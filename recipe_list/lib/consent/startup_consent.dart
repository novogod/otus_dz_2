import 'package:sqflite/sqflite.dart';

import '../data/api/recipe_api_config.dart';
import '../data/local/recipe_db.dart';
import '../i18n.dart';

const String kStartupConsentCurrentVersion = '2026-05-09-v3';

const String _kConsentPlatformWeb = 'web';
const String _kConsentPlatformNative = 'native';

enum StartupConsentKind { terms, personalData, cookies, storage }

enum StartupPrivacyVariant { general, gdpr, russian152Fz, kvkk, pdpl }

class StartupConsentItem {
  const StartupConsentItem({
    required this.kind,
    required this.docUrl,
    required this.docTitle,
    this.privacyVariant = StartupPrivacyVariant.general,
  });

  final StartupConsentKind kind;
  final String docUrl;
  final String docTitle;
  final StartupPrivacyVariant privacyVariant;
}

class StartupConsentSpec {
  const StartupConsentSpec({
    required this.lang,
    required this.countryCode,
    required this.countryName,
    required this.legislationLabel,
    required this.requiredItems,
  });

  final AppLang lang;
  final String countryCode;
  final String countryName;
  final String legislationLabel;
  final List<StartupConsentItem> requiredItems;

  String get version => kStartupConsentCurrentVersion;
}

StartupConsentSpec startupConsentSpecFor(AppLang lang, {required bool isWeb}) {
  final country = _countryForLang(lang);
  final policyDoc = _docUrl(lang.name, 'personal_data');
  final termsDoc = _docUrl(lang.name, 'terms');
  final cookiesOrStorageDoc = isWeb
      ? _docUrl(lang.name, 'cookies')
      : _docUrl(lang.name, 'storage');

  final items = <StartupConsentItem>[
    StartupConsentItem(
      kind: StartupConsentKind.terms,
      docUrl: termsDoc,
      docTitle: 'Terms of use',
    ),
    StartupConsentItem(
      kind: StartupConsentKind.personalData,
      docUrl: policyDoc,
      docTitle: 'Personal data disclosure',
      privacyVariant: _privacyVariantForLang(lang),
    ),
    StartupConsentItem(
      kind: isWeb ? StartupConsentKind.cookies : StartupConsentKind.storage,
      docUrl: cookiesOrStorageDoc,
      docTitle: isWeb ? 'Cookies policy' : 'Local storage policy',
    ),
  ];

  switch (lang) {
    case AppLang.es:
      return StartupConsentSpec(
        lang: lang,
        countryCode: country.code,
        countryName: country.name,
        legislationLabel: country.legislation,
        requiredItems: items,
      );
    case AppLang.fr:
      return StartupConsentSpec(
        lang: lang,
        countryCode: country.code,
        countryName: country.name,
        legislationLabel: country.legislation,
        requiredItems: items,
      );
    case AppLang.de:
      return StartupConsentSpec(
        lang: lang,
        countryCode: country.code,
        countryName: country.name,
        legislationLabel: country.legislation,
        requiredItems: items,
      );
    case AppLang.it:
      return StartupConsentSpec(
        lang: lang,
        countryCode: country.code,
        countryName: country.name,
        legislationLabel: country.legislation,
        requiredItems: items,
      );
    case AppLang.ru:
      return StartupConsentSpec(
        lang: lang,
        countryCode: country.code,
        countryName: country.name,
        legislationLabel: country.legislation,
        requiredItems: items,
      );
    case AppLang.tr:
      return StartupConsentSpec(
        lang: lang,
        countryCode: country.code,
        countryName: country.name,
        legislationLabel: country.legislation,
        requiredItems: items,
      );
    case AppLang.ar:
      return StartupConsentSpec(
        lang: lang,
        countryCode: country.code,
        countryName: country.name,
        legislationLabel: country.legislation,
        requiredItems: items,
      );
    case AppLang.fa:
      return StartupConsentSpec(
        lang: lang,
        countryCode: country.code,
        countryName: country.name,
        legislationLabel: country.legislation,
        requiredItems: items,
      );
    case AppLang.ku:
      return StartupConsentSpec(
        lang: lang,
        countryCode: country.code,
        countryName: country.name,
        legislationLabel: country.legislation,
        requiredItems: items,
      );
    case AppLang.en:
      return StartupConsentSpec(
        lang: lang,
        countryCode: country.code,
        countryName: country.name,
        legislationLabel: country.legislation,
        requiredItems: items,
      );
  }
}

String _docUrl(String langCode, String slug) {
  final base = RecipeApiConfig.mahallemBaseUrl;
  final origin = _originFromBase(base);
  return '$origin/recipes/legal/$langCode/$slug.html';
}

String _originFromBase(String base) {
  if (base.isEmpty) return 'https://recipies.mahallem.ist';
  final uri = Uri.tryParse(base);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return 'https://recipies.mahallem.ist';
  }
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port';
}

class _CountryConsentProfile {
  const _CountryConsentProfile({
    required this.code,
    required this.name,
    required this.legislation,
  });

  final String code;
  final String name;
  final String legislation;
}

_CountryConsentProfile _countryForLang(AppLang lang) {
  switch (lang) {
    case AppLang.en:
      return const _CountryConsentProfile(
        code: 'US',
        name: 'United States',
        legislation: 'Consumer privacy + cookie notice',
      );
    case AppLang.ru:
      return const _CountryConsentProfile(
        code: 'RU',
        name: 'Russia',
        legislation: '152-FZ personal data notice',
      );
    case AppLang.es:
      return const _CountryConsentProfile(
        code: 'ES',
        name: 'Spain',
        legislation: 'GDPR + ePrivacy',
      );
    case AppLang.fr:
      return const _CountryConsentProfile(
        code: 'FR',
        name: 'France',
        legislation: 'GDPR + ePrivacy',
      );
    case AppLang.de:
      return const _CountryConsentProfile(
        code: 'DE',
        name: 'Germany',
        legislation: 'GDPR + ePrivacy',
      );
    case AppLang.it:
      return const _CountryConsentProfile(
        code: 'IT',
        name: 'Italy',
        legislation: 'GDPR + ePrivacy',
      );
    case AppLang.tr:
      return const _CountryConsentProfile(
        code: 'TR',
        name: 'Türkiye',
        legislation: 'KVKK notice',
      );
    case AppLang.ar:
      return const _CountryConsentProfile(
        code: 'SA',
        name: 'Saudi Arabia',
        legislation: 'PDPL notice',
      );
    case AppLang.fa:
      return const _CountryConsentProfile(
        code: 'IR',
        name: 'Iran',
        legislation: 'Personal data and disclosure notice',
      );
    case AppLang.ku:
      return const _CountryConsentProfile(
        code: 'IQ',
        name: 'Iraq',
        legislation: 'Personal data and disclosure notice',
      );
  }
}

StartupPrivacyVariant _privacyVariantForLang(AppLang lang) {
  switch (lang) {
    case AppLang.es:
    case AppLang.fr:
    case AppLang.de:
    case AppLang.it:
      return StartupPrivacyVariant.gdpr;
    case AppLang.ru:
      return StartupPrivacyVariant.russian152Fz;
    case AppLang.tr:
      return StartupPrivacyVariant.kvkk;
    case AppLang.ar:
      return StartupPrivacyVariant.pdpl;
    case AppLang.en:
    case AppLang.fa:
    case AppLang.ku:
      return StartupPrivacyVariant.general;
  }
}

String startupConsentLabel(StartupConsentItem item, S s) {
  switch (item.kind) {
    case StartupConsentKind.terms:
      return s.consentLabelTerms;
    case StartupConsentKind.personalData:
      switch (item.privacyVariant) {
        case StartupPrivacyVariant.gdpr:
          return s.consentLabelPersonalDataGdpr;
        case StartupPrivacyVariant.russian152Fz:
          return s.consentLabelPersonalData152Fz;
        case StartupPrivacyVariant.kvkk:
          return s.consentLabelPersonalDataKvkk;
        case StartupPrivacyVariant.pdpl:
          return s.consentLabelPersonalDataPdpl;
        case StartupPrivacyVariant.general:
          return s.consentLabelPersonalDataGeneral;
      }
    case StartupConsentKind.cookies:
      return s.consentLabelCookies;
    case StartupConsentKind.storage:
      return s.consentLabelStorage;
  }
}

Future<bool> hasAcceptedStartupConsent({
  Database? db,
  required AppLang lang,
  required bool isWeb,
}) async {
  final database = db ?? await openRecipeDatabase();
  final rows = await database.query(
    'startup_consents',
    columns: ['version'],
    where: 'locale = ? AND platform = ?',
    whereArgs: [
      lang.name,
      isWeb ? _kConsentPlatformWeb : _kConsentPlatformNative,
    ],
    limit: 1,
  );
  if (rows.isEmpty) return false;
  return rows.first['version'] == kStartupConsentCurrentVersion;
}

Future<void> acceptStartupConsent({
  Database? db,
  required AppLang lang,
  required bool isWeb,
}) async {
  final database = db ?? await openRecipeDatabase();
  await database.insert('startup_consents', {
    'locale': lang.name,
    'platform': isWeb ? _kConsentPlatformWeb : _kConsentPlatformNative,
    'version': kStartupConsentCurrentVersion,
    'accepted_at': DateTime.now().millisecondsSinceEpoch,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}
