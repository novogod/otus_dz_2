# Tech-card (ТТК) service — design proposal

> Status: **proposal / not implemented**.
> Author: GitHub Copilot, 2026-05-07.
> Sibling: [nutrition-service.md](nutrition-service.md).

## 1. Goals

Generate a **professional Russian-style technological card**
(`Технико-технологическая карта`, ТТК) for any recipe in the
catalogue — TheMealDB-seeded, admin-added, or user-posted —
conforming to the public-catering standards used across the
RU/CIS food-service market:

- **GOST 31987-2012** — general requirements for ТТК format.
- **GOST 31988-2012** — calculation method for energy and
  nutritional value.
- **МР 2.3.1.0253-21** — physiological norms used for `% DV`.
- **TR TS 021/2011** — food-safety baseline cited in the
  "сырьё" section.
- **SanPiN 2.3.2.1324-03** — shelf-life table referenced in
  the "хранение" section.

Output is a **printable PDF + structured JSON**, both reachable
from the Flutter app's recipe-details page via a new
`Тех. карта` / `Tech card` button.

## 2. Why a separate container

The nutrition service ([nutrition-service.md](nutrition-service.md))
already resolves ingredients to canonical food rows and computes
macros. The ТТК service is a **consumer** of nutrition: it adds
the regulatory layer (brutto/netto/wastage tables, cooking-loss
coefficients per GOST 31988, organoleptic boilerplate, header
metadata, PDF rendering).

Separating it keeps:

- **PDF/typography stack** (LaTeX or Chromium-headless) out of
  the nutrition container's hot path.
- **Russian regulatory tables** (Skurikhin/Tutelyan composition
  DB, Сборник рецептур wastage tables, SanPiN shelf-life tables,
  МР 2.3.1.0253-21 norms) co-located with the code that uses
  them, instead of bloating nutrition's USDA index.
- **Establishment metadata** (organisation name, director,
  signatures, ТТК numbering) in its own scoped Postgres schema —
  this is multi-tenant by design (one Otus account = one
  establishment).
- **Audit log** (every issued ТТК PDF is archived; inspectors
  can request the exact PDF that was active on a date) on a
  dedicated table, not muddled with recipe data.

## 3. Architecture

```
                ┌────────────────────────────────────┐
   Flutter SPA  │  GET  /techcard/recipes/:id        │
   recipe page  │  POST /techcard/recipes/:id/issue  │   ← admin
   ───────────► │  GET  /techcard/recipes/:id.pdf    │
                │                                    │
                │   ┌──────────────────────────────┐ │
                │   │ assembler                    │ │
                │   │  · pull recipe (user-portal) │ │
                │   │  · pull macros (nutrition)   │ │
                │   │  · resolve brutto/netto via  │ │
                │   │    Сб.рецептур wastage table │ │
                │   │  · apply GOST 31988 thermal  │ │
                │   │    loss per cooking method   │ │
                │   │  · merge boilerplate         │ │
                │   │    (organoleptic, safety)    │ │
                │   └──────────────┬───────────────┘ │
                │                  │                 │
                │   ┌──────────────▼───────────────┐ │
                │   │ renderer  (HTML → PDF via    │ │
                │   │  headless Chromium)          │ │
                │   └──────────────────────────────┘ │
                │                                    │
                │  Postgres `techcard` schema:        │
                │   establishment, ttk, ttk_revision, │
                │   wastage_table, thermal_loss,      │
                │   skurikhin_food                    │
                │  Object store: PDFs (S3 / minio)    │
                └────────────────────────────────────┘
```

### 3.1 Container placement

Compose service `techcard` in
[docker-compose.web.yml](../../docker-compose.web.yml):

- Joins `local_docker_admin_backend_mahallem_network` so it can
  reach `mahallem-user-portal:4000` and `nutrition:8090`.
- Bound to `127.0.0.1:8091:8091`. Host nginx terminates TLS at
  `recipies.mahallem.ist/api/techcard/*`.
- Mount-volume `techcard_pdfs` for archived PDFs (or S3 via
  `S3_BUCKET=…` env), and `techcard_data` for the
  Skurikhin/Сб.рецептур reference dataset.

### 3.2 Why two services and not a flag in `nutrition`

