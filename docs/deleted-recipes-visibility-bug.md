# Deleted Recipes Still Visible — Data Consistency Bug

**Status:** 🔴 Confirmed in production (2026-05-04)  
**Discovered:** During "Recipes added" feature testing  
**Affects:** Admin deletions not fully cascading to user-facing lists

---

## Symptoms

1. Admin (Novogod) deletes a recipe via admin edit/delete affordance
2. Recipe disappears from main recipe feed ✓
3. BUT recipe still appears in:
   - **Admin "Recipes added" list** (after refresh) ✗
   - **Creator's "My recipes" list** (after refresh) ✗

---

## Root Cause Analysis

### Issue 1: Admin "Recipes added" List

**Query:** `GET /api/recipe-admin/recipes-added`

```sql
SELECT c.recipe_id, c.actor_type, c.user_id, c.admin_id, c.actor_email,
       c.created_at, u.full_name, u.email, r.i18n->'en'->>'strMeal'
  FROM recipe_app_recipe_creators c
  LEFT JOIN recipe_app_users u ON u.id::text = c.user_id
  LEFT JOIN recipes r ON r.id = c.recipe_id
  ORDER BY c.created_at DESC
  LIMIT $1 OFFSET $2;
```

**Problem:** When recipe is deleted, `r.id IS NULL` but the row is still returned with NULL recipe fields.

**Root cause:** `recipe_app_recipe_creators` is an **audit table** — entries persist even after the recipe is gone. The LEFT JOIN allows NULL matches, so deleted recipes appear with empty recipe metadata.

### Issue 2: Creator's "My recipes" List

**Endpoint:** `GET /recipes/user/:userId` (or equivalent)

**Problem:** Similar — user's recipe list query likely uses a condition like:
```sql
WHERE id >= RECIPES_USER_MEAL_ID_FLOOR
  AND ... (some user ownership check)
```

Without checking if the recipe actually exists in the `recipes` table or without soft-delete logic.

---

## Design Considerations

### Keep Audit Trail

The `recipe_app_recipe_creators` table serves as an immutable audit log of who created which recipes and when. **We should NOT delete from this table.**

Instead, **filter at query time** by ensuring the recipe still exists.

### Solutions

#### For `GET /api/recipe-admin/recipes-added`
Add WHERE clause to filter deleted recipes:
```sql
WHERE r.id IS NOT NULL
```

#### For user's "My recipes" endpoint
- Option A: Add WHERE clause checking recipe existence
- Option B: Check if DELETE actually removes from `recipes` or soft-deletes
- Option C: Audit table approach — check if recipe_app_recipe_creators entry is marked as "deleted"

---

## Deployment Impact

- ✅ No schema changes
- ✅ No data migration
- ✅ Backend query logic only
- ✅ Can be deployed immediately after code review

---

## Testing Checklist

- [ ] Admin deletes user-created recipe
- [ ] Recipe removed from "Recipes added" list on refresh
- [ ] Creator still sees recipe in deletion history (if applicable)
- [ ] Recipe removed from creator's "My recipes" list on refresh
- [ ] Admin's own deletions work correctly
