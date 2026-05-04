# 17 — Restore PUT/DELETE /recipes/:id (owner edit/delete)

**Status:** 🟡 Backend implemented + deployed (manual app E2E pending)  
**Priority:** High — user-owned recipe edit/delete is completely broken on production  
**Server target:** `mahallem_ist/local_user_portal/routes/recipes.js`  
**Deploy:** `docker compose up -d --build user-portal` on `72.61.181.62`  
**Detailed diagnosis:** `docs/owner-edit-delete-broken-routes.md`

---

## Motivation

After the recipe-app DB isolation (`20260503_recipe_app_service_isolation.sql`), the
`PUT /recipes/:id` and `DELETE /recipes/:id` routes were dropped from
`local_user_portal/routes/recipes.js`. Express now returns `404 Cannot PUT /recipes/…`
for every edit/save attempt. The Flutter client sees an HTTP 404 and shows "Не удалось
сохранить рецепт" to the user.

The floor guard (`id >= RECIPES_USER_MEAL_ID_FLOOR = 1_000_000`) ensures TheMealDB
rows cannot be mutated. Auth uses the existing `x-recipes-user-token` header (same as
`/favorites`). Backup hooks survive `go-clean` via the host bind-mount at `../backups/`.

---

## Chunk 1 — Import `backupRecipe` in `routes/recipes.js`

**File:** `local_user_portal/routes/recipes.js`

Add to the import block (near the `uploadToStorage` import):

```js
import { backupRecipe } from '../utils/backup-service.js';
```

**Test:** `node --test local_user_portal` still passes (no regression).

---

## Chunk 2 — Add `RecipeRepository.updateUserMeal(id, meal)`

**File:** `local_user_portal/routes/recipes.js`  
**Location:** Inside `RecipeRepository`, after `updateUserMealThumb`.

```js
/**
 * Replace i18n.en for a user-submitted recipe (id >= USER_MEAL_ID_FLOOR).
 * Clears all non-English locales so the translation cascade re-runs on
 * next /lookup. Floor guard prevents editing TheMealDB rows.
 * Returns the canonicalized i18n.en draft, or null if not found / blocked.
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
```

**Tests to add in `tests/recipes.test.js`:**

```js
test('updateUserMeal updates i18n.en and clears other locales', async () => {
  const db = makeFakeDb();
  const repo = new RecipeRepository(db.q, { cap: 100 });
  const { id } = await repo.createUserMeal({
    strMeal: 'Original', strMealThumb: 'https://x/a.jpg',
  });
  const updated = await repo.updateUserMeal(id, {
    strMeal: 'Edited', strMealThumb: 'https://x/b.jpg',
  });
  assert.equal(updated.strMeal, 'Edited');
  assert.equal(updated.strMealThumb, 'https://x/b.jpg');
  assert.equal(updated.idMeal, String(id));
  // Should be readable back
  const rows = await db.q(`SELECT id, i18n FROM recipes WHERE id = $1`, [id]);
  assert.equal(rows[0].i18n.en.strMeal, 'Edited');
});

test('updateUserMeal returns null for id below floor (TheMealDB guard)', async () => {
  const db = makeFakeDb();
  const repo = new RecipeRepository(db.q, { cap: 100 });
  const result = await repo.updateUserMeal(52772, { strMeal: 'Hacked', strMealThumb: 'x' });
  assert.equal(result, null);
});

test('updateUserMeal throws invalid_meal when strMeal missing', async () => {
  const db = makeFakeDb();
  const repo = new RecipeRepository(db.q, { cap: 100 });
  const { id } = await repo.createUserMeal({ strMeal: 'X', strMealThumb: 'https://x/a.jpg' });
  await assert.rejects(
    () => repo.updateUserMeal(id, { strMealThumb: 'https://x/b.jpg' }),
    /invalid_meal/,
  );
});

test('updateUserMeal returns null for unknown user-range id', async () => {
  const db = makeFakeDb();
  const repo = new RecipeRepository(db.q, { cap: 100 });
  const result = await repo.updateUserMeal(1_999_999, { strMeal: 'Ghost', strMealThumb: 'x' });
  assert.equal(result, null);
});
```

---

## Chunk 3 — Add `RecipeRepository.deleteUserMeal(id)`

**File:** `local_user_portal/routes/recipes.js`  
**Location:** Inside `RecipeRepository`, after `updateUserMeal`.

