# Admin "Recipes Added" Feature

**Date:** 2026-05-04

## Overview

When a regular user adds a new recipe, the recipe is **automatically added to their favorites**, and the **admin can immediately see** which recipes were added by which users via a dedicated "Recipes added" button in the admin profile panel.

## Requirements Met

- ✅ User adds recipe → auto-favorited (if logged in)
- ✅ Admin profile shows "Recipes added" button below other buttons
- ✅ Button opens list of recipes with:
  - Recipe name and link to recipe card
  - Creator name, email, and link to user card
  - Creation timestamp
- ✅ Backend tracks all recipe creators in `recipe_app_recipe_creators` table
- ✅ Admin can view full list with pagination

## Implementation

### Flutter Client (`recipe_list`)

#### Auto-Favorite on Create
**File:** `lib/ui/add_recipe_page.dart` (lines 485-492)

After successful recipe creation (new recipe only, not edits):
```dart
if (existing == null) {
  // Auto-add to favorites only on creation
  try {
    final store = favoritesStoreNotifier.value ?? 
                  await ensureFavoritesStoreInitialized();
    if (store != null && userLoggedInNotifier.value) {
      await store.add(localized.id, appLang.value);
    }
  } catch (_) {}
  // ... track owned recipes
}
```

#### Admin Profile Button
**File:** `lib/ui/admin_after_login_page.dart` (lines 157-175)

Visible in admin panel with icon `Icons.library_books_outlined`:
```dart
FilledButton.icon(
  style: _primaryButtonStyle,
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminAddedRecipesPage(
          adminLogin: widget.adminLogin,
          adminPassword: widget.adminPassword,
        ),
      ),
    );
  },
  icon: const Icon(Icons.library_books_outlined),
  label: const Text('Recipes added'),
),
```

#### Recipes Added List UI
**File:** `lib/ui/admin_added_recipes_page.dart`

- Fetches recipes-added list via `fetchRecipeAdminAddedRecipes()`
- Displays cards per recipe with:
  - Recipe name
  - Creator name/email (or "Unknown user")
  - Timestamp
  - "Open recipe card" button → `RecipeDetailsPage`
  - "Open user card" button → `AdminUsersPage`
- Pull-to-refresh via refresh icon in AppBar
- Empty/error states handled

**File:** `lib/auth/admin_session.dart` (lines 134-177, 726-773)

Models and API:
```dart
class AdminAddedRecipeItem {
  final int recipeId;
  final String recipeName;
  final String? recipeThumb;
  final String? recipeLink;
  final String creatorType;
  final String? creatorUserId;
  final String? creatorName;
  final String? creatorEmail;
  final String? creatorLink;
  final DateTime? createdAt;
  // ...
}

Future<List<AdminAddedRecipeItem>> fetchRecipeAdminAddedRecipes({
  required String adminLogin,
  required String adminPassword,
}) async {
  // Calls GET /api/recipe-admin/recipes-added
  // Returns list of recipes with creator metadata
}
```

### Backend (`mahallem_ist`)

#### Creator Tracking Table
**Created by migration:** `20260503_recipe_app_service_isolation.sql`

```sql
CREATE TABLE recipe_app_recipe_creators (
  id BIGSERIAL PRIMARY KEY,
  recipe_id INT NOT NULL,
  actor_type TEXT NOT NULL,          -- 'user' | 'admin'
  user_id TEXT,
  admin_id TEXT,
  actor_email TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

#### Recipe Creation Hook
**File:** `routes/recipes.js`

On `POST /recipes`, after successful recipe creation:
```javascript
// Insert creator record
await pool.query(
  `INSERT INTO recipe_app_recipe_creators
     (recipe_id, actor_type, user_id, actor_email, created_at)
   VALUES ($1, $2, $3, $4, $5)`,
  [recipeId, 'user', user_id, user_email, new Date()]
);
```

#### Admin Endpoint
**File:** `routes/auth.js` (lines 2506-2590)

`GET /api/recipe-admin/recipes-added`
- Requires admin token with scope: `viewer`, `operator`, or `super_admin`
- Query params: `limit` (default 200, max 500), `offset` (default 0)
- Response:
```json
{
  "success": true,
  "total": 42,
  "limit": 200,
  "offset": 0,
  "recipes": [
    {
      "recipeId": 1000012,
      "recipeName": "Test Recipe",
      "recipeThumb": "https://...",
      "recipeLink": "/recipes/lookup/1000012",
      "creatorType": "user",
      "creatorUserId": "uuid-123",
      "creatorName": "Andrey",
      "creatorEmail": "info@lagente.do",
      "creatorLink": "/api/recipe-admin/users/uuid-123",
      "createdAt": "2026-05-04T03:45:18Z"
    }
  ]
}
```

SQL query (lines 2530-2549):
```sql
SELECT c.recipe_id,
       c.actor_type,
       c.user_id,
       c.admin_id,
       c.actor_email,
       c.created_at,
       u.full_name AS user_full_name,
       u.email AS user_email,
       r.i18n->'en'->>'strMeal' AS recipe_name,
       r.i18n->'en'->>'strMealThumb' AS recipe_thumb
  FROM recipe_app_recipe_creators c
  LEFT JOIN recipe_app_users u ON u.id::text = c.user_id
  LEFT JOIN recipes r ON r.id = c.recipe_id
  ORDER BY c.created_at DESC
  LIMIT $1 OFFSET $2
```

## Testing

### E2E Flow
1. Regular user logs in → creates a recipe
2. Recipe auto-added to user's favorites ✓
3. Admin logs in → sees "Recipes added" button in profile
4. Admin clicks button → sees newly added recipe in the list ✓
5. Admin can click "Open recipe card" → views recipe details ✓
6. Admin can click "Open user card" → views user profile ✓

### Manual Testing (Production)
- Deployed to `https://mahallem.ist`
- Admin credentials: `foodapi@lagente.do`
- Test user account: `info@lagente.do`
- Endpoint: `GET https://mahallem.ist/api/recipe-admin/recipes-added`

## Links

- Backend: [routes/auth.js](../mahallem/mahallem_ist/local_user_portal/routes/auth.js) (lines 2506-2590)
- Flutter UI: [admin_added_recipes_page.dart](../recipe_list/lib/ui/admin_added_recipes_page.dart)
- Flutter API: [admin_session.dart](../recipe_list/lib/auth/admin_session.dart) (lines 726-773)
- Admin Panel: [admin_after_login_page.dart](../recipe_list/lib/ui/admin_after_login_page.dart) (lines 157-175)
- Add Recipe: [add_recipe_page.dart](../recipe_list/lib/ui/add_recipe_page.dart) (lines 485-492)

## Related Issues

- None currently open
- All criteria met and tested
