# Search Predictions — API-driven prefix filter

Status: **partially implemented** (online API path live; MongoDB
buffer + translation are described in
[i18n_proposal.md](i18n_proposal.md) and tracked in
[todo/search_api_deploy.md](todo/search_api_deploy.md)).

## What changed

Earlier the search field filtered the in-memory list of recipes that
the page had received from `RecipeListLoader`. That meant the user
could only "find" recipes that happened to be in the initial batch —
typing `c` would never reveal `Chicken Handi` if the loader fetched
only `searchByName('a')`.

The new behaviour:

1. The dropdown asks **TheMealDB** (`searchByName`) for matches as
   the user types — debounced 300 ms.
2. Results are kept only if the recipe's name **starts with** the
   typed prefix (case-insensitive). TheMealDB returns substring
   matches; we tighten that to `startsWith` so suggestions match
   what the user is typing.
3. The dropdown is scrollable (`Scrollbar` + `ListView.separated`,
   `maxHeight: 320`). Long answer sets aren't truncated.
4. Selecting a prediction (or pressing the keyboard "Search" action)
   **replaces the main list** with the same downloaded set, fills
   the field with the chosen recipe's name, and unfocuses. So the
   prediction is a one-tap filter, not just a deep-link.
5. Clearing the field (✕ button or backspace to empty) restores the
   original list passed in by `RecipeListLoader`.

## State machine

```
            +-- text empty ----+
            v                  |
   ┌────────────────┐  type   ┌────────────────┐
   │ Idle           │────────>│ Debouncing     │
   │ list = base    │   300ms │ predictions=∅  │
   └────────────────┘<────────│ loading=false  │
            ^   clear         └────────────────┘
            │                          │ debounce fired
            │                          v
            │                 ┌────────────────┐
            │                 │ Querying API   │
            │                 │ loading=true   │
            │                 └────────────────┘
            │                          │ resp / err
            │                          v
            │                 ┌────────────────┐
            │     submit      │ Predictions    │
            │ ────────────────│ shown          │
            │                 │ loading=false  │
            │                 └────────────────┘
            │                          │ submit / pick
            │                          v
            │                 ┌────────────────┐
            └─────────────────│ Filtered list  │
                              │ list = hits    │
                              └────────────────┘
```

## Race-condition handling

Each fired query stamps `_lastQueryInFlight = prefix`. When the
response arrives, if `_lastQueryInFlight` no longer equals that
prefix, the response is dropped — the user has typed past it. This
is cheaper than cancelling Dio requests and gives the same UX.

## Test fallback

The page accepts `api == null` (used by the unit tests). In that
mode `_runPredictionQuery` does a local `startsWith` filter against
`widget.recipes` instead of calling the API. The existing test
"search field filters list on submit" exercises this path.

## How this relates to the MongoDB buffer

The current code talks to TheMealDB directly. The end goal —
spelled out in [i18n_proposal.md](i18n_proposal.md) — is to talk to
the `mahallem_ist` Node API instead, which:

* serves recipes from MongoDB (fast, bilingual);
* on a search miss, fetches from TheMealDB, runs the Gemini
  translation pipeline, persists, and returns the bilingual rows;
* enforces the 2 000-row server-side cap with LRU/popularity
  eviction.

The Flutter page won't change: it still calls
`RecipeApi.searchByName(query: prefix)`. Only the URL inside
`MealDbClient` (or its successor) flips from `themealdb.com/api/...`
to `https://api.<our-domain>/recipes/search?...`. That is why the
client-side state machine is provider-agnostic.

The phone-side capped local store (200 rows, Drift) caches the
results of these searches so a re-typed prefix doesn't re-hit the
network. See the deploy plan in
[todo/search_api_deploy.md](todo/search_api_deploy.md).

## Files

* [recipe_list/lib/ui/recipe_list_page.dart](../recipe_list/lib/ui/recipe_list_page.dart) — state.
* [recipe_list/lib/ui/search_app_bar.dart](../recipe_list/lib/ui/search_app_bar.dart) — `SearchAppBar` + `SearchPredictions`.
* [recipe_list/test/recipe_list_page_test.dart](../recipe_list/test/recipe_list_page_test.dart) — local-fallback test.
