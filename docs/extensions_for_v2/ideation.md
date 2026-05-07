# Tech-card multi-jurisdiction ideation

> Status: **ideation / pre-design**.
> Author: GitHub Copilot, 2026-05-07.
> Captures the design discussion that fed into
> [techcard-service.md](techcard-service.md). Lives next to the
> proposal it informs; can be deleted once the choices below land
> in the formal doc.
> Sibling: [nutrition-service.md](nutrition-service.md),
> [techcard-service.md](techcard-service.md).

## 1. Problem framing

> "We want Russian and US restaurants to participate in this
> project. Do you have any idea? The pipe writes Russian and US
> technology cards separately for territory, and leave the open
> end for the restaurant for edit/amend? Or what do you think?"

The Russian *Технико-технологическая карта* (ТТК, GOST 31987-2012)
and the US "standardized recipe + FDA nutrition panel + HACCP
cover" are **different documents** carrying mostly the **same
underlying facts**. We need both, and the system must let
restaurants amend the result without breaking the regulatory
audit trail.

## 2. Background — what each jurisdiction actually requires

### 2.1 Russia / CIS

Closed regulatory stack, single document:

- **GOST 31987-2012** — ТТК format (8 sections: scope, raw
  material requirements, recipe table with brutto/netto, process,
  presentation/storage, quality & safety, nutritional value,
  signatures).
- **GOST 31988-2012** — calculation method for energy and
  nutritional value, including thermal-loss coefficients.
- **МР 2.3.1.0253-21** — physiological norms for `% DV`.
- **TR TS 021/2011** — food-safety baseline cited in §2.
- **SanPiN 2.3.2.1324-03** — shelf life referenced in §5.

Output: a single Russian-language signed PDF held by the
establishment for Роспотребнадзор inspection.

### 2.2 United States

Distributed regulatory stack, several artifacts:

- **No federal recipe-card spec.** De-facto reference is USDA's
  *Food Buying Guide* + standardized recipe templates from USDA
  Team Nutrition / NRA / ServSafe.
- **FDA Menu Labeling Rule (21 CFR 101.11)** — chains 20+ outlets
  must publish calories on menus and provide the full panel
  (fat / saturated / *trans* / cholesterol / sodium / carbs /
  fiber / sugars (incl. added) / protein / vit D / calcium /
  iron / potassium) per serving, `% DV` on FDA 2016 reference
  diet (2,000 kcal). Independents are exempt but most large
  operators maintain the same dataset for liability.
- **FDA Food Code 2022** — adopted by 49 states. Holding/cooling
  temps, date-marking, employee health (analogue of
  SanPiN 2.3.2.1324-03).
- **HACCP** — required for juice (21 CFR 120), seafood
  (21 CFR 123), meat/poultry (USDA-FSIS 9 CFR 417), reduced-O₂
  packaging and sous-vide under variance (Food Code §3-502.12).
- **FALCPA + FASTER Act** — 9 major allergens (milk, eggs, fish,
  shellfish, tree nuts, peanuts, wheat, soybeans, sesame) must
  be disclosed on request.
- **ServSafe / NRFSP / Prometric** — manager certification
  expected.

Output: a **package** — standardized recipe + FDA nutrition panel
+ HACCP plan cover + allergen list. Often in a binder rather than
a single signed document.

### 2.3 ТТК ↔ US side-by-side

| ТТК section (GOST 31987)                 | US functional equivalent                                                                  |
|------------------------------------------|-------------------------------------------------------------------------------------------|
| 1. Область применения                    | Cover page on the standardized recipe                                                     |
| 2. Требования к сырью                    | Spec sheets / supplier *Certificates of Analysis*; FSMA Preventive Controls supplier list |
| 3. Рецептура (brutto/netto)              | Standardized recipe with **AP/EP** yields and yield % from USDA Food Buying Guide         |
| 4. Технологический процесс               | Recipe procedure; HACCP flow diagram with CCPs                                            |
| 5. Оформление, реализация, хранение      | Food Code chapter 3 — holding/serving/cooling/date-marking                                |
| 6. Показатели качества и безопасности    | HACCP critical limits + ServSafe SOPs                                                     |
| 7. Пищевая и энергетическая ценность     | FDA Menu Labeling panel (21 CFR 101.11)                                                   |
| 8. Подписи                                | HACCP plan signed by *PCQI* and operator                                                  |

