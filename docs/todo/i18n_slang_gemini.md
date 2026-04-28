# TODO — Full UI i18n via slang + Gemini

Each chunk is independently committable and has explicit test gates. Mark `[x]`
as you go. Design rationale lives in `docs/i18n_slang_gemini.md`.

## C0 — secrets plumbing  ✅ done in this PR

- [x] Copy `GEMINI_API_KEY` from `mahallem_ist/.env` into
  `recipe_list/.env_gemini` (chmod 600).
- [x] Add `recipe_list/.env_gemini` and `.env_gemini` to `.gitignore`.
- **Test gate:** `git check-ignore -v recipe_list/.env_gemini` exits 0.

## C1 — slang scaffolding (no behaviour change yet)

- [ ] Add deps in `recipe_list/pubspec.yaml`:
  - `slang: ^4.14.0`, `slang_flutter: ^4.14.0`, `flutter_localizations: { sdk: flutter }`,
    `intl: ^0.20.2`.
  - `dev_dependencies`: `slang_build_runner: ^4.14.0`, `build_runner: ^2.4.13`.
- [ ] Add `recipe_list/slang.yaml` with `base_locale: en`, `input_directory: lib/i18n`,
  `input_file_pattern: .i18n.json`, `output_directory: lib/i18n`,
  `output_file_name: strings.g.dart`, `locale_handling: false` (we drive locale
  via `LocaleSettings.setLocaleRaw`), `flutter_integration: true`.
- [ ] Create `lib/i18n/strings.i18n.json` containing every key currently in
  `S` (audited list, ~30 keys) with English values copied verbatim from
  current `_t(ru, en)` second argument. Use slang plural blocks for
  `ingredientCount`.
- [ ] Create `lib/i18n/strings_ru.i18n.json` with the existing Russian values.
- [ ] Run `dart run slang` and commit `lib/i18n/strings.g.dart`.
- **Test gate:**
  - `dart analyze` passes.
  - `flutter test` passes (no call sites changed yet).
  - `lib/i18n/strings.g.dart` exists and exports `Translations`, `AppLocale`.

## C2 — Gemini translator script

- [ ] Add `recipe_list/tool/translate_strings.dart`. Reads `.env_gemini`,
  iterates targets `[es, fr, de, it, tr, ar, fa, ku]`, calls Gemini 2.5 Flash
  REST, writes `strings_<code>.i18n.json`. Validates JSON shape (same keys,
  plural blocks intact). Refuses to overwrite if validation fails.
- [ ] Add `recipe_list/tool/README.md` with the one-line invocation.
- **Test gate:** `dart run tool/translate_strings.dart --dry-run` (mock mode)
  prints "would translate N keys to 8 locales" and exits 0.

## C3 — generate the 8 missing locale files

- [ ] Run `dart run tool/translate_strings.dart` (no flag) to populate
  `strings_es/fr/de/it/tr/ar/fa/ku.i18n.json`.
- [ ] Run `dart run slang` to regenerate `strings.g.dart`.
- **Test gate:**
  - All 10 JSON files validate against the base shape (script exits 0).
  - `dart analyze` passes.

## C4 — wire `appLang` → slang

- [ ] In `lib/main.dart`, wrap root with `TranslationProvider(child: …)`.
- [ ] Install a top-level listener: `appLang.addListener(() =>
  LocaleSettings.setLocaleRaw(appLang.value.name))`. Call once on startup.
- [ ] Add `localizationsDelegates: GlobalMaterialLocalizations.delegates` and
  `supportedLocales: AppLocaleUtils.supportedLocales` to `MaterialApp`.
- [ ] Wrap `MaterialApp.builder` with a `Directionality` selector for
  `ar/fa/ku`.
- **Test gate:** Hot-restart sim, tap flag once. AppBar text changes; Material
  back-button tooltip changes language too.

## C5 — replace every `S.of(context).foo` with `t.foo`

- [ ] Migrate call sites in this exact list:
  - `lib/ui/recipe_list_page.dart`
  - `lib/ui/recipe_list_loader.dart`
  - `lib/ui/recipe_details_page.dart`
  - `lib/ui/app_bottom_nav_bar.dart`
  - `lib/ui/search_app_bar.dart`
- [ ] Delete the `S` class from `lib/i18n.dart`. Keep `AppLang` enum,
  `appLang` notifier, `cycleAppLang`, `AppLangScope`.
- **Test gate:** `dart analyze` passes; `flutter test` runs all 27 tests
  green.

## C6 — kill remaining hardcoded English

- [ ] `lib/main.dart` `MaterialApp.title` → `t.appTitle`.
- [ ] `lib/ui/lang_icon_button.dart` Semantics labels → `t.a11y.switchLanguage(label: …)` / `t.a11y.flag(label: …)`.
- [ ] `lib/ui/app_page_bar.dart` `tooltip: 'Back'` → `t.back`.
- [ ] `lib/ui/source_page.dart` `tooltip: 'Back'` → `t.back`.
- [ ] `lib/ui/recipe_list_page.dart` offline banner `tooltip: 'Dismiss'` → `t.dismiss`.
- [ ] Add the new keys (`appTitle`, `back`, `dismiss`, `a11y.switchLanguage`,
  `a11y.flag`) to `strings.i18n.json` + `strings_ru.i18n.json`, regenerate
  the 8 others via the script.
- **Test gate:** `grep` for any remaining hardcoded English string in
  `lib/ui/**/*.dart` → only brand strings (`OTUS\nFOOD`, `YouTube`) remain.

## C7 — completeness tests

- [ ] Add `test/i18n_completeness_test.dart`:
  - For every `AppLocale` value: instantiate `Translations`, walk every key in
    the base bundle via reflection of the generated nested classes, assert
    each leaf is a non-empty `String` (or non-empty plural form).
  - Assert no leaf equals its English counterpart unless tagged in a known
    `_brandKeys` set (`youtube`, etc.).
- **Test gate:** `flutter test` passes; the new test runs in <2 s.

## C8 — ship

- [ ] `flutter test --no-pub` (28+ tests).
- [ ] `git add -A && git commit -m 'feat(i18n): full slang + gemini pipeline …'`
  → `git push origin main`.
- [ ] Hot-restart sim, screenshot list page in `ar` (RTL), `de`, `tr`, `ku`.
- [ ] Verify zero English tokens visible on any of those screens.
- **Test gate:** screenshots match expectations; user signs off.

## Rollback plan

If anything goes sideways the change is contained to:

- `pubspec.yaml`, `pubspec.lock`
- `lib/i18n/**` (new), `lib/i18n.dart` (S class removed)
- `lib/main.dart` (root wrap)
- five `lib/ui/*.dart` files (call-site renames)
- `tool/translate_strings.dart` (new)

`git revert <sha>` brings back the previous `S` and the existing tests still pass.
