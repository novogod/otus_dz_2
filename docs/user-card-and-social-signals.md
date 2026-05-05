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
