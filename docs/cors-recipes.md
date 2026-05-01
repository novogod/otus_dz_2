# CORS for `/recipes/*` (Pattern A: public reads, no cookies)

**Date:** 2026-05-01
**Status:** Implemented in `routes/recipes.js` (mahallem-user-portal). Verified on prod: `Access-Control-Allow-Origin: *` on both OPTIONS preflight and GET responses for `/recipes/*`.

## Зачем

Flutter web (`flutter run -d chrome`) и любой будущий PWA-фронтенд
крутятся на чужом origin (`http://localhost:<port>` для дев, или
`https://app.example` для прода). Браузер блокирует чтение ответов
из `https://mahallem.ist/recipes/*`, потому что бэкенд не отдаёт
`Access-Control-Allow-Origin`. Native-клиенты (iOS/Android/desktop
Flutter, curl, server-to-server) на CORS не смотрят и работают
как и раньше.

## Что такое CORS

CORS — браузерное правило: JS, загруженный с origin A, не может
прочитать ответ с origin B, если B явно не разрешит это
заголовками `Access-Control-Allow-*`. CORS **не** про
аутентификацию и не про публичность API. API по-прежнему
доступен любому curl/Postman/мобильному приложению; CORS только
гейтит чтение ответа JS-кодом в чужой вкладке.

См. также:

* MDN — <https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS>
* Fetch Standard — <https://fetch.spec.whatwg.org/#http-cors-protocol>

## Выбранный паттерн: A — public reads, no cookies

Backend (`local_user_portal/server.js` или per-route в
`routes/recipes.js`):

```js
import cors from 'cors';

app.use('/recipes', cors({
  origin: '*',                                  // любой origin
  credentials: false,                           // cookies не пропускаем
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  maxAge: 86400,                                // кэш preflight 24 ч
}));
```

`credentials: false` принципиально:

* Спецификация запрещает `Access-Control-Allow-Origin: *` вместе с
  `Access-Control-Allow-Credentials: true` — браузер обрубит запрос.
* Это же отрезает "confused deputy"-вектор: даже если пользователь
  залогинен в `mahallem.ist` и открыл `evil.com`, JS на `evil.com`
  не сможет дёрнуть DELETE/PUT с его сессионной cookie. Пишущие
  ручки требуют `Authorization: Bearer <token>`, а токен evil.com
  взять неоткуда.

## Что меняется по сравнению с текущим состоянием

| Caller | До | После |
|---|---|---|
| Native-клиенты (iOS/Android/desktop, curl, скрипты) | Работает | Работает (без изменений) |
| Flutter web в Chrome dev | Блок CORS | Работает |
| `<script>` на `evil.com`, читает публичные ручки | Блок CORS | Может прочитать те же данные, что и `curl` — это уже было общедоступно |
| `<script>` на `evil.com`, делает DELETE с cookie пользователя | Блок CORS | Блок: cookies не пропускаются (`credentials:false`), Bearer-токена нет |

Резюме: безопасность не падает — все три слоя защиты
(`limiter` → `authMiddleware` → owner-checks внутри хэндлеров)
остаются на месте. CORS-настройка влияет только на то, что
разрешено читать из браузера; авторизация не зависит от CORS.

## Что НЕ делаем

* `Access-Control-Allow-Origin: <reflect Origin>` + credentials —
  классическая CSRF-дыра, нам не нужна.
* `cors()` без аргументов глобально — лишние ручки (например,
  job-management, wallet) останутся без явного контракта.
  Применяем только к `/recipes`.

## Если в будущем понадобятся cookies cross-origin

Перейти на паттерн B (allow-list + credentials + CSRF-токены).
Шаблон лежит здесь же ниже, в комментариях кода.

## Проверка после деплоя

```bash
curl -sD- -o /dev/null -X OPTIONS \
  -H 'Origin: http://localhost:8080' \
  -H 'Access-Control-Request-Method: GET' \
  -H 'Access-Control-Request-Headers: content-type' \
  https://mahallem.ist/recipes/page | grep -i access-control
```

Должны прийти:

```
access-control-allow-origin: *
access-control-allow-methods: GET,POST,PUT,DELETE
access-control-allow-headers: Content-Type,Authorization
access-control-max-age: 86400
```

После этого `flutter run -d chrome` начинает получать ленту
`/recipes/page` без ошибок в DevTools. Остальные web-блокеры
(sqflite, webview_flutter, dart:io.File при загрузке фото) — это
отдельные задачи, см. вершину этого документа и
`docs/reload-no-network.md`.
