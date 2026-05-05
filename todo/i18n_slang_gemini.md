# TODO — Full UI i18n via slang + Gemini

## ⛳ PRIME DIRECTIVE — never close this task

**EVERY VISIBLE WORD ON THE CURRENT SCREEN SHOULD BE ON the language
displayed on the language button. On button click every word on the same
screen should change. No questions. Silent implementation till the final
result.**

Failure definition: any deviation from the main task in exact formula as
written in the prompt (no changes, no additions or extractions, no
assumptions, exactly as written).

### Quality contract (added 2026-04-28)

The app must show **smooth, fully translated content for every language
on every page**. The persisted DB on every layer must contain only
**correct** translations. The exact rules:

1. The 4-tier sequence in [translation-pipeline.md](../translation-pipeline.md)
   is binding.
2. Every translation produced by an engine MUST pass mahallem's scoring
   system (`evaluateCandidate`: `isGarbageTranslation`,
   `isWrongScriptTranslation`, `isLowQualityTranslation`) before being
   written to `translation_cache` OR `recipes.i18n[lang]`.
3. Long-instruction blobs MUST additionally pass an echo-ratio check —
   sentence-level overlap with the English source above a threshold
   means the row is treated as a failure and is **not** persisted.
4. Paid translation APIs (Gemini) are invoked **only** when:
   a) the DB has no entry for the (text, src, tgt) triple, OR
   b) the existing entry's score is low / detected as wrong (echo,
      script mismatch, latin residue ≥ threshold), OR
   c) the existing `recipes.i18n[lang]` row is detected as poisoned
      (re-evaluated on read; if it fails the gate it is purged and
      re-translated).
5. The loading page stays up — with progress reflecting `done/total` —
   until every recipe on the seeded list is fully translated for the
   current `appLang`. No partial flicker.

Workflow loop until done:
1. Pick the next locale not yet fully matching the language button.
2. Identify the offending visible word's source.
3. Implement the smallest fix that closes it. Silent — no questions.
4. `flutter test --no-pub` — must stay green.
5. Hot-restart sim, screenshot, verify, commit, push.
6. Repeat.

Status: **in progress** — interface labels shipped (`30766ef`,
`f446b3e`, `df33035`); recipe content (title, area, tags, instructions)
still leaks English from the mahallem backend. See §C10.

Design rationale lives in `docs/i18n_slang_gemini.md`.

## C0 — secrets plumbing  ✅

- [x] Copy `GEMINI_API_KEY` from `mahallem_ist/.env` into
  `recipe_list/.env_gemini` (chmod 600).
- [x] Add `recipe_list/.env_gemini` to root `.gitignore` (line 12). Verified
  via `git check-ignore -v`.

## C1 — slang scaffolding  ✅

- [x] Deps in `recipe_list/pubspec.yaml`: `slang ^4.14.0`, `slang_flutter
  ^4.14.0`, `flutter_localizations` (sdk), `intl ^0.20.2`; dev:
  `slang_build_runner ^4.14.0`, `build_runner ^2.4.13`.
- [x] `recipe_list/slang.yaml`: `base_locale: en`, `fallback_strategy: none`,
  `input_directory: lib/i18n`, `input_file_pattern: .i18n.json`,
  `output_file_name: strings.g.dart`, `flutter_integration: true`,
  `locale_handling: true`, `namespaces: false`, `lazy: false` (deferred
  imports off — they broke widget tests).
- [x] `lib/i18n/en.i18n.json` + `lib/i18n/ru.i18n.json` with the 30 audited
  keys, including the `ingredientCount` plural block.
- [x] Generated `lib/i18n/strings.g.dart` + `strings_<code>.g.dart`
  committed.

## C2 — Gemini translator script  ✅

- [x] `recipe_list/tool/translate_strings.dart` — reads `.env_gemini`, hits
  Gemini 2.5 Flash REST
  (`generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent`),
  writes `<code>.i18n.json`. Validates shape, preserves placeholders,
  tolerates extra CLDR plural keys, supports `--force` and `--only=<code>`.