A single GOST-compliant ТТК needs **per-establishment** state
(name, address, OGRN, director's signature image, ТТК counter)
and a **PDF rendering pipeline**. Both are absent from the
nutrition service and would push it from a stateless compute
service into a stateful, tenant-aware service. Splitting also
means the nutrition rebuild cycle (alias map retraining) and
the techcard rebuild cycle (regulation changes, signature
updates) are independent.

## 4. Reference datasets

Shipped read-only inside the container, refreshed by the same
`techcard-ingest` cron container as the nutrition reference
data:

- **Skurikhin/Tutelyan** «Химический состав российских пищевых
  продуктов питания» — RU equivalent of USDA FDC. Per-100 g
  composition (B/Ж/У + vitamins + minerals + organic acids +
  ash + water). Provides the canonical numbers ТТК require.
  Mapping `usda_food.fdc_id` ↔ `skurikhin_food.code` lives in
  `food_xref` table; missing rows fall back to USDA scaled by
  the standard moisture conversion.
- **Сборник рецептур блюд и кулинарных изделий** (Здобнов,
  Цыганенко, Пересичный — current edition) — wastage tables for
  cold prep (`Холодная обработка`) and standard yields. Encoded
  as `wastage_table(food_code, prep_kind, wastage_pct)`.
- **GOST 31988-2012 Annex Б** — thermal-loss coefficients per
  cooking method (varka, zharka, tushenie, zapekanie, etc.) for
  each macro. Encoded as
  `thermal_loss(method, macro, loss_pct)`.
- **МР 2.3.1.0253-21** — physiological norms by demographic
  cohort. Encoded as `dv_profile(cohort_code, nutrient, dv_value,
  unit)`. Cohorts: `adult-male`, `adult-female`,
  `child-7-10`, `pregnant`, etc.
- **SanPiN 2.3.2.1324-03** Annex 1 — storage conditions and
  shelf life by dish category. Encoded as
  `shelf_life(category, temp_min_c, temp_max_c, hours)`.
- **TR TS 021/2011 Annex 2** — microbiological limits, rendered
  inline into section §6 of the ТТК as a stock table.

## 5. Data model

```sql
-- Establishment = tenant.
CREATE TABLE establishment (
  id              UUID PRIMARY KEY,
  name            TEXT NOT NULL,
  legal_form      TEXT NOT NULL,           -- "ООО", "ИП"
  ogrn            TEXT,
  inn             TEXT,
  address         TEXT,
  director_name   TEXT,
  director_sig    BYTEA,                    -- PNG signature
  technologist    TEXT,
  technologist_sig BYTEA,
  ttk_counter     INT NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Issued ТТК = immutable revision per recipe per establishment.
CREATE TABLE ttk (
  id              UUID PRIMARY KEY,
  establishment_id UUID NOT NULL REFERENCES establishment,
  recipe_id       BIGINT NOT NULL,
  ttk_no          TEXT NOT NULL,            -- "ТТК № 14/2026"
  issued_at       DATE NOT NULL,
  in_force_from   DATE NOT NULL,
  superseded_by   UUID REFERENCES ttk,
  recipe_snapshot JSONB NOT NULL,           -- frozen recipe at issue
  nutrition_snapshot JSONB NOT NULL,        -- frozen macros at issue
  doc_pdf_url     TEXT NOT NULL,            -- S3 key
  doc_pdf_sha256  TEXT NOT NULL,
  signed_by       JSONB,                    -- {director, technologist}
  UNIQUE (establishment_id, ttk_no)
);

-- Per-line table (brutto/netto/wastage) used in §3 of the PDF.
CREATE TABLE ttk_line (
  ttk_id          UUID NOT NULL REFERENCES ttk ON DELETE CASCADE,
  ord             INT NOT NULL,
  ingredient_raw  TEXT NOT NULL,            -- "филе куриное"
  food_code       TEXT,                      -- skurikhin_food.code
  brutto_g        NUMERIC(8,1) NOT NULL,
  netto_g         NUMERIC(8,1) NOT NULL,
  wastage_cold_pct NUMERIC(4,1) NOT NULL,
  wastage_thermal_pct NUMERIC(4,1) NOT NULL,
  PRIMARY KEY (ttk_id, ord)
);
```

PDFs themselves live in object storage; only the URL + hash are
in Postgres.

## 6. ТТК document layout (PDF)

Eight sections per **GOST 31987-2012**. Pagination: A4 portrait,
margins 20/20/15/15 mm, font Times New Roman 12 (table 10),
single-spaced.

| # | Section (RU)                                  | Source                                                   |
|---|-----------------------------------------------|----------------------------------------------------------|
| 0 | Header: УТВЕРЖДАЮ + signatures + ТТК №        | `establishment` + `ttk_no`                               |
| 1 | Область применения                            | template + recipe.name                                   |
| 2 | Требования к сырью                            | static block citing TR TS 021/2011 + GOSTs per ingredient|
| 3 | Рецептура (brutto / netto / wastage table)    | `ttk_line` rows; column "выход на 1 порц / 100 г"        |
| 4 | Технологический процесс                       | `recipe.instructions`, augmented with detected method    |
| 5 | Оформление, реализация, хранение              | template + `shelf_life` lookup by recipe category        |
| 6 | Показатели качества и безопасности            | organoleptic table + TR TS 021/2011 micro limits         |
| 7 | Пищевая и энергетическая ценность             | nutrition snapshot, both **per 100 g** and **per portion** |
| 8 | Подписи                                       | director + technologist signature PNGs                   |

Section 7 table columns (per GOST 31988-2012):

```
                       per 100 g       per portion (XX g)
Белки, г                ...              ...
Жиры, г                 ...              ...
Углеводы, г             ...              ...
Энергетическая ценность  ... ккал /       ... ккал /
                         ... кДж           ... кДж
```

Optional appendix table when admin checks "Расширенные
показатели": full vitamin/mineral list with `% МР 2.3.1.0253-21`.

## 7. Calculation pipeline

For each ingredient line:

1. **Resolve to Skurikhin code.** Reuse the nutrition resolver
   (HTTP `GET nutrition:8090/resolve?lang=ru&q=…`) → fdc_id →
   `food_xref` → skurikhin code. If no Skurikhin row exists,
   convert USDA per-100 g composition into the Skurikhin row
   shape (same atoms, just different DB).
2. **Compute brutto/netto.** Recipe stores netto-equivalent in
   the `RecipeIngredient.measure` field (after the parser
   already converted to grams). Multiply by
   `1 / (1 - wastage_cold_pct/100)` to get brutto using
   `wastage_table` keyed by `(food_code, prep_kind)`. Default
   prep_kind = "сырье основное"; admin UI lets technologist
   override (e.g. "полуфабрикат высокой степени готовности").
3. **Apply thermal loss.** Detect cooking method from
   `recipe.instructions` using a small rule-set (varka, zharka,
   tushenie, zapekanie, pripuskanie, …). For each macro M:
   `M_final = M_raw * (1 - thermal_loss[method, M]/100)`.
   Fallback if no method detected: "комбинированный" (default
   coefficients 6/12/9 for B/Ж/У from GOST 31988 §5.4).
4. **Aggregate per portion.** Recipe's `strServings` (or admin
   override) gives N portions; total dish weight = Σ netto × (1
   − thermal_water_loss). Per-portion = total / N. Per-100 g
   computed from per-portion.