The *content* maps cleanly; the *document shape* and the
*reference DB* (Skurikhin/Tutelyan vs. USDA FDC) differ.

## 3. Architecture — three options considered

### 3.1 Option A — One canonical model + jurisdiction renderers ★ RECOMMENDED

The assembler builds a single, jurisdiction-agnostic
`RecipeFacts` object:

- Resolved foods (cross-referenced to both Skurikhin and FDC via
  `food_xref`).
- Brutto / netto **AND** AP / EP weights for each line — both
  computable from the same wastage table.
- Macros per portion, per 100 g, per ounce.
- Allergens (9-major + RU SanPiN allergen list).
- Cooking-method metadata (with both GOST 31988 thermal-loss
  coefficients and Food Code CCP temps).
- Holding / cooling parameters (both SanPiN and Food Code values).

Then **renderers** emit different documents from the same facts:

- `template=ru-ttk` → GOST 31987 ТТК (Russian, signed PDF).
- `template=us-standardized` → standardized recipe + FDA panel +
  HACCP cover (English, imperial units).
- `template=eu-1169` → EU 1169/2011 information card (future).

A US restaurant doing pop-ups in Moscow opts in to **both**
templates; the same recipe yields two PDFs from the same facts,
guaranteed numerically consistent because they read from the
same `RecipeFacts`.

Pros:
- Single calc pipeline, single source of truth, no drift.
- Easy to add a third jurisdiction (Canada, EU, UAE) — write a
  renderer, no parser changes.
- Cross-format consistency for chains.

Cons:
- The canonical model must be a strict superset of every
  template's needs — adds complexity up front.
- Numbers in the body need a clearly documented "primary food
  DB" per template (Skurikhin for ТТК, FDC for US) to avoid
  confusing inspectors.

### 3.2 Option B — Two parallel pipelines per recipe

Separate parser/calc per territory, no shared canonical model.

Pros: simplest mental model — RU code path is fully
self-contained, US code path is fully self-contained.

Cons:
- Doubles the parser/calc surface area.
- Drift: Skurikhin protein vs. USDA protein on the same dish
  produces different macro numbers — chain operators will notice
  and inspectors *will* ask.
- Allergen, CCP, cooking-method detection duplicated.
- Two ingest crons, two Postgres footprints.

Reject unless the canonical model proves too lossy in practice.

### 3.3 Option C — One bilingual document with parallel columns

Print RU + EN side-by-side in one PDF (the "bilingual" mode I
sketched in [techcard-service.md §9.3](techcard-service.md)).

Pros: easy to author; useful for menus and staff training in
mixed-locale kitchens.

Cons: works for *menu* translation, **fails for legal
compliance** — a US health inspector will not accept a
ТТК-shaped doc; Роспотребнадзор will not accept an FDA-shaped
doc. Document *format* differs, not just language.

Conclusion: bilingual mode is a *menu-translation* feature, not a
*regulatory* feature. Keep it as an optional flag on the existing
`ru-ttk` template, but it does not solve the multi-jurisdiction
problem.

### 3.4 Decision

Go with **Option A**. Bilingual mode demoted to a renderer-side
toggle on `ru-ttk`. Option B kept in the back pocket if Option A's
canonical model proves insufficient.

## 4. Editor / amend flow ("open end")

Three concentric layers, in increasing immutability:

1. **Computed facts** — produced by the assembler from the
   recipe + nutrition snapshots. Immutable, deterministic,
   regenerable from inputs alone.
