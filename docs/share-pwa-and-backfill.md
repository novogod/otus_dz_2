# Share UX, iOS PWA install, and the recipes backfill cron

This document consolidates four production changes that landed
between commits `b42a327` and `00f8420`, plus the operational cron
entry installed afterwards.

| # | Topic                                       | Commit    |
| - | ------------------------------------------- | --------- |
| 1 | `Sign Up` translated inside snackbars       | `b42a327` |
| 2 | Share button uses the Web Share API         | `ca09447` |
| 3 | Four social buttons → one native-share btn  | `6859fe1` |
| 4 | PWA install button on iOS + auto-language   | `38bace8` |
| 5 | Fallback social dropdown when no Web Share  | `00f8420` |
| 6 | `recipes-backfill` cron at 05:30 UTC daily  | (server)  |

All client-side changes live under
[recipe_list/lib/ui/web_share/](../recipe_list/lib/ui/web_share/) and
[recipe_list/web/index.html](../recipe_list/web/index.html).

---

## 1. `Sign Up` translated inside snackbars (`b42a327`)

The "registration required" snackbar had a hard-coded English
fragment ("…tap **Sign Up**.") that survived all 10 locales. Added
a `signUpButton` slang key in every locale and interpolated it into
the snackbar message via slang rich-text. Snackbar now reads, e.g.
in Russian: «Чтобы добавить рецепт, нажмите **Регистрация**.»

## 2. Share button uses the Web Share API (`ca09447`)

`share_plus` on web defaults to `navigator.share` when available.
We now construct the share payload via
`SharePlus.instance.share(ShareParams(title, text, uri, subject))`
so the recipient app actually receives a structured link instead of
a plain text blob. Confirmed working on iOS Safari, Android Chrome,
modern Edge and Win10+/macOS13+/ChromeOS Chrome — the user picks
WhatsApp / Messages / Mail / etc. from the system share sheet.

## 3. Four social buttons → one native-share button (`6859fe1`)

The first iteration of the AppBar had four hand-rolled circle
buttons (Facebook, Instagram, VK, WhatsApp). They were redundant
once the system share sheet worked, and they cluttered narrow
phones. Collapsed the row to a single `Icons.share` circle button
which opens the native sheet; that sheet already lists every
installed app on iOS/Android.

## 4. PWA install button on iOS + auto-language (`38bace8`)

Two improvements:

- **iOS detection.** Safari does not fire `beforeinstallprompt`,
  so `window.isPwaInstallAvailable()` is always false on iOS and
  the install button used to stay hidden. Added
  `window.isIosBrowser()` (UA-sniffs `iPad|iPhone|iPod`) and
  `window.isPwaStandalone()` (detects `display-mode: standalone`).
  When iOS && !standalone the button is shown and tapping it pops
  a translated modal: «Tap **Share** → **Add to Home Screen**».
- **Auto language detection.** The instructions modal renders in
  whichever locale the app is currently running, using four new
  slang keys (`pwaInstallTitleIos`, `pwaInstallStepShare`,
  `pwaInstallStepAddToHomeScreen`, `pwaInstallGotIt`) across all
  10 locales.

The JS↔Dart bridge lives in
[recipe_list/web/index.html](../recipe_list/web/index.html) and
[recipe_list/lib/ui/web_share/pwa_install_web.dart](../recipe_list/lib/ui/web_share/pwa_install_web.dart);
the conditional-import facade is in
[recipe_list/lib/ui/web_share/pwa_install.dart](../recipe_list/lib/ui/web_share/pwa_install.dart).

## 5. Fallback social dropdown when no Web Share (`00f8420`)

### Problem

`navigator.share` is **not** available on:

- Linux desktop Chrome
- Firefox desktop (any OS)
- older Edge
- any non-HTTPS origin

`share_plus` then silently writes the link to the clipboard with no
UI, so the share button appeared to "do nothing" on those browsers.

### Fix

Added a JS helper `window.canWebShare()` that returns
`typeof navigator.share === 'function'` and a Dart facade
`canWebShareWeb()` (with stub for non-web).