5. **Round.** Macros to 0.1 g; kcal to integer; kJ = kcal × 4.184
   rounded to integer (per GOST 31988 §6.2).

All inputs and outputs frozen into `nutrition_snapshot` JSONB so
the PDF is reproducible byte-for-byte from any historical
revision.

## 8. API contract

Base path: `https://recipies.mahallem.ist/api/techcard`.

### 8.1 Read

#### `GET /recipes/:id?lang=ru&estab=:uuid`

Returns the **current draft** ТТК for the recipe under the
specified establishment (or the global default if `estab`
omitted — uses public Otus boilerplate). Useful for the Flutter
preview screen — does not allocate a `ttk_no`.

```jsonc
// 200 OK
{
  "recipeId": 53220,
  "establishmentId": "5c8f…",
  "ttkNo": null,                 // null until issued
  "status": "draft",
  "header": {
    "name": "Каббсе",
    "approvedBy": null,
    "issuedAt": null
  },
  "sections": {
    "scope":         "Настоящая ТТК распространяется на блюдо…",
    "rawMaterials":  [/* GOST citations per ingredient */],
    "recipe": {
      "lines": [
        { "ord": 1, "name": "филе куриное",
          "bruttoG": 220, "nettoG": 200,
          "wastageColdPct": 9.1, "wastageThermalPct": 25 }
      ],
      "yieldPortionG": 320,
      "yieldServings": 4
    },
    "process":       "1. Куриное филе нарезать… 2. …",
    "presentation":  { "tempC": 65, "shelfLifeH": 24 },
    "qualitySafety": { "organoleptic": {/* … */}, "micro": {/* … */} },
    "nutrition":     {
      "per100g":   { "kcal": 192, "kJ":  803, "p": 13.4, "f": 4.1, "c": 22.1 },
      "perPortion":{ "kcal": 614, "kJ": 2569, "p": 42.9, "f":13.1, "c": 70.7,
                     "portionG": 320 }
    }
  },
  "computedAt": "2026-05-07T08:33:11Z"
}
```