2. **Establishment overrides** — per-tenant, applied on every
   issue: preferred wastage `prep_kind` per food (e.g. "филе
   с кожей" vs "филе без кожи"), default cooking method per
   category, organisation-specific shelf-life if shorter than the
   regulatory default, allergen flags, supplier names.
3. **Per-issue edits** — mutable while the ТТК is in `draft`,
   frozen on `POST /issue`: the technologist's adjustments to a
   specific document — wastage% override on a single line,
   free-text additions to "Технологический процесс" / "Process",
   custom organoleptic table, custom yield, custom CCP notes,
   chef's plating photo.

Every issued PDF freezes layers 1 + 2 + 3 into
`recipe_snapshot.amendments[]` JSONB so an inspector (and the
audit trail) can see exactly what was added on top of the
computed baseline. Once `POST /issue` succeeds the row is
immutable; any further change is a new revision via
`POST /:ttkId/revise` which preserves the old PDF and links via
`superseded_by`.

This is the "open end": technologists / chef-managers keep
editing the draft indefinitely, with the editor offering an
inline diff against the computed baseline ("you changed the
wastage from 9.1% to 12% — this affects per-portion protein by
+0.4 g"). Only the issued PDF is locked.

## 5. Which template gets used

Defaulting rules (in order):

1. **Establishment** picks one or more jurisdictions on
   onboarding via `establishment.jurisdictions TEXT[]`. Examples:
   - Saint-Petersburg restaurant: `["ru-ttk"]`.
   - Brooklyn diner: `["us-standardized"]`.
   - Chain operating in both: `["ru-ttk", "us-standardized"]`.
2. **Recipe** itself is **jurisdiction-agnostic** — a recipe is a
   recipe; the document that wraps it is jurisdiction-specific.
3. **Issue** action accepts a `template` parameter; the UI
   pre-selects the establishment's *primary* (= first) template
   and offers an "Issue both" when multiple are configured.
4. **Public preview** (anonymous, no establishment): the SPA
   defaults the preview template to:
   - `ru-ttk` if `Accept-Language` ∈ {ru, ua, by, kz, uz, az, ge}
     OR the CDN edge geo is in the EAEU.
   - `us-standardized` otherwise.

   A dropdown in the preview header lets the user switch
   manually.

## 6. Concrete additions earmarked for `techcard-service.md`

When this ideation lands in the formal proposal, the following
deltas apply to [techcard-service.md](techcard-service.md):

- **§3.1 templates** — list supported templates and how renderers
  register (`templateRegistry` keyed by template id, each with
  `{render(facts, lang) → html, fonts, units, defaultLang,
  primaryFoodDb}`).
- **§5 schema additions:**
  - `establishment.jurisdictions TEXT[] NOT NULL DEFAULT '{}'`.
  - `establishment.primary_jurisdiction TEXT` (FK into
    `jurisdictions[]` for default issue).
  - `ttk.template TEXT NOT NULL` (e.g. `'ru-ttk'`,
    `'us-standardized'`).
  - `ttk.amendments JSONB NOT NULL DEFAULT '{}'` capturing layer
    2 + layer 3 deltas applied at issue time.
- **§6.x US template** — full layout for `us-standardized`:
  AP/EP yield columns, FDA nutrition panel (per-serving + per-100 g
  + `% DV` on FDA 2016 reference), HACCP cover sheet with CCP
  table populated from cooking-method detection (e.g. poultry
  CCP = 165 °F / 74 °C, 15 s), allergen footer for the 9 majors,
  English text, imperial units.
- **§7 calculation pipeline** — split into:
  1. `parse + resolve` (jurisdiction-agnostic).
  2. `RecipeFacts` materialisation with **both** Skurikhin and
     FDC numbers attached per line, plus CCPs and allergens.
  3. `template.render(facts)` → HTML → PDF. Renderer picks which
     food DB's numbers go into the body via
     `template.primaryFoodDb`.
- **§8 API additions:**
  - `template` query parameter on `GET /recipes/:id` and
    `GET /recipes/:id.pdf`.
  - `template` body field on `POST /issue` (multi-issue:
    `templates: ["ru-ttk","us-standardized"]` returns an array of
    `ttk` ids and PDF urls).
  - `GET /reference/templates` for SPA discovery (returns
    metadata: id, label, supported langs, default units, foodDb).
  - `GET /reference/jurisdictions` for the onboarding form.
- **§9 Flutter UI:**
  - When establishment has a single template, "Тех. карта" /
    "Tech card" button opens directly into that template's
    preview.
  - When multiple, opens a small chooser sheet ("ТТК (RU)" /
    "Standardized recipe (US)" / "Both").
  - Public (no establishment): a dropdown in the preview header.
  - **Editor pane** (technologist role) offers inline editing
    for all layer-3 fields, with a "vs computed" diff and a
    "Reset to computed" button per line.
- **§9 amend / edit flow** — explicit description of layers 1–3
  and the audit trail.
- **§11 Rollout:**
  - Stage T2 ships `ru-ttk` template only.
  - **New Stage T7 — `us-standardized` template.** Adds AP/EP
    columns to `RecipeFacts`, FDA panel renderer, HACCP cover
    template, allergen detection from FDC `food_attribute` +
    Open Food Facts. Onboarding wizard supports
    `jurisdictions = ["us-standardized"]`.
  - Stage T6 (bilingual PDF) demoted to a flag on `ru-ttk` rather
    than a separate stage; can ship anytime after T2.
  - **New Stage T8 — multi-template issue** (`POST /issue` with
    `templates: [...]`). Useful for chains operating across
    jurisdictions.

## 7. Open questions

- **Food DB cross-reference quality.** Skurikhin↔FDC mapping
  needs to be validated by a domain expert; missing mappings
  fall back to USDA scaled, which slightly biases RU numbers
  toward US averages. Acceptable for v2; flag in §13 of
  techcard-service.md.
- **HACCP plan completeness.** A standalone HACCP plan (hazard
  analysis, prerequisite programs, monitoring/verification
  procedures) is more than the cover sheet our `us-standardized`
  template generates. We render the *cover + CCP table* — the
  full plan remains the operator's responsibility. Document this
  clearly in the PDF footer.
- **Allergen detection accuracy.** USDA FDC's `food_attribute`
  table covers staples; user-uploaded recipes with brand-name
  ingredients (e.g. "Old Bay") need Open Food Facts. Edge cases
  (cross-contact, hidden allergens in sauces) beyond v2 scope.
- **Date format / unit per template.** Templates must own their
  formatting: ru-ttk = `dd.mm.yyyy`, °C, g, kJ; us-standardized
  = `mm/dd/yyyy`, °F, oz/lb, no kJ. Drives a small
  `template.formatters` interface.
- **Multi-tenant signature handling.** `establishment.director_sig`
  is a single PNG. For US PCQI signatures we may need a separate
  `signatories[]` table — defer to T7.
- **Inspector self-service URL.** Russian Роспотребнадзор and
  US health departments may want a stable URL to verify a PDF
  hash. We already store `doc_pdf_sha256`; expose
  `GET /verify/:sha256` returning the issuing establishment +
  date — no PDF download (inspectors already hold the PDF). T8.

## 8. Summary

- **Architecture:** one canonical `RecipeFacts` model, multiple
  jurisdiction renderers (`ru-ttk`, `us-standardized`, future
  `eu-1169`).
- **Tenant model:** `establishment.jurisdictions[]` selects which
  templates are offered; recipe is jurisdiction-agnostic.
- **Editor model:** three layers — computed / establishment /
  per-issue — frozen into the issued PDF for audit.
- **Default template:** establishment's primary; for anonymous
  previews, geo + Accept-Language with a manual override.
- **Rollout:** T2 ships RU, T7 adds US, T8 adds multi-template
  issue.
