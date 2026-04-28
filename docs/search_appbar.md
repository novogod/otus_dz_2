# Search AppBar (recipe_list)

Status: **implemented**. See `lib/ui/search_app_bar.dart`,
`lib/ui/lang_icon_button.dart`, and `lib/ui/recipe_list_page.dart`.

## Goal

Replace the floating language toggle with a proper top app bar that
hosts:

* a back-navigation control on the left,
* a single-line search field with a live predictions dropdown in the
  centre,
* the language toggle (`RU` ↔ `EN`) on the right.

The previous overlay `LangFab` was visible during the splash screen and
covered content in the top-left corner. The new control lives **inside
the AppBar of `RecipeListPage`**, so it is shown only after the splash
slide-in transition completes (`AppDurations.splash` + `splashTransition`).

## Composition

```
┌───────────────────────────────────────────────────────────┐
│ [‹ back ]  ┌──────────  search field  ──────────┐  [RU/EN]│  ← AppBar
│            │ 🔍  Поиск рецепта             ✕   │         │
│            └─────────────────────────────────────┘         │
├───────────────────────────────────────────────────────────┤
│ ┌──── predictions dropdown (when focused & query ≠ ∅) ───┐│
│ │ 🔍 Spicy Arrabiata Penne                              ││  ← Material elev.4,
│ │ 🔍 Apple Frangipan Tart                                ││    above ListView
│ └────────────────────────────────────────────────────────┘│
│                                                           │
│  [ recipe card ]                                          │
│  [ recipe card ]                                          │
│  …                                                        │
└───────────────────────────────────────────────────────────┘
```

### `SearchAppBar` — `PreferredSizeWidget`

Members:

| Slot | Widget | Behaviour |
| --- | --- | --- |
| `leading` | `IconButton(Icons.arrow_back)` | `onBack ?? Navigator.maybePop` — on the root list it is a visual no-op (Flutter's Navigator returns false when no route to pop), used as a back affordance once the list is pushed under another route. |
| `title` | rounded `TextField` (`#ECECEC` background, 8 dp radius, 40 dp tall) | `prefixIcon` 🔍, `suffixIcon` ✕ that clears the controller. Reports each keystroke via `onChanged` and final intent via `onSubmitted`. |
| `actions` | `LangIconButton` | 40×40 circle, `AppColors.primary` (`#2ECC71`) background, white Roboto-800 / 14 sp `RU` / `EN` label, taps `cycleAppLang()`. |

### `SearchPredictions`

A `Material(elevation: 4)` panel anchored to the top of the page body
(under the AppBar), `maxHeight: 240`. Renders up to 5 `ListTile`s; each
selection unfocuses the search field and pushes the recipe details page.

When the query has no matches it shows `S.searchNoMatches`.

## State management

`RecipeListPage` is now a `StatefulWidget` and owns the search state.

| Field | Purpose |
| --- | --- |
| `_controller` | Backing `TextEditingController`. |
| `_focusNode` | Drives dropdown visibility — predictions appear only while the field has focus. |
| `_debounceTimer` | 250 ms debounce for `_liveQuery` updates. |
| `_liveQuery` | Drives the **predictions** content. |
| `_appliedQuery` | Drives the **list** content. Set on `onSubmitted` (Enter / IME search action) or when a prediction is tapped. |

Filtering is purely local — `recipes.where((r) => r.name.toLowerCase().contains(q))`.
This keeps the UX responsive and avoids hammering TheMealDB on every
keystroke. Remote search (calling `RecipeApi.searchByName` directly from
the field) is a follow-up; see [Open extensions](#open-extensions).

## Splash-vs-AppBar interaction

The splash screen (`SplashPage`) does **not** have an `AppBar`. The list
loader screens (`CircularProgressIndicator` / error / `RecipeListPage`)
each render a `Scaffold` whose AppBar is either absent (loader/error
states) or the `SearchAppBar` (list state). Because the splash sits in
the same root `Stack` and is covered by the sliding list, the language
toggle becomes visible exactly when the list AppBar enters the viewport.

This satisfies the requirement: **no language control visible during
the splash playback**.

## Details page

`RecipeDetailsPage` keeps its existing `AppBar` (centred title
«Рецепт» / "Recipe", primary-dark colour). It now also renders
`LangIconButton` in `actions`, so the language toggle is reachable from
both screens.

The back arrow on the details page comes for free from Flutter's
`AppBar.automaticallyImplyLeading`.

## Strings

Added to `S` in `lib/i18n.dart`:

* `searchHint` — "Поиск рецепта" / "Search recipe"
* `searchClear` — tooltip for the ✕ button
* `searchNoMatches` — fallback line in the predictions panel

## Tests

`test/recipe_list_page_test.dart`:

* Existing tests keep working — `RecipeListPage` is still a widget that
  renders one `RecipeCard` per recipe and an empty state.
* The "no global header" test was updated: an `AppBar` is now present,
  but it must not contain the literal text "Рецепты" (that label still
  belongs to the bottom navbar, per `design_system.md` §6).
* New test `search field filters list on submit`: types into the search
  `TextField`, dispatches the IME search action, and asserts only the
  matching `RecipeCard` is visible.

## Open extensions

* **Remote predictions.** Wire `_onChanged` debounce to
  `RecipeApi.searchByName(query)` instead of the local filter. Cache by
  query string. Useful once the dataset is bigger than the initial page.
* **Search history.** Persist the last N submitted queries in
  `shared_preferences` and surface them as predictions when the field
  gets focus with empty input.
* **Voice / barcode entry.** Replace the `prefixIcon` with an
  `IconButton` that opens a sheet — the AppBar layout already has the
  room.
* **Material 3 `SearchBar` / `SearchAnchor`.** Once we move to Material
  3 search components, `SearchAppBar` becomes a thin shim around
  `SearchAnchor.bar`. The current implementation deliberately stays on
  the lower-level primitives for one-language control over the visual
  spec.
