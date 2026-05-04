# Owner Edit/Delete — Broken PUT/DELETE Routes (Post-Isolation)

**Status:** 🔴 Broken on production as of 2026-05-03  
**Affects:** Regular (non-admin) users trying to edit or delete their own recipes  
**Symptoms:** Flutter app shows error snackbar when tapping Save/Edit on a user-owned recipe  
**Root cause:** `PUT /recipes/:id` and `DELETE /recipes/:id` routes were never registered in
`local_user_portal/routes/recipes.js`; Express returns `404 Cannot PUT /recipes/…`.

---

## Diagnosis

```bash
curl -X PUT  https://mahallem.ist/recipes/1000012   → 404 Cannot PUT /recipes/1000012
curl -X DELETE https://mahallem.ist/recipes/1000012 → 404 Cannot DELETE /recipes/1000012
```

The `PUT` and `DELETE` verb handlers exist in the design doc
(`docs/owner-edit-delete.md`) and were committed to `main` at commit `88074a61` in the
`mahallem_ist` repo, but were **never carried forward** when the recipe-app was isolated
into `local_user_portal/` (the `20260503_recipe_app_service_isolation.sql` migration window).

The `GET`, `POST`, and `/favorites` routes all survived. The two mutation routes did not.

---

## What the Design Doc Specifies

From `docs/owner-edit-delete.md` §3 (Backend):

| Route | Behaviour |
|-------|-----------|
| `PUT /recipes/:id` | Multipart **or** JSON. Validates `id >= RECIPES_USER_MEAL_ID_FLOOR`; calls `repo.updateUserMeal`; uploads new photo to bucket if multipart; calls `backupRecipe(updated, 'update')`. |
| `DELETE /recipes/:id` | Validates floor guard; calls `repo.deleteUserMeal`; calls `backupRecipe({id}, 'delete')`; returns 204. |

Auth: uses **`x-recipes-user-token`** (same `verifyRecipesUserToken` / `recipesUserAuthMiddleware`
already in the file for `/recipes/favorites`).

Ownership on the server is **not** checked by user-id — the floor guard
(`id >= 1_000_000`) is the only server-side protection against editing TheMealDB rows.
This is intentional: `docs/owner-edit-delete.md` §2 states that single-device ownership
tracking via `owned_recipes` SQLite table is the client-side gate.

---

## Go-Clean Survival

`backups/` is a **host bind-mount** (`../backups:/app/backups:rw` in `docker-compose.yml`).
`go-clean` (`docker compose down -v && up --build`) wipes Docker volumes but not the host
bind-mount, so JSONL realtime backups survive. No schema migration is required — the
`recipes` table and `recipes_id_seq` sequence are already in place.

Deployment is git-based (see `hostinger-deployment/DEPLOYMENT_WORKFLOW.md`):

1. Edit locally → commit/push to `main`  
2. SSH to `72.61.181.62` → `git pull && docker compose up -d --build user-portal`

---

## What Was Missing vs What Existed

| Component | Status before fix |
|-----------|-------------------|
| `verifyRecipesUserToken` / `recipesUserAuthMiddleware` | ✅ Present (used by `/favorites`) |
| `multipartLimiter` / `recipePhotoUpload` multer | ✅ Present (used by `POST /recipes`) |
| `repo.createUserMeal` | ✅ Present |
| `repo.updateUserMealThumb` | ✅ Present |
| `backupRecipe` import from `backup-service.js` | ❌ Not imported in `routes/recipes.js` |
| `repo.updateUserMeal(id, meal)` | ❌ Missing from `RecipeRepository` |
| `repo.deleteUserMeal(id)` | ❌ Missing from `RecipeRepository` |
| `PUT /recipes/:id` Express route | ❌ Not registered |
| `DELETE /recipes/:id` Express route | ❌ Not registered |

---

## Fix Summary

Three changes to `local_user_portal/routes/recipes.js`:

### 1. Import `backupRecipe`

```js
import { backupRecipe } from '../utils/backup-service.js';
```

### 2. Add `updateUserMeal` and `deleteUserMeal` to `RecipeRepository`

```js
/**
 * Replace i18n.en for a user-submitted recipe (id >= USER_MEAL_ID_FLOOR).
 * Clears all non-English locales so the translation cascade re-runs on
 * the next /lookup — same semantic as the POST flow.
 * Returns the updated i18n.en meal, or null if not found / floor guard fails.
 */
async updateUserMeal(id, meal) {
  const floor = Number(process.env.RECIPES_USER_MEAL_ID_FLOOR || 1_000_000);
  const numId = Number(id);
  if (!Number.isFinite(numId) || numId < floor) return null;
  const draft = canonicalize({ ...meal, idMeal: String(numId) });
  if (!draft || !draft.strMeal) throw new Error('invalid_meal');
  const i18n = JSON.stringify({ [SOURCE_LANG]: draft });
  const hash = contentHash(draft);
  const rows = await this.q(
    `UPDATE recipes
        SET i18n = $2::jsonb,
            category = $3,
            area = $4,
            content_hash = $5,
            fetched_at = NOW()
      WHERE id = $1 AND id >= $6
      RETURNING id`,
    [numId, i18n, draft.strCategory, draft.strArea, hash, floor],
  );
  return rows.length ? draft : null;
}

/**
 * Delete a user-submitted recipe (id >= USER_MEAL_ID_FLOOR).
 * Returns true if a row was deleted, false if not found or floor guard fails.
 */
async deleteUserMeal(id) {
  const floor = Number(process.env.RECIPES_USER_MEAL_ID_FLOOR || 1_000_000);
  const numId = Number(id);
  if (!Number.isFinite(numId) || numId < floor) return false;
  const rows = await this.q(
    `DELETE FROM recipes WHERE id = $1 AND id >= $2 RETURNING id`,
    [numId, floor],
  );
  return rows.length > 0;
}
```

