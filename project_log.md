# Legal Documents Implementation - Project Log

## Shared deep-link production fix (`/ru/recipes/:id`) — 2026-05-10

**Environment:** `https://recipies.mahallem.ist`

### Problem
- Shared recipe URLs such as `https://recipies.mahallem.ist/ru/recipes/1000015` could fail to open recipe details reliably on cold startup paths.

### Fix shipped
- `recipe_list/lib/router/app_router.dart`
	- `_DeepLinkDetailsLoaderState` now includes a fallback `RecipeApi`.
	- Details fetch now uses `services?.api ?? _fallbackApi`, so deep-link loading does not block on delayed app-services initialization.

### Git / deploy
- **Commit:** `a409f25`
- **Message:** `Fix shared deep links before appServices init`
- Deployed from `/var/www/recipie/otus_dz_2` with full rebuild/restart of `flutter-web` container.

### Verification
- Container `recipe_list_web`: **Up**
- `http://127.0.0.1:8088/`: **200 OK**
- `https://recipies.mahallem.ist/ru/recipes/1000015`: **200 OK**

**Project Date:** May 8, 2026

## Overview
Implementation of multi-language legal documentation infrastructure for Mahallem Recipes Flutter app with Express backend serving legal documents at `https://recipies.mahallem.ist/legal/<lang>/<slug>.html`.

## Completion Summary

### Total Progress: 11/12 Chunks Complete (91.7%)
- **Documents Created:** 40 HTML legal documents
- **Languages Supported:** 10 (en, ru, es, fr, de, it, tr, ar, fa, ku)
- **Document Types:** 4 per language (terms, personal_data, cookies, storage)
- **Total Size:** ~370 KB of legal content

## Chunk Completion Status

### ✅ Chunk 1: Backend Route Setup
- Express route: `GET /recipes/legal/:lang/:slug.html`
- Language whitelist validation (10 languages)
- Slug whitelist validation (4 document types)
- Path traversal protection via `path.resolve()`
- HTTP headers: `Content-Type: text/html; charset=utf-8`, `Cache-Control: public, max-age=3600`
- File: `/routes/recipes.js` (modified)

### ✅ Chunk 2: English Legal Docs (EN)
- `terms.html` (6.1 KB) - US Terms of Service
- `personal_data.html` (8.1 KB) - CCPA Privacy Notice
- `cookies.html` (8.5 KB) - Cookie Policy with browser controls
- `storage.html` (11 KB) - Local Storage Policy for mobile apps
- **Status:** All 4 files created in `/public/legal/en/`

### ✅ Chunk 3: Russian Legal Docs (RU)
- `terms.html` (7.8 KB) - Условия использования with 152-FZ references
- `personal_data.html` (12 KB) - 152-FZ Политика обработки персональных данных
- `cookies.html` (9.3 KB) - Политика использования cookies
- `storage.html` (14 KB) - Политика хранения данных
- **Status:** All 4 files created in `/public/legal/ru/`

### ✅ Chunk 4: Spanish Legal Docs (ES - GDPR)
- `terms.html` (3.3 KB) - Términos de Servicio
- `personal_data.html` (3.7 KB) - Política de Privacidad (GDPR compliant)
- `cookies.html` (2.8 KB) - Política de Cookies
- `storage.html` (3.3 KB) - Política de Almacenamiento Local
- **Status:** All 4 files created in `/public/legal/es/`

### ✅ Chunk 5: French Legal Docs (FR - GDPR)
- `terms.html` (2.9 KB) - Conditions d'Utilisation
- `personal_data.html` (2.9 KB) - Avis de Confidentialité (RGPD conforme)
- `cookies.html` (2.4 KB) - Politique de Cookies
- `storage.html` (2.9 KB) - Politique de Stockage
- **Status:** All 4 files created in `/public/legal/fr/`

