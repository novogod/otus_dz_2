# User Card, Avatars, "Added by", Star Ratings, Favorite-Count Pill

**Status:** 🟡 Design proposal, not yet implemented.
**Scope:** Food app (`recipe_list/`) + mahallem-user-portal backend.
**Last updated:** 2026-05-05

This doc proposes four interlocking changes:

1. **User Card** — a dedicated profile screen accessible by tapping
   "Profile" after login, with avatar (camera / library), display
   name, language, and an optional "Add" flow shown to users right
   after registration.
2. **"Added by" footer** on recipe details for user-uploaded recipes
   (id ≥ `1_000_000`), with the author's avatar, name, and total
   number of recipes they've added.
3. **Star rating 1-5** on each recipe, with a count of clickers.
   Logged-out tap → existing `showRegistrationRequiredSnackBar`.
4. **Favorite count** moved from a round badge to a **pill** on the
   recipe card: number on the left, heart icon on the right.

Everything must comply with [docs/design_system.md](./design_system.md)
and be translated across all 10 supported languages
(en, ru, de, es, fr, it, tr, ar, fa, ku).

The exact file paths and design tokens used below were extracted
from the current codebase — see "Reference inventory" at the end.

---

## 1. User Card (Profile screen)

### 1.1 Goal

The current "profile" surface is
[recipe_list/lib/ui/admin_after_login_page.dart](../recipe_list/lib/ui/admin_after_login_page.dart) —
admin-shaped, no avatar, no display name. We need a real **User Card**
shown when a regular logged-in user taps the Profile tab; admins
keep their extra buttons on the same screen above the card.

### 1.2 Wireframe

```
┌──────────────────────────────────────┐
│  ← Profile                           │  AppBar (§9a, primaryDark title)
├──────────────────────────────────────┤
│                                      │
│              ┌──────────┐            │
│              │  AVATAR  │            │  120×120 circle
│              │          │            │  border 1px primary (#2ECC71)
│              │  [+]     │            │  bottom-right small camera FAB
│              └──────────┘            │  (only when editing)
│                                      │
│            John Doe                  │  Roboto w500 24/22 textPrimary
│         john@example.com             │  Roboto w400 14 textSecondary
│                                      │
│  ┌────────────────────────────────┐  │
│  │ Display name                   │  │  Outlined input, radius 10
│  │ [ John Doe                   ] │  │  (read-only when not editing)
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ Language                       │  │  DropdownFormField
│  │ [ English ▾                  ] │  │
│  └────────────────────────────────┘  │
│                                      │
│  Recipes added: 12                   │  Roboto w400 14 textSecondary
│  Member since:  May 2026             │
│                                      │
│  ┌──────────────┐ ┌────────────────┐ │
│  │  Edit        │ │  Save          │ │  primary outline / filled
│  └──────────────┘ └────────────────┘ │
│                                      │
│  ┌────────────────────────────────┐  │
│  │           Logout               │  │  danger #F54848
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

Idle state shows the read-only view with **Edit**; tap **Edit** →
inputs become editable, "Save" appears, the camera FAB on the avatar
appears.

### 1.3 Routing

- New route `Routes.profile` in
  [recipe_list/lib/router/routes.dart](../recipe_list/lib/router/routes.dart);
  shell branch like `recipes`.
- The existing tab-bar already has a Profile tab (`tabProfile`); it
  currently lands on the admin page only when `adminLoggedInNotifier`
  is true. We add a regular-user branch:
  - logged out → existing login page
  - logged in, non-admin → new `UserCardPage`
  - logged in, admin → `AdminAfterLoginPage` with a "User card"
    button at the top that opens `UserCardPage` (admins should be
    able to edit their own card too).

### 1.4 Optional "Add" right after registration

After successful sign-up in
[recipe_list/lib/ui/signup_page.dart](../recipe_list/lib/ui/signup_page.dart)
we currently `context.go(Routes.recipes)`. New flow:

```
signup OK
  └─ push UserCardPage(initialEditMode: true, isPostSignup: true)
       buttons row: [Skip] [Add]
       Skip → context.go(Routes.recipes)
       Add  → save card → context.go(Routes.recipes)
```

`isPostSignup` controls only the buttons (Skip vs Edit/Save) and
the appbar title (`profileFinishSetup` vs `tabProfile`). Same widget,
same fields, same avatar picker.

### 1.5 New i18n keys

Manual `_byLang` in
[recipe_list/lib/i18n.dart](../recipe_list/lib/i18n.dart) (so we
don't regenerate slang for 10 locales right now):

| key                       | en                          | ru                                    |
|---------------------------|-----------------------------|---------------------------------------|
| `profileDisplayName`      | Display name                | Отображаемое имя                       |
| `profileLanguage`         | Language                    | Язык                                  |
| `profileRecipesAdded`     | Recipes added: {n}          | Добавлено рецептов: {n}                |
| `profileMemberSince`      | Member since: {date}        | С нами с: {date}                      |
| `profileEdit`             | Edit                        | Редактировать                         |
| `profileSave`             | Save                        | Сохранить                             |
| `profilePhotoFromCamera`  | Take photo                  | Сделать фото                          |
| `profilePhotoFromGallery` | Choose from library         | Выбрать из галереи                    |
| `profilePhotoRemove`      | Remove photo                | Удалить фото                          |
| `profileFinishSetup`      | Finish setup                | Завершите настройку                   |
| `profileAdd`              | Add                         | Добавить                              |
| `profileSkip`             | Skip                        | Пропустить                            |
| `profileSavedToast`       | Profile saved               | Профиль сохранён                       |

Translations to es/fr/de/it/tr/ar/fa/ku follow the same `_byLang`
pattern; produced by the existing slang i18n cron / Gemini cascade
when we promote them to JSON.

---

## 2. Avatars (camera + library, separate bucket, imgproxy)

### 2.1 Picker — same code path as recipe photo

Reuse the bottom-sheet from
[recipe_list/lib/ui/add_recipe_page.dart](../recipe_list/lib/ui/add_recipe_page.dart)
(camera / gallery `ImagePicker`) and the compression util
[recipe_list/lib/utils/photo_downscaler.dart](../recipe_list/lib/utils/photo_downscaler.dart).
Extract `_pickPhoto` and the bottom-sheet builder into a small
shared helper:

```
recipe_list/lib/ui/photo_picker_sheet.dart
  Future<Uint8List?> pickAndCompressPhoto(BuildContext, {
    required String cameraLabel,   // s.profilePhotoFromCamera / s.addRecipePhotoFromCamera
    required String galleryLabel,
    String? removeLabel,           // shown only when caller has a current photo
  })
