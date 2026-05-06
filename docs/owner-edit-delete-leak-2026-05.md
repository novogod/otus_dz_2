# Owner edit/delete leak + missing author chip on search cards

**Date:** 2026-05-06

**Commits:**
- mahallem `68ae49e8` — `recipes: project social signals on /recipes/search`
- otus_dz `9ea367d` — `recipes: server-authoritative ownership for edit/delete buttons`

## Symptoms (reported by anonymous, not-logged-in user)

1. **No author chip on the recipe-list card.** Opening "Unloading bag"
   from the list (a search result or feed) showed no creator name /
   avatar on the card. The chip *did* appear on the details page after
   tapping the card. Across web and devices.
2. **Edit/Delete visible on cards belonging to other users.** The
   anonymous viewer (and any signed-in non-author) saw the
   edit/delete circular badges on the card and on the details-page
   hero photo for recipes they did not author. The server still
   rejects the writes with 403/404, but the buttons must not be
   visible at all.

## Root causes

### Issue 1 — chip missing on list cards

`GET /recipes/search` was the only list-style endpoint that did **not**
call `attachSocialSignals(executeQuery, meals, optUid)`. The other
endpoints — `/recipes/page`, `/recipes/lookup/:id`, `/recipes/random`,
`/recipes/filter` — all project `creatorUserId`,
`creatorDisplayName`, `creatorAvatarPath`, `creatorRecipesAdded`,
`favoritesCount` onto every meal in the response.

`/search` returned the raw `repo.searchByName(q, lang)` rows, so the
client received `creatorDisplayName == null`. The author-chip widget
in `recipe_card.dart` short-circuits on
`if (name == null || name.isEmpty) return SizedBox.shrink()`, which
explained why the chip was missing on the search-result card but
present on the details page (which calls `/lookup/:id`, projected).

### Issue 2 — edit/delete visible to non-authors

Two layered bugs combined:

1. **`OwnedRecipesStore.ensureLoaded()` poisoned itself on every
   device.** The store is a per-device sqflite registry of recipe
   ids "this device created". Its first-load backfill, however, did:

   ```dart
   final candidateRows = await _db.query(
     'recipes',
     columns: const ['id'],
     where: 'id >= ?',
     whereArgs: [userMealIdFloor], // 1_000_000
   );
   // → insert ALL of them into owned_recipes
   ```

   `recipes` is the local cache populated by every list/details fetch.
   So as soon as ANY user (including anon visitors) opened a card, the
   row entered the cache, the next `ensureLoaded` flagged it as
   "owned by this device", and any gate that OR-ed in
   `ownedRecipesStoreNotifier.value?.isOwned(recipe.id)` lit up the
   buttons.

   Every gate did exactly that:
   - `recipe_card._CardActions` — the badge in `Positioned(top, left)`.
   - `recipe_list_page._openEditRecipe` — tap-handler on edit badge.
   - `recipe_list_page._confirmAndDeleteFromCard` — tap-handler on
     delete badge.

2. **`_OwnerActions` in `recipe_details_page.dart` had a permissive
   `userLoggedIn && !isAdmin && id >= userMealIdFloor` fallback.**
   Any logged-in non-admin user saw the buttons on every user-floor
   recipe regardless of author.

These pre-dated the chunk-H server projection of `creatorUserId`. With
the projection in place the server-authoritative author check
(`recipe.creatorUserId == myProfileNotifier.value?.id`) is the correct
gate, and the per-device fallbacks are only harm.

## Fix

### Server (mahallem `68ae49e8`)

`local_user_portal/routes/recipes.js` — `GET /recipes/search`:

```diff
   const meals = await repo.searchByName(q, lang);
+  const optUid = verifyRecipesUserToken(req.get('x-recipes-user-token'))?.uid || null;
+  await attachSocialSignals(executeQuery, meals, optUid);
   res.json({ meals: meals.length ? meals : null });
```

Mirrors the `optUid` + `attachSocialSignals` call already present in
`/filter`. Verified post-deploy:

```
$ curl -sS 'https://mahallem.ist/recipes/search?q=unload&lang=en' | jq '.meals[0] | {idMeal, creatorDisplayName, creatorUserId}'
{
  "idMeal": "1000012",
  "creatorDisplayName": "Andrey",
  "creatorUserId": "bf703e42-1641-42b4-88a4-d46ea17c756c"
}
```

### Client (otus_dz `9ea367d`)

All four ownership gates collapsed to
`isAdmin || isCurrentUserAuthor(recipe)`:

- `recipe_list/lib/ui/recipe_card.dart`
  - `_CardActions` wrapper: drop the
    `ValueListenableBuilder<OwnedRecipesStore?>` /
    `ValueListenableBuilder<Set<int>>` chain; only listen to
    `adminLoggedInNotifier` + `myProfileNotifier`.
  - Author-chip fallback: `isMine = isCurrentUserAuthor(recipe)` only;
    drop the `ownedRecipesStoreNotifier.value?.isOwned(recipe.id)`
    branch.
- `recipe_list/lib/ui/recipe_list_page.dart`
  - `_openEditRecipe` and `_confirmAndDeleteFromCard`: `canManage =
    adminLoggedInNotifier.value || isCurrentUserAuthor(recipe)`.
- `recipe_list/lib/ui/recipe_details_page.dart`
  - `_OwnerActions.build`: collapse the nested
    `OwnedRecipesStore?` / `Set<int>` / `userLoggedInNotifier`
    builders to a single `adminLoggedInNotifier` +
    `myProfileNotifier` pair, gated by
    `isAdmin || isCurrentUserAuthor(recipe)`.

### Cleansing the per-device poison

`recipe_list/lib/data/repository/owned_recipes_store.dart` —
`ensureLoaded` no longer infers ownership from the `recipes` cache.
On first load it also purges any rows at or above
`userMealIdFloor` so historical poisoning from earlier app
versions is cleared on the next launch:

```dart
Future<Set<int>> ensureLoaded() async {
  if (!_loaded) {
    await _db.delete(
      'owned_recipes',
      where: 'id >= ?',
      whereArgs: [userMealIdFloor],
    );
  }
  final ownedRows = await _db.query('owned_recipes', columns: const ['id']);
  ids.value = {for (final r in ownedRows) r['id']! as int};
  _loaded = true;
  return ids.value;
}
```

The store is retained as an offline-create-replay aid populated only
through `add()` from the create flow. Ownership for UI is now
strictly server-authoritative.

## Verification

- Anonymous viewer on web (hard-refresh PWA): "Unloading bag" card on
  the recipe-list shows the "Andrey" author chip; no edit/delete
  badge in the card top-left or the details hero photo.
- Logged in as a different non-author account: same as anonymous.
- Logged in as `info@lagente.do` (the actual author): edit/delete
  visible on both the card and the details page on every device, on
  fresh installs and on devices that never created the recipe.
- Server `GET /recipes/search?q=unload&lang=en` returns the
  `creatorDisplayName` field.

## Lessons

- Per-device caches must never be treated as an authorisation
  signal. sqflite is shared across whoever uses the device; any "did
  this device do X" inference leaks across accounts.
- When the server gains a projection for an attribute (here
  `creatorUserId`), every UI gate that previously worked around its
  absence must be revisited and collapsed to the server-authoritative
  check; lingering OR-ed local fallbacks become security holes.
- A new endpoint added to the list family must call
  `attachSocialSignals` or its absence will silently break
  cross-cutting UI (chips, favorites pill) on that surface only.
