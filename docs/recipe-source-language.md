# Автоопределение языка пользовательского рецепта

Документ описывает фичу «пользователь может писать рецепт на любом
поддерживаемом языке, а сервер сам приводит его к английскому
канону и индексирует во всех локалях» — расширение фич
[add-recipe-feature.md](add-recipe-feature.md) и
[owner-edit-delete.md](owner-edit-delete.md).

Релевантные коммиты:

- Flutter (`otus_dz_2`, ветка `main`): `9a128d9` — i18n заголовка
  `editRecipeTitle` и удаление подсказки «English only».
- Backend (`mahallem_ist`, ветка `main`): `a3d32083` — детектор +
  пайплайн перевода в POST/PUT.

## Проблема

До этого `AddRecipePage` явно требовал заполнять форму на английском
(подсказка «Please write in English» под полем имени). Это:

* ломало UX для русско-/арабско-/курдскоязычных пользователей —
  они и так печатают на родном языке;
* делало невозможным поиск своего же рецепта в `RecipeListPage` на
  русском, потому что `searchByName` ищет по `i18n.<lang>->>'strMeal'`,
  а при `lang=ru` UI не находил английскую запись.

Кроме того, заголовок страницы редактирования был хардкодом
«Edit Recipe» — не переводился в slang.

## Решение

### 1. Flutter (UI)

* В `lib/i18n/<lang>.i18n.json` (все 10 локалей) добавлен ключ
  `editRecipeTitle`. Подсказка `addRecipeEnglishHint` удалена из всех
  файлов.
* `lib/i18n.dart` (фасад `S` поверх slang) получает геттер
  `editRecipeTitle`; геттер `addRecipeEnglishHint` удалён.
* `lib/ui/add_recipe_page.dart`:
  * `AppBar.title` теперь `Text(_isEdit ? s.editRecipeTitle : s.addRecipeTitle)`;
  * `Text(s.addRecipeEnglishHint, …)` + `SizedBox(height: AppSpacing.lg)`
    из шапки формы убраны — `ListView` начинается прямо с поля имени.

### 2. Backend (`local_user_portal`)

#### Новый модуль `utils/detect-language.js`

Чистая синхронная эвристика без сетевых зависимостей. Сканирует
первые 1000 символов и возвращает один из поддерживаемых
`SUPPORTED_LANGS`:

| Условие                                                 | Результат |
|---------------------------------------------------------|-----------|
| Кириллический блок (`U+0400–U+04FF`)                    | `ru`      |
| Арабская графика + курдская специфика (`ڕ ڵ ێ ۆ ھ`)     | `ku`      |
| Арабская графика + персидская специфика (`پ چ ژ گ ی ک`) | `fa`      |
| Арабская графика без указанных букв                     | `ar`      |
| Латинница / неизвестно                                  | `en`      |

Эвристики достаточно для коротких названий рецептов (1–3 слова) —
дописывать stop-word-детектор для de/fr/es/it/tr пока шумно;
если когда-либо понадобится, клиент сможет передать
`sourceLang` явно в payload.

#### Изменения в `routes/recipes.js`

POST `/recipes` и PUT `/recipes/:id`:

```js
const detected = detectLanguage(`${meal.strMeal} ${meal.strInstructions}`);
let extraI18n = null;
if (detected !== SOURCE_LANG) {
  try {
    const englishMeal = await translateRecipe(meal, detected, SOURCE_LANG);
    if (englishMeal && englishMeal.strMeal) {
      extraI18n = { [detected]: meal };
      meal = { ...englishMeal, strMealThumb: meal.strMealThumb };
    }
  } catch (txErr) {
    console.warn(`POST /recipes translate ${detected}→en failed: ${txErr.message}`);
  }
}
const { id, meal: stored } = await repo.createUserMeal(meal, { extraI18n });
```

* Английский перевод становится каноническим `i18n.en` — на нём
  работает остальной cascade (`_ensureLang` тянет ru/de/fr/… по
  требованию через тот же `translateRecipe`).
* Оригинал на исходном языке сохраняется в `i18n[detected]` —
  чтобы `searchByName` (`SELECT 1 FROM jsonb_object_keys(i18n) k
  WHERE LOWER(i18n->k->>'strMeal') LIKE …`) сразу же находил
  рецепт по запросу в родном скрипте, не дожидаясь read-time
  перевода.
* Падение перевода не валит запрос: `extraI18n` остаётся `null`,
  draft пишется как есть, а перевод выполнится лениво при первом
  чтении.

`createUserMeal` и `updateUserMeal` получили опциональный
параметр `{ extraI18n }`, который мерджит дополнительные локали
в jsonb-объект `i18n`:

```js
const i18nObj = { [SOURCE_LANG]: draft };
if (extraI18n && typeof extraI18n === 'object') {
  for (const [lang, payload] of Object.entries(extraI18n)) {
    if (lang === SOURCE_LANG) continue;
    const localized = canonicalize({
      ...payload,
      idMeal: String(id),
      strMealThumb: draft.strMealThumb,
    });
    if (localized && localized.strMeal) i18nObj[lang] = localized;
  }
}
```

`strMealThumb` форсится из английского draft, чтобы клиент,
который шлёт `pending://upload` в multipart-режиме, не получил
расхождение URL между локалями после `updateUserMealThumb`.

### 3. Автокомплит

Изменений в `searchByName` не потребовалось: запрос уже сканирует
все ключи `i18n` через `jsonb_object_keys`, поэтому сразу после
вставки и `i18n.en`, и `i18n[sourceLang]` индексируются — рецепт
находится и по «Plov», и по «Плов».

## Smoke-тест

```text
POST /recipes  {strMeal:"Плов", strInstructions:"Обжарить мясо…"}
→ 201 {id:1000005, meal:{strMeal:"PILAF", strInstructions:"Fry meat…"}}

SELECT i18n->'en'->>'strMeal', i18n->'ru'->>'strMeal'
  FROM recipes WHERE id = 1000005;
   en   |  ru
 ------+------
  PILAF | Плов

GET /recipes/search?q=плов&lang=ru
→ ["53083","53263","1000005"]

GET /recipes/search?q=pilaf&lang=en
→ user-meal 1000005 присутствует
```

## Совместимость

* Старые рецепты, у которых только `i18n.en`, продолжают работать
  как раньше: detectLanguage над английским payload-ом возвращает
  `en`, ветка перевода пропускается.
* Документы [add-recipe-feature.md](add-recipe-feature.md) и
  [owner-edit-delete.md](owner-edit-delete.md) теперь не отражают
  «English-only» ограничение — формально оно снято этим релизом.
