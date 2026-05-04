# 18 — Fix deleted recipes still visible in lists

**Status:** ✅ Implemented and committed  
**Priority:** High — data consistency issue  
**Impact:** When admin deletes a recipe, it disappears from main feed but still appears in:
  1. Admin "Recipes added" list  
  2. Original creator's "My recipes" list

**Server target:** `mahallem_ist/local_user_portal/routes/auth.js` + recipes.js  
**Deploy:** `docker compose up -d --build user-portal` on `72.61.181.62`  
**Commit:** `433b9de6` in mahallem_ist repo

---

## ✅ IMPLEMENTATION COMPLETE

### Issue 1: Deleted recipes in admin "Recipes added" list

**File:** `local_user_portal/routes/auth.js`  
**Endpoint:** `GET /api/recipe-admin/recipes-added` (line ~2530)

**Fixed SQL:**
```sql
SELECT c.recipe_id, ...
  FROM recipe_app_recipe_creators c
  LEFT JOIN recipe_app_users u ON u.id::text = c.user_id
  LEFT JOIN recipes r ON r.id = c.recipe_id
  WHERE r.id IS NOT NULL
  ORDER BY c.created_at DESC
  LIMIT $1 OFFSET $2
```

Also updated COUNT query to filter deleted recipes:
```sql
SELECT COUNT(*)::int AS c 
  FROM recipe_app_recipe_creators c
  LEFT JOIN recipes r ON r.id = c.recipe_id
  WHERE r.id IS NOT NULL
```

---

### Issue 2: Cache invalidation on recipe mutations

**File:** `local_user_portal/routes/recipes.js`

1. Import invalidate function:
```js
import {
    filterKey,
    getOrSet,
    pageKey,
    recipeKey,
    invalidate,
} from '../lib/cache/redis-recipes.js';
```

2. DELETE /recipes/:id: Invalidate recipe caches for all languages
```js
// Invalidate recipe cache for all supported languages
for (const lang of SUPPORTED_LANGS) {
  await invalidate(redis, recipeKey(id, lang)).catch(console.error);
}
```

3. PUT /recipes/:id: Invalidate recipe caches for all languages (same pattern)

---

## Deployment Steps

1. **Pull latest code:**
   ```bash
   cd /path/to/mahallem_ist
   git pull origin main  # includes commit 433b9de6
   ```

2. **Build and restart backend:**
   ```bash
   docker compose up -d --build user-portal
   ```

3. **Verify:**
   - Admin deletes a recipe → admin "Recipes added" list refreshes → recipe gone ✓
   - Creator's recipe list refreshes → deleted recipe gone ✓

---

## Testing Checklist

- [ ] Admin deletes user-created recipe
- [ ] Recipe removed from "Recipes added" list on refresh
- [ ] Recipe removed from creator's feed on refresh
- [ ] Admin's own recipe deletions work correctly
- [ ] PUT /recipes/:id cache invalidation working
- [ ] DELETE /recipes/:id cache invalidation working
- [ ] No errors in server logs during mutations

---

## Design Notes

- **Audit Trail:** `recipe_app_recipe_creators` table persists (immutable) — only query filters deleted recipes
- **Page Cache:** `/recipes/page` uses 24h TTL for offset/limit combinations; individual recipe caches invalidated on mutation
- **Client-side:** Flutter app cleans up owned_recipes SQLite table on deletion; recipe data fetched fresh from backend on refresh

