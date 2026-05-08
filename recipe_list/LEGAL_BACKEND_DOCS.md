# Backend legal HTML contract

The startup consent splash now opens legal docs from backend URLs, not app assets.

## URL format

`{MAHALLEM_ORIGIN}/recipes/legal/{lang}/{doc}.html`

- `{MAHALLEM_ORIGIN}` = origin from `RecipeApiConfig.mahallemBaseUrl` (defaults to `https://mahallem.ist`)
- `{lang}` in: `en`, `ru`, `es`, `fr`, `de`, `it`, `tr`, `ar`, `fa`, `ku`
- `{doc}` in:
  - `terms`
  - `personal_data`
  - `cookies` (web)
  - `storage` (native)

## Required HTML files per language

For each supported language, backend must provide:

- `/recipes/legal/{lang}/terms.html`
- `/recipes/legal/{lang}/personal_data.html`
- `/recipes/legal/{lang}/cookies.html`
- `/recipes/legal/{lang}/storage.html`

This gives per-checkbox docs in each UI language.

## Frontend behavior

- Splash shows required checkboxes.
- Each checkbox has an **Open** link near it.
- Link opens the corresponding backend HTML doc in external browser.
- Recipe loading stays blocked until all required checkboxes are checked and user presses **I agree**.