## C3 — 8 locale JSONs  ✅

- [x] `lib/i18n/{es,fr,de,it,tr,ar,fa,ku}.i18n.json` populated and
  regenerated. Brand strings (`appTitle = "Otus Food"`, `youtube =
  "YouTube"`) preserved across all locales.

## C4 — `appLang` → slang wiring  ✅

- [x] `lib/i18n.dart`: `enum AppLang(label, flag, AppLocale locale)`,
  `appLang` `ValueNotifier`, `cycleAppLang()`, `initI18n()` (idempotent),
  `AppLangScope` (wraps in `Directionality(rtl)` for `ar/fa/ku`).
- [x] `lib/main.dart`: `WidgetsFlutterBinding.ensureInitialized();
  initI18n(); runApp(TranslationProvider(child: const RecipeApp()));`
  `MaterialApp` uses `locale: TranslationProvider.of(context).flutterLocale`
  + `GlobalMaterialLocalizations.delegates` +
  `AppLocaleUtils.supportedLocales`.
- [x] Switched from async `setLocale` to `LocaleSettings.setLocaleSync` —
  avoids the deferred-import path that broke tests.

## C5 — `S.of(context).foo` → `t.foo`  ✅

- [x] All call sites migrated. `S` class kept as a thin wrapper around
  `Translations` for back-compat (try/catch falls back to global `t` when
  no `TranslationProvider` is in scope, e.g. inside widget tests).

## C6 — hardcoded English purge  ✅

- [x] `MaterialApp.title` → `t.appTitle`.
- [x] `lib/ui/lang_icon_button.dart` Semantics → `s.switchLanguageTo(...)` /
  `s.flagOf(...)`.
- [x] `lib/ui/app_page_bar.dart`, `lib/ui/source_page.dart` back tooltip →
  `s.back`.
- [x] `lib/ui/recipe_list_page.dart` offline banner dismiss → `s.dismiss`.
- [x] All new keys present in every locale JSON.

## C7 — completeness tests  ✅

- [x] `recipe_list/test/i18n_completeness_test.dart` — verifies every locale
  has every key, no empty values, placeholders preserved, and a high
  fraction of leaves differs from English (excluding brand keys `appTitle`,
  `youtube`).

## C8 — ship  ✅

- [x] `flutter test --no-pub` → 39 passed.
- [x] Pushed `30766ef` to `origin/main`.
- [x] iPhone 16e sim verified RU loading screen renders translated copy.

## C9 — loading-screen progress-bar fix  ✅ (post-ship)

Surfaced during sim verification: bar looked frozen on cold non-EN seed.
Two root causes:

1. Progress was solely `recipes_loaded / 200`, which stays at `0` until the
   first `filterByCategory` returns (30+ s on translated payloads).
