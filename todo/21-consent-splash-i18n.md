# 21 — Consent Splash i18n

> **Статус:** 🔄 в работе.
> **См.:** [docs/consent-splash-i18n.md](../docs/consent-splash-i18n.md).
> **Приоритет:** P1 (UX — пользователь видит английский текст при нерусском устройстве).
> **Scope:** `[client]`, без серверных правок.

Все строки экрана согласия (legal gate) захардкожены на английском.
Нужно перевести их через существующую slang-инфраструктуру (`*.i18n.json` → `dart run slang`).

---

## Чанк A — Добавить ключи в 10 JSON-файлов

Добавить новые ключи в `en.i18n.json` и все 9 локальных файлов.

**Новые ключи (16 штук):**

```
consentTitle
consentCountry          # ${country} (${code}) · ${law}
consentOpenDoc          # Open "${title}"
consentAgree            # I agree
consentSaving           # Saving...
consentCheckAll         # Please check all required consents
consentDocUrlInvalid    # Legal document URL is invalid
consentDocOpenFailed    # Failed to open legal document
consentLabelTerms
consentLabelPersonalDataGdpr
consentLabelPersonalData152Fz
consentLabelPersonalDataKvkk
consentLabelPersonalDataPdpl
consentLabelPersonalDataGeneral
consentLabelCookies
consentLabelStorage
```

**Файлы:** все 10 в `recipe_list/lib/i18n/*.i18n.json`.

---

## Чанк B — Регенерация `strings.g.dart`

```bash
cd recipe_list
dart run slang
```

Проверить, что сгенерированные файлы не имеют ошибок компиляции.

---

## Чанк C — Подключение строк в Dart-файлах

Заменить каждый захардкоженный английский литерал на `t.keyName`.

**Файлы:**
- `lib/ui/splash_and_recipes.dart` — `_StartupConsentPanel.build()`
  и `_agreeAndContinue()` / `_openDoc()` снекбары.
- `lib/consent/startup_consent.dart` — функция `startupConsentLabel()`.

**Паттерн получения `t`:**
```dart
final t = appLang.value.locale.build();
```

---

## Коммиты

- Чанк A — JSON-переводы
- Чанк B — регенерированный `strings.g.dart`
- Чанк C — подключение в Dart + редеплой
