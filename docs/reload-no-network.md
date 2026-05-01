# Reload always shows «Нет сети» (offline) on non-English UIs

**Date:** 2026-05-01
**Status:** Diagnosed and fixed.

## Симптом

Пользователь жмёт кнопку reload в шапке `RecipeListPage` (RU/AR/FA/...
локаль), спиннер крутится \~60 c, после чего поверх старой ленты
всплывает snackbar `offlineReloadUnavailable` («Нет сети. Показываем
прежние рецепты.»). На EN reload работает мгновенно.

## Воспроизведение

```
ssh prod
time curl -sG http://localhost:4000/recipes/page \
  --data-urlencode lang=ru --data-urlencode limit=50 \
  -o /dev/null -w 'HTTP %{http_code} %{time_total}s\n'
# => HTTP 504 30.018s

time curl -sG http://localhost:4000/recipes/page \
  --data-urlencode lang=en --data-urlencode limit=50 \
  -o /dev/null -w 'HTTP %{http_code} %{time_total}s\n'
# => HTTP 200 0.031s

time curl -sG http://localhost:4000/recipes/filter \
  --data-urlencode c=Beef --data-urlencode lang=ru --data-urlencode full=1 \
  -o /dev/null -w 'HTTP %{http_code} %{time_total}s\n'
# => HTTP 504 30.013s
```

`docker logs mahallem-user-portal` в этот момент:

```
⚠️ Gemini API 503, retrying in 1000ms (attempt 1/2)
⚠️ Gemini API timeout, retrying (attempt 1/2)
⚠️ translateBest [en→ru] tiers exhausted (no cache write): "1"
⚠️ Slow translation en->ru: 3304ms for "3..."
```

## Корневая причина

Деградация Gemini (квоты/503) роняет MyMemory/LibreTranslate fallback на
коротких токенах («1», «3», «4» из ингредиентов). Каждое проблемное поле
ждёт полный retry-цикл, а серверный код считал результат «доехал — пишем
в кэш, иначе ждём». Дальше эффект каскадирует:

* `routes/recipes.js → RecipeRepository.page(lang)` гнал
  `rows.map(r => _ensureLang(r, lang))` **последовательно** (`for ... of`)
  — 50 рецептов × «слепой» перевод = быстро упирается в nginx 30s
  proxy_read_timeout → клиент видит `504`.
* `_ensureLang` ждал `this.translate(...)` без своего таймаута: если
  Gemini завис, корутина зависала вместе с ним.
* Фронтовый reload в [`recipe_list_loader.dart:175`](../recipe_list/lib/ui/recipe_list_loader.dart#L175) выставлял
  `forceReseed: true`, что в `_runLoad` намеренно **минует** и cache-hit,
  и `/recipes/page`, и валится в `_seedFromCategories` — 14 серийных
  `/recipes/filter?c=…&lang=ru&full=1`, каждый capped 12 c. С деградацией
  бэка это 14 × 12 c → один общий `Duration(seconds: 60)` reload-budget
  истекает → `catchError` → `_showOfflineReloadSnack()` лжёт «Нет сети».

То есть это **не** offline и **не** падение Wi-Fi. Это честная
деградация серверного перевода + неудачная стратегия reload-кнопки на
клиенте + недоинформативное сообщение.

## Фикс

### Backend (`routes/recipes.js`)

1. `_ensureLang` теперь оборачивает `this.translate(...)` в
   `Promise.race` с бюджетом `RECIPES_TRANSLATE_BUDGET_MS` (по умолчанию
   8 c, env-overrideable). По таймауту — возвращаем английский payload
   как fallback **без записи** в БД (как и для echo-translation): кэш
   не отравляем, повторный запрос снова попробует Gemini.
2. `RecipeRepository.page(lang)` параллелит per-row `_ensureLang` через
   `Promise.all` — суммарное время = max(per-row), а не sum. Для уже
   переведённых строк это nop; для непереведённых (cold язык) серверный
   ответ = budget × ровно один (8 c), а не × 50.

После фикса `/recipes/page?lang=ru&limit=50` отдаёт **HTTP 200** за
~1 c (cache hit) или ~8 c (cold-lang при деградации Gemini), уже с
английским fallback’ом для пустых полей. nginx 504 уходит.

### Client (`recipe_list/lib/ui/recipe_list_loader.dart`)

1. `_onReloadRequested` сначала пробует `RecipeApi.fetchPage(lang,
   limit=seedTarget)` (тот же путь, что `useBulkPage` cold-start). При
   успехе — локально `shuffle()` для свежего вида, persist в SQLite,
   `_LoadResult`. `_seedFromCategories` остаётся как fallback на случай
   полного отказа `/recipes/page`.
2. Снэкбар реагирует на тип ошибки. Добавлен ключ
   `a11y.reloadServerBusy` («Сервер занят. Показываем прежние рецепты.»).
   Классификация:
     * `DioException` `connectionError / connectionTimeout / sendTimeout`
       или отсутствие соединения → `offlineReloadUnavailable`.
     * `TimeoutException`, `receiveTimeout`, 5xx, любой прочий → новый
       `reloadServerBusy`.

## Проверка после деплоя

```
curl -sG http://72.61.181.62/api/recipes/page \
  --data-urlencode lang=ru --data-urlencode limit=50 \
  -o /dev/null -w 'HTTP %{http_code} %{time_total}s\n'
# должно быть 200 в пределах ~8 c
```

В приложении на RU UI: жмём reload → лента перешафливается за 1–2 c,
никаких snackbar-ов. При искусственной деградации сети — корректный
текст «Нет сети.». При остановленном бэкенде — «Сервер занят.».

## Связанные документы

* [`docs/translation-pipeline.md`](translation-pipeline.md) — общий
  каскад перевода и quality gate.
* [`docs/reload-hang-after-favorites.md`](reload-hang-after-favorites.md)
  — предыдущая итерация reload-фикса (60 s budget, `whenComplete`).