### 3. Register PUT and DELETE routes (before the multer error handler)

```js
// PUT /recipes/:id — edit a user-owned recipe (id >= RECIPES_USER_MEAL_ID_FLOOR).
// Accepts JSON { meal: {...} } or multipart form-data (meal field + optional photo file).
// Auth: x-recipes-user-token required.
app.put(
  '/recipes/:id',
  recipesUserAuthMiddleware,
  (req, res, next) => req.is('multipart/*') ? multipartLimiter(req, res, next) : next(),
  recipePhotoUpload.single('photo'),
  async (req, res) => {
    const id = Number(req.params.id);
    const isMultipart = !!req.file;
    let meal = null;
    try {
      if (isMultipart) {
        const raw = req.body?.meal;
        if (typeof raw !== 'string' || !raw) {
          cleanupTempFile(req.file.path);
          return res.status(400).json({ error: 'missing_meal' });
        }
        try { meal = JSON.parse(raw); } catch {
          cleanupTempFile(req.file.path);
          return res.status(400).json({ error: 'invalid_meal_json' });
        }
      } else {
        meal = req.body?.meal;
      }
      if (!meal || typeof meal !== 'object') {
        if (req.file) cleanupTempFile(req.file.path);
        return res.status(400).json({ error: 'missing_meal' });
      }

      const updated = await repo.updateUserMeal(id, meal);
      if (!updated) {
        if (req.file) cleanupTempFile(req.file.path);
        return res.status(404).json({ error: 'not_found' });
      }

      if (isMultipart && req.file) {
        const ext = (path.extname(req.file.originalname) || '.jpg').toLowerCase();
        const safeExt = /^\.(jpe?g|png|webp)$/.test(ext) ? ext : '.jpg';
        const ts = Date.now();
        const rand = crypto.randomBytes(4).toString('hex').slice(0, 6);
        const key = `recipes/${id}/photo_${ts}_${rand}${safeExt}`;
        try {
          const publicUrl = await uploadFn(req.file, 'recipe-photos', key, executeQuery);
          await repo.updateUserMealThumb(id, publicUrl);
          updated.strMealThumb = publicUrl;
        } catch (uploadErr) {
          console.error('PUT /recipes upload_failed', { id, err: uploadErr.message });
          cleanupTempFile(req.file.path);
          return res.status(502).json({ id, error: 'upload_failed' });
        }
        cleanupTempFile(req.file.path);
      }

      // Fetch full row for backup (includes updated i18n blob)
      const rows = await executeQuery(`SELECT id, i18n, category, area, content_hash FROM recipes WHERE id = $1`, [id]);
      backupRecipe(rows[0] || { id, ...updated }, 'update').catch(console.error);

      return res.json({ meal: updated });
    } catch (err) {
      if (req.file) cleanupTempFile(req.file.path);
      if (err?.message === 'invalid_meal') return res.status(400).json({ error: 'invalid_meal' });
      console.error('PUT /recipes/:id', err);
      return res.status(500).json({ error: 'internal' });
    }
  },
);

// DELETE /recipes/:id — remove a user-owned recipe (id >= RECIPES_USER_MEAL_ID_FLOOR).
// Auth: x-recipes-user-token required.
app.delete('/recipes/:id', recipesUserAuthMiddleware, async (req, res) => {
  const id = Number(req.params.id);
  try {
    const deleted = await repo.deleteUserMeal(id);
    if (!deleted) return res.status(404).json({ error: 'not_found' });
    backupRecipe({ id }, 'delete').catch(console.error);
    return res.status(204).send();
  } catch (err) {
    console.error('DELETE /recipes/:id', err);
    return res.status(500).json({ error: 'internal' });
  }
});
```

---

## Test Plan

See `todo/17-owner-edit-delete-routes.md` for chunk breakdown with test assertions.

### Manual smoke tests (after deploy)

```bash
# 1. Create a recipe (get a token first from /users/login)
TOKEN="<x-recipes-user-token from login>"
ID=$(curl -s -X POST https://mahallem.ist/recipes \
  -H "x-recipes-user-token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"meal":{"strMeal":"Test","strMealThumb":"https://x/t.jpg"}}' \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
echo "Created: $ID"

# 2. Edit it
curl -s -X PUT "https://mahallem.ist/recipes/$ID" \
  -H "x-recipes-user-token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"meal":{"strMeal":"Test Edited","strMealThumb":"https://x/t.jpg"}}' | python3 -m json.tool

# 3. Delete it
curl -s -o /dev/null -w "%{http_code}" -X DELETE "https://mahallem.ist/recipes/$ID" \
  -H "x-recipes-user-token: $TOKEN"
# Expect: 204

# 4. Floor guard: cannot edit a TheMealDB recipe
curl -s -X PUT "https://mahallem.ist/recipes/52772" \
  -H "x-recipes-user-token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"meal":{"strMeal":"Hacked","strMealThumb":"x"}}' | python3 -m json.tool
# Expect: 404 not_found

# 5. No auth
curl -s -o /dev/null -w "%{http_code}" -X DELETE "https://mahallem.ist/recipes/$ID"
# Expect: 401
```