### ✅ Chunk 6: German Legal Docs (DE - GDPR)
- `terms.html` (2.6 KB) - Nutzungsbedingungen
- `personal_data.html` (2.7 KB) - Datenschutzerklärung (DSGVO)
- `cookies.html` (2.4 KB) - Cookie-Richtlinie
- `storage.html` (2.8 KB) - Speicherrichtlinie
- **Status:** All 4 files created in `/public/legal/de/`

### ✅ Chunk 7: Italian Legal Docs (IT - GDPR)
- `terms.html` (2.6 KB) - Condizioni di Servizio
- `personal_data.html` (2.8 KB) - Avviso sulla Privacy (GDPR)
- `cookies.html` (2.4 KB) - Politica dei Cookie
- `storage.html` (2.9 KB) - Politica di Archiviazione
- **Status:** All 4 files created in `/public/legal/it/`

### ✅ Chunk 8: Turkish Legal Docs (TR - KVKK)
- `terms.html` (2.6 KB) - Kullanım Şartları
- `personal_data.html` (2.7 KB) - Kişisel Veri Politikası (KVKK 6698)
- `cookies.html` (2.3 KB) - Çerez Politikası
- `storage.html` (2.8 KB) - Depolama Politikası
- **Status:** All 4 files created in `/public/legal/tr/`

### ✅ Chunk 9: Arabic Legal Docs (AR - PDPL)
- `terms.html` (3.0 KB) - شروط الخدمة
- `personal_data.html` (3.3 KB) - سياسة الخصوصية (PDPL compliant)
- `cookies.html` (2.8 KB) - سياسة ملفات تعريف الارتباط
- `storage.html` (3.3 KB) - سياسة التخزين
- **Status:** All 4 files created in `/public/legal/ar/`

### ✅ Chunk 10: Persian Legal Docs (FA - General)
- `terms.html` (3.1 KB) - شرایط خدمات
- `personal_data.html` (3.3 KB) - سیاست حریم خصوصی
- `cookies.html` (2.8 KB) - سیاست کوکی‌ها
- `storage.html` (3.5 KB) - سیاست ذخیره‌سازی
- **Status:** All 4 files created in `/public/legal/fa/`

### ✅ Chunk 11: Kurdish Legal Docs (KU - General)
- `terms.html` (2.6 KB) - Şertên Bikaranîn
- `personal_data.html` (2.7 KB) - Rêbaza Nihûmendiya
- `cookies.html` (2.3 KB) - Rêbaza Cookies
- `storage.html` (2.8 KB) - Rêbaza Helanîna Cîhî
- **Status:** All 4 files created in `/public/legal/ku/`

### ⏳ Chunk 12: End-to-End Testing (IN PROGRESS)
- Testing valid requests to all 40 documents
- Testing invalid language codes (expect 400)
- Testing invalid slugs (expect 400)
- Testing invalid paths (directory traversal prevention)
- Verifying HTTP headers (Content-Type, Cache-Control)
- Testing from Flutter app consent links
- Rendering verification in browser
- **Status:** Starting testing phase

## Compliance Frameworks by Language

| Language | Country | Framework | Key Features |
|----------|---------|-----------|--------------|
| English | US | CCPA + General | Consumer rights, opt-out |
| Russian | Russia | 152-FZ | Data subject rights, controller obligations |
| Spanish | Spain | GDPR + ePrivacy | GDPR articles, ePrivacy Directive |
| French | France | GDPR + Law 78-17 | CNIL references, French requirements |
| German | Germany | GDPR + TMG | DSGVO articles, Telemediengesetz |
| Italian | Italy | GDPR + Italian Privacy Code | Italian-specific requirements |
| Turkish | Turkey | KVKK (Law 6698) | Personal data controller obligations |
| Arabic | Saudi Arabia | PDPL | Personal Data Protection Law compliance |
| Persian | Iran | General Data Protection | Islamic law principles |
| Kurdish | Iraq | General Data Protection | Regional standards |