```js
/**
 * Delete a user-submitted recipe (id >= USER_MEAL_ID_FLOOR).
 * Floor guard prevents deleting TheMealDB rows.
 * Returns true if deleted, false if not found or blocked.
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

**Tests to add:**

```js
test('deleteUserMeal removes an owned recipe and returns true', async () => {
  const db = makeFakeDb();
  const repo = new RecipeRepository(db.q, { cap: 100 });
  const { id } = await repo.createUserMeal({ strMeal: 'Temp', strMealThumb: 'https://x/a.jpg' });
  const deleted = await repo.deleteUserMeal(id);
  assert.equal(deleted, true);
  const rows = await db.q(`SELECT id, i18n FROM recipes WHERE id = $1`, [id]);
  assert.equal(rows.length, 0);
});

test('deleteUserMeal returns false for id below floor', async () => {
  const db = makeFakeDb();
  const repo = new RecipeRepository(db.q, { cap: 100 });
  const result = await repo.deleteUserMeal(52772);
  assert.equal(result, false);
});

test('deleteUserMeal returns false for unknown user-range id', async () => {
  const db = makeFakeDb();
  const repo = new RecipeRepository(db.q, { cap: 100 });
  const result = await repo.deleteUserMeal(1_999_998);
  assert.equal(result, false);
});
```

---

## Chunk 4 — Register `PUT /recipes/:id` Express route

**File:** `local_user_portal/routes/recipes.js`  
**Location:** In the `recipesRoute` function, BEFORE the multer error handler
(`app.use('/recipes', (err, req, res, next) => {`).

```js
// PUT /recipes/:id — edit a user-owned recipe (id >= RECIPES_USER_MEAL_ID_FLOOR).
// JSON: { meal: {...} }  or  multipart: field `meal` (JSON string) + optional `photo`.
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

      const rows = await executeQuery(
        `SELECT id, i18n, category, area, content_hash FROM recipes WHERE id = $1`, [id],
      );
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
```

**HTTP-level tests (add to `tests/recipes.test.js` after the multipart tests):**

> Note: These require the full `recipesRoute(app, q)` Express wiring. Follow the same
> pattern as the existing multipart route tests (lines 471–end): create a mini `express()`
> app, call `recipesRoute`, issue requests with `supertest` or Node's built-in `fetch`.

```js
// PUT /recipes/:id — JSON path
test('PUT /recipes/:id JSON updates recipe and returns meal', async () => {
  // ... use supertest pattern from multipart tests
});

// PUT /recipes/:id — rejects TheMealDB id
test('PUT /recipes/:id returns 404 for TheMealDB id', async () => { ... });

// PUT /recipes/:id — 400 missing meal field
test('PUT /recipes/:id returns 400 when meal missing', async () => { ... });

// PUT /recipes/:id — 401 without token
test('PUT /recipes/:id returns 401 without token', async () => { ... });
```

---

## Chunk 5 — Register `DELETE /recipes/:id` Express route

**File:** `local_user_portal/routes/recipes.js`  
**Location:** After `PUT /recipes/:id`, still before the multer error handler.

```js
// DELETE /recipes/:id — remove a user-owned recipe (id >= RECIPES_USER_MEAL_ID_FLOOR).
// Auth: x-recipes-user-token required. Returns 204 on success.
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

**HTTP-level tests:**

```js
test('DELETE /recipes/:id returns 204 for owned recipe', async () => { ... });
test('DELETE /recipes/:id returns 404 for TheMealDB id', async () => { ... });
test('DELETE /recipes/:id returns 401 without token', async () => { ... });
```

---

## Chunk 6 — Fake DB support for new SQL in test harness

The `makeFakeDb()` in `tests/recipes.test.js` needs to handle two new SQL patterns:

```js
// In makeFakeDb() q() function, add:

if (text.startsWith('UPDATE recipes SET i18n = $2::jsonb')) {
  // updateUserMeal
  const floor = Number(params[5]);
  const r = rows.get(Number(params[0]));
  if (!r || Number(params[0]) < floor) return [];
  r.i18n = JSON.parse(params[1]);
  r.category = params[2];
  r.area = params[3];
  r.content_hash = params[4];
  return [{ id: r.id }];
}

if (text.startsWith('DELETE FROM recipes WHERE id = $1 AND id >= $2')) {
  const id = Number(params[0]);
  const floor = Number(params[1]);
  const r = rows.get(id);
  if (!r || id < floor) return [];
  rows.delete(id);
  return [{ id }];
}

if (text.startsWith('SELECT id, i18n, category, area, content_hash FROM recipes')) {
  const r = rows.get(Number(params[0]));
  return r ? [{ id: r.id, i18n: r.i18n, category: r.category, area: r.area, content_hash: r.content_hash }] : [];
}
```

---

## Chunk 7 — Deployment

### Pre-flight checks (from local Mac)

```bash
SSH_KEY=$(if [[ "$(hostname)" == *"MacBook"* ]]; then echo "$HOME/.ssh/Macbook"; else echo "$HOME/.ssh/mahallem_key_2"; fi)

# 1. Sync production back if it has any local edits
ssh -i "$SSH_KEY" root@72.61.181.62 \
  "cd /root/mahallem/mahallem_ist && git add -A && git diff --cached --quiet || git commit -m 'Production sync before owner-edit-delete fix' && git push origin main"

# 2. Pull production changes to local
cd /Volumes/Working_MacOS_Extended/mahallem/mahallem_ist && git pull origin main
```

### Commit and push

```bash
cd /Volumes/Working_MacOS_Extended/mahallem/mahallem_ist
# Clear local test backups (NEVER commit them — they overwrite production data)
rm -f backups/realtime/*.jsonl backups/metadata.json backups/sync.log
touch backups/realtime/.gitkeep && echo '{}' > backups/metadata.json
git add -A
git commit -m "feat(recipes): restore PUT/DELETE /recipes/:id owner-edit-delete routes

Routes were dropped during recipe-app DB isolation.
- Add RecipeRepository.updateUserMeal and deleteUserMeal
- Register PUT /recipes/:id (JSON + multipart with photo)
- Register DELETE /recipes/:id (204 on success)
- Import backupRecipe from backup-service for go-clean survival
- Add unit tests for new repo methods and HTTP routes

Fixes: user sees 'Не удалось сохранить рецепт' when editing own recipe
Ref: docs/owner-edit-delete-broken-routes.md"
git push origin main
```

### Deploy to production

```bash
SSH_KEY=$(if [[ "$(hostname)" == *"MacBook"* ]]; then echo "$HOME/.ssh/Macbook"; else echo "$HOME/.ssh/mahallem_key_2"; fi)
ssh -i "$SSH_KEY" root@72.61.181.62 \
  "cd /root/mahallem/mahallem_ist && git pull origin main && \
   cd local_docker_admin_backend && docker compose up -d --build user-portal"
```

### Smoke tests

```bash
# Health check
curl -s https://mahallem.ist/recipes/health | python3 -m json.tool

# PUT floor guard (must be 404, not 404 "Cannot PUT")
curl -s -X PUT https://mahallem.ist/recipes/52772 \
  -H "Content-Type: application/json" \
  -H "x-recipes-user-token: invalid" \
  -d '{"meal":{"strMeal":"x","strMealThumb":"x"}}' | cat
# Expect: {"error":"unauthorized"}

# DELETE floor guard
curl -s -o /dev/null -w "%{http_code}" -X DELETE https://mahallem.ist/recipes/52772 \
  -H "x-recipes-user-token: invalid"
# Expect: 401
```

---

## Acceptance Criteria

- [ ] `PUT /recipes/1000012` with valid token → 200 `{ meal: {...} }` *(pending manual token-based smoke test)*
- [ ] `DELETE /recipes/1000012` with valid token → 204 *(pending manual token-based smoke test)*
- [ ] `PUT /recipes/52772` (TheMealDB id) → 404 `not_found` *(pending authorized smoke test)*
- [ ] `DELETE /recipes/52772` → 404 `not_found` *(pending authorized smoke test)*
- [x] No token → 401
- [x] `node --test local_user_portal` passes new owner-edit-delete tests *(2 unrelated pre-existing failures remain in lookup/translation tests)*
- [ ] Flutter app: user can save/edit own recipe without error snackbar *(pending device E2E)*
- [ ] Flutter app: user can delete own recipe and it disappears from list *(pending device E2E)*
- [ ] After `go-clean`: recipe still in `backups/realtime/recipes.jsonl`, restored on next startup *(pending destructive verification window)*

### Verification notes (2026-05-03)

- Backend commit deployed to production: `2372e0ac` (`main`)
- Production rebuild executed: `docker compose up -d --build user-portal`
- Live smoke checks:
  - `PUT /recipes/52772` without token → `401`
  - `DELETE /recipes/1000012` without token → `401`
  - Confirms handlers are registered (previously returned `404 Cannot PUT/DELETE ...`).