2. Empty track was `AppColors.surface` (#FFFFFF) on top of `surfaceMuted`
   (#ECECEC) — 0% looked identical to 100%.

Fix in `lib/ui/recipe_list_loader.dart`:

- [x] `progress = max(categoryDone/total, recipesLoaded/target)` during the
  fetching stage, falling back to recipe-only progress otherwise.
- [x] Emit a `_LoadStage.fetching(done: i+1, …)` update **after** each
  category completes, not only before.
- [x] Track colour for both `LinearProgressIndicator` and
  `CircularProgressIndicator` → `AppColors.primary.withValues(alpha:
  0.18)`.
- [x] Verified on sim (mint track + green fill at ~33% with 1/10 cats,
  66/200 recipes). Pushed as `f446b3e`.

## Outstanding

- [ ] Drive the running sim through `ar` (RTL), `de`, `tr`, `ku` once the
  list is loaded; capture a screenshot per locale; confirm zero English
  tokens in interface labels.

## C10 — recipe content gap (NEW, blocks PRIME DIRECTIVE) 🔴

Verified on `2026-04-28` against `https://mahallem.ist/recipes/filter?c=Pork&lang=ru&full=1`:

| field           | value                                  | translated? |
|-----------------|----------------------------------------|-------------|
| `strMeal`       | ` Bubble & Squeak`                     | ❌ English  |
| `strArea`       | `British`                              | ❌ English  |
| `strTags`       | `SideDish,Speciality`                  | ❌ English  |
| `strCategory`   | `Свинина`                              | ✅          |
| `strIngredient1`| `Сливочное масло`                      | ✅          |
| `strInstructions` | mostly English with a few RU nouns   | ❌ partial  |

The doc `docs/i18n_slang_gemini.md` declared recipe content "out of scope —
already translated server-side". That assumption is wrong. Until either
the server is fixed or the client compensates, the prime directive cannot
be satisfied.

Decision pending (user to choose):

- [ ] **Option A — Fix mahallem backend.** Extend `local_user_portal/utils/translate-recipe.js`
  to also translate `strMeal`, `strArea`, `strTags`, full `strInstructions`
  for all 10 langs. Requires SSH deploy. Architecturally correct.
- [ ] **Option B — Translate in Flutter.** On first display per
  `(recipeId, lang)`, send untranslated fields to Gemini at runtime, cache
  in sqflite. Self-contained but ships a Gemini key into the binary or
  proxies through a backend route.
- [ ] **Option C — A + B.** Backend authoritative; client fills any
  remaining English-leak as a safety net.

## Rollback plan

`git revert f446b3e 30766ef` restores the pre-i18n `S` class. Surface area
is contained to:

- `recipe_list/pubspec.yaml`, `pubspec.lock`
- `recipe_list/lib/i18n/**` (new), `recipe_list/lib/i18n.dart`
- `recipe_list/lib/main.dart`
- `recipe_list/lib/ui/{recipe_list_page,recipe_list_loader,recipe_details_page,app_bottom_nav_bar,search_app_bar,lang_icon_button,app_page_bar,source_page}.dart`
- `recipe_list/tool/translate_strings.dart`
- `recipe_list/test/i18n_completeness_test.dart`

## C11 — scoring-gated persistence + poison purge (2026-04-28) 🔴

Verified poisoning on `2026-04-28` against
`https://mahallem.ist/recipes/lookup/52772?lang=es`: title/category/area
correctly Spanish, but `strInstructions` returned the English source
verbatim because `_isEchoTranslation` only flags byte-equal blobs while
the partial-Spanish output differs by whitespace. The English-leaked
row was persisted into `recipes.i18n.es.strInstructions` and now
short-circuits all subsequent reads.

Tasks (binding, in order):

- [ ] **Server (mahallem):** tighten `_isEchoTranslation` to use
  sentence-overlap ratio (≥ ~30 % of source sentences identical, OR
  latin-residue ratio ≥ 15 % in non-Latin targets, OR Jaccard with
  source above threshold for Latin targets). On gate failure: serve
  to caller, do NOT `UPDATE recipes SET i18n`.
- [ ] **Server:** in `translateLongField`, do not cache joined output
  via `cacheTranslation` when echo-ratio ≥ 0.3 even for Latin targets;
  current behaviour caches partial-English under non-`isStillLatinResidue`
  branch.
- [ ] **Server:** add re-evaluation on read — when `_ensureLang` finds
  an existing `row.i18n[lang]`, run the same gate; if it fails, drop
  the key from `i18n` and fall through to the translate path.
- [ ] **Server:** purge already-poisoned `recipes.i18n.{es,fr,de,it,tr,
  ar,fa,ku,ru}` rows where `instructions` echoes English.
- [ ] **Server deploy:** Go-Clean prod path per
  `mahallem_ist/AI_instructions_and_guidelines/GO_CLEAN_PHILOSOPHY.md`.
- [ ] **Client:** in `_retranslate`, when a returned recipe still
  contains visible English residue for a non-en target, treat it as a
  miss and retry once (bounded). Loading page stays up; counter
  advances per resolved recipe; only flips to list page when **all**
  recipes pass the residue check or the bounded retry budget is spent.
- [ ] **Verify:** iOS + Android cold launch on every locale; capture
  one screenshot per language; assert zero English residue on the
  visible card content. Append findings to `docs/project_log.md`.