#### `GET /recipes/:id.pdf?lang=ru&estab=:uuid&signed=false`

Renders the draft as PDF. `signed=false` = "ПРОЕКТ" watermark.
Used by the Flutter "Tech card" button when the user is **not**
an authorised technologist (everyone gets a PROJECT preview).
`Cache-Control: private, max-age=60`.

### 8.2 Issue (admin / technologist only)

#### `POST /recipes/:id/issue`

```jsonc
{
  "establishmentId": "5c8f…",
  "inForceFrom":     "2026-06-01",
  "overrides": {
    "servings": 4,
    "lines": [
      { "ord": 1, "wastagePrepKind": "филе с кожей" }   // technologist tweaks
    ],
    "method": "тушение"
  },
  "signedBy": { "director": "Иванов И.И.", "technologist": "Петров П.П." }
}
```

Allocates `ttk_no = "ТТК № <counter>/<year>"`, freezes
recipe + nutrition snapshots, renders the signed PDF, stores it
in S3, increments `establishment.ttk_counter`. Returns the new
`ttk.id` and the PDF URL.

#### `POST /:ttkId/revise`

Issues a **superseding** revision; old `ttk` row is preserved
with `superseded_by` set. PDFs of all revisions remain available
for inspection-trail purposes.

#### `GET /establishments/:uuid/ttk?recipeId=…&active=true`

Lists issued ТТК for an establishment. `active=true` filters to
non-superseded.

### 8.3 Reference data (read-only)

Useful for the admin UI:

- `GET /reference/wastage?foodCode=…&prepKind=…`
- `GET /reference/thermal-loss?method=…`
- `GET /reference/shelf-life?category=…`
- `GET /reference/dv?cohort=adult-male`

## 9. Flutter integration

### 9.1 Recipe-details "Tech. card" button

Place a button **after** the `Details ▸` button from
[nutrition-service.md §6.1](nutrition-service.md), so the bottom
of the nutrition card on
[recipe_details_page.dart](../../recipe_list/lib/ui/recipe_details_page.dart)
becomes:

```
Nutrition (per serving)
… P/F/C bar …
                                  [ Details ▸ ]   [ Тех. карта ▸ ]
```

`onPressed` opens a new route `/recipe/:id/techcard`
(localised label: `i18n.techCardButton`). The route renders a
read-only preview of sections 1–7 in native Flutter widgets
(scrollable, mobile-friendly typography), with an action bar:

- **Скачать PDF** — fetches `/recipes/:id.pdf?signed=false`,
  shares via the existing `share_plus` pipeline.
- **Открыть в браузере** — opens the same URL in a tab.
- For users with `role=technologist` AND a linked establishment:
  **Утвердить и подписать** — opens the issue dialog and calls
  `POST /recipes/:id/issue`. The button is hidden for everyone
  else.

The button is **always visible** on a recipe — even for
user-posted recipes — because every recipe goes through the
same parser and produces a draft ТТК. When the underlying
nutrition coverage is `< 0.6` the button shows a warning icon
and the preview opens with a banner: "Coverage is approximate;
review wastage and method before issuing".

### 9.2 Models