```

Both `AddRecipePage` and `UserCardPage` call the same helper. Net
zero new dependencies — `image_picker` and `flutter_image_compress`
are already in `pubspec.yaml`.

### 2.2 Bucket separation: `food-avatars` (NOT `mahallem-avatars`)

Mahallem (the parent portal at
`/Volumes/Working_MacOS_Extended/mahallem/mahallem_ist/`) has its
own user-avatars bucket. Per the user's requirement, **food app
avatars must not mix** with mahallem avatars. Plan:

- **New S3-compatible bucket** on the same Hetzner Object Storage
  account that serves `recipe-photos`:
  - bucket name: `food-avatars`
  - same access policy as `recipe-photos` (public-read, signed PUT
    for backend only; client never sees S3 credentials).
- **New backend endpoint** in `mahallem-user-portal`:
  - `POST /recipes/users/avatar` — multipart `{ photo: file }`,
    auth via `x-recipes-user-token`. Server side:
    1. Validates token, resolves `user_id`.
    2. Streams to `food-avatars/${user_id}/${ts}.jpg`.
    3. Updates `recipes_users.avatar_path = ...`.
    4. Returns `{ avatarUrl: "<imgproxy>" }`.
  - `DELETE /recipes/users/avatar` — clears row, deletes object
    (best-effort).
  - `GET /recipes/users/me` — returns
    `{ id, email, displayName, language, avatarPath, addedRecipes,
    memberSince }` (used to render the User Card).
- **DB column**: `recipes_users.avatar_path TEXT NULL` (S3 path,
  not full URL — we render via imgproxy on read).

Local SQLite on device gets a mirror in
[recipe_list/lib/data/local/recipe_db.dart](../recipe_list/lib/data/local/recipe_db.dart):

- New table `user_profile (user_id TEXT PK, display_name, language,
  avatar_path TEXT, member_since INTEGER, recipes_added INTEGER,
  cached_at INTEGER)` — stored per logged-in user, single row.
- New table `recipe_creator_cache (creator_user_id TEXT PK,
  display_name, avatar_path, recipes_added, cached_at)` — used by
  the "Added by" footer (§3) so the card renders without an extra
  network hop per scroll. TTL 24 h; refreshed lazily.

**Schema migration**: bump `recipe_db.dart` to v12, add both tables
in `_onCreate` and a guarded `CREATE TABLE IF NOT EXISTS` in
`_onUpgrade(11 → 12)`.

### 2.3 Imgproxy — same as recipe photos

The avatar URL is rendered through the existing
[recipe_list/lib/utils/imgproxy.dart](../recipe_list/lib/utils/imgproxy.dart)
helper:

```dart
imgproxyUrl(avatarS3Url, 240, 240)   // user card hero
imgproxyUrl(avatarS3Url,  64,  64)   // recipe details "added by" + admin lists
imgproxyUrl(avatarS3Url,  32,  32)   // recipe card hint (if ever needed)
```

Server saves only the raw S3 URL; the food app composes the
imgproxy URL on read at the right size for the surface. This
matches the pattern used for `Recipe.photo`.

### 2.4 Compliance with design_system.md

- Avatar 120×120, full circle (`borderRadius: 60`), 1 px stroke
  `AppColors.primary` (§1).
- Camera FAB on avatar bottom-right: 32×32 circle, bg
  `AppColors.primaryDark`, white icon `Icons.photo_camera`,
  `AppShadows.card`.
- Inputs: radius 10 (§3), label Roboto w500 14 `textSecondary`,
  value Roboto w400 16 `textPrimary`.
- Edit/Save row: §9g primary filled (filled `primaryDark`,
  radius 25, h 48); Edit can be `OutlinedButton` with same h/radius.
- Logout button keeps the existing danger style (`#F54848`).

### 2.5 OWASP / security notes

- Backend rejects `Content-Type` that isn't `image/jpeg` /
  `image/png` / `image/webp`; and re-encodes via the same imgproxy
  pipeline before persisting (mitigates SSRF / polyglot uploads,
  OWASP A03/A05).
- Multipart size capped at 5 MB (already enforced by the recipe
  photo path).
- `avatar_path` is never accepted from the client — server writes
  it after a successful S3 PUT.

---

## 3. "Added by" footer on recipes

### 3.1 Trigger

Show the footer **only when the recipe was added by an end user**,
i.e. when `recipe.id ≥ 1_000_000` (current convention — see
[recipe_list/lib/models/recipe.dart](../recipe_list/lib/models/recipe.dart)).
TheMealDB recipes (id < 1_000_000) get nothing. Where to render:

- Recipe **details** page: under the ingredients list, above the
  instructions block.
- Recipe **card** in the list: optional small chip below the title
  ("by John Doe • 12"). Only when the layout has room (lite=false
  variant). Disabled by default behind a `showCreatorChip` flag,
  to keep the card tight; can be enabled later without backend
  changes.

### 3.2 Wireframe — recipe details

```
…  ingredients list (existing) …
─────────────────────────────────────────
┌─────┐
│ AV  │   John Doe                          ← Roboto w500 16 textPrimary
│ 64  │   12 recipes                         ← Roboto w400 13 textSecondary
└─────┘
─────────────────────────────────────────
…  instructions (existing) …
```

