# i18n & Live Translation Proposal

Status: **proposal** (not implemented yet — only the offline RU/EN switcher is live, see `lib/i18n.dart` and `lib/ui/lang_fab.dart`).

## 1. What is already done

* `AppLang { ru, en }` enum + global `ValueNotifier<AppLang> appLang` in `lib/i18n.dart`.
* `AppLangScope` widget wraps the root subtree in `MaterialApp.home`, so toggling language rebuilds the whole app.
* `S.of(context)` returns a const string bag for the current language. All visible strings in the app (navbar, snackbars, list/empty/error states, details page, ingredient pluralization) are routed through `S`.
* `LangFab` — a 56×56 dp circular FAB with `AppColors.primary` (`#2ECC71`) background and white Roboto-900 / 18 sp `RU` / `EN` label, pinned to the top-left corner of the root `Stack` (`main.dart`) so it floats above every screen. Tap → `cycleAppLang()`.

This covers **static UI strings**. It does **not** translate dynamic recipe content fetched from TheMealDB (recipe name, category, area, instructions, tags, ingredient names) — TheMealDB returns those mostly in English, plus some non-Latin meals in their native language. Live translation is the next step.

## 2. Live translation strategy

The `mahallem_ist` project (`/Volumes/Working_MacOS_Extended/mahallem/mahallem_ist/local_docker_admin_backend/.env`) already has a working `GEMINI_API_KEY` provisioned for Google's Gemini API. We reuse the same key, **never embedding it in the Flutter client**.

### 2.1 Provider: Google Gemini (`gemini-1.5-flash`)

* Endpoint: `POST https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$GEMINI_API_KEY`.
* Prompt template:
  ```
  Translate the following short text from {sourceLang} to {targetLang}.
  Preserve cooking jargon. Output translation only, no quotes, no commentary.
  Text: """{text}"""
  ```
* Why Gemini and not Google Translate / DeepL: the only translation-capable key already provisioned in `mahallem_ist` is for Gemini. No new API contracts, no extra billing setup. Quality on cooking-domain text is on par with DeepL for `ru`↔`en`.

### 2.2 Architecture: thin proxy, **never the raw key in the app**

```
Flutter app  ──HTTPS──>  /translate (our proxy)  ──HTTPS──>  Gemini API
                                  ▲
                         GEMINI_API_KEY (server-side only)
```

**Reason — OWASP A02 (Cryptographic Failures) / A07 (Identification & Authentication).** Bundling the Gemini key into a release APK/IPA exposes it to anyone who unzips the bundle. A malicious actor would burn through the quota and the bill. The key MUST stay on a server we control. The proxy:

1. accepts `POST /translate` with `{ text, from, to }` (and optionally an idempotency hash);
2. injects the key from env (`process.env.GEMINI_API_KEY`);
3. forwards to Gemini and returns the translated string;
4. enforces auth (e.g. Firebase ID token or a signed app-attestation token), per-IP rate limit, and request-size cap.

For local development only, `--dart-define=GEMINI_API_KEY=...` may be used while we don't yet have the proxy. This MUST NOT ship to release builds.

### 2.3 Client-side caching

Translating ~20 ingredients × N recipes per scroll session is wasteful. Cache by `sha256(sourceText + '|' + targetLang)`:

* in-memory `LinkedHashMap<String, String>` (LRU, cap 1000) for the session;
* persistent layer: `shared_preferences` or `hive` keyed by the same hash, with a TTL of 30 days.

Cache hit ratio ≥ 80 % is realistic since ingredient names repeat heavily.

### 2.4 Batching

Gemini's request quota is per-call, not per-token, and round-trips dominate latency. For each recipe build:

* collect all uncached strings (name, category, area, tags, ingredients\*, instructions);
* serialize into a single prompt with numbered lines;
* parse the numbered response back.

That collapses ~25 calls per recipe into 1.

### 2.5 What to translate, what NOT to translate

| Field | Translate? | Notes |
| --- | --- | --- |
| `recipe.name` | yes | Source is usually English; Russians want it in RU. |
| `recipe.category`, `recipe.area` | yes | Short, very cacheable. |
| `recipe.tags` | yes | Same. |
| `recipe.ingredients[].name` | yes | Highest cache reuse. |
| `recipe.ingredients[].measure` | **no** | Numeric + unit; risk of misformatting outweighs benefit. |
| `recipe.instructions` | yes | Long; translate only when details page opens, not in list. |
| `recipe.youtubeUrl`, `recipe.sourceUrl`, `recipe.imageUrl` | no | URLs. |

### 2.6 Failure modes

* Network error / 5xx → fall back to original English text and surface a small "translation unavailable" hint (no exception bubble-up).
* Rate-limit (429) → exponential backoff in the proxy; client treats it like a transient network error.
* Wrong-language detection (Gemini sometimes echoes the source) → cheap heuristic: if output equals input, log + retry once with a stricter prompt.

## 3. Migration of static strings

Once the proxy exists, static UI strings should move from `S` (hand-rolled map) to standard Flutter `gen-l10n` ARB files. `S` will then expose the same getters (`s.tabRecipes`, etc.) backed by generated `AppLocalizations`. The `AppLang` toggle becomes a wrapper that flips `MaterialApp.locale`. The migration is mechanical because every call site already uses `S.of(context).<getter>`.

## 4. Open questions

1. **Where does the proxy live?** Existing `mahallem_ist` Docker stack already has Node/Express services; the cheapest path is to add a `/translate` route there next to whatever consumes `GEMINI_API_KEY` today. Confirm with the mahallem_ist owner before reusing the deployment.
2. **Auth on the proxy.** If recipe_list has no user accounts yet, a minimum viable defense is App Check / Play Integrity API to gate the endpoint to our app builds.
3. **Cost ceiling.** Gemini Flash is cheap (~$0.075 per 1M input tokens at the time of writing) but unlimited client-driven translation can still spike. Set a daily/monthly cap in the proxy and degrade to English on cap.
