# Translation priority: RU first, others best-effort

**Date:** 2026-05-01

## Правило

* **EN** — source language, без перевода.
* **RU** — приоритетный язык. Получает полный
  `RECIPES_TRANSLATE_BUDGET_MS` (8 c) внутри `_ensureLang`.
* **ES/FR/DE/IT/TR/AR/FA/KU** — best-effort. Получают
  `RECIPES_TRANSLATE_BUDGET_LOW_MS` (3 c). Если Gemini/LT
  деградирует — быстро отдаём английский fallback и не сжигаем
  квоту, оставляя её для RU.

Список приоритетных языков настраивается env-переменной
`RECIPES_PRIORITY_LANGS` (по умолчанию `"ru"`). Можно расширить,
например, `RECIPES_PRIORITY_LANGS=ru,tr` для региональной
конфигурации.

## Где применяется

`routes/recipes.js → RecipeRepository._ensureLang`. Это узкое
горло, через которое проходят все ленивые переводы на чтение
(`/recipes/lookup/:id`, `/recipes/page`, `/recipes/filter?full=1`).
EN-короткий путь не меняется.

```js
const PRIORITY_LANGS = (process.env.RECIPES_PRIORITY_LANGS || "ru")
  .split(",").map((s) => s.trim()).filter(Boolean);
const FULL_BUDGET_MS = Number(process.env.RECIPES_TRANSLATE_BUDGET_MS) || 8000;
const LOW_BUDGET_MS  = Number(process.env.RECIPES_TRANSLATE_BUDGET_LOW_MS) || 3000;
const TRANSLATE_BUDGET_MS = PRIORITY_LANGS.includes(lang)
  ? FULL_BUDGET_MS
  : LOW_BUDGET_MS;
```

## Почему это правильно

* **Не блокирует ленту.** Низкий бюджет для не-приоритетных
  языков означает, что `/recipes/page?lang=fa` почти всегда
  отвечает быстро английским payload-ом, пользователь видит
  карточки, а перевод подтягивается на следующий заход
  (translation_cache отделён, повторный вызов Gemini внутри
  `translateBest` уже хитнет cache при удаче).
* **Сохраняет квоту Gemini для RU.** Даже при штормах
  деградации (наблюдалось 503 + timeout, см.
  [`reload-no-network.md`](reload-no-network.md)) RU-перевод
  получает полные 8 c вместо борьбы за квоту c курдским и
  персидским.
* **Кэш не отравлен.** Echo-translation gate
  (`_isEchoTranslation`) и timeout-fallback оба возвращают
  английский payload **без записи** в БД. Следующая попытка
  снова попробует Gemini.

## Frontend следствие

Цикл UI-языков теперь идёт `EN → RU → ES → FR → DE → IT → TR →
AR → FA → KU → EN` (см.
[`recipe_list/lib/i18n.dart`](../recipe_list/lib/i18n.dart)).
Самый частый ручной свитч `EN ↔ RU` стоит один тап. Ленту с
этими двумя языками сервер всегда отдаёт быстро; экзотические
языки тоже работают, просто без гарантий «полный перевод за
8 c», что соответствует их доле трафика.

## Тюнинг

Поднять low-budget до 4–5 c можно env-переменной без релиза:

```bash
RECIPES_TRANSLATE_BUDGET_LOW_MS=5000 docker compose up -d user-portal
```

Если в какой-то регион добавляется язык-приоритет (например,
турецкий), достаточно:

```bash
RECIPES_PRIORITY_LANGS=ru,tr docker compose up -d user-portal
```

## Проверка

После деплоя:

```bash
ssh prod 'time curl -sG http://localhost:4000/recipes/page \
  --data-urlencode lang=ru --data-urlencode limit=50 -o /dev/null \
  -w "ru HTTP %{http_code} %{time_total}s\n"'
ssh prod 'time curl -sG http://localhost:4000/recipes/page \
  --data-urlencode lang=fa --data-urlencode limit=50 -o /dev/null \
  -w "fa HTTP %{http_code} %{time_total}s\n"'
```

Ожидаемое: `ru` — до 8 c (cold), мгновенно (cache);
`fa` — до 3 c (cold) или мгновенно (cache).