- Avatar 64×64 circle (imgproxy 64×64).
- Whole row is tappable when admin (opens user card on the admin
  panel — wire-compatible with the §1 user card; for end users the
  row is non-tappable until we add a public "creator profile"
  endpoint, which is out of scope here).

### 3.3 Backend

Recipe model gains:

```
creatorUserId: String?
creatorDisplayName: String?
creatorAvatarPath: String?
creatorRecipesAdded: int?
```

Server already knows `created_by` per recipe (admin "added
recipes" list relies on it — see
[recipe_list/lib/ui/admin_added_recipes_page.dart](../recipe_list/lib/ui/admin_added_recipes_page.dart)).
Extend `GET /recipes/lookup/:id` and `GET /recipes/page` to project
the four creator fields by joining `recipes_users` once and counting
recipes via a denormalized `recipes_added` column updated on
recipe insert/delete (avoids a per-row count). No N+1 on bulk fetch.

Client caches in `recipe_creator_cache` (§2.2) with 24 h TTL.

### 3.4 i18n

| key                     | en                | ru                  |
|-------------------------|-------------------|---------------------|
| `recipeAddedByPrefix`   | by                | автор               |
| `recipeAuthorRecipes`   | {n} recipes       | рецептов: {n}        |

Pluralisation handled with the existing slang plural pattern (see
how the app already pluralises `searchNoMatches`).

---

## 4. Star rating 1–5

### 4.1 Goal

Below "Added by" on the details page (and as a small overlay on
the recipe card), show a 5-star row + a count of clickers. Logged-in
users tap a star to rate; logged-out users get the same
`showRegistrationRequiredSnackBar` we already use for favorites
([recipe_list/lib/ui/registration_required_snackbar.dart](../recipe_list/lib/ui/registration_required_snackbar.dart)).

### 4.2 Wireframe

```
─────────────────────────────────────────
☆ ☆ ☆ ☆ ☆       4.3       127 votes        ← idle (logged out / not voted)
★ ★ ★ ★ ☆       4.3       127 votes        ← logged in, voted 4
─────────────────────────────────────────
```

- Star 24 dp, outline `AppColors.textSecondary`, filled
  `AppColors.primary` (§1). Spacing 4 dp.
- Average shown in Roboto w500 16 `textPrimary`, count in Roboto
  w400 13 `textSecondary` with `recipeVotesCount(n)` plural.
- On the recipe card we render only the average + count, no
  interactive stars (tap on details page only).

### 4.3 Behaviour

- **Tap a star while logged out** → `showRegistrationRequiredSnackBar`.
  No optimistic UI change.
- **Tap a star while logged in** → optimistic update, then `POST`
  the rating; on failure revert + show snackbar.
- **Re-tapping the same star** removes the rating
  (`DELETE /recipes/:id/rating`).
- One rating per `(user_id, recipe_id)` — server upserts.

### 4.4 Backend

New table:

```
recipe_ratings (
  recipe_id    INTEGER NOT NULL,
  user_id      TEXT    NOT NULL,
  stars        INTEGER NOT NULL CHECK (stars BETWEEN 1 AND 5),
  rated_at     INTEGER NOT NULL,
  PRIMARY KEY (recipe_id, user_id)
)
```

Plus denormalized aggregates on `recipes`:

```
ratings_count    INTEGER NOT NULL DEFAULT 0
ratings_sum      INTEGER NOT NULL DEFAULT 0
```

Updated by trigger on insert/update/delete (or by the same
`/rating` handler in a single SQL transaction).

Endpoints:

- `GET /recipes/:id/rating` → `{ avg, count, my? }` (`my` only
  when authenticated).
- `POST /recipes/:id/rating` body `{ stars }` (1–5) — upserts.
- `DELETE /recipes/:id/rating` — removes the user's rating.
- Denormalized fields included in `GET /recipes/lookup/:id` and
  `GET /recipes/page` so the recipe card can render aggregate
  without a second round trip.

### 4.5 Client

- New widget
  `recipe_list/lib/ui/social/recipe_rating_row.dart` — stateless,
  takes `(avg, count, my, onRate)` and renders the row.
- Wired into details page below "Added by".
- Recipe model gains `ratingsCount`, `ratingsAvg`, `myRating`.
- Optimistic update via a small `RatingStore` (similar to
  `favorites_store.dart`).

### 4.6 i18n

| key                  | en                | ru                     |
|----------------------|-------------------|------------------------|
| `recipeRateTooltip`  | Rate this recipe  | Оценить рецепт          |
| `recipeRatingAvg`    | {avg}             | {avg}                  |
| `recipeVotesCount`   | {n} votes         | {n} голос(а)            |
| `recipeRatedToast`   | Rating saved      | Оценка сохранена        |

`recipeVotesCount` uses CLDR plural categories (one/few/many/other)
already supported by slang.

---

## 5. Favorite-count pill on the recipe card

### 5.1 Goal

Replace the round favorite badge in
[recipe_list/lib/ui/recipe_card.dart](../recipe_list/lib/ui/recipe_card.dart)
with a **pill**: number on the left, heart icon on the right.

### 5.2 Wireframe

```
   not favorited:                           favorited:
   ┌───────────────┐                        ┌───────────────┐
   │  127  ♡       │   ← outline heart      │  128  ♥       │   ← filled heart
   └───────────────┘                        └───────────────┘

   logged-out user (n hidden, only ♡):
   ┌────┐
   │ ♡  │
   └────┘
```

- Pill: height 32, horizontal padding 12, radius 16 (full pill),
  background `AppColors.surface` @ 0.92 opacity, border 1 px
  `AppColors.textInactive`, shadow `AppShadows.card`.
- Number: Roboto w500 14 `textPrimary` (or `primary` when
  favorited), right margin 6.
- Heart: 18 dp, outline `textSecondary`, filled `primary`.
- When the recipe has 0 favorites (or the user is logged out), the
  pill collapses to a square 32×32 with just the heart, preserving
  the existing affordance for logged-out users.

### 5.3 Backend