```dart
class TechCardDraft {
  final int recipeId;
  final String? ttkNo;          // null while draft
  final TechCardHeader header;
  final TechCardSections sections;
  final DateTime computedAt;
}
class TechCardSections {
  final String scope;
  final List<RawMaterialCitation> rawMaterials;
  final TechCardRecipe recipe;
  final String process;
  final TechCardPresentation presentation;
  final TechCardQualitySafety qualitySafety;
  final TechCardNutritionTable nutrition;
}
```

### 9.3 Localisation

The PDF and the Flutter preview render in **Russian** by
default (the regulatory standard is Russian). When the SPA is in
en/de/fr/es/it/tr the preview labels are translated (via
existing `slang`/i18n), but the PDF stays Russian-text +
optional bilingual mode (RU left column, locale right column)
for export to mixed kitchens. Bilingual mode is admin-toggle
per establishment.

## 10. Admin UI

A new `/admin/techcard` route. Tabs:

- **Establishments** — manage tenant cards (name, OGRN,
  signatures, technologist roster).
- **Drafts** — recipes whose draft ТТК hasn't been issued.
- **Issued** — table of `ttk` rows; columns: `ttk_no`, recipe,
  date, status (active / superseded), actions.
- **Reference** — read-only view of wastage tables, thermal-loss
  table, shelf-life table, DV norms — so a technologist can
  audit the numbers used by the calculator.

## 11. Rollout

Depends on **Stage 4** of [nutrition-service.md](nutrition-service.md)
(macros must be available before ТТК can be assembled).

1. **Stage T0 — reference data ingest.** Skurikhin DB,
   Сб.рецептур wastage table, GOST 31988 thermal-loss table,
   МР 2.3.1.0253-21 norms, SanPiN shelf-life table loaded into
   `techcard-ingest` container; verify queryable via
   `/reference/*`.
2. **Stage T1 — assembler + draft API** (`GET /recipes/:id`).
   No PDF, no issue endpoint. Internal QA with 5–10 reference
   dishes against hand-computed ТТК samples.
3. **Stage T2 — PDF renderer.** Headless Chromium + HTML
   templates. Sample ТТК reviewed by a domain expert
   (technologist).
4. **Stage T3 — Flutter "Tech. card" button** (read-only
   preview + PDF download). Behind feature flag `techcard.enabled`.
5. **Stage T4 — establishment management + issue flow.** Tenant
   onboarding, signature upload, `POST /issue`.
6. **Stage T5 — multi-revision tracking + audit trail.**
7. **Stage T6 — bilingual PDF + child/elderly DV cohorts.**

## 12. Operational notes

- **Reproducibility:** every issued ТТК stores the full
  recipe + nutrition snapshot inline. Re-running the calculator
  on a `ttk` row must produce a byte-identical PDF
  (`doc_pdf_sha256` is verified on every read).
- **Skurikhin licensing:** the dataset itself is published; we
  ship a derived, normalised JSON we are entitled to
  redistribute. License attribution lives in the PDF footer and
  in `/reference/about`.
- **Memory budget:** ~250 MB resident (Chromium + reference
  tables). Cold render ~600 ms, warm ~150 ms.
- **PDF storage:** sized for ~500 KB per ТТК × 50 establishments
  × 200 dishes × 3 revisions ≈ 15 GB lifetime. Comfortably fits
  in MinIO; S3 fallback configured but not required for v2.
- **Failure modes are fail-soft:** if `nutrition` is down, the
  ТТК preview shows section 7 as "—" and a banner; sections 1–6
  still render from boilerplate + recipe text. Issuing is
  blocked until nutrition recovers.

## 13. Out of scope (future work)

- **Калькуляционная карта (price card)** — adjacent document,
  needs procurement prices per ingredient. Easy follow-up once
  brutto values are stored.
- **Сводная ведомость продуктов** — daily aggregate of brutto
  weights across a menu; sum operation over `ttk_line`.
- **Меню-раскладка** — per-day staff guide; thin layout layer
  on top of the calc card.
- **Электронный документооборот** — integration with Russian
  e-doc systems (СБИС, Контур.Диадок) for inspector workflows.
- **HACCP plan generation** — separate regulatory regime
  (GOST R 51705.1-2001), out of v2 scope.
