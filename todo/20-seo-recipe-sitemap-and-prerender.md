# 20 — Per-recipe SEO: dynamic sitemap + multi-locale pre-render

> **Статус:** 🟡 не начато.
> **См.:** [docs/seo-recipe-sitemap-and-prerender.md](../docs/seo-recipe-sitemap-and-prerender.md), [docs/seo.md](../docs/seo.md).
> **Приоритет:** P2 (рост органического трафика, корректные
> share-card'ы для каждого рецепта).
> **Scope:** `[server]` (новый endpoint, cron-скрипт,
> pre-render container, host nginx), `[client]` (router с
> locale-prefix), `[ops]` (cron, мониторинг Search Console).
>
> Цель: сегодня sitemap содержит 2 URL и Search Console
> показывает «Discovered: 2». Нужно вывести каждый рецепт во
> всех 10 локалях (`en/ru/de/es/fr/it/tr/ar/fa/ku`) как
> индексируемую страницу с per-recipe Open Graph и JSON-LD
> `Recipe`-схемой → rich-results в Google, real preview cards
> в FB/Telegram/WhatsApp/X, Pinterest Rich Pins.

Реализация делится на **6 чанков**. Каждый чанк — отдельный
коммит, тесты проходят перед переходом к следующему. Чанки A–C
формируют Phase 1 (динамический sitemap, минимально-инвазивно).
Чанки D–F — Phase 2 (pre-render и locale-prefix роутинг).

---

## Чанк A — Backend: `GET /recipes/sitemap`

`[server]`

Новый эндпойнт в `mahallem-user-portal`, отдаёт slim-проекцию
для генератора sitemap. Никакой авторизации, лёгкий JSON.

### Контракт

```
GET /recipes/sitemap
Accept: application/json

→ 200
[
  { "id": 52772, "updatedAt": "2026-05-04T12:34:56Z" },
  { "id": 52773, "updatedAt": "2026-05-04T12:35:01Z" },
  …
]
```

Ограничения:

* Только `id` и `updatedAt`. Никакого title/text/image —
  payload должен быть < 1 MB при текущем размере БД.
* Сортировка по `id ASC` (детерминированно для diff'ов
  sitemap'а).
* Возвращает только публичные / не-deleted рецепты (то же
  условие, что в `/recipes/page`).

### Тесты

* **Unit (server)** — handler возвращает массив из ≥ 2 объектов,
  каждый имеет `id:int` и `updatedAt:string` в ISO-8601.
* **Unit (server)** — soft-deleted рецепт **не** появляется в
  ответе.
* **Integration (server)** — `curl -fsS http://172.25.0.41:4000/recipes/sitemap | jq '. | length'`
  совпадает с `SELECT COUNT(*) FROM recipes WHERE deleted_at IS NULL`.
* **Smoke (prod)** — endpoint отвечает < 200 ms на текущем
  размере БД.

### Definition of done

* Endpoint развёрнут на проде.
* Open API / handwritten доке добавлена строка про
  `/recipes/sitemap` (см. `docs/recipe-ingester-and-size-cap.md`).

---

## Чанк B — Cron: `/root/build_recipe_sitemap.sh` + расписание

`[ops]`

Bash-скрипт по дизайну из
[docs/seo-recipe-sitemap-and-prerender.md](../docs/seo-recipe-sitemap-and-prerender.md)
§3.3, расписание в `/etc/cron.d/recipes-sitemap`.

Скрипт:

1. `curl http://172.25.0.41:4000/recipes/sitemap` → JSON.
2. Генерит `sitemap.xml` с одним `<url>` на рецепт + 10
   `<xhtml:link rel="alternate">` + `x-default`.
3. **Используем существующие пути `/recipes/details/<id>` для
   `<loc>` пока чанки D–F не выкатят locale-prefix routing.**
   Hreflang-блоки до Phase 2 — закомментированы / опущены,
   иначе Search Console будет жаловаться на «alternate page
   with proper canonical tag».
4. `docker cp` атомарно подменяет файл внутри
   `recipe_list_web:/usr/share/nginx/html/sitemap.xml`.
5. Лог в `/var/log/recipes_sitemap.log` с `[ISO-timestamp]`.

Cron: `0 6 * * * root /root/build_recipe_sitemap.sh ...` (через
30 минут после backfill в 05:30, см.
`/etc/cron.d/recipes-backfill`).

### Тесты

* **Smoke (server)** — `bash -n /root/build_recipe_sitemap.sh`
  (синтаксис).
* **Manual (server)** — первый ручной прогон:
  `/root/build_recipe_sitemap.sh && curl -sI https://recipies.mahallem.ist/sitemap.xml | head -4`
  возвращает `HTTP/2 200` + `text/xml`.
* **Manual (server)** — `curl -s https://recipies.mahallem.ist/sitemap.xml | xmllint --noout -`
  не показывает ошибок XML.
* **Manual (server)** — `curl -s https://recipies.mahallem.ist/sitemap.xml | grep -c '<url>'`
  ≥ количество рецептов в БД.
* **Cron** — после ручной симуляции `run-parts --test
  /etc/cron.d/recipes-sitemap` или просто проверка через 24 ч,
  что лог содержит свежую запись.

### Definition of done

* Скрипт лежит на проде в `/root/build_recipe_sitemap.sh`,
  права `0750 root:root`.
* Cron установлен.
* Файл sitemap.xml на проде > 2 KB и содержит ≥ N URL'ов.
* В git добавлен sample-копия скрипта в `ops/build_recipe_sitemap.sh`
  как backup (фактический файл — на сервере).

---

## Чанк C — Re-submission в Search Console и валидация

`[ops]`

Не код — операционный шаг.

1. В Google Search Console (Domain property `mahallem.ist`) →
   Sitemaps → строка `https://recipies.mahallem.ist/sitemap.xml`
   → дождаться повторного fetch (или удалить и пере-добавить).
2. То же самое в Bing Webmaster и Yandex Webmaster.
3. Validate в https://search.google.com/test/rich-results
   на главной — должно отображать WebSite + Organization JSON-LD.
4. Опционально — добавить «ping» вызовы в конец cron'а
   из чанка B (см.
   [docs/seo-recipe-sitemap-and-prerender.md](../docs/seo-recipe-sitemap-and-prerender.md)
   §3.6).

### Тесты

* **Manual** — Search Console через 24–72 ч показывает
  «Discovered pages» ≈ количество рецептов (а не 2).
* **Manual** — `Coverage` отчёт: рецепты в статусе
  `Discovered – currently not indexed` (это нормально до
  Phase 2; индексация — задача чанков D–F).
* **Manual** — Bing / Yandex консоли тоже подхватили sitemap.

### Definition of done

* Sitemap submitted и read во всех трёх поисковиках.
* Discovered ≥ 80% рецептов в течение 7 дней.
* В `docs/seo.md` обновлена таблица «What's implemented» с
  числом URL'ов в текущем sitemap'е.

---

## Чанк D — Client: locale-prefix routing в `go_router`

`[client]`

Подготовка под Phase 2: `go_router` начинает понимать пути вида
`/<lang>/recipes/<id>`, старые пути `/recipes/details/:id`
становятся 301-редиректами на текущую locale пользователя.
**Без** этого шага hreflang-аннотации в sitemap бесполезны —
все 10 локалей резолвятся в один и тот же URL.

Файлы:

* [recipe_list/lib/router/routes.dart](../recipe_list/lib/router/routes.dart)
  — добавить:
  * `static const String localePathPattern = r'(en|ru|de|es|fr|it|tr|ar|fa|ku)';`
  * `static String localizedRecipe(String lang, int id) => '/$lang/recipes/$id';`
* [recipe_list/lib/router/app_router.dart](../recipe_list/lib/router/app_router.dart)
  — top-level `GoRoute` с `path: '/:lang(...)/recipes/:id'`,
  редирект со старого `/recipes/details/:id`.
* На locale-switch в UI вызывать `context.go(localizedRecipe(...))`
  чтобы URL и shared deep-link всегда были корректны.
* `<base href>` или `<html lang>` в
  [recipe_list/web/index.html](../recipe_list/web/index.html)
  динамически выставляется JS-хелпером по `location.pathname`.

### Тесты

* **Unit (client)** — `routes_test.dart`:
  * `Routes.localizedRecipe('en', 52772) == '/en/recipes/52772'`
  * `Routes.localizedRecipe('ar', 1) == '/ar/recipes/1'`
* **Widget (client)** — открытие `/recipes/details/52772` через
  `GoRouter` приводит к редиректу на `/<currentLocale>/recipes/52772`.
* **Widget (client)** — переключение локали из в-app picker
  меняет URL на `/<newLocale>/recipes/52772` (через
  `context.go`).
* **Widget (client)** — расширить
  [recipe_list/test/router_smoke_test.dart](../recipe_list/test/router_smoke_test.dart)
  и `router_branches_test.dart` новыми кейсами для locale-prefix.
* **Manual (web)** — открыть в Chrome DevTools
  `https://recipies.mahallem.ist/ru/recipes/52772` после
  деплоя — отрисовывается русский интерфейс, URL не
  переписывается обратно.

### Definition of done

* Все существующие unit/widget тесты зелёные.
* Новые тесты добавлены в `recipe_list/test/router_*`.
* Старый share-link `/recipes/details/<id>` продолжает
  работать (через redirect).
* Sitemap.xml пока ссылается на старые пути (чанк B), но клиент
  уже готов к переключению — переключение сделает чанк F.

---

## Чанк E — Pre-render container + nginx UA split

`[server]` `[ops]`

Stack: новый Docker-контейнер `recipe_list_prerender`
(Node + Puppeteer / Playwright). Дизайн —
[docs/seo-recipe-sitemap-and-prerender.md](../docs/seo-recipe-sitemap-and-prerender.md)
§§4.3–4.4.

Файлы:

* `prerender/Dockerfile` — Node 20 + Chromium.
* `prerender/server.ts` — HTTP сервер на порту 8089,
  файловый кэш, ключ `${locale}:${id}:${updatedAt}`.
* `docker-compose.web.yml` — добавить service
  `recipe_list_prerender`, порт 8089, volume для кэша.
* `/etc/nginx/sites-available/recipies.mahallem.ist` на хосте
  — добавить `map $http_user_agent $is_bot { ... }` и
  условный proxy_pass на `127.0.0.1:8089` для path-pattern
  `^/(en|ru|...)/recipes/[0-9]+/?$`.

Скрипт-flag в SPA: добавить распознавание `?ssr=1` в
[recipe_list/web/index.html](../recipe_list/web/index.html)
(или в `main.dart`) — выставлять `<meta name="ssr-ready">`
после загрузки данных рецепта, чтобы pre-renderer знал,
когда снимать снимок.

### Тесты

* **Unit (prerender)** — кэш-ключ корректно учитывает
  `updatedAt` (изменение `updatedAt` → новый файл).
* **Unit (prerender)** — `<title>`, `<link rel="canonical">`,
  `<script type="application/ld+json">` присутствуют в
  результате; `<script src="flutter_bootstrap.js">` удалён.
* **Integration (prerender)** — стартует контейнер, GET на
  `http://localhost:8089/en/recipes/52772` возвращает 200 +
  HTML с правильным локализованным `<title>`.
* **Integration (nginx)** — после деплоя:
  * `curl -sA "Googlebot/2.1" https://recipies.mahallem.ist/en/recipes/52772 | grep -c '<title>Otus Food'`
    ≥ 1 (имя рецепта в title).
  * `curl -sA "Mozilla/5.0" https://recipies.mahallem.ist/en/recipes/52772 | grep -c flutter_bootstrap.js`
    == 1 (юзер всё ещё получает SPA-shell).
  * `curl -sA "facebookexternalhit/1.1" https://recipies.mahallem.ist/en/recipes/52772 | grep og:image`
    показывает per-recipe `og:image`.
* **Validation (external)** — открыть
  https://search.google.com/test/rich-results?url=...
  на конкретной recipe-странице: должна валидироваться как
  `Recipe` (rich result eligible).

### Definition of done

* Контейнер запущен и в `docker compose ps` показывает Up.
* Nginx host config обновлён, `nginx -t` ok, перезагружен
  `systemctl reload nginx`.
* Все integration-тесты выше проходят на проде.
* В `docs/seo-recipe-sitemap-and-prerender.md` обновлён
  раздел «Phase 2» с реальными путями к файлам и портами.

---

## Чанк F — Sitemap с locale-prefix + hreflang + JSON-LD `Recipe`

`[server]` `[ops]`

После того, как клиент (D) и pre-render (E) обрабатывают
locale-prefixed URL'ы, переписываем генератор sitemap'а на
полную форму:

* `<loc>` ссылается на `/en/recipes/<id>`.
* 10 × `<xhtml:link rel="alternate" hreflang="<lang>" href="/<lang>/recipes/<id>"/>` +
  `x-default` → `/en/recipes/<id>`.
* `<lastmod>` = `updatedAt` рецепта.

Pre-renderer (чанк E) дополнительно эмитит JSON-LD `Recipe`
schema с локализованными `name`, `description`,
`recipeIngredient`, `recipeInstructions`, `inLanguage`. Список
обязательных полей — `docs/seo-recipe-sitemap-and-prerender.md`
§4.5.

### Тесты

* **Manual (sitemap)** —
  `curl -s https://recipies.mahallem.ist/sitemap.xml | xmllint --xpath 'count(//*[local-name()="link" and @hreflang])' -`
  ≥ `10 × N` (10 hreflang блоков на каждый из N рецептов).
* **Manual (sitemap)** —
  `xmllint --schema sitemap.xsd --noout sitemap.xml`
  не показывает ошибок (стандартная схема sitemaps.org).
* **Validation (Google)** — Search Console раздел
  «International Targeting» через ≤ 7 дней: нет ошибок
  «hreflang return tag missing» / «no return links».
* **Validation (rich-results)** — на 5 случайных рецептах в
  каждой локали (особенно `ar` и `fa` — RTL) рассыпание
  результатов нет.
* **Manual (FB)** — debugger показывает per-recipe preview
  card с `og:image` рецепта (а не дефолтным
  `og-image.jpg`).

### Definition of done

* Sitemap содержит N × 1 `<url>` блоков с 10 + 1 hreflang
  внутри каждого.
* Поисковики показывают «Indexed pages» ≥ 50% от N в течение
  30 дней (метрика для Search Console retrospective).
* `og:image` per-recipe виден в FB/Telegram/WhatsApp.
* JSON-LD `Recipe` валиден в rich-results test.

---

## Cross-cutting tests (после всех 6 чанков)

* **Regression (client)** — все существующие тесты в
  `recipe_list/test/` зелёные.
* **Regression (server)** — `npm test` в `mahallem-user-portal`
  зелёный.
* **Regression (web)** —
  https://pagespeed.web.dev/report?url=https%3A%2F%2Frecipies.mahallem.ist%2F
  Performance ≥ старого baseline ± 5 пунктов (pre-render
  не должен ухудшать время загрузки для людей).
* **Regression (PWA)** — `manifest.json`, install-flow,
  share-button продолжают работать (см.
  [docs/share-pwa-and-backfill.md](../docs/share-pwa-and-backfill.md)).
* **Translation gap** — для рецепта без перевода в локали `X`,
  pre-renderer чанка E возвращает английский контент с
  `<link rel="canonical" href="…/en/…">`. Подтвердить через
  ручной curl с UA Googlebot.

---

## Rollback plan

* Чанки A–C самодостаточны и легко откатываются: удалить
  cron, `git revert` коммита со скриптом, восстановить
  static `recipe_list/web/sitemap.xml` из git.
* Чанк D откатывается коммитным revert'ом — старые URL
  продолжают работать (никто не делал hard cut).
* Чанк E откатывается выключением `recipe_list_prerender`
  контейнера и удалением `map $http_user_agent` блока в
  host nginx; SPA снова обслуживает всех.
* Чанк F — `git revert` скрипта, перегенерация sitemap'а
  (B-форма) выполнится в следующий 06:00 UTC.

---

## Связанные документы

* [docs/seo-recipe-sitemap-and-prerender.md](../docs/seo-recipe-sitemap-and-prerender.md)
  — детали дизайна, обоснования, ссылки.
* [docs/seo.md](../docs/seo.md) — базовый SEO-stack.
* [docs/share-pwa-and-backfill.md](../docs/share-pwa-and-backfill.md)
  — share-кнопка, FB scraper.
* [docs/translation-pipeline.md](../docs/translation-pipeline.md)
  — перевод ↔ pre-render fallback на en.