Already implicit: server can count favorites by `recipe_id` from
the `favorites` table. Add `favorites_count` to the `Recipe` JSON
in `GET /recipes/lookup/:id` and `GET /recipes/page` (denormalized
column on `recipes` updated on favorite/unfavorite, exactly like
`ratings_count` in §4.4).

### 5.4 Client

- `RecipeFavoriteButton` (current widget) gains an
  `int favoritesCount` and an `bool showCount` flag.
- When `showCount && favoritesCount > 0`: render the pill layout.
- Otherwise: render the existing 32×32 square so we don't break
  the logged-out / zero-count look.
- Tap behaviour unchanged: logged-out → `showRegistrationRequiredSnackBar`,
  logged-in → optimistic toggle.

### 5.5 i18n

The pill itself has no text other than the number, so no new
strings — but the existing tooltip
`s.favoritesAddTooltip` / `s.favoritesRemoveTooltip` must keep
covering the new pill (we just put the same tooltip on the pill).

---

## 6. Implementation chunks (rough order)

| #  | Chunk                                          | Touches                                                                 |
|----|------------------------------------------------|-------------------------------------------------------------------------|
| A  | Photo picker helper extraction                 | `ui/photo_picker_sheet.dart`, `ui/add_recipe_page.dart`                 |
| B  | DB migration v11 → v12 (user + creator cache)  | `data/local/recipe_db.dart`                                             |
| C  | Backend: avatar bucket + endpoints             | `mahallem-user-portal` (separate repo)                                  |
| D  | User Card page + routing + post-signup `Add`   | `ui/user_card_page.dart`, `ui/signup_page.dart`, `router/*`             |
| E  | Recipe model: creator + ratings + fav count    | `models/recipe.dart`, `data/api/recipe_api.dart`, slang                 |
| F  | "Added by" footer (details + card chip flag)   | `ui/recipe_details_page.dart`, `ui/recipe_card.dart`                    |
| G  | Star rating widget + endpoints + store         | `ui/social/recipe_rating_row.dart`, `data/repository/rating_store.dart` |
| H  | Favorite pill                                  | `ui/recipe_card.dart`, `ui/favorite_button.dart`                        |
| I  | i18n: 13 + 4 + 1 keys × 10 locales             | `i18n.dart`, `i18n/*.i18n.json`                                         |
| J  | Tests: golden for card pill, rating widget,    | `test/ui/recipe_card_test.dart`, `test/ui/recipe_rating_row_test.dart`, |
|    | user card render, post-signup Add flow         | `test/ui/user_card_page_test.dart`                                      |

Each chunk lands in its own commit. Backend work (chunk C, the
ratings endpoints in G, the denormalised counts in §4 and §5) is
prerequisite to client chunks D, F, G, H — but the client chunks
can be written against the local-only fallback (model fields
default to `null`/0, widgets render gracefully) so they merge
even if backend work lags by a day.

---

## 7. Out of scope (deliberately)

- Public per-user profile pages (clicking a creator avatar from a
  recipe card by an end user) — needs a new `GET /users/:id/public`
  endpoint and moderation rules. Punted to a follow-up doc.
- Reviews / comments — favorites + stars cover the immediate
  signal. Comments imply moderation, which is a much larger
  feature.
- Following / social graph.
- Reverse-image dedup of avatars.

---

## 8. Reference inventory (current code, for the reader)

The proposal is grounded in these files:

- Design tokens — [docs/design_system.md](./design_system.md),
  [recipe_list/lib/ui/app_theme.dart](../recipe_list/lib/ui/app_theme.dart).
- Recipe photo upload —
  [recipe_list/lib/ui/add_recipe_page.dart](../recipe_list/lib/ui/add_recipe_page.dart),
  [recipe_list/lib/utils/photo_downscaler.dart](../recipe_list/lib/utils/photo_downscaler.dart),
  [recipe_list/lib/data/api/recipe_api.dart](../recipe_list/lib/data/api/recipe_api.dart).
- Imgproxy URL builder —
  [recipe_list/lib/utils/imgproxy.dart](../recipe_list/lib/utils/imgproxy.dart).
- Recipe model —
  [recipe_list/lib/models/recipe.dart](../recipe_list/lib/models/recipe.dart).
  No `creatorUserId` yet; user-added recipes detected by id ≥ 1_000_000.
- Recipe card —
  [recipe_list/lib/ui/recipe_card.dart](../recipe_list/lib/ui/recipe_card.dart);
  current round favorite badge.
- Profile (admin-only today) —
  [recipe_list/lib/ui/admin_after_login_page.dart](../recipe_list/lib/ui/admin_after_login_page.dart).
- Favorites sync —
  [recipe_list/lib/data/repository/favorites_store.dart](../recipe_list/lib/data/repository/favorites_store.dart),
  endpoints in
  [recipe_list/lib/auth/admin_session.dart](../recipe_list/lib/auth/admin_session.dart).
- Registration-required snackbar —
  [recipe_list/lib/ui/registration_required_snackbar.dart](../recipe_list/lib/ui/registration_required_snackbar.dart).
- i18n —
  [recipe_list/lib/i18n.dart](../recipe_list/lib/i18n.dart),
  10 locales in `lib/i18n/*.i18n.json`.
- Local SQLite —
  [recipe_list/lib/data/local/recipe_db.dart](../recipe_list/lib/data/local/recipe_db.dart),
  current schema v11.

---

## 9. Chunked TODO with tests

This section turns §6 into actionable, ship-one-at-a-time chunks.
Each chunk has:

