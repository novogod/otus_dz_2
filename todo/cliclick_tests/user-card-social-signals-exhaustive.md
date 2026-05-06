# User Card & Social Signals — Exhaustive Cliclick + Automated Test Matrix

Date: 2026-05-06
Source requirements:
- `docs/user-card-and-social-signals.md`
- `docs/design_system.md`

## Test execution policy

- Run automated tests first (fast signal), then simulator/cliclick UAT.
- Every UI checkpoint must also verify design-system compliance:
  - color contrast and readability on current background,
  - token compliance for critical colors (`primary`, `primaryDark`, `textPrimary`, `textSecondary`, `danger`),
  - key dimensions/radius where specified,
  - text hierarchy and legibility.
- If a feature fails: fix code, rerun targeted tests, then full suite.
- Repeat until all checked items pass or are explicitly blocked by documented backend/infrastructure dependency.

---

## Chunk A — Shared photo picker helper

### Automated
- [ ] `photo_picker_sheet` bottom sheet shows camera/gallery labels.
- [ ] Remove option appears only when `removeLabel` is provided.
- [ ] `add_recipe_page` still opens picker sheet.

### Simulator / cliclick
- [ ] On Add Recipe, tap photo placeholder, sheet opens with proper labels.
- [ ] Cancel path returns cleanly.
- [ ] Camera path works (or gracefully denied with readable error).
- [ ] Gallery path works (or gracefully denied with readable error).

### Design checks
- [ ] Bottom sheet text is readable, contrast acceptable.
- [ ] Action ordering and spacing remain consistent.

---

## Chunk B — SQLite migration (v12 user profile + creator cache)

### Automated
- [ ] Migration test v11→v12 passes.
- [ ] Fresh install schema includes both tables.
- [ ] Existing DB tests unaffected.

### Runtime checks
- [ ] App launches without DB migration errors in console.
- [ ] No malformed/upgrade loop.

---

## Chunk C — Backend `/recipes/users/me` + avatar endpoints

### API checks
- [ ] `GET /recipes/users/me` unauthorized returns 401 without token.
- [ ] Authorized returns profile payload: id/email/displayName/language/avatarPath/recipesAdded/memberSince.
- [ ] `POST /recipes/users/avatar` returns success + avatar path/url (when infra enabled).
- [ ] `DELETE /recipes/users/avatar` clears avatar.

### Contract checks
- [ ] `recipesAdded` reflects user-created recipe counts.
- [ ] `memberSince` parseable and stable.

---

## Chunk D — User Card page + routing + post-signup flow

### Automated
- [ ] UserCard renders display-name field, language picker, primary actions.
- [ ] Edit/Save behavior toggles correctly.
- [ ] Post-signup mode shows Skip/Add flow and redirects to recipes.

### Simulator / cliclick
- [ ] Logged out → Profile tab lands on Login page.
- [ ] Logged in non-admin → Profile tab lands on UserCard.
- [ ] Logged in admin → admin page with access to user card.
- [ ] UserCard initial state read-only with expected primary action label.
- [ ] Tap Edit → fields editable, camera FAB appears.
- [ ] Save updates profile on server and survives reload.
- [ ] Language change persists across restart.
- [ ] Post-signup scenario: Skip routes to recipes, Add saves and routes to recipes.

### Design checks
- [ ] Avatar 120x120 circle, visible border/token compliance.
- [ ] Display name text uses readable primary text color.
- [ ] Inputs shape/spacing align with DS (radius/typography hierarchy).
- [ ] Logout uses danger color and is legible.

---

## Chunk E — Recipe model fields (creator + ratings + favorite count)

### Automated
- [ ] JSON parsing handles full payload and missing fields safely.
- [ ] No runtime null exceptions on list/details rendering.

### Runtime checks
- [ ] Page/list endpoints populate `creator*`, `ratings*`, `favoritesCount` where available.

---

## Chunk F — Added-by footer

### Automated
- [ ] Visibility gate: show only for user recipes (`id >= 1_000_000`) with creator name.
- [ ] Hidden for TheMealDB recipes.
- [ ] Hidden for user recipe with missing creator metadata.

### Simulator / cliclick
- [ ] Open user-created recipe details.
- [ ] Confirm Added-by row present (avatar/name/recipes count).
- [ ] Open TheMealDB recipe details.
- [ ] Confirm Added-by row absent.
- [ ] (Optional flag) Card creator chip only appears when enabled.

### Design checks
- [ ] Avatar sizing and row spacing are visually aligned.
- [ ] Name/secondary text hierarchy and contrast are readable.

---

## Chunk G — Star rating 1–5

### Automated
- [ ] Tapping star triggers `onRate(n)`.
- [ ] Read-only mode disables interaction.
- [ ] Optimistic update + rollback behavior (store-level) validated.

### Simulator / cliclick
- [ ] Logged out tap star → registration-required snackbar.
- [ ] Logged in tap 4-star → rating persists after refresh/reopen.
- [ ] Re-tap same star removes rating.
- [ ] Average/count update on details and summary on card.
- [ ] Error path shows readable feedback.

### Design checks
- [ ] Star color states match DS intent.
- [ ] Avg/count typography is readable and aligned.

---

## Chunk H — Favorite-count pill

### Automated
- [ ] Square fallback when logged out or count == 0.
- [ ] Pill appears for count > 0 with number + heart.
- [ ] Favorited state styling is correct.
- [ ] Logged-out tap shows registration-required snackbar.

### Simulator / cliclick
- [ ] Toggle favorite on recipe details and/or card.
- [ ] Count increments/decrements correctly.
- [ ] State persists after reload.
- [ ] Count displayed consistently between list and details.

### Design checks
- [ ] Pill dimensions/radius/shadow/opacity are compliant and legible.
- [ ] Number contrast on pill background is readable.

---

## Chunk I — i18n across 10 locales

### Automated
- [ ] i18n completeness test passes.
- [ ] New keys resolve non-empty in all locales.
- [ ] Plural forms (`recipeVotesCount`, `recipeAuthorRecipes`, profile counters) pass checks.

### Simulator / cliclick
- [ ] Switch locale to EN/RU/DE/ES/FR/IT/TR/AR/FA/KU.
- [ ] Verify UserCard labels/rating labels/added-by labels/favorite tooltips.
- [ ] Verify RTL behavior and readability for AR/FA/KU.

---

## Chunk J — Integration + UAT closure

### Automated
- [ ] `post_signup_flow_test.dart` green.
- [ ] `rate_and_favorite_flow_test.dart` green.
- [ ] `added_by_visibility_test.dart` green.
- [ ] Full `flutter test` suite green.

### Simulator / cliclick full run
- [ ] Login end-to-end with production test user.
- [ ] Navigate all relevant tabs and flows without dead navigation.
- [ ] Create recipe and verify social signals render on created recipe.
- [ ] Upload avatar and verify it appears on UserCard and Added-by surfaces.
- [ ] Delete avatar and verify fallback placeholder everywhere.
- [ ] Accessibility/readability pass for key text blocks against backgrounds.

---

## Regression & compliance sweep (must pass before close)

- [ ] Read `docs/user-card-and-social-signals.md` and `docs/design_system.md` again.
- [ ] Compare implemented code + actual UAT/test results against every required feature.
- [ ] Add missed test cases to this checklist.
- [ ] Re-run tests after additions/fixes.
- [ ] Only close when all feasible items are checked and blockers are documented.
