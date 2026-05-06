# Cliclick + Codebase Test Plan — User Card & Social Signals

Source requirements:
- `docs/user-card-and-social-signals.md`
- `docs/design_system.md`

Goal: exhaustively verify and fix all listed features using automated tests plus iPhone Simulator UI checks (cliclick), with credentials:
- user: `info@lagente.do`
- password: `111111`

---

## Chunk A — Baseline, environment, and regression harness

### Scope
- Ensure simulator automation path is stable before feature checks.
- Ensure existing test commands run and can be repeated.

### Steps
1. Boot iPhone Simulator and ensure app launches.
2. Run baseline Flutter tests to snapshot current failures.
3. Prepare repeatable UI runbook for login/open tabs/search/recipe details.

### Checks
- App opens without crashes.
- Login form is reachable.
- All major tabs are reachable.

### Tests
- `flutter test`
- Capture failing tests list as baseline.

---

## Chunk B — Recipe cards: stars visible and clickable everywhere

### Scope
- "stars on ALL recipe cards are present and clickable by user"

### UI checks (cliclick)
1. Login as `info@lagente.do` / `111111`.
2. Open recipes list and scroll through multiple pages.
3. Verify each visible recipe card renders rating aggregate/stars area.
4. Tap star area on multiple cards and open details to verify update consistency.

### Code checks
- Ensure card widget always renders rating block when data exists.
- Ensure tap targets are not obscured by overlays.

### Tests
- Widget tests for recipe card rating visibility across:
  - logged-in
  - logged-out
  - with/without rating data
- Integration test: tap rating from list/details and assert persisted state.

---

## Chunk C — Favorites pill: count + heart icon layout and behavior

### Scope
- "favorite button displays in pill shape the quantity of favorites added left to the heart icon"

### UI checks (cliclick)
1. Tap favorites on several recipes.
2. Confirm pill shape appears with number left, heart right.
3. Confirm count increments/decrements correctly.
4. Validate behavior at `0`, `1`, and `>1` counts.

### Design compliance
- Pill height/radius/color/contrast per `docs/design_system.md`.
- Text and icon readable on background (no low-contrast grey-on-grey).

### Tests
- Widget tests for all pill states.
- Golden tests for visual states.
- Integration test: toggle favorite and assert count transitions.

---

## Chunk D — Rating behavior: stars, average, and voter count

### Scope
- "clicking the stars and seeing rating changes and number of voters"

### UI checks (cliclick)
1. Open recipe details.
2. Rate 1..5 stars and verify immediate UI updates.
3. Re-rate with different value.
4. Tap same rating again to remove vote (if supported).
5. Verify voter count updates correctly.

### Code checks
- Optimistic update + rollback on API failure.
- Logged-out tap shows registration-required snackbar.

### Tests
- Store/unit tests for rating transitions.
- Widget tests for rating row interactions.
- Integration tests for end-to-end rating flow.

---

## Chunk E — Card completeness vs `user-card-and-social-signals.md`

### Scope
- "check if all elements described ... are on card"

### Required card-level elements
- Favorite control and count behavior
- Rating surface (avg/votes and/or stars per intended surface)
- User-added signal where applicable
- Any creator/social metadata required by spec

### Tests
- Snapshot/golden matrix for card variants:
  - TheMealDB recipe
  - user-created recipe
  - no favorites
  - with favorites
  - no ratings
  - with ratings

---

## Chunk F — Add recipe flow and new social/user elements on created recipe

### Scope
- "adding recipes, checking all new elements ... are present on the recipe"

### UI checks (cliclick)
1. Create a new recipe from Add flow.
2. Open created recipe card and details.
3. Verify "Added by" + creator metadata + social signals.
4. Verify recipe appears in relevant lists.

### Tests
- Integration test: create recipe -> verify creator/social fields rendered.
- Repository/API tests for creator projection fields.

---

## Chunk G — User avatar upload/storage/display

### Scope
- "adding avatar to user, displayed and stored correctly"
- "avatar displayed on created recipe cards"

### UI checks (cliclick)
1. Open user card/profile.
2. Upload avatar (camera/gallery path as available in simulator).
3. Save and relaunch app.
4. Verify avatar persists in user card.
5. Verify avatar appears in created recipe surfaces (card/details/added-by).

### Tests
- Widget tests for user card edit/save.
- API/repository tests for get/update profile and avatar path propagation.
- Integration test: upload avatar -> verify on profile + recipe creator UI.

---

## Chunk H — User profile completeness vs spec

### Scope
- "check ALL features to be on card and in user profile"

### Checklist
- Display name view/edit/save
- Language view/edit/save
- Recipes added counter
- Member since field
- Avatar change/remove behavior
- Post-signup setup behavior (if applicable)

### Tests
- User card widget tests for idle/edit/post-signup modes.
- Integration tests for save/skip/add flows.

---

## Chunk I — Visual quality + design-system compliance pass

### Scope
- "no grey fonts on grey background"
- "all text is contrast and human readable"
- "all elements compliant with docs/design_system.md"

### UI checks (cliclick/manual-assisted)
1. Review all touched screens in light theme on simulator.
2. Check text/background contrast for labels, meta text, disabled states, pills, chips.
3. Check typography sizes/weights and spacing against design tokens.

### Tests
- Golden tests for touched widgets/screens.
- Optional semantics/readability checks where practical.

---

## Chunk J — Full run, gap analysis, repeat-until-green loop

### Scope
- Execute full suite, fix, rerun, then re-read specs and verify nothing missing.

### Loop
1. Run all automated tests.
2. Fix failing tests/issues.
3. Re-run until fully green.
4. Re-read:
   - `docs/user-card-and-social-signals.md`
   - `docs/design_system.md`
5. Mark any missing coverage and add tests/fixes.
6. Re-run again until complete.

### Exit criteria
- All tests pass.
- No unresolved feature gaps vs spec files.
- UI checks pass on iPhone simulator.
- Readability/contrast issues fixed.

---

## Command checklist (execution order)
1. `flutter test`
2. Focused test files for modified areas.
3. Integration tests.
4. Simulator UI pass with cliclick scenarios above.
5. Re-read both docs and run final gap pass.