## Directory Structure
```
/public/legal/
├── en/ (4 files, 33 KB)
├── ru/ (4 files, 44 KB)
├── es/ (4 files, 13 KB)
├── fr/ (4 files, 11 KB)
├── de/ (4 files, 11 KB)
├── it/ (4 files, 11 KB)
├── tr/ (4 files, 11 KB)
├── ar/ (4 files, 13 KB)
├── fa/ (4 files, 13 KB)
└── ku/ (4 files, 11 KB)
Total: 40 files, ~371 KB
```

## Backend Route Implementation
**File:** `/routes/recipes.js`

**Route:** `GET /recipes/legal/:lang/:slug.html`

**Validation:**
- Language whitelist: en, ru, es, fr, de, it, tr, ar, fa, ku
- Slug whitelist: terms, personal_data, cookies, storage
- Path traversal protection: path.resolve() validation

**Response Headers:**
- `Content-Type: text/html; charset=utf-8`
- `Cache-Control: public, max-age=3600`
- `X-Content-Type-Options: nosniff`

## Flutter Integration
**Frontend URL Generation:** `RecipeApiConfig.mahallemBaseUrl + '/recipes/legal/' + lang + '/' + slug + '.html'`

**Link Opening:** `url_launcher` v6.3.2 opens external browser for legal documents

**Consent Panel:** Links integrated with splash/consent gate checkboxes (10 languages × 4 document types)

## Files Modified/Created
- **Modified:** `/routes/recipes.js` (added legal route handler)
- **Created:** 40 HTML documents in `/public/legal/{lang}/`
- **Documentation:** TODO_LEGAL_DOCS.md, LEGAL_BACKEND_DOCS.md

## Next Steps
1. Complete Chunk 12 end-to-end testing
2. Verify all routes are accessible
3. Test consent links from Flutter app
4. Deploy to production at `recipies.mahallem.ist`

---
**Last Updated:** May 8, 2026
**Status:** 91.7% Complete (11/12 chunks)

---

## Production Incident Log — RU Recipe Cards Partially Untranslated

**Incident Date:** May 9, 2026  
**Environment:** Production (`recipies.mahallem.ist`)  
**Reported Symptom:** In Russian UI, many recipe cards still displayed English titles.

### Findings
- Production `GET /recipes/page?lang=ru` returned mixed-language payloads (both RU and EN titles).
- Per-item translation path was confirmed to work:
	- `GET /recipes/lookup/<id>?lang=ru` returned RU title.
	- `GET /recipes/lookup/<id>?lang=en` returned EN title for the same recipe.
- Root cause in frontend loader: initial list load from bulk page/category seed could accept mixed payload as-is, without forcing lookup-based backfill on startup.

### Fix Implemented
- Updated `recipe_list/lib/ui/recipe_list_loader.dart`.
- Added startup translation backfill trigger for non-EN languages when feed appears untranslated.
- RU heuristic: if a card title contains Latin letters and no Cyrillic, run `_retranslate(...)` to fetch localized entries via lookup and refresh list.
- Applied to both startup paths:
	- bulk page load (`/recipes/page`)
	- category seed fallback

### Verification
- Local analyzer check passed for modified file (`No issues found`).
- Deployed to production and verified active revision on server: `df8d67e`.
- Containers healthy after deploy (`recipe_list_web`, `recipe_list_prerender` up).

### Git
- **Commit:** `df8d67e`
- **Message:** `Backfill RU translations on initial feed load`

---

## Session + Preferred Language Policy Fix (Trust Device)

**Issue Date:** May 9, 2026  
**Environment:** Production (`recipies.mahallem.ist`)  
**Requested Behavior:**
- "Trust this device" login session must persist until explicit logout.
- Explicit logout must destroy session.
- Preferred language must be stored from login/profile edit and restored on next login/startup before UI/feed load.

### Root Causes
- Logout path in login UI could preserve biometric/token session for regular users.
- Preferred language selected in profile edit was not immediately mirrored to the active local session row.
- Post-login language could depend on login payload only; if backend payload lacked `preferredLanguage`, startup/login could drift to default/device language.

