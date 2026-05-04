# 18 — Fix deleted recipes still visible in lists

**Status:** 🔴 Bug confirmed in production (2026-05-04)  
**Priority:** High — data consistency issue  
**Impact:** When admin deletes a recipe, it disappears from main feed but still appears in:
  1. Admin "Recipes added" list  
  2. Original creator's "My recipes" list

**Server target:** `mahallem_ist/local_user_portal/routes/auth.js` + recipes.js  
**Deploy:** `docker compose up -d --build user-portal` on `72.61.181.62`

---

## Issue 1: Deleted recipes in admin "Recipes added" list

**File:** `local_user_portal/routes/auth.js`  
**Endpoint:** `GET /api/recipe-admin/recipes-added` (line ~2530)

### Current SQL (BROKEN)
```sql
SELECT c.recipe_id, c.actor_type, c.user_id, ...
  FROM recipe_app_recipe_creators c
  LEFT JOIN recipe_app_users u ON u.id::text = c.user_id
  LEFT JOIN recipes r ON r.id = c.recipe_id
  ORDER BY c.created_at DESC
  LIMIT $1 OFFSET $2
```

When recipe is deleted, `r.*` fields are NULL but the row is still returned.

### Fix
Add `WHERE r.id IS NOT NULL`:
```sql
SELECT c.recipe_id, c.actor_type, c.user_id, ...
  FROM recipe_app_recipe_creators c
  LEFT JOIN recipe_app_users u ON u.id::text = c.user_id
  LEFT JOIN recipes r ON r.id = c.recipe_id
  WHERE r.id IS NOT NULL
  ORDER BY c.created_at DESC
  LIMIT $1 OFFSET $2
```

---

## Issue 2: Deleted recipes in user's own recipes list

**File:** `local_user_portal/routes/recipes.js`  
**Endpoint:** `GET /recipes/user/:userId` (likely)

### Status
🔎 **TODO:** Locate the endpoint that returns user-owned recipes. Search for:
- `SELECT ... FROM recipes WHERE ... user_id` or similar filter
- Endpoint handler for user recipes list
- Any filtering on `id >= RECIPES_USER_MEAL_ID_FLOOR`

### Fix
Same pattern: filter out rows where `recipes.id IS NULL` after joining with any deletion/archive table, or check if recipe still exists in main `recipes` table.

---

## Testing

After deploy:
1. Admin deletes recipe via admin feed
2. Recipe should disappear immediately from both:
   - Admin "Recipes added" list (refresh)
   - Original user's "My recipes" tab (refresh)
3. No audit record changes needed — `recipe_app_recipe_creators` can persist (historical tracking)
