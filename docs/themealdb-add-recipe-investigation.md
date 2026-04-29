# TheMealDB — can we push user-submitted recipes upstream?

**Short answer: no, not via a public API.** We surveyed
[`themealdb.com/api.php`](https://www.themealdb.com/api.php) and the
premium-tier announcements; there is no documented `POST /addmeal` or
similar. User-submitted recipes therefore live only in our Postgres
table and the on-device sqflite cache (see
[`add-recipe-feature.md`](./add-recipe-feature.md)).

---

## 1. Free public API (v1)

Base URL: `https://www.themealdb.com/api/json/v1/1/…`

All endpoints are **HTTP GET only**. Confirmed by reading the
official "API Endpoints" section on
<https://www.themealdb.com/api.php>:

| Endpoint | Purpose |
|---|---|
| `search.php?s={name}` | Search recipes by name |
| `search.php?f={letter}` | List recipes by first letter |
| `lookup.php?i={id}` | Single recipe by id |
| `random.php` | One random recipe |
| `categories.php` | All categories (rich) |
| `list.php?c=list` / `?a=list` / `?i=list` | Filter pivots |
| `filter.php?{c|a|i}={value}` | Filter by category / area / ingredient |

There is **no** `add.php`, no `submit.php`, no documented mutation
endpoint, and the page does not advertise any HTTP-mutation entry
point. The only "upload your recipe" mechanism mentioned anywhere
on the site is a contact email: **<thedatadb@gmail.com>** —
described as a way to suggest *new categories or recipes*, not a
programmatic write API.

## 2. Premium API (v2)

The same `api.php` page advertises a paid v2 tier
(<https://www.themealdb.com/api/json/v2/{key}/…>) requested via
PayPal. Quoting the page:

> "The MealDB API allows you to access more advanced features
> include adding your own meals and images. As a thank you for
> supporting the project supporters get access to additional API
> features such as multi-ingredient filter, latest meals & search
> by area."

Important nuances:

* The phrase **"adding your own meals and images"** appears in the
  benefits blurb but **no URL or schema is published**. The
  documented v2 endpoints on the same page (`latest.php`,
  `randomselection.php`, multi-ingredient `filter.php?i=…,…`) are
  read-only.
* Access requires a paid PayPal subscription and a one-off email
  exchange to receive an API key.
* No SDK, no OpenAPI spec.

We have not paid for v2, so we cannot empirically verify whether a
write endpoint exists, what shape it expects, or what the rate
limits are. **Treat the "add meals" capability as undocumented
until proven otherwise.**

## 3. Why we don't try anyway

Even if a v2 write endpoint existed:

1. **Provenance & moderation.** TheMealDB is a curated dataset.
   Pushing arbitrary user input upstream would either require their
   moderation queue (slow, no ETA) or pollute their public corpus —
   neither is acceptable for the feature scope.
2. **Locale split.** Our submitter writes in their app locale; we
   normalise to English on the server (`i18n.en`), but TheMealDB
   only hosts English. We'd need to gate uploads behind the same
   echo-quality + translation pipeline (`_ensureLang`, see
   `mahallem_ist/local_user_portal/docs/translation-pipeline.md`)
   before submission, doubling the surface area.
3. **Legal.** Re-publishing user-submitted content under a
   third-party catalogue's terms is a separate legal review.
4. **Reversibility.** Our own Postgres row can be deleted by an
   operator. An upstream POST cannot.

## 4. Decision

User-submitted recipes are stored only in:

* `recipes` table in our Postgres (`local_user_portal`),
* `recipe_bodies` + `recipes` tables in the on-device sqflite
  cache via `RecipeRepository.upsertAll`.

They are surfaced to other users through the same
`/recipes/page`, `/recipes/search`, `/recipes/lookup/:id` endpoints
that already serve TheMealDB-fetched rows — distinguished only by
their id range (≥ `RECIPES_USER_MEAL_ID_FLOOR`, default `1_000_000`).

If we ever want to contribute a recipe upstream, the operational
path is **manual**: email <thedatadb@gmail.com> with the canonical
JSON.

## 5. Re-evaluation triggers

Reopen this investigation when any of the following becomes true:

* TheMealDB publishes an OpenAPI / Swagger spec including a write
  endpoint;
* a paying member of the team subscribes to v2 and confirms the
  shape and quota of the "add your own meal" feature;
* we decide to host our own MealDB-shape mirror (then the question
  becomes "can we contribute *to our own mirror*", which is what
  the current `POST /recipes` endpoint already does).

## 6. References

* TheMealDB API documentation page: <https://www.themealdb.com/api.php>
  — accessed during this investigation; no POST endpoint listed.
* Contact: <thedatadb@gmail.com> (free) /
  <https://www.themealdb.com/api.php#join> (premium signup).
* Internal companion: [`add-recipe-feature.md`](./add-recipe-feature.md).