### Implemented Changes
- **`recipe_list/lib/auth/admin_session.dart`**
	- `logoutAdmin(clearSavedSession: true)` now clears persisted token sessions across mirrored credentials (not only active row), enforcing explicit-logout destruction.
	- Added `persistActiveSessionPreferredLanguage(AppLang lang)` to mirror explicit profile language changes into `auth_credentials.preferred_language`.
	- After successful token-based login and passkey/biometric restore, runs `reconcilePreferredLanguageFromServer()` to read `/recipes/users/me.language`, apply UI language, and persist it locally.
- **`recipe_list/lib/ui/user_card_page.dart`**
	- On profile language change/save, now persists chosen language into active mirrored session (`persistActiveSessionPreferredLanguage`).
- **`recipe_list/lib/ui/login_page.dart`**
	- Logout now always calls `logoutAdmin(clearSavedSession: true)` and resets saved-biometric state in UI.

### Verification
- Analyzer passed for changed files:
	- `lib/auth/admin_session.dart`
	- `lib/ui/user_card_page.dart`
	- `lib/ui/login_page.dart`

### Git
- **Commit:** `12d71fa`
- **Message:** `Restore language from server profile on session bootstrap`

---

## Profile Branch Navigation + Admin Logout Surface Fix

**Change Date:** May 10, 2026  
**Environment:** Production (`recipies.mahallem.ist`)

### Reported Symptoms
- After admin passkey login/logout, Profile could show a dead surface with 3 buttons (`Save admin login`, `Edit recipes`, `Logout`) and inconsistent navigation.
- From admin subpages (`Edit users list`, `Recipes added`), tapping bottom-navbar **Profile** did not always return to Profile root; users had to use back arrow.

### Root Causes
- `AdminAfterLoginPage` could remain mounted/rendered when admin context was dropped.
- Admin subpages were opened via imperative `Navigator.push(...)`, so they were outside predictable profile branch-root reset behavior.

### Implemented Changes
- **`recipe_list/lib/ui/admin_after_login_page.dart`**
	- Added guard to avoid non-admin rendering on admin-only page.
	- On admin-session loss/logout, route via go_router (`Routes.profile` / `Routes.recipes`) with Navigator fallback.
- **`recipe_list/lib/router/routes.dart`**
	- Added profile branch subroutes:
		- `/profile/users`
		- `/profile/recipes-added`
	- Added helper builders (`Routes.profileUsers(...)`, `Routes.profileRecipesAdded`).
- **`recipe_list/lib/router/app_router.dart`**
	- Registered nested admin subroutes under `/profile` with admin-session guards/redirects.
- **`recipe_list/lib/ui/admin_added_recipes_page.dart`**
	- Switched creator-card navigation to route-based `context.push(Routes.profileUsers(...))`.

### Tests / Validation
- Analyzer passed on changed routing/UI files.
- Tests passed:
	- `test/router_profile_branch_test.dart`
	- `test/router_branches_test.dart`
	- `test/admin_after_login_page_test.dart` (new regression test)

### Production Deployment
- Full server-side redeploy sequence executed from repo path:
	- `/var/www/recipie/otus_dz_2`
	- `git pull --ff-only`
	- `docker compose -f docker-compose.web.yml build flutter-web`
	- `docker compose -f docker-compose.web.yml up -d flutter-web`
- Health checks:
	- `recipe_list_web` container: **Up**
	- `http://127.0.0.1:8088/`: **200 OK**
	- `https://recipies.mahallem.ist/`: **200 OK**

### Git
- **Commit:** `9a708e0`
- **Message:** `Fix dead profile admin surface after logout`
- **Commit:** `7a8ab89`
- **Message:** `Format admin session bootstrap debug logs`
- **Commit:** `10bbce3`
- **Message:** `Route admin profile pages through /profile branch`