- a goal (what's "done" looks like),
- a list of code TODOs,
- a list of tests that must pass before the chunk is merged,
- explicit prerequisites and rollback plan.

Conventions:

- Unit / widget tests live next to the existing
  [recipe_list/test/](../recipe_list/test/) structure
  (`test/<area>/<thing>_test.dart`). Use `flutter test` from the
  app root.
- Backend tests live in the `mahallem-user-portal` repo under
  `test/` and run via `npm test`.
- Each chunk is one PR / one commit on `main`. CI must be green
  before the next chunk starts.
- A chunk is **not** done until manual smoke on the installed PWA
  passes (see §11).

Status legend: ⬜ not started · 🟡 in progress · ✅ done.

### Chunk A — Photo picker helper extraction

**Goal:** one shared `pickAndCompressPhoto()` helper used by both
`AddRecipePage` and the (future) `UserCardPage`. No behavioural
change to `AddRecipePage`.

**Status:** ⬜

**Prereqs:** none.

**Code TODO**

- ⬜ Create `recipe_list/lib/ui/photo_picker_sheet.dart` exporting
  `Future<Uint8List?> pickAndCompressPhoto(BuildContext, {required
  String cameraLabel, required String galleryLabel, String?
  removeLabel})`.
- ⬜ Move the camera/gallery bottom-sheet builder out of
  `add_recipe_page.dart` into the helper. Keep the current
  `photo_downscaler.dart` call.
- ⬜ Update `AddRecipePage` to call the helper; pass the existing
  `s.addRecipePhotoFromCamera` / `s.addRecipePhotoFromGallery` keys.
- ⬜ Verify no other call sites broke (`grep ImagePicker` to confirm
  only the helper now imports it).

**Tests**

- ⬜ `test/ui/photo_picker_sheet_test.dart` — widget test that pumps
  a `Scaffold` with a button calling the helper, verifies the
  bottom sheet shows both labels and (when `removeLabel != null`)
  the remove option. Mock `ImagePicker` via a fake `pickerOverride`
  parameter (add a `@visibleForTesting` injection seam if needed).
- ⬜ `test/ui/add_recipe_page_test.dart` — extend the existing test
  (or add one if missing) to assert the bottom sheet still appears
  when the user taps the photo placeholder.
- ⬜ Run `flutter analyze` — zero new warnings.

**Rollback:** revert the single commit. The helper has no consumers
besides `AddRecipePage`.

---

### Chunk B — DB migration v11 → v12 (user_profile + recipe_creator_cache)

**Goal:** schema bumped, migration safe on existing v11 IndexedDB
snapshots, both tables empty but queryable.

**Status:** ⬜

**Prereqs:** none. Safe to land before backend.

**Code TODO**

- ⬜ Bump `kRecipeDbSchemaVersion = 12` in
  [recipe_db.dart](../recipe_list/lib/data/local/recipe_db.dart).
- ⬜ Add `applyUserProfileSchema(Database)` and
  `applyRecipeCreatorCacheSchema(Database)`; call them from
  `applyRecipeSchema` (fresh installs) and from `_onRecipeDbUpgrade`
  (`if (oldV < 12) { … }`).
- ⬜ DDL:
  - `user_profile (user_id TEXT PRIMARY KEY, display_name TEXT,
    language TEXT, avatar_path TEXT, member_since INTEGER,
    recipes_added INTEGER, cached_at INTEGER)`.
  - `recipe_creator_cache (creator_user_id TEXT PRIMARY KEY,
    display_name TEXT, avatar_path TEXT, recipes_added INTEGER,
    cached_at INTEGER)`.
- ⬜ Smoke that the Chunk-3-style runtime corruption recovery still
  applies (no new code; just confirm `_runLoad` shell still wraps
  the new queries when they're added in later chunks).

**Tests**

- ⬜ `test/data/local/recipe_db_migration_test.dart`:
  - Open an in-memory DB at v11 (apply v11 schema only), close.
  - Re-open with v12 schema; assert `PRAGMA table_info(user_profile)`
    and `PRAGMA table_info(recipe_creator_cache)` return the
    expected columns.
  - Insert + select one row in each table.
- ⬜ `test/data/local/recipe_db_fresh_install_test.dart` — open at
  v12 from scratch, assert both tables exist.
- ⬜ Existing `recipe_db` tests still green (no regression on
  recipes / favorites / owned tables).

**Rollback:** revert. Users on prod that already migrated to v12
get a no-op (the tables become unused but harmless); one extra
recovery wipe via `deleteRecipeDatabaseWebOnly` is the worst case.

---

### Chunk C — Backend: avatar bucket + user endpoints (mahallem-user-portal)

**Goal:** `food-avatars` bucket live, three endpoints shipped,
`recipes_users.avatar_path` column added. No client changes.

**Status:** ⬜

**Prereqs:** Hetzner Object Storage credentials for the new bucket.

**Code TODO** (in the **mahallem-user-portal** repo, not this one)

- ⬜ Create `food-avatars` bucket; copy the `recipe-photos`
  bucket's CORS + public-read policy.
- ⬜ Migration: `ALTER TABLE recipes_users ADD COLUMN avatar_path
  TEXT NULL`.
- ⬜ Migration: `ALTER TABLE recipes_users ADD COLUMN
  recipes_added INTEGER NOT NULL DEFAULT 0` (denormalised count
  needed by §3 & §1.4).
- ⬜ Trigger / handler: increment / decrement `recipes_added` on
  user-recipe insert / delete (`recipes.id >= 1_000_000` and
  `created_by = user_id`).
- ⬜ `POST /recipes/users/avatar` — multipart upload; validate MIME
  (`image/jpeg|png|webp`); cap 5 MB; re-encode through imgproxy;
  PUT to S3 at `food-avatars/${user_id}/${ts}.jpg`; update
  `recipes_users.avatar_path`; return `{ avatarPath, avatarUrl }`.
- ⬜ `DELETE /recipes/users/avatar` — best-effort S3 delete;
  null the column.
- ⬜ `GET /recipes/users/me` — `{ id, email, displayName, language,
  avatarPath, recipesAdded, memberSince }`.
- ⬜ Auth on all three: existing `x-recipes-user-token` middleware.
- ⬜ Update OpenAPI / docs in that repo.

**Tests** (in `mahallem-user-portal`)

- ⬜ `test/avatar_upload.test.js`:
  - 200 happy path: small JPEG → 200, returns avatarPath, S3
    object exists, DB row updated.
  - 415 wrong content-type (`text/plain` payload).
  - 413 oversize (6 MB).
  - 401 missing token.
- ⬜ `test/avatar_delete.test.js` — 200 clears column; 404 when
  no avatar set.
- ⬜ `test/users_me.test.js` — returns the seven fields; counts
  user-added recipes correctly when seed has two id ≥ 1_000_000
  recipes by that user.
- ⬜ `test/recipes_added_trigger.test.js` — insert / delete a
  user recipe, observe the count change.

**Rollback:** revert the migration is non-trivial (column add is
fine to leave); revert the routes by removing them and redeploying.
The food app doesn't call these yet, so no client breakage.

---

### Chunk D — User Card page + routing + post-signup Add flow

**Goal:** `Routes.profile` resolves to `UserCardPage` for non-admin
users; admin path keeps existing screen with a new "User card"
button; signup screen pushes the post-signup variant.

**Status:** ⬜

**Prereqs:** Chunk A (picker), Chunk B (DB), Chunk C (`/recipes/users/me`
+ `/avatar`).

**Code TODO**

- ⬜ Add `Routes.profile = '/profile'` to
  [routes.dart](../recipe_list/lib/router/routes.dart) with a shell
  branch.
- ⬜ Create `recipe_list/lib/ui/user_card_page.dart`:
  - constructor `UserCardPage({initialEditMode = false,
    isPostSignup = false})`.
  - state: avatar bytes, displayName, language, edit-mode flag.
  - calls `RecipeApi.getMe()` on init; renders read-only or edit.
  - "Save" → `RecipeApi.updateMe()` + `RecipeApi.uploadAvatar()`
    (only when bytes changed); shows `s.profileSavedToast`.
  - "Logout" reuses the existing logout helper.
  - "Skip" / "Add" buttons gated by `isPostSignup`.
- ⬜ Wire `tabProfile` shell logic:
  - `adminLoggedInNotifier == false && userTokenNotifier != null`
    → `UserCardPage()`.
  - admin path: add a top-of-screen "User card" `OutlinedButton`
    on `AdminAfterLoginPage` that pushes `UserCardPage()`.
- ⬜ Update `signup_page.dart` success handler:
  - replace `context.go(Routes.recipes)` with
    `context.go(Routes.profile, extra: {'initialEditMode': true,
    'isPostSignup': true})`.
- ⬜ Add new i18n keys in `i18n.dart`'s manual `_byLang` per §1.5
  (English + Russian first; other 8 locales fall back to English
  initially — slang cron will fill them later).

**Tests**

- ⬜ `test/ui/user_card_page_test.dart`:
  - renders read-only with mocked `getMe` payload — labels shown,
    "Edit" button present, no "Save" button.
  - tap "Edit" → fields become editable, "Save" appears, camera
    FAB on avatar appears.
  - "Save" calls `RecipeApi.updateMe` once with the edited fields
    and shows the saved toast.
  - `isPostSignup: true` shows "Skip" / "Add" instead of
    "Edit" / "Save"; "Skip" calls `context.go(Routes.recipes)`.
- ⬜ `test/ui/admin_after_login_user_card_link_test.dart` — the
  new "User card" button is present and pushes the page.
- ⬜ `test/ui/signup_post_redirect_test.dart` — successful signup
  navigates to the profile route with the post-signup extras.
- ⬜ `flutter analyze` clean.

**Rollback:** revert. `Routes.profile` falls back to the previous
admin-only branch; signup goes back to `Routes.recipes`.

---

### Chunk E — Recipe model: creator + ratings + favorites_count fields

**Goal:** `Recipe` carries the new fields end-to-end (JSON parse +
in-memory model + DB column where relevant). Widgets that consume
them ship in later chunks.

**Status:** ✅ done (commit pending). DB v13 migration intentionally
deferred — see "Implementation note" below.

**Prereqs:** Chunk C (server returns the fields). Acceptable to land
client-only with default-null values first if backend lags ≤ 1 day.

**Implementation note (deferral):** the model fields are NOT
persisted in the local SQLite cache. Counts go stale immediately,
so we always read them from the server's `/lookup` / `/page`
response; cached recipe rows reconstruct with `favoritesCount = 0`,
`ratingsCount = 0`, `ratingsSum = 0`, `myRating = null`, and the
loader refreshes them on the next list fetch. This keeps the
SQLite cache schema at v12 and avoids a migration that would have
to be invalidated on every count tick.

**Code TODO**

- ✅ Extend `Recipe` in
  [recipe.dart](../recipe_list/lib/models/recipe.dart):
  - `String? creatorUserId, creatorDisplayName, creatorAvatarPath`
  - `int? creatorRecipesAdded`
  - `int favoritesCount` (default 0)
  - `int ratingsCount, ratingsSum` (default 0)
  - `int? myRating` (auth-dependent)
- ✅ Update `fromMealDb` to project the new fields tolerantly
  (strings / ints / null / missing → safe defaults).
- ⏭ Skipped: `recipes`-table column additions + DB v13 migration
  (deferred as above).
- ⏭ Skipped: `RecipeRepository.upsertAll` / `listCached` /
  `lookupCached` — no schema change to wire up.

**Tests**

- ⬜ `test/models/recipe_json_test.dart`:
  - parses a payload with all new fields populated.
  - parses a payload missing every new field (defaults applied,
    no exception).
  - round-trips `toJson` → `fromJson` with values intact.
- ⬜ `test/data/local/recipe_db_v13_migration_test.dart` — open at
  v12 (after Chunk B), then re-open at v13, assert new columns
  exist.
- ⬜ `test/data/repository/recipe_repository_cache_test.dart` —
  insert a recipe with all new fields, read back via `listCached`,
  assert equality.

**Rollback:** revert. Migration is additive; columns can be left
unused.

---

### Chunk F — "Added by" footer (details + optional card chip)

**Goal:** recipe details page shows the creator row for user-added
recipes (id ≥ 1_000_000); recipe card chip is behind a feature flag
(off by default).

**Status:** 🟡 partially landed — `AddedByRow` widget + details
wiring shipped (commit pending). Card chip and `recipe_creator_cache`
TTL reads/writes deferred to a follow-up since they aren't on any
critical path until backend chunk C lands.

**Prereqs:** Chunk E (model fields). ✅

**Code TODO**

- ✅ Create
  [recipe_list/lib/ui/social/added_by_row.dart](../recipe_list/lib/ui/social/added_by_row.dart):
  stateless, props `(name, avatarPath, recipesAdded)`, 64×64 imgproxy
  avatar, hidden completely when `name == null`.
- ✅ Render in `recipe_details_page.dart` only when
  `recipe.id >= 1_000_000` AND `creatorDisplayName != null`. Below
  ingredients, above instructions.
- ⬜ Add `bool showCreatorChip` to `RecipeCard` (default `false`).
  Deferred — no UI surface uses it yet.
- ⬜ Cache reads/writes via `recipe_creator_cache` (Chunk B).
  Deferred — server projects creator on every list fetch already,
  per chunk C plan.
- ✅ i18n keys per §3.4: `recipeAddedByPrefix`, `recipeAuthorRecipes`
  added to all 10 locale JSONs and regenerated via `dart run slang`.

**Tests**

- ⬜ `test/ui/social/added_by_row_test.dart`:
  - renders name + "12 recipes" with a network image stub.
  - returns `SizedBox.shrink` when name is null.
- ⬜ `test/ui/recipe_details_added_by_test.dart`:
  - recipe with `id < 1_000_000` and creator fields populated →
    no row.
  - recipe with `id >= 1_000_000` and creator fields → row
    rendered.
- ⬜ Golden test
  `test/golden/added_by_row_golden_test.dart` (light theme only,
  iPhone 14 dimensions).

**Rollback:** revert. Chip flag stays off; the model fields remain
populated but unused.

---

### Chunk G — Star rating widget + endpoints + store

**Goal:** users can rate 1–5 stars on the details page; logged-out
users see the registration snackbar; aggregates render on the card.

**Status:** ⬜

**Prereqs:** Chunk E (model fields). Backend ratings tables /
endpoints land **as part of this chunk** in mahallem-user-portal.

**Code TODO** (server, in mahallem-user-portal)

- ⬜ Migration: create `recipe_ratings` table per §4.4; add
  `ratings_count`, `ratings_sum` to `recipes`.
- ⬜ Trigger / handler: keep aggregates in sync.
- ⬜ `GET /recipes/:id/rating` — `{ avg, count, my? }`.
- ⬜ `POST /recipes/:id/rating` — body `{ stars }`, upsert.
- ⬜ `DELETE /recipes/:id/rating` — remove.
- ⬜ Project `ratingsCount`, `ratingsSum`, `myRating` (when
  authenticated) into `/recipes/lookup/:id` and `/recipes/page`.

**Code TODO** (client)

- ⬜ `recipe_list/lib/data/repository/rating_store.dart` —
  per-recipe optimistic store (similar to `favorites_store`),
  exposes `myRating(id)`, `setRating(id, stars)`, `clearRating(id)`.
- ⬜ `recipe_list/lib/ui/social/recipe_rating_row.dart` — stateless
  row with 5 tappable stars, average and votes count.
- ⬜ Wire into `recipe_details_page.dart` below `AddedByRow`.
- ⬜ Recipe card: render avg + count without interactive stars (a
  separate compact widget; tap is a no-op on the card).
- ⬜ Logged-out tap → `showRegistrationRequiredSnackBar`.
- ⬜ i18n per §4.6.

**Tests** (server)

- ⬜ `test/recipe_rating.test.js`:
  - first POST creates row, count + sum updated.
  - second POST same user upserts (count unchanged, sum updated).
  - DELETE removes row, count -1, sum -= old stars.
  - 401 without auth.
  - 422 stars out of range.

**Tests** (client)

- ⬜ `test/ui/social/recipe_rating_row_test.dart`:
  - logged-out tap on a star → snackbar shown, no API call.
  - logged-in tap → `RatingStore.setRating` called with star value;
    optimistic UI updates.
  - re-tap same star → `clearRating` called.
  - on API failure, UI reverts and shows an error snackbar.
- ⬜ `test/data/repository/rating_store_test.dart` — optimistic
  flow: set → in-memory updated → server failure → revert.
- ⬜ Golden test
  `test/golden/recipe_rating_row_golden_test.dart` (idle, voted,
  logged-out variants).

**Rollback:** revert client; server endpoints can stay (no
references). `ratings_count` / `ratings_sum` columns remain at 0.

---

### Chunk H — Favorite-count pill on the recipe card

**Goal:** card shows pill (`<count> ♡`) when count > 0 and user is
logged in; otherwise the existing 32×32 square. Logged-out behaviour
unchanged.

**Status:** ⬜

**Prereqs:** Chunk E (`Recipe.favoritesCount`). Backend already
counts favorites in the `favorites` table; server change is a
denormalised `favorites_count` column on `recipes` updated by the
same handler that toggles favorites — small companion to Chunk C
(can be folded into the same backend PR).

**Code TODO** (server)

- ⬜ Migration: `ALTER TABLE recipes ADD COLUMN favorites_count
  INTEGER NOT NULL DEFAULT 0`.
- ⬜ Update favorite/unfavorite handler to bump the count in the
  same SQL transaction.
- ⬜ Project `favoritesCount` in `/recipes/lookup/:id` and
  `/recipes/page`.

**Code TODO** (client)

- ⬜ Refactor the round badge in `recipe_card.dart` into
  `RecipeFavoriteButton(favoritesCount, showCount)`.
- ⬜ Pill layout per §5.2 when `showCount && favoritesCount > 0`;
  square fallback otherwise.
- ⬜ Tap behaviour unchanged.
- ⬜ Tooltip reuses `s.favoritesAddTooltip` /
  `s.favoritesRemoveTooltip`.

**Tests** (server)

- ⬜ `test/favorites_count.test.js` — toggle on / off updates
  `favorites_count`; concurrent toggles end at the right value
  (use a small race test).

**Tests** (client)

- ⬜ `test/ui/recipe_favorite_button_test.dart`:
  - `showCount = false` → square 32×32, no number.
  - `showCount = true, favoritesCount = 0` → square (no number).
  - `showCount = true, favoritesCount = 7` → pill with "7" and
    outline heart.
  - `showCount = true, isFavorite = true, favoritesCount = 8` →
    pill with "8" and filled heart.
  - logged-out tap → snackbar, no toggle call.
  - logged-in tap → optimistic flip + count delta.
- ⬜ Golden test
  `test/golden/recipe_favorite_pill_golden_test.dart` (4 visual
  states above).

**Rollback:** revert. Card returns to round badge; server column
stays at 0 and is harmless.

---

### Chunk I — i18n: 13 + 4 + 1 keys × 10 locales

**Goal:** all new strings translated to en/ru/de/es/fr/it/tr/ar/fa/ku
(production parity).

**Status:** ⬜

**Prereqs:** Chunks D, F, G, H (so we know the final key list).
Manual `_byLang` entries can land earlier with EN-only fallback;
this chunk is the **promotion to the slang JSON files**.

**Code TODO**

- ⬜ Move all keys from manual `_byLang` in `i18n.dart` to the
  per-locale `i18n/*.i18n.json` (slang source of truth).
- ⬜ Run the existing slang i18n cron / Gemini cascade for the 8
  non-en/ru locales; review by eye for AR/FA/KU plural & RTL.
- ⬜ Re-run codegen (`dart run slang`) and commit the generated
  files.

**Tests**

- ⬜ `test/i18n/key_coverage_test.dart`:
  - asserts every new key (hard-coded list) resolves to a non-empty
    string in all 10 locales.
  - asserts plural forms (`recipeVotesCount`, `recipeAuthorRecipes`)
    resolve for 0/1/2/5/11 in en, ru, ar.
- ⬜ Translation review checklist filed in
  [docs/i18n_proposal.md](./i18n_proposal.md) (or a comment on the
  PR for the chunk).

**Rollback:** revert keeps EN fallback (slang fallback chain), so no
user-visible breakage.

---

### Chunk J — Tests + manual smoke on installed PWA

**Goal:** belt-and-braces. All chunks above include their unit /
widget / golden tests; this chunk is the **integration sweep**.

**Status:** ⬜

**Prereqs:** Chunks A–I merged.

**Code TODO**

- ⬜ Add an integration test
  `test/integration/post_signup_flow_test.dart` that walks: signup
  → user card edit mode → save → recipes list visible.
- ⬜ Add an integration test
  `test/integration/rate_and_favorite_flow_test.dart` that walks:
  details page → tap 4 stars → success snackbar → tap heart pill →
  card pill increments.
- ⬜ Add `test/integration/added_by_visibility_test.dart`:
  user-added recipe shows the row; TheMealDB recipe doesn't.

**Manual smoke (must be re-run after each merge)**

- ⬜ Installed PWA on iOS Safari (per
  [pwa-installed-bugs-2026-05.md](./pwa-installed-bugs-2026-05.md)
  — the safe-area / reload / SQLite recovery still hold).
- ⬜ Installed PWA on Android Chrome.
- ⬜ Profile tab as logged-out user → login page.
- ⬜ Profile tab as logged-in non-admin → user card.
- ⬜ Profile tab as admin → admin page with "User card" button.
- ⬜ Signup new user → post-signup user card → Skip → recipes.
- ⬜ Rate a recipe, refresh the app, rating persists.
- ⬜ Favorite a recipe, count pill increments on the card.
- ⬜ Avatar upload → reflected on user card and on the "added by"
  row of the user's own recipe.
- ⬜ Delete avatar → falls back to default placeholder everywhere.
- ⬜ Languages: switch UI to ar/fa/ku, confirm RTL on user card and
  rating row, plurals on votes count.

**Done criteria:** all integration tests green, all manual checkboxes
ticked, prerender cache cleared on prod
(`docker exec recipe_list_prerender sh -c "rm -f /var/cache/prerender/*"`),
no Sentry / console error spike for 24 h.

---

## 10. Risks & mitigations

| Risk                                                    | Mitigation                                                                 |
|---------------------------------------------------------|----------------------------------------------------------------------------|
| Avatar upload fails silently → user thinks it saved.    | `Save` button awaits both `updateMe` and `uploadAvatar`; toast only on success; revert local bytes on error. |
| `recipes_added` denorm drifts from reality.             | Backend test (Chunk C) covers insert + delete; nightly reconciliation job in mahallem-user-portal optional. |
| Rating endpoint abuse (spam votes).                     | Server upserts on `(recipe_id, user_id)` PK — one vote per user; rate-limit per token (existing middleware). |
| IndexedDB schema bumps colliding with Chunk-3 recovery. | Already covered: open-time and runtime corruption paths wipe + rebuild on `malformed`. Always run the v11→v12→v13 migration sequence in tests. |
| Translation regressions for new keys.                   | Chunk I `key_coverage_test.dart` enforces non-empty for all 10 locales before merge. |
| Card layout breakage from the new pill.                 | Golden tests in Chunk H. Changes gated behind golden review. |

---

## 11. Manual smoke script (copy-paste for each release)

```
# 1. Build & deploy
cd recipe_list && flutter build web --release
ssh prod 'cd /var/www/recipie/otus_dz_2 && git pull && \
  docker compose -f docker-compose.web.yml up -d --build flutter-web && \
  docker exec recipe_list_prerender sh -c "rm -f /var/cache/prerender/*"'

# 2. Smoke (browser tab + installed PWA)
open https://recipies.mahallem.ist/en/recipes
#   - login as a non-admin user
#   - tap Profile → user card renders
#   - tap Edit → save a new display name → toast appears, name persists after reload
#   - upload a photo → avatar updates everywhere
#   - rate a recipe 4 stars → average updates, count increments
#   - favorite a recipe → pill on the card shows count
```