`_onShareTap` branches at click time:

```dart
if (!kIsWeb || canWebShareWeb()) {
  await _systemShare();        // unchanged: native sheet
} else {
  await _showShareMenu(ctx);   // new: dropdown of URL intents
}
```

When the API is missing, we open a Material `showMenu` anchored
under the share button with **10 social-network share-via-URL
intents**, in display order:

| # | Network    | URL template                                                   |
| - | ---------- | -------------------------------------------------------------- |
| 1 | WhatsApp   | `https://wa.me/?text={url+text}`                               |
| 2 | Telegram   | `https://t.me/share/url?url={url}&text={text}`                 |
| 3 | Facebook   | `https://www.facebook.com/sharer/sharer.php?u={url}`           |
| 4 | X          | `https://twitter.com/intent/tweet?url={url}&text={text}`       |
| 5 | Reddit     | `https://www.reddit.com/submit?url={url}&title={title}`        |
| 6 | LinkedIn   | `https://www.linkedin.com/sharing/share-offsite/?url={url}`    |
| 7 | VK         | `https://vk.com/share.php?url={url}&title={title}&description={text}` |
| 8 | Pinterest  | `https://pinterest.com/pin/create/button/?url={url}&description={text}` |
| 9 | Email      | `mailto:?subject={title}&body={url+text}`                      |
|10 | Copy link  | `Clipboard.setData` + translated snackbar                      |

Each menu entry is a 28×28 brand-coloured circle (BoxShape.circle)
with an icon or stylised glyph, plus a label in the active locale.
The link-preview card on the recipient side renders from the
existing `og:image` / `og:title` / `og:description` meta tags in
[recipe_list/web/index.html](../recipe_list/web/index.html) — same
mechanism WhatsApp uses for ordinary links.

Four new slang keys were added across all 10 locales:
`shareTooltip`, `shareEmail`, `shareCopyLink`, `shareLinkCopied`.

## 6. `recipes-backfill` cron at 05:30 UTC daily

Background: see
[themealdb-ingest-cron-and-translate-gap.md](./themealdb-ingest-cron-and-translate-gap.md)
and
[recipe-list-88-recipes-non-en-locales.md](./recipe-list-88-recipes-non-en-locales.md).

The daily ingest cron inside `mahallem-user-portal`
(`/app/routes/recipes.js`, `RECIPES_INGEST_CRON='0 4 * * *'`)
already translates new recipes into all 10 locales, but a small
fraction of `(id, lang)` pairs are dropped per run:

- Gemini occasionally echo-rejects (returns the English back) and
  the row is left with a missing key.
- Per-row `RECIPES_TRANSLATE_BUDGET_MS` may expire on slow upstream.
- A 503 storm on Gemini drops a chunk of the fan-out.

The **one-time** script `/root/backfill_recipes.sh` walks every
recipe row where `i18n` is missing a target lang and calls
`GET /recipes/lookup/$id?lang=$L` to repopulate it. It now runs
**daily at 05:30 UTC** — about 90 minutes after the ingest's start
at 04:00 UTC, well past its typical completion — via:

```cron
# /etc/cron.d/recipes-backfill
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
30 5 * * * root /root/backfill_recipes.sh >> /var/log/recipes_backfill.cron.log 2>&1
```

Log files:

- `/var/log/recipes_backfill.log` — per-row trace, overwritten
  each run by the script's `: > "$LOG"`.
- `/var/log/recipes_backfill.cron.log` — cron stdout/stderr,
  appended.

If `RECIPES_INGEST_CRON` ever changes, bump the `30 5` here to
stay roughly 1.5 h after the ingest start.

### Why a fixed offset and not event-driven

Tailing container logs for `[ingest] done` would be more precise
but needs a long-running supervisor (systemd unit) and has to
handle restarts and missed events. The ingest reliably completes
in well under 90 min (small daily batch, bounded `probeBudget`),
so the fixed offset is robust and zero-maintenance.
