# Project Log

## Web auth follow-up — recovery «session expired» + залипший Login

**Date:** 2026-05-05

**Status:** ✅ Fixed

После релиза round-H пользователь сообщил две веб-проблемы:

1. **Recovery всегда отдаёт `sessionExpired`.** Бэкенд хранил
   email из шага `/forgot-password` в `req.session.resetPasswordEmail`.
   Браузер в cross-origin (`localhost:50968` → `mahallem.ist`)
   режет Set-Cookie сессии, поэтому к шагу `/reset-password`
   `req.session` пустой → 401. На iOS/Android Dio честно носит
   cookie, поэтому там работало.
2. **Login «зависает».** После клика «Log in» Chrome показывал
   prompt «Save password»; пользователь его закрывал — кнопка
   оставалась в busy-состоянии, форма не реагировала. В nginx
   логах сам POST `/users/login` приходил с 200 OK — то есть
   сервер логинил успешно, но клиент не выходил из `_authBusy`
   и не уводил роутер на `/recipes`.

**Root cause.**

* Recovery: cross-origin cookie policy браузера + клиентский
  fallback в `requestPasswordRecovery`, который при отсутствии
  Set-Cookie подставляет `sessionCookie = email`. На сервере он
  не помогал — endpoint email не читал.
* Login: post-auth шаги (`_refreshBiometricSavedStatus`,
  `S.of(context)`, `ScaffoldMessenger`) в web-сборке могли
  бросить исключение (например, sqflite-ffi-web write в
  IndexedDB после Save-password prompt), а `_authBusy = false`
  стоял ПОСЛЕ `await loginAsAdmin(...)` без try/finally — при
  любом throw он не сбрасывался.

**Fix.**

* **Сервер** (`local_user_portal/routes/auth.js`, контейнер
  `mahallem-user-portal`, в репо проекта не зеркалится): POST
  `/reset-password` теперь читает email из тела запроса, если
  `req.session.resetPasswordEmail` пуст. 4-значный код остаётся
  единственным фактором аутентификации (он уходит только на
  введённый email через `email-verification-api`), поэтому
  ослабления безопасности нет. Бэкап оригинала на хосте:
  `/tmp/auth.js.bak.<ts>`.
* **Клиент**
  ([`recipe_list/lib/ui/login_page.dart`](../recipe_list/lib/ui/login_page.dart))
  — `_submit()` обёрнут в `try/finally`: `_authBusy` гарантированно
  сбрасывается, ошибка `loginAsAdmin` показывается в snackbar
  вместе с текстом, `_refreshBiometricSavedStatus()` вынесен в
  отдельный try/catch, чтобы провал биометрии не блокировал
  навигацию на `/recipes`.

**Verification.**

* `POST /reset-password` из Flutter web — nginx access log
  `200 239`, server log `Password updated for user info@lagente.do`.
* Login — после hot-reload форма реагирует, snackbar теперь
  показывает реальную причину при ошибке.

**Files.**

* [`recipe_list/lib/ui/login_page.dart`](../recipe_list/lib/ui/login_page.dart)
  — `_submit()` try/finally + раскрытие ошибки в snackbar.
* Серверный патч `routes/auth.js` (вне репо) — задокументирован
  выше.

**Tests.** Регрессия только web-flow; unit-тесты не затронуты,
`flutter analyze` clean.

---

## Go-router follow-up I — grey-screen на не-EN локалях при тапе Profile

**Date:** 2026-05-04

**Status:** ✅ Fixed

После релиза round-H пользователь сообщил: на Novogod (iPhone,
release) тап по нижней кнопке Profile открывает серый экран на
русском (и на любом другом не-EN языке); на английском всё
работает — слайдается `LoginPage`.

**Root cause (гипотеза).** На голом `/profile` builder ветки
рендерил `Scaffold(body: SizedBox.shrink())` — пустой холст под
оверлейным `/profile/login` (с `parentNavigatorKey: rootNavigatorKey`).
В EN-сценарии `_profileRedirect` успевает увести роутер в
`/profile/login` до первого кадра, и поверх SizedBox-а ложится
`LoginPage`. На не-EN локалях (после `cycleAppLang`) приоритеты
кадров смещаются: `MaterialApp.router` пересобирается из-за смены
`title`/`locale`, redirect срабатывает с задержкой, overlay-роут
не успевает смонтироваться к первому кадру — пользователь видит
серый экран ветки. Воспроизвести стабильно через MCP/widget-tree
не удалось (DTD-сессия залочена под старый VS Code DAP-launcher).

**Fix.** Branch-root `/profile` теперь сам рендерит auth-aware
страницу: `_ProfileBranchRoot` подписан на
`adminLoggedInNotifier` / `currentRecipeAdminTokenNotifier` /
`currentUserLoginNotifier` и возвращает `AdminAfterLoginPage` для
авторизованных или `LoginPage` для гостей. Sub-routes
`/profile/login` и `/profile/admin` оставлены как slide-up
overlay-варианты для совместимости с прямыми ссылками — но даже
если они «не поедут», пользователь видит рабочий экран сразу.

**Files.**
* [`recipe_list/lib/router/app_router.dart`](../recipe_list/lib/router/app_router.dart)
  — `Routes.profile` builder теперь `_ProfileBranchRoot()`; сам
  класс добавлен ниже по файлу.

**Tests.** `flutter analyze` — clean. `flutter test` — 105 pass /
6 fail (baseline). `router_profile_branch_test.dart` — 4 pass.

## Go-router follow-up H — UX-регрессии после shell-рефакторинга

**Date:** 2026-05-04

**Status:** ✅ Fixed

После ручного прогона на iPhone (release) и Pixel 8 (debug) всплыли
пять багов в навигации/UX, связанных с тем, что после перехода на
`StatefulShellRoute.indexedStack` в дереве одновременно живут
несколько `Scaffold`-ов и `Navigator`-ов. Все пять починены одним
заходом.

### 1. Snackbar `favoritesRegistrationRequired` «висит вечно»

**Symptom.** Гость тапает Add-FAB / сердце / вкладку Favorites — на
4 с показывается snackbar «Registration required…», но фактически он
не дисмиссится никогда: остаётся поверх навбара даже после смены
вкладки.

**Root cause.** Авто-таймер у `ScaffoldMessenger`-а стартует только
в `_handleSnackBarStatusChanged` при `AnimationStatus.completed`
slide-in-анимации. До рефакторинга в дереве был один `Scaffold`
(`RecipeListPage`), который и хостил мессенджер; теперь
одновременно зарегистрированы 2–3 `Scaffold`-а (`AppShell` + текущая
ветка + при наличии `LoginPage` поверх root-Navigator-а). При смене
топ-приоритетного `Scaffold`-а мессенджер перетаскивает snackbar на
новый host и **сбрасывает** анимацию — `completed` так и не
наступает, таймер не запускается.

**Fix.** Вынесли единый helper
[`recipe_list/lib/ui/registration_required_snackbar.dart`](../recipe_list/lib/ui/registration_required_snackbar.dart),
который рядом с `messenger.showSnackBar(...)` ставит собственный
real-time `Timer(const Duration(seconds: 4), () => controller.close())`.
`ScaffoldFeatureController.close()` форсирует закрытие независимо
от состояния анимации. Таймер отменяется через
`controller.closed.whenComplete`, если snackbar закрылся «своим
ходом» (тап по action / другой `showSnackBar`). Все три call-site
(`AppShell._onTabTap`, `RecipeListPage._showFavoritesRegistrationRequired`,
`FavoritesPage._showFavoritesRegistrationRequired`) теперь
делегируют в этот helper.

### 2. Тап по Profile-иконке у гостя → пустой экран

**Symptom.** На холодном старте без сессии тап по вкладке
«Profile» ведёт на серый пустой экран вместо `LoginPage`.

**Root cause.** В `appRouter` builder заглушки `/profile` имел
defensive post-frame callback с `context.go(Routes.recipes)` —
он гонился с `_profileRedirect` (который корректно уводил на
`/profile/login`) и перетягивал приложение прочь от только что
показанного login-маршрута. Login живёт на root-Navigator-е через
`parentNavigatorKey`, поэтому branch-плейсхолдер `/profile`
рендерится одновременно с ним и его post-frame-bounce срабатывает
**после** редиректа.

**Fix.** Из builder-а `/profile`-маршрута убран post-frame bounce.
Builder теперь возвращает только нейтральный `Scaffold(body:
SizedBox.shrink())` под оверлейным login/admin. Вся auth-aware
логика осталась в `_profileRedirect`.

### 3. Вкладка «Fridge» показывала пустой экран

**Symptom.** Тап по «Fridge» открывает совершенно пустой `Scaffold`
(маленький `Center(child: Text(...))` без AppBar практически
невиден на устройстве).

**Fix.** `_ComingSoonPage` в
[`recipe_list/lib/router/app_router.dart`](../recipe_list/lib/router/app_router.dart)
теперь рендерит полноценный экран: `AppBar` с заголовком вкладки,
крупная иконка `Icons.construction` и локализованный
`s.tabComingSoon` ("This section is coming soon" /
"Этот раздел пока в разработке") по центру.

### 4. Кнопка «назад» в шапке Favorites не работала

**Symptom.** Тап по back-стрелке в `SearchAppBar` на вкладке
«Избранное» — ничего не происходит.

**Root cause.** `AppPageBar` по умолчанию делает
`Navigator.of(context).maybePop()`. `FavoritesPage` — корень
shell-ветки, в её branch-Navigator-е стек состоит из одной
страницы — pop-ать нечего, поэтому жест глотался без эффекта.

**Fix.** В
[`recipe_list/lib/ui/favorites_page.dart`](../recipe_list/lib/ui/favorites_page.dart)
`SearchAppBar` теперь получает явный
`onBack: () => context.go(Routes.recipes)` — кнопка «назад»
переключает пользователя на ленту рецептов.

### 5. Клавиатура не закрывалась по тапу вне поля поиска

**Symptom.** На любом экране с `TextField` (Favorites / Recipes /
Login) после фокуса в поле и тапа по фоновой области клавиатура
оставалась видимой.

**Fix.** В `MaterialApp.router.builder`-е (см.
[`recipe_list/lib/main.dart`](../recipe_list/lib/main.dart)) выдача
роутера теперь обёрнута в `GestureDetector` с
`HitTestBehavior.translucent`, который по тапу делает
`FocusManager.instance.primaryFocus?.unfocus()`. `translucent`
гарантирует, что тапы по кнопкам/спискам продолжают доезжать до
своих хитов.

### Затронутые файлы

- `recipe_list/lib/main.dart` — global tap-outside-to-dismiss-keyboard.
- `recipe_list/lib/router/app_router.dart` — снят bounce из builder-а
  `/profile`; `_ComingSoonPage` переделан в полноценный экран.
- `recipe_list/lib/ui/registration_required_snackbar.dart` — новый
  файл, единый helper с real-time страховочным `Timer`-ом.
- `recipe_list/lib/ui/app_shell.dart` — использует helper.
- `recipe_list/lib/ui/recipe_list_page.dart` — использует helper.
- `recipe_list/lib/ui/favorites_page.dart` — использует helper +
  явный `onBack` у `SearchAppBar`.

### Verification

- `flutter analyze` — clean.
- `flutter test` — 105 pass / 6 baseline fail (без изменений
  относительно follow-up G).
- Live-проверка на Pixel 8 (debug) и iPhone (release) подтвердила
  фиксы по всем пяти симптомам.

---

## Go-router follow-up G — три регрессии после `3dd4308`

**Date:** 2026-05-04

**Status:** ✅ Fixed (commit `3a07ab5`)

После ручного прогона на Android-эмуляторе всплыли три бага и одно
свежее исключение. Все четыре прокинуты вместе.

### 1. `setState() called during build` при тапе на «Reload»

**Symptom.** Кнопка «Reload» на splash валит ассерт:
`setState() or markNeedsBuild() called during build` —
`ValueListenableBuilder<AppServices?>` пытается ребилдиться, пока
родительский `FutureBuilder<_LoadResult>` ещё в фазе билда.

**Root cause.**
[`recipe_list/lib/ui/recipe_list_loader.dart`](recipe_list_loader.dart)
`_RecipeListLoaderState._publishServices(...)` писал прямо в
`appServicesNotifier.value` синхронно из `FutureBuilder.builder`.
Подписчики (`FavoritesBranchRoot`, page-builders для details/add)
получали `notifyListeners` посреди билда — Flutter ругается.

**Fix.** Откладываем мутацию через
`WidgetsBinding.instance.addPostFrameCallback`, на конце кадра
делаем `mounted`-проверку и сравниваем `(api, repository)` с
текущим значением — чтобы не публиковать одно и то же дважды
(reload вызывается часто).

### 2. Кнопка «назад» с экрана логина → серый экран

**Symptom.** На `LoginPage` тап по back-FAB закрывает экран, и
вместо `RecipeListPage` появляется пустой серый экран — навбар
есть, контента нет.

**Root cause.** `LoginPage` живёт на root-навигаторе через
`parentNavigatorKey: rootNavigatorKey` (см. follow-up F). Старый
`Navigator.of(context).pop()` снимает оверлей логина, и go_router
оказывается на `/profile`, у которого `builder` —
`Scaffold(body: SizedBox.shrink())` (заглушка для родительского
маршрута, рендер которого никогда не должен случиться). Отсюда
серый экран. `_profileRedirect` срабатывает только при
`router.refresh()`, а не при pop-е дочернего маршрута root-Navigator-а.

**Fix.** В
[`recipe_list/lib/ui/login_page.dart`](login_page.dart) back-FAB
теперь делает:

```dart
if (context.canPop()) {
  context.pop();
} else {
  context.go(Routes.recipes);
}
```

`signup_page.dart`/`password_recovery_page.dart` не трогаем — они
push-ятся поверх LoginPage (на тот же root-Navigator), их `pop`
возвращает на LoginPage, не на `/profile`.

### 3. Тап по «Избранному» гостем — нет snackbar-а

**Symptom.** Гость (не залогинен) тапает таб «Избранное» —
открывается пустой `FavoritesPage` без какой-либо реакции. По
[docs/login-auth.md](login-auth.md) §5 здесь должен показываться
snackbar `favoritesRegistrationRequired` с экшеном «Sign Up».

**Root cause.** Старая проверка жила в
`RecipeListPage._onNavTap` (commit `8fc7b21`). После того как
follow-up F-ом навбар переехал в `AppShell`, гард при переезде
просто потеряли. Heart-badge на карточках продолжал работать
(там отдельная проверка), а вот сама вкладка — нет.

**Fix.** В
[`recipe_list/lib/ui/app_shell.dart`](../recipe_list/lib/ui/app_shell.dart)
введён `_onTabTap(context, tab)`: если
`tab == AppNavTab.favorites && !userLoggedInNotifier.value`,
показываем тот же snackbar+action, что и раньше; иначе
`navShell.goBranch(...)`.

### 4. Тесты, упавшие после фикса №3

`router_smoke_test.dart` и `router_branches_test.dart` тапали
«Избранное» без авторизации — новый гард их блокировал. В обоих
тестах теперь:

```dart
userLoggedInNotifier.value = true;
addTearDown(() => userLoggedInNotifier.value = false);
```

### Add-FAB snackbar «hangs forever»

В отчёте пользователя был четвёртый пункт — snackbar на add-FAB
не дисмиссился. **Не воспроизводится** на текущей кодовой базе:
per-branch `ScaffoldMessenger`, который ломал автодисмисс, был
откачен в follow-up F (`3dd4308`). Сейчас snackbar-ы садятся на
единственный корневой `ScaffoldMessenger` от `MaterialApp.router`
поверх всегда-рисующегося `AppShell.Scaffold` — таймер на 4 с
работает. Если ситуация повторится — нужно прислать конкретный
текст snackbar-а и экран, чтобы копнуть глубже.

### Тесты

* `flutter analyze` — clean.
* `flutter test` — 105 pass / 6 несвязанных fail (тот же baseline,
  что был до follow-up-а).

### Файлы

* [recipe_list/lib/ui/recipe_list_loader.dart](../recipe_list/lib/ui/recipe_list_loader.dart)
  — `_publishServices` обёрнут в `addPostFrameCallback`.
* [recipe_list/lib/ui/login_page.dart](../recipe_list/lib/ui/login_page.dart)
  — back-FAB c `canPop`-fallback.
* [recipe_list/lib/ui/app_shell.dart](../recipe_list/lib/ui/app_shell.dart)
  — `_onTabTap` + guest-gate snackbar.
* [recipe_list/test/router_smoke_test.dart](../recipe_list/test/router_smoke_test.dart),
  [recipe_list/test/router_branches_test.dart](../recipe_list/test/router_branches_test.dart)
  — `userLoggedInNotifier` setup.

### Урок

При переносе виджета из одного места в другое нужно ехать вместе
со всеми его побочными эффектами (auth-гарды, side-effects), а не
только с визуальной частью. И любая мутация глобального
`ValueNotifier` из `build`/`FutureBuilder.builder` — потенциальный
`setState during build`; использовать `addPostFrameCallback`.

---

## Refresh docs for go_router follow-up F

**Date:** 2026-05-04

**Status:** ✅ Done

Документация по рефакторингу навигации обновлена под фактическое
состояние кода после commit `3dd4308`:

* [docs/go-router-shell-refactor.md](go-router-shell-refactor.md) —
  обновлены «Целевая архитектура», «Ключевые принципы» и «Карта
  маршрутов» (login/admin теперь на root-навигаторе через
  `parentNavigatorKey: rootNavigatorKey`); добавлен раздел
  «Follow-up F» с описанием root-cause-ов обеих регрессий
  (full-screen splash/login + snackbar) и принятого решения.
* [todo/19-go-router-shell.md](../todo/19-go-router-shell.md) —
  список коммитов дополнен `3dd4308`; чек-лист «Приёмка»
  переведён в `[x]` + добавлены пункты про splash-полноэкранность
  и работу snackbar-ов; добавлен раздел «Follow-up F» с конкретным
  списком файлов и тестовым отчётом.

Изменений в коде нет — только документация.

---

## flutter_svg drops `<marker>`-based stars in `assets/flags/us.svg`

**Date:** 2026-05-04

**Status:** ✅ Fixed

**Symptom.** В рантайме `LangIconButton` для английского флага в
консоль печаталось `unhandled element <marker/>` и сами 50 звёзд
кантона не отрисовывались — синий прямоугольник без узора.

**Root cause.** `flutter_svg` (через `vector_graphics_compiler`)
поддерживает подмножество SVG: элементы `<marker>`, `<pattern>`,
`<filter>`, `<symbol>` и `<foreignObject>` парсер пропускает с
warning'ом. В исходном `us.svg` звёзды задавались как
`marker-mid="url(#us-a)"` на «зигзаговой» полилинии, и весь их
геометрический след молча отбрасывался.

**Fix.** Переписан `assets/flags/us.svg` в чистые элементы:
- 13 чередующихся `<rect>` для полос (#B22234 / #FFFFFF);
- кантон 2964×2100 (#3C3B6E) и 50 явных `<polygon>` пятиконечных
  звёзд на каноническом 9-рядном сетчатом каркасе (точные
  координаты по спеке Wikipedia).

Заодно `assets/flags/sa.svg` лишился невалидной разметки сабли
(`<rect width="-60">` — отрицательная ширина, которую парсер
тихо отбрасывал) и теперь рисуется набором `polygon` + `rect` +
`circle`.

**Regression guard.** Добавлен `test/flag_svgs_test.dart`: для
каждого `assets/flags/*.svg` вызывает
`vector_graphics_compiler.encodeSvg(..., warningsAsErrors: true)`
и падает, если парсер встречает неподдерживаемый элемент или
невалидный атрибут.

**Caveat.** `iq.svg` и `sa.svg` всё ещё содержат `<text>` с
арабской каллиграфией. flutter_svg такие тексты рендерит без
warning'а, но без harfbuzz-shaping'а — лигатуры могут «рассыпаться».
Для текущего использования (24-px кружок рядом с language
toggle) это незаметно; полноценная замена на `<path>` отложена.

## Splash + login below bottom nav, snackbars don't show

**Date:** 2026-05-04

**Status:** ✅ Fixed

**Symptom.**
1. На splash и на экранах `LoginPage` / `SignupPage` /
   `PasswordRecoveryPage` / `AdminAfterLoginPage` снизу всё
   время торчал `AppBottomNavBar` — UX сломан, эти экраны
   должны быть полноэкранные.
2. Любой `showSnackBar(...)` ничего не показывал — ни в
   recipes/favorites, ни в формах авторизации.

**Root cause #1 (нав-бар).** Все эти экраны жили **внутри**
`StatefulShellRoute` — splash/recipe-list как корень ветки
recipes; login/admin как sub-route'ы ветки profile. Поскольку
shell-builder это `Scaffold(bottomNavigationBar: AppBottomNavBar)`,
любой контент любой ветки рендерится в `body:` этого Scaffold-а,
и навбар всегда виден.

**Root cause #2 (snackbar).** В предыдущем коммите
(`905bbdd "give each shell branch its own ScaffoldMessenger"`)
мы обернули каждую ветку в собственный `ScaffoldMessenger`,
пытаясь починить «висящий навсегда snackbar». Это сломало больше
чем починило:

* `Scaffold` приложения (`AppShell`-а) лежит **снаружи** per-branch
  messenger-ов — он регистрируется в корневом messenger-е
  `MaterialApp`-а. Page-Scaffold-ы веток регистрируются в своём
  per-branch messenger-е. В итоге у branch-messenger-а нет
  «root» Scaffold-а в смысле `_isRoot()` (нет
  `findAncestorStateOfType<ScaffoldState>()` в его
  `_scaffolds`-сете), и snackbar монтируется во **все**
  page-Scaffold-ы ветки одновременно, включая offstage-ные
  (которых в стеке `Navigator`-а ветки больше одного, когда
  открыта sub-route). На offstage Scaffold-е снэк показывается
  невидимо, а dismiss-Timer создаётся в `build()`-е messenger-а,
  где `ModalRoute.of(messengerContext).isCurrent` для shell-уровня
  **false**, когда сверху лежит sub-route своей же ветки. Timer
  просто не создаётся → автодисмисс не работает; визуально
  выглядит «snackbar не показался / не пропал».
* По умолчанию (default `StatefulShellRoute.indexedStack`,
  один общий messenger от `MaterialApp`) snackbar показывается
  ровно на **AppShell-овском** Scaffold-е — он зарегистрирован
  первым, всегда красится, всегда тикает, а page-Scaffold-ы
  отфильтровываются `_isRoot(scaffold)` (их
  `findAncestorStateOfType<ScaffoldState>()` находит AppShell в
  `_scaffolds`). Таймер автодисмисса в `build()` корневого
  messenger-а не имеет проблемы с `ModalRoute` (контекст
  глобальный, `route == null`).

Иначе говоря — изначальный «hang forever» был неверно
диагностирован: `IndexedStack` оборачивает детей в `Visibility`
с `maintainAnimation: true` (см.
`flutter/lib/src/widgets/basic.dart` `IndexedStack.build`), так
что offstage-ветки **не** теряют тикеры. Default behaviour был
рабочим. «Чинящий» per-branch messenger как раз и сломал
автодисмисс + потерю snackbar-а.

**Fix.**

1. **Откат per-branch ScaffoldMessenger.** Возвращаемся к
   `StatefulShellRoute.indexedStack(...)`. Один корневой
   messenger от `MaterialApp.router`, snackbar садится на
   AppShell-Scaffold, автодисмисс работает.
2. **Login / admin переехали на root-навигатор.** В
   `app_router.dart` объявлен `rootNavigatorKey`, передан в
   `GoRouter(navigatorKey: …)`. Sub-route'ы `/profile/login`
   и `/profile/admin` получили `parentNavigatorKey:
   rootNavigatorKey` — теперь они рендерятся **поверх**
   shell-а, без `AppShell`-Scaffold-а вокруг → нет навбара.
   Slide-up `_slideUpPage` сохранён. Связанные через
   `Navigator.of(context).push` экраны (signup, recovery)
   автоматически уезжают на root-навигатор, потому что
   `Navigator.of(loginPageContext)` теперь резолвится в
   root-Navigator.
3. **Splash скрывает навбар на время slide-up.** Глобальный
   `ValueNotifier<bool> bottomNavVisibleNotifier` (default
   `true`); `SplashAndRecipesState.initState` ставит `false`,
   а `AnimationStatus.completed` slide-controller-а ставит
   `true`. `AppShell` оборачивает `bottomNavigationBar` в
   `ValueListenableBuilder` и рисует `SizedBox.shrink()`, пока
   `false`. На `restart()` splash-а флаг снова сбрасывается.

**Файлы:**
* [recipe_list/lib/router/app_router.dart](recipe_list/lib/router/app_router.dart) —
  `rootNavigatorKey`, `StatefulShellRoute.indexedStack`,
  `parentNavigatorKey:` для login/admin; `navigatorContainerBuilder`
  с `ScaffoldMessenger`-обёрткой удалён.
* [recipe_list/lib/main.dart](recipe_list/lib/main.dart) —
  `bottomNavVisibleNotifier`.
* [recipe_list/lib/ui/app_shell.dart](recipe_list/lib/ui/app_shell.dart) —
  `ValueListenableBuilder` вокруг `bottomNavigationBar`.
* [recipe_list/lib/ui/splash_and_recipes.dart](recipe_list/lib/ui/splash_and_recipes.dart) —
  переключение `bottomNavVisibleNotifier` в initState/restart/
  status-listener.

**Тесты.** Все суиты — 105 pass / 6 несвязанных fail (тот же
baseline, что был до серии коммитов, начиная с `b697853`).

---

## Navigation refactor — `go_router` + `StatefulShellRoute`

**Date:** 2026-05-04

**Status:** ✅ Completed (chunks A–E)

**See also:** [go-router-shell-refactor.md](go-router-shell-refactor.md),
[todo/19-go-router-shell.md](../todo/19-go-router-shell.md).

Перевели навигацию `recipe_list` со связки `MaterialApp(home:)` +
`Navigator.push` на `go_router` с `StatefulShellRoute.indexedStack`.
Цели: убрать дублирование `AppBottomNavBar` (4 копии), устранить
`RecipeDetailsPage.originTab`, сохранять state вкладок между
переключениями, получить deep-link URLs для Flutter web.

### Что сделано (по чанкам)

* **Чанк A — `fe1235d`.** Зависимость `go_router ^14.0.0`, общий
  `AppShell(navShell)` рисует единственный `AppBottomNavBar`,
  `MaterialApp.router` с одной веткой Recipes.
* **Чанк B — `514b720`.** Favorites как отдельная
  `StatefulShellBranch`. `RecipeDetailsPage.originTab` удалён;
  путь к деталям теперь branch-aware (`/recipes/details/:id` vs
  `/favorites/details/:id`), полный `Recipe` пробрасывается через
  `extra`.
* **Чанк C — `15a66d9`.** Profile-ветка с двумя sub-route'ами
  `/profile/login` и `/profile/admin`. Корневой `/profile` — redirect-only
  (`_profileRedirect` смотрит на `adminLoggedInNotifier` /
  `userLoggedInNotifier` через `refreshListenable`). Slide-up
  анимация воспроизведена `CustomTransitionPage` + `Tween<Offset>`.
* **Чанк D — `6b7f888`.** `SourcePage` и `AddRecipePage` (add/edit)
  как nested-routes под каждой веткой. Открытие — `context.push`
  по `Routes.addUnder/editUnder/sourceUnder`; ветка определяется по
  текущему location'у через `Routes.currentBranchBase`. `SourcePage`
  потеряла свой рудиментарный `bottomNavigationBar` — его рисует
  `AppShell`.
* **Чанк E — финальный cleanup.** Добавлена «Карта маршрутов» в
  `docs/go-router-shell-refactor.md`, статусы переключены на ✅.
  `_onNavTap`-методов в lib/ не осталось; `originTab` остался только
  в комментариях-объяснениях.

### Что намеренно не вошло

* `AdminUsersPage` и `AdminAddedRecipesPage` живут целиком внутри
  admin-модального стека поверх `/profile/admin` и не отображаются в
  навбаре. Перевод их на nested-routes даёт лишь косметический
  выигрыш — оставлены на `Navigator.push(MaterialPageRoute)`.

### Тесты

Базовый прогон: 95 pass / 6 fail (те же 6 несвязанных, что и до
рефакторинга — feed_config × 1, recipe_card × 1, recipe_list_page × 2,
recipe_repository × 2). Новые маршрутные тесты:

* `test/router_smoke_test.dart` (чанк A).
* `test/router_branches_test.dart` (чанк B).
* `test/router_profile_branch_test.dart` (чанк C).
* `test/router_helpers_routes_test.dart` (чанк D).

`flutter analyze` чистый.

---

## Admin "Recipes Added" feature — track user-created recipes

**Date:** 2026-05-04

**Status:** ✅ Fully implemented, tested, and deployed

Реализована полная цепочка для отслеживания рецептов, добавленных пользователями:
- Пользователь добавляет рецепт → рецепт автоматически добавляется в избранное
- Admin видит кнопку "Recipes added" в профиле
- Admin может просмотреть полный список добавленных рецептов с информацией о создателе
- Backend отслеживает всех создателей в таблице `recipe_app_recipe_creators`

### Flutter (`otus_dz/recipe_list`)

- `lib/ui/add_recipe_page.dart` (строки 485-492)
  - После создания нового рецепта (не при редактировании), если пользователь
    залогинен, рецепт автоматически добавляется в избранное:
    ```dart
    if (existing == null) {
      try {
        final store = favoritesStoreNotifier.value ?? 
                      await ensureFavoritesStoreInitialized();
        if (store != null && userLoggedInNotifier.value) {
          await store.add(localized.id, appLang.value);
        }
      } catch (_) {}
    }
    ```

- `lib/ui/admin_after_login_page.dart` (строки 157-175)
  - Кнопка "Recipes added" с иконкой `Icons.library_books_outlined`
  - Открывает `AdminAddedRecipesPage` с полным списком рецептов, добавленных пользователями

- `lib/ui/admin_added_recipes_page.dart` (новый)
  - Экран со списком рецептов, добавленных пользователями
  - Карточки включают:
    - Имя рецепта и ссылку на карточку рецепта
    - Имя создателя, email и ссылку на профиль пользователя
    - Дату создания
    - Кнопки "Open recipe card" и "Open user card"
  - Refresh action и обработка ошибок/пустого списка

- `lib/auth/admin_session.dart` (строки 134-177, 726-773)
  - DTO `AdminAddedRecipeItem` с полями: recipeId, recipeName, creatorType,
    creatorUserId, creatorName, creatorEmail, createdAt и т.д.
  - Функция `fetchRecipeAdminAddedRecipes()` — запрашивает
    `GET /api/recipe-admin/recipes-added` и возвращает список

### Backend (`mahallem_ist/local_user_portal`)

- `routes/recipes.js`
  - На POST /recipes, после успешного создания рецепта:
    - Создаётся запись в таблице `recipe_app_recipe_creators` с информацией
      о создателе (user_id, actor_email, actor_type='user', created_at)

- `routes/auth.js` (строки 2506-2590)
  - Добавлен endpoint `GET /api/recipe-admin/recipes-added`
  - Требуется admin token с scope: viewer, operator, super_admin
  - Query params: limit (default 200, max 500), offset (default 0)
  - SQL JOIN по `recipe_app_recipe_creators` + `recipe_app_users` + `recipes`
  - Возвращает recipes с полной информацией о создателе

### Database

- Таблица `recipe_app_recipe_creators` (создана в миграции)
  - recipe_id INT
  - actor_type TEXT ('user' | 'admin')
  - user_id TEXT (nullable, для пользовательских рецептов)
  - admin_id TEXT (nullable, для админских рецептов)
  - actor_email TEXT
  - created_at TIMESTAMP

### Docs

- `docs/admin-recipes-added-feature.md` (новый)
  - Полная документация feature с примерами API и кода

---

## Admin after-login panel + users management + backend admin endpoints

**Date:** 2026-05-03

Реализован отдельный post-login поток для admin-пользователя в recipe app,
с user-management UI и backend API для управления пользователями
`recipe_app_users`.

### Flutter (`otus_dz/recipe_list`)

- `lib/ui/login_page.dart`
  - после успешного admin-login теперь открывается новый admin экран,
    вместо обычного `Navigator.pop(true)`.

- `lib/ui/admin_after_login_page.dart` (новый)
  - экран «после логина» с 3 кнопками:
    1) Edit users list,
    2) Edit cards,
    3) Logout.
  - `Edit cards` возвращает на корневой feed (`popUntil(isFirst)`), где
    уже действуют admin edit/delete affordances.

- `lib/ui/admin_users_page.dart` (новый)
  - карточки пользователей с действиями edit/delete;
  - checkbox per-card + select-all;
  - bulk delete выбранных пользователей;
  - refresh action и диалоги подтверждения.

- `lib/auth/admin_session.dart`
  - добавлены admin API-методы для recipe-domain пользователей:
    - `fetchRecipeAdminUsers(...)`
    - `updateRecipeAdminUser(...)`
    - `deleteRecipeAdminUser(...)`
    - `bulkDeleteRecipeAdminUsers(...)`
  - добавлен DTO `AdminRecipeUser`.

- i18n/polish
  - в `lib/i18n.dart` добавлены admin-строки через фасад `S` (manual mapping
    c EN fallback; RU/TR покрыты), чтобы не трогать generated slang-файлы;
  - `admin_after_login_page.dart` и `admin_users_page.dart` переведены на
    эти ключи;
  - дополнительная правка форматирования (line-wrap) в i18n/admin_users.

### Backend (`mahallem_ist/local_user_portal`)

- `routes/auth.js`
  - добавлен `requireRecipeCompatAdmin` по заголовкам:
    - `x-recipe-admin-login`
    - `x-recipe-admin-password`
  - добавлены admin endpoints для `recipe_app_users`:
    - `GET /users/admin/list`
    - `PATCH /users/admin/:id`
    - `DELETE /users/admin/:id`
    - `POST /users/admin/bulk-delete`

### Commits / push

- `otus_dz`: `3b48976` — `feat(admin): add post-login panel and users management UI`
- `mahallem_ist`: `17cafc5f` — `feat(auth): add recipe-app admin user management endpoints`

### Validation

- Diagnostics checked on touched files (Flutter + backend `auth.js`) — no errors.
- `recipes.js` в `mahallem_ist` имел отдельный локальный style-only diff
  (reindent import block), логически не связанный с admin фичей.

## Recipe auth domain isolation from Mahallem users + login logout-field UX

**Date:** 2026-05-03

После жалобы на конфликт signup (`"user already exists"` для email,
который есть в mahallem, но не регистрировался в recipe app) изолировали
auth-домен Otus Food от общего Mahallem `users`.

### Backend (`mahallem_ist/local_user_portal`)

- `routes/auth.js`
  - Recipe compatibility auth (`/users/login`, `/users`, aliases)
    переведён с `users` на отдельную таблицу `recipe_app_users`.
  - Lazy schema ensure для `recipe_app_users` (auto-create при первом вызове).
  - Логин recipe app теперь выдаёт token для recipe-domain пользователя;
    `isAdmin=false` для этого контура.
  - Password recovery изолирован по домену:
    - если `app_name = "Otus Food"` → `forgot/reset` работают с
      `recipe_app_users`;
    - иначе поведение прежнее (`users`).

- `routes/recipes.js`
  - Favorites persistence для recipe-domain переведён на
    `recipe_app_user_favorites` (user_id text, PK `(user_id, recipe_id, lang)`).
  - Добавлен one-time backfill из legacy `recipe_user_favorites` (если таблица есть).

### Deploy

- Backend commit: `90d26bc4`
  (`feat: isolate recipe app auth from mahallem users`).
- Push в `main` + production deploy:
  `docker compose up -d --build user-portal` на `72.61.181.62`.
- Smoke: `GET https://mahallem.ist/recipes/health` → `status: ok`.

### Data checks / hotfixes

- Проверка `alarmdcs@gmail.com`:
  - `users.preferred_language = ru`
  - `recipe_app_users.preferred_language = en`
- Проверка `info@lagente.do`:
  - был только в `users` (`tr`),
  - добавлен в `recipe_app_users`, выставлен `preferred_language = ru`.

### Client UX (`otus_dz/recipe_list`)

- `lib/ui/login_page.dart`
  - В состоянии logged-in (кнопка `Log out`):
    - email field disabled, prefilled текущим login;
    - password field disabled, prefilled `••••••••`.

### Result

- Signup/login recipe app больше не конфликтует с Mahallem users-domain.
- Предпочтительный язык и recovery flow теперь доменно-разделены.
- Logout state в login UI визуально подтверждает, под каким аккаунтом
  пользователь сейчас авторизован.

## Preferred language on signup/login/bootstrap + language carousel semantics

**Date:** 2026-05-03

Реализован полный контур «пользователь выбирает язык при signup → язык
сохраняется на backend/local mirror → восстанавливается при следующем входе
и при открытии приложения».

### Клиент (`otus_dz/recipe_list`)

- `lib/ui/lang_icon_button.dart`
  - зафиксирована семантика карусели языка:
    - круглый флаг = **текущий** язык,
    - круглая кнопка = **следующий** язык (`next.label`), в который
      переключится приложение по тапу.

- `lib/ui/signup_page.dart`
  - добавлен блок выбора языка перед submit:
    - текст `s.signUpChooseLanguage`,
    - круглый флаг текущего языка,
    - круглая кнопка-cycle (как в app bar);
  - в `signUpUser(...)` передаётся `preferredLang: appLang.value`.

- `lib/auth/admin_session.dart`
  - `signUpUser` принимает `AppLang? preferredLang` и отправляет `language` в signup payload;
  - онлайн-логин парсит `preferredLanguage` из ответа;
  - при наличии `preferredLanguage` сразу переключает `appLang` (`cycleAppLangTo`);
  - локальный mirror `auth_credentials` сохраняет `preferred_language`;
  - `bootstrapAdminSession` читает `preferred_language` и восстанавливает язык до
    финальной инициализации UI-сессии.

- `lib/data/local/recipe_db.dart`
  - schema version: `8 → 9`;
  - `auth_credentials` получил `preferred_language TEXT` + миграция `ALTER TABLE`.

- i18n
  - добавлен ключ `signUpChooseLanguage` во все 10 локалей;
  - slang regenerated (`strings.g.dart`, `strings_*.g.dart`);
  - фасад `S` получил геттер `signUpChooseLanguage`.

### Бэкенд (`mahallem_ist/local_user_portal`)

- `routes/auth.js`
  - login compatibility handler теперь возвращает
    `preferredLanguage: user.preferred_language || null`.

### Deploy / commits

- Backend commit: `d2532ec9` (push + production deploy `user-portal`).
- Flutter commit: `f514691` (push `main`).

### Результат

- Пользователь может явно выбрать язык на signup.
- Следующий логин и следующий cold start приложения используют
  сохранённый пользовательский язык.
- Карусель языка в app bar теперь отображает «куда переключимся»,
  а флаг — «где сейчас находимся».

## Forgot password flow + signup→login chaining + session-aware favorites

**Date:** 2026-05-03

### Signup → login chaining

- `openSignUpPage(context)` теперь возвращает `bool` (true = аккаунт создан).
- После успешного signup автоматически открывается `LoginPage` (email не pre-fill на этом шаге).

### Session-aware favorites (cross-user protection)

- `FavoritesStore` сбрасывает in-memory ids и инвалидирует sync-кэш при смене auth-identity.
- `list(lang)` вызывает `ensureLoaded(lang)` перед возвратом результата.

### "Forgot password" flow

Полный контур сброса пароля в клиенте. Бэкенд уже был в production — новые деплои не нужны.

#### Клиент (`otus_dz/recipe_list`)

- `lib/auth/admin_session.dart`
  - `enum PasswordRecoveryStartResult` / `PasswordRecoveryStartResponse`
  - `requestPasswordRecovery({required String email})` → POST /forgot-password, захватывает `set-cookie` как `sessionCookie`
  - `enum PasswordResetResult`
  - `resetPasswordWithCode({email, code, newPassword, sessionCookie})` → POST /reset-password с Cookie-заголовком

- `lib/ui/login_page.dart`
  - "Forgot password?" TextButton под кнопкой Login/Logout
  - `openLoginPage(context, {String? prefillLogin})` — опциональный prefill email
  - `_forgotPassword()`: валидирует email-поле, вызывает `requestPasswordRecovery`, роутит по результату

- `lib/ui/password_recovery_page.dart` (новый файл)
  - Тот же визуал: gradient, SplashMaskedLogo, form-style
  - Поле кода (4 цифры) + поле нового пароля с visibility toggle
  - Submit → `resetPasswordWithCode` → snackbar "Your new password is saved" → `openLoginPage(prefillLogin: email)`
  - Snackbar для каждого error-кейса: `invalidCode`, `passwordTooShort`, `sessionExpired`, `serverError`

- i18n
  - 15 новых ключей во всех 10 локалях (en, ru, de, es, fr, it, tr, ar, fa, ku):
    `forgotPassword`, `passwordRecoveryTitle`, `passwordRecoveryInstruction`,
    `passwordRecoveryCodeLabel`, `passwordRecoveryCodeHint`, `passwordRecoveryNewPassword`,
    `passwordRecoverySubmit`, `passwordRecoveryEnterEmail`, `passwordRecoveryInvalidEmail`,
    `passwordRecoveryRequestFailed`, `passwordRecoveryInvalidCode`,
    `passwordRecoveryPasswordTooShort`, `passwordRecoverySessionExpired`,
    `passwordRecoverySaveFailed`, `passwordRecoverySaved`
  - `dart run slang` → "Translations generated successfully."

#### Бэкенд

Без изменений — `/forgot-password` и `/reset-password` уже были живы на production.
Деплой бэкенда не производился.

---

## Role-aware login, favorites auth gate, backend user-token favorites sync + production rollout

**Date:** 2026-05-03

Реализован и задеплоен полный контур для запроса:

- «Admin mode enabled» только для admin, не для обычного пользователя;
- edit/delete только owner или admin;
- favorites доступны только зарегистрированным;
- favorites сохраняются на production backend под user credentials;
- у гостя при тапе в favorites — snackbar с требованием регистрации + переход на Sign Up.

### Клиент (`otus_dz/recipe_list`)

- `lib/auth/admin_session.dart`
  - добавлены state-notifier'ы:
    `userLoggedInNotifier`, `adminLoggedInNotifier`,
    `currentUserLoginNotifier`, `currentUserTokenNotifier`;
  - онлайн-логин теперь читает `token` и role flags (`isAdmin` / `role`),
    а не сводится к одному bool «admin logged in»;
  - добавлены методы remote favorites API:
    `fetchRemoteFavorites(lang)` / `setRemoteFavorite(...)`
    с заголовком `x-recipes-user-token`.

- `lib/ui/login_page.dart`
  - success snackbar разделён:
    `loginSuccessAdmin` для admin и `loginSuccessUser` для regular user;
  - UI login/logout привязан к `userLoggedInNotifier`.

- `lib/ui/app_bottom_nav_bar.dart`
  - подсветка profile-tab переведена на `userLoggedInNotifier`
    (а не admin-only).

- `lib/ui/recipe_card.dart` / `lib/ui/recipe_list_page.dart`
  - owner/admin guard для edit/delete;
  - guest guard для favorite heart и favorites-tab;
  - snackbar `favoritesRegistrationRequired` + action `Sign Up`.

- `lib/ui/add_recipe_page.dart`
  - photo field обязателен в create-flow;
  - на web URL fallback явно валидируется как required, если нет picked photo;
  - автодобавление нового рецепта в favorites убрано.

- `lib/data/repository/favorites_store.dart`
  - remote sync в `ensureLoaded`: подтягивание ids с backend по токену;
  - `add/remove` делают best-effort POST sync на backend;
  - local cache остаётся fallback при сетевых ошибках.

- i18n
  - добавлены ключи `loginSuccessUser` и `favoritesRegistrationRequired`
    во все локали + regen `strings_*.g.dart`.

### Бэкенд (`mahallem_ist/local_user_portal`)

- `routes/auth.js`
  - login compatibility (`/users/login` aliases) теперь выдаёт
    signed recipes-user token + `isAdmin`.

- `routes/recipes.js`
  - добавлена token verification middleware (`x-recipes-user-token`);
  - реализованы endpoints:
    - `GET /recipes/favorites?lang=...`
    - `POST /recipes/favorites` (`{recipeId, lang, favorite}`);
  - lazy schema ensure:
    `recipe_user_favorites(user_id, recipe_id, lang, saved_at)` + индекс.

### Деплой (строго по `hostinger-deployment/DEPLOYMENT_WORKFLOW.md`)

1. Step 0 sync-check на EU production (`72.61.181.62`) — clean `main`.
2. Commit + push backend изменений в `mahallem_ist`:
   `192df999`.
3. Pull на production + rebuild `user-portal` из
   `/root/mahallem/mahallem_ist/local_docker_admin_backend`:
   `docker compose up -d --build user-portal`.

### Production smoke (`https://mahallem.ist`)

- `POST /users` → `201` ✅
- `POST /users/login` → `200` и возвращает `token` + `isAdmin` ✅
- `GET /recipes/favorites?lang=en` без токена → `401` ✅
- `POST /recipes/favorites` с токеном (`favorite:true`) → `200` ✅
- `GET /recipes/favorites` с токеном содержит id → `200` ✅
- `POST /recipes/favorites` (`favorite:false`) → `200` ✅

---

## Chrome web: фильтр поиска — выбор из автокомплита не применялся

**Date:** 2026-05-01

**Симптом.** В Chrome после нажатия на подсказку в выпадающем списке
поиска список рецептов не менялся — оставался нефильтрованным.

**Причина.** Браузер генерирует событие `blur` **синхронно на
`pointerdown`**, до того как завершится `pointerup`/tap на элементе
списка. `_onFocusChange` вызывал `setState` немедленно, `_showPredictions`
становился `false`, виджет `SearchPredictions` убирался из дерева прямо
во время жеста — `onTap` у `ListTile` отменялся, и `_onPredictionTap`
никогда не вызывался.

**Исправление** (`recipe_list/lib/ui/recipe_list_page.dart`):
при потере фокуса **на web** `setState` в `_onFocusChange` откладывается
на 200 мс через `Future.delayed`, что даёт текущему жесту завершиться.
На native и при получении фокуса поведение не изменилось.

Коммит: `c444484`.

---

## Chrome web: фото не загружалось на странице «Добавить рецепт»

**Date:** 2026-05-01

**Симптом.** На Chrome после выбора фото с компьютера превью не
появлялось; при сохранении рецепта фотография также не загружалась.

**Причина.** Весь pipeline работы с фото строился на `dart:io.File`,
которого в web-сборке Flutter не существует:
* `downscaleForUpload` использует `flutter_image_compress` с нативными
  путями файловой системы;
* `Image.file()` не работает на web;
* `MultipartFile.fromFile(path)` — тоже только нативный вызов.

**Исправление:**

* `add_recipe_page.dart` — `_pickPhoto` теперь ветвится по `kIsWeb`:
  на web пропускает сжатие и читает байты через `XFile.readAsBytes()`
  в новое поле `_webPickedBytes`/`_webPickedFilename`.
* `_PhotoPicker` — добавлен параметр `webPickedBytes`; превью на web
  строится через `Image.memory(bytes)` вместо `Image.file()`.
* `_save` — байты для загрузки определяются один раз: `_webPickedBytes`
  на web или `File.readAsBytes()` на native.
* `recipe_api.dart` — `createRecipeWithPhoto` / `updateRecipeWithPhoto`
  переведены с `File` на `Uint8List bytes + String filename`; используют
  `MultipartFile.fromBytes()`, который работает и на web, и на native.
* `recipe_api_test.dart` — тест обновлён под новую сигнатуру.

Коммит: `ec58ce3`.

---

## Chrome web: responsive grid for recipes and favorites cards

**Date:** 2026-05-01

Реализован адаптивный грид карточек для web (Chrome) на экранах
списка рецептов и избранного:

* `recipe_list/lib/ui/recipe_list_page.dart`:
  на web вместо `ListView` используется `GridView` с динамическим
  `crossAxisCount` по ширине viewport.
* `recipe_list/lib/ui/favorites_page.dart`:
  применена та же схема адаптивного грида, чтобы поведение и
  плотность карточек совпадали с основным списком.
* `recipe_list/lib/ui/recipe_card.dart`:
  добавлен параметр `outerPadding`, чтобы карточка одинаково
  корректно работала в list-режиме (старые отступы) и в grid-ячейке
  (`EdgeInsets.zero`), без дублирования компонента.

Поведение:

* размер карточки сохраняется близким к «мобильному» (фиксированный
  диапазон ширин, без растягивания на весь desktop);
* при значимом изменении ширины браузера меняется число карточек
  в строке (responsive break by viewport);
* на native-таргетах (iOS/Android) сохранён прежний `ListView`.

Коммит: `74d8dc3`.

## Chrome web: сердце не кликалось + sqflite `unsupported result null`

**Date:** 2026-05-01

Симптомы в `flutter run -d chrome`:

* ❤️ на карточке не меняет цвет и не добавляет рецепт в избранное;
* тап по зоне сердца иногда открывает details карточки;
* в логах sqflite: предупреждение про смену default factory и
  `[favorites] store init failed: unsupported result null (null)`.

Итоговый набор фиксов:

* `recipe_list/lib/ui/recipe_card.dart` / `recipe_details_page.dart`:
  `PointerInterceptor` для overlay-виджетов поверх
  `WebHtmlElementStrategy.fallback` (`<img>` platform view на web).
* `recipe_list/lib/ui/recipe_card.dart`:
  `FavoriteBadge` вынесен в внешний `Stack` (sibling поверх карточки),
  чтобы tap сердца не конкурировал с `InkWell` карточки в gesture arena.
* `recipe_list/lib/data/repository/favorites_store.dart`:
  добавлен fail-safe `ensureFavoritesStoreInitialized()`; первый тап
  по сердцу при `store == null` bootstrap-ит БД и делает `toggle`.
* `recipe_list/lib/data/local/recipe_db.dart`:
  убран глобальный `databaseFactory = ...`; вместо этого приватный
  `_webDbFactory = databaseFactoryFfiWebNoWebWorker`.
  Это убрало warning про global factory side effects и обходило
  flaky worker-path, который давал `unsupported result null (null)`.

Коммиты: `fd175fc`, `bf83a0c`, `68f738f`, `1677e84`.
Подробности: [`docs/chrome-web-support.md`](chrome-web-support.md).

## Web: добавление в избранное в Chrome

**Date:** 2026-05-01

В Chrome (`flutter run -d chrome`) тап «в избранное» падал, потому
что `recipe_list/lib/data/local/recipe_db.dart` открывал sqflite
через `path_provider` + дефолтный фабричный канал, которых на
web нет. Решение:

* Добавлена зависимость `sqflite_common_ffi_web: ^0.4.5`
  (sqlite3.wasm в IndexedDB) в
  [`recipe_list/pubspec.yaml`](../recipe_list/pubspec.yaml).
* `openRecipeDatabase` теперь определяет `kIsWeb` и переключает
  `databaseFactory = databaseFactoryFfiWeb`, открывая БД по
  имени `recipes.db` (без файловой системы). Логика миграций
  (`_onRecipeDbUpgrade`) общая для нативки и web.
* В каталог `recipe_list/web/` положены ассеты
  `sqflite_sw.js` (~250KB) + `sqlite3.wasm` (~706KB) через
  `dart run sqflite_common_ffi_web:setup`. Это требование
  пакета: воркер и wasm загружаются браузером во время первого
  open.

Native-сборки (iOS/Android/desktop) не затронуты — на них
работает прежний `getApplicationSupportDirectory()` + `openDatabase`.

## CORS для `/recipes/*` (паттерн A)

**Date:** 2026-05-01

В `routes/recipes.js` добавлен `cors({origin:'*',
credentials:false, methods:['GET','POST','PUT','DELETE'],
allowedHeaders:['Content-Type','Authorization'], maxAge:86400})`,
применён только к `/recipes` плюс явный `app.options('/recipes/*')`,
чтобы preflight не уходил в `authMiddleware`. Native-клиенты не
затронуты, Flutter web (`flutter run -d chrome`) теперь читает
ленту без CORS-блока. Cookies сессии mahallem.ist в cross-origin
не утекают (`credentials:false`), пишущие ручки по-прежнему
требуют `Authorization: Bearer`.

Проверено на проде: OPTIONS и GET на `/recipes/page` возвращают
`Access-Control-Allow-Origin: *`. См.
[`docs/cors-recipes.md`](cors-recipes.md).

## RU-приоритет в каскаде перевода + цикл EN→RU→…

**Date:** 2026-05-01

* **Frontend** ([recipe_list/lib/i18n.dart](../recipe_list/lib/i18n.dart)):
  enum `AppLang` переупорядочен в `en, ru, es, fr, de, it, tr, ar,
  fa, ku`. Цикл по тапу `LangIconButton` теперь EN → RU → … →
  EN. Самый частый ручной свитч (EN ↔ RU) — один тап.
* **Backend** (`local_user_portal/routes/recipes.js`):
  `_ensureLang` теперь даёт RU полный
  `RECIPES_TRANSLATE_BUDGET_MS` (8 c), остальным неприоритетным
  языкам — `RECIPES_TRANSLATE_BUDGET_LOW_MS` (3 c). При
  деградации Gemini/LT экзотические локали быстро откатываются на
  английский fallback и не сжигают квоту, оставляя её для RU.
  Список приоритетов настраивается env-переменной
  `RECIPES_PRIORITY_LANGS` (по умолчанию `"ru"`).

См. [`docs/translation-priority.md`](translation-priority.md).

## English по умолчанию при холодном старте

**Date:** 2026-05-01

`764d373` — `appLang` инициализируется `AppLang.en` вместо
`AppLang.ru` ([recipe_list/lib/i18n.dart](../recipe_list/lib/i18n.dart#L41)).
Порядок цикла не менялся (`next = (index+1) % length`): тап по
`LangIconButton` ведёт EN → ES → FR → DE → IT → TR → AR → FA → KU
→ RU → EN. Полезно, потому что на холодном языке `/recipes/page`
и `/lookup/:id` тратят translate-budget, а EN отдаётся из БД
мгновенно.

## Reload «Нет сети» на не-английских локалях

**Date:** 2026-05-01

Симптом: на RU/AR/FA UI кнопка reload в шапке ленты крутилась
~60 c, после чего поверх старой ленты всплывал snackbar
«Нет сети. Показываем прежние рецепты.» — независимо от того,
есть ли реальная сеть. На EN reload работал мгновенно.

Диагностика и фикс: см.
[`docs/reload-no-network.md`](reload-no-network.md). Кратко:

* **Backend** (`routes/recipes.js`):
  * `_ensureLang` теперь оборачивает `this.translate(...)` в
    `Promise.race` с бюджетом
    `RECIPES_TRANSLATE_BUDGET_MS` (по умолчанию 8 c). По таймауту
    отдаём английский payload как fallback **без записи** в БД —
    кэш не отравляется, повторный запрос снова попробует Gemini.
  * `RecipeRepository.page(lang)` параллелит per-row `_ensureLang`
    через `Promise.all` — суммарное время = max(per-row), а не sum.
    На прод-проверке `/recipes/page?lang=ru&limit=50` ушёл с
    HTTP 504 30 s на HTTP 200 8 s.
* **Client** (`recipe_list/lib/ui/recipe_list_loader.dart`):
  * Reload теперь сначала пробует `RecipeApi.fetchPage(...)` (тот же
    путь, что cold-start через `useBulkPage`); локально шафлит и
    персистит. `_seedFromCategories` остаётся как fallback на случай
    полного отказа bulk-эндпойнта.
  * Snackbar реагирует на тип ошибки. Добавлен ключ
    `a11y.reloadServerBusy` («Сервер занят. Показываем прежние
    рецепты.») во всех 10 локалях. `DioException`
    `connectionError/connectionTimeout/sendTimeout` → старый
    `offlineReloadUnavailable` («Нет сети.»). Прочее (5xx,
    `receiveTimeout`, общий 60 s budget `TimeoutException`,
    «server busy» и проч.) → новый `reloadServerBusy`.

Деплой: `docker compose build user-portal && docker compose up -d
user-portal` на `72.61.181.62`. `flutter analyze` чистый.

## RTL-порядок вкладок + усиленные тени/elevation

**Date:** 2026-04-30

* `677588d` — `AppBottomNavBar` оборачивает Row вкладок в
  `Directionality(textDirection: ltr)`. В ar/fa/ku порядок
  Recipes → Fridge → Favorites → Profile теперь не зеркалится:
  иконки не несут текстовой семантики, а §6 дизайн-системы
  фиксирует последовательность.
* `3ac549e` — тема: предыдущая правка теней (alpha 0x1A→0x24,
  0x40→0x5A) была почти неразличима на сером scaffold.
  Перешли на двухслойные key + ambient тени и подняли
  Material-elevation:
  * `AppColors.cardShadow` 0x24959292 → 0x66000000 (~0.40
    чёрного), `navBarShadow` 0x5A000000 → 0x80000000 (~0.50).
  * `AppShadows.card` теперь key-light (0/6, blur 14) + ambient
    (0/2, blur 4); `AppShadows.navBar` — umbra (0/0, blur 16) +
    верхний акцент (0/−2, blur 6).
  * `appBarTheme` elevation 4→8, `scrolledUnderElevation` 4→10;
    `cardTheme` 4→8; FAB 6/6/8/12 → 12/12/14/18;
    `bottomNavigationBarTheme` / `navigationBarTheme` 8→16.
  * `RecipeCard`, `AppBottomNavBar`, pinned-header и оба FAB
    `RecipeListPage` уже читают `AppShadows.*`, так что
    подхватили новые значения без правки экранов.

## Полировка UI редактирования рецепта + Favorites/Details

**Date:** 2026-04-30

Серия мелких UX-фиксов поверх owner-edit/delete фичи.

* **Flutter** (`otus_dz_2`):
  * `df9d808` — заголовок `AddRecipePage` (`flexibleSpace`) был
    невидим (textTheme.titleLarge → `brandTitle` белым на белом).
    Перешли на токен `AppTextStyles.pageTitle` (24sp, чёрный).
  * `0d7456d` — зарегистрировали тот же токен в
    `appBarTheme.titleTextStyle` / `toolbarTextStyle`, чтобы все
    AppBar-ы тянули его из темы, а не из локального хардкода.
  * `063eac9` — на форме add/edit перекрыли локальной `Theme`
    `inputDecorationTheme.{label,floatingLabel,helper,hint}Style`
    цветом `textPrimary`: на сером скаффолде глобальные
    `textSecondary`/`primaryDark` были серо-зелёные и
    нечитабельные.
  * `1c9f61b` — токены теней: `cardShadow` 0x1A→0x24,
    `navBarShadow` 0x40→0x5A (×1.4 темнее); подняли elevation
    в `appBarTheme` (4 + scrolledUnder 4), новый `cardTheme`
    (4), `floatingActionButtonTheme` (6/6/8/12),
    `bottomNavigationBarTheme` / `navigationBarTheme` (8). Сняли
    лишние локальные `elevation: 0` с SourcePage и AppPageBar.
  * `19345b3` — text-color самого инпута на форме: глобальный
    `textTheme.bodyLarge` мапится в `recipeMeta` (светло-зелёный
    `AppColors.primary`), и набираемый текст почти исчезал; в
    локальной `Theme` принудительно ставим `textPrimary`.
  * `057040b` — после POST/PUT сервер возвращает рецепт уже
    переведённым в `i18n.en`. Добавили дополнительный
    `api.lookup(id, lang: appLang.value)`, чтобы кэш и
    `recipeUpdatedNotifier` получили локализованный вариант
    (если lookup упал — деградируем до ответа POST/PUT).
  * `1444b93` — `_splitMeasure(raw)` режет серверный `measure`
    на префиксное число (`1`, `1.5`, `1,5`, `1/2`,
    `\u00BC`–`\u215E`) и хвост-единицу — раньше всё уходило в
    `unit`, а `qty` в режиме edit оставался пустой.
  * `43562df` — `FavoritesPage` теперь форвардит `api` /
    `repository` в `RecipeDetailsPage`. `FavoritesStore.list`
    джойнит только лёгкую `recipes`, инструкции лежат в
    `recipe_bodies` и тянутся ленивым `getInstructions` уже на
    деталях; без репозитория FutureBuilder инструкций
    проваливался и блок «Instructions» пропадал.
  * `af3e5a9` — `RecipeListLoader` ловил `setState() called when
    widget tree was locked`. Виноват был
    `_onActiveDetailsChanged` — `activeDetailsCount` декрементится
    из `RecipeDetailsPage.dispose` (фаза unmount), а listener
    синхронно дёргал `_onLangChanged` → `setState`. Завернули
    отложенный retranslate в `scheduleMicrotask`.
  * `13db16f` — `RecipeDetailsPage` принимает `originTab` (по
    умолчанию `AppNavTab.recipes`); `FavoritesPage._openDetails`
    передаёт `AppNavTab.favorites`, чтобы при открытии рецепта
    из «Избранного» в нижней навигации подсвечивался именно
    favorites-таб.

* **Backend** (`mahallem_ist`, commit `248a646c`): при edit с
  загрузкой нового фото из неанглийского UI маршрут пишет
  одновременно `i18n.en` и `i18n[sourceLang]` с placeholder-ом
  `pending://upload` в `strMealThumb`, после чего грузит файл и
  патчит thumbnail через `updateUserMealThumb`. Раньше хелпер
  обновлял только `i18n.en.strMealThumb`, и `lookup?lang=ru`
  отдавал русскую локаль с placeholder-ом — на сохранённом
  рецепте фото пропадало. `updateUserMealThumb` переписан так,
  что новый URL раскатывается по всем ключам `i18n`, а не
  только по `SOURCE_LANG`.

## Автоопределение языка нового рецепта + i18n заголовка «Edit recipe»

**Date:** 2026-04-30

Полный разбор — [docs/recipe-source-language.md](recipe-source-language.md).

Два мелких фидбэка по фиче владельца:

1. Заголовок `AppBar` на `AddRecipePage` в режиме редактирования
   был хардкодом «Edit Recipe» — не переводился. Под полем
   имени висела подсказка «please enter in English», навязывающая
   пользователю чужой язык.
2. Сервер ожидал английский payload и складывал его как
   `i18n.en`, поэтому рецепт, созданный условным русскоязычным
   пользователем, не находился в автокомплите при `lang=ru`.

* **Flutter** (`otus_dz_2`, commit `9a128d9`): новый ключ
  `editRecipeTitle` во всех 10 локалях; геттер в фасаде `S`
  поверх slang; `AppBar.title` — тернарник
  `_isEdit ? s.editRecipeTitle : s.addRecipeTitle`. Подсказка
  `addRecipeEnglishHint` удалена из JSON и из UI.
* **Backend** (`mahallem_ist`, commit `a3d32083`):
  * `local_user_portal/utils/detect-language.js` — синхронная
    Unicode-эвристика (Cyrillic→ru, арабская графика с
    курдскими/персидскими дискриминирующими буквами→ku/fa,
    иначе ar; Latin→en).
  * POST `/recipes` и PUT `/recipes/:id` детектируют язык на
    `strMeal + strInstructions`, гонят draft через
    `translateRecipe(meal, sourceLang, 'en')` и пишут английскую
    версию как канон `i18n.en`. Оригинал кладётся в
    `i18n[sourceLang]`, чтобы `searchByName` находил рецепт и в
    родном скрипте — `searchByName` уже перебирает все ключи
    `jsonb_object_keys(i18n)`, отдельная индексация не нужна.
  * `createUserMeal` / `updateUserMeal` получили опциональный
    `{ extraI18n }`: мерджит дополнительные локали в общий jsonb
    `i18n`, форсит `strMealThumb` из английского draft.
  * Падение перевода не валит запрос — draft уходит в БД как
    есть, перевод выполняется лениво при первом чтении.

**Smoke-тест:** POST `Плов` → запись `1000005` с
`i18n.en="PILAF"` и `i18n.ru="Плов"`; `/recipes/search?q=плов&lang=ru`
возвращает `1000005` в выдаче рядом с TheMealDB-овскими
`53083/53263`.

## Owner edit/delete + бэкап рецептов на mahallem

**Date:** 2026-04-30

Владелец рецепта (создавший его на этом устройстве) теперь видит
две круглые кнопки в левом верхнем углу фотографии на
`RecipeDetailsPage`: 🗑 — удалить, ✏ — редактировать. Полный разбор —
[docs/owner-edit-delete.md](owner-edit-delete.md).

* **Flutter** (`otus_dz_2`, commit `72f595f`): таблица
  `owned_recipes` (sqflite v6→v7) + `OwnedRecipesStore`; шина
  `recipeDeletedNotifier` / `recipeUpdatedNotifier`; `RecipeApi`
  получил `updateRecipe` / `updateRecipeWithPhoto` / `deleteRecipe`;
  `AddRecipePage` поддерживает режим редактирования (prefill +
  `PUT /recipes/:id`); `RecipeListPage` и `FavoritesPage` слушают
  шину и обновляют свои списки; удаление снимает рецепт из
  избранного во всех локалях.
* **Backend** (`mahallem_ist`):
  * `88074a61` — `PUT`/`DELETE /recipes/:id` с floor-id guard
    (`id >= RECIPES_USER_MEAL_ID_FLOOR`), multipart-фото грузится
    в bucket `recipe-photos`.
  * `d45c8c2b` — `RECIPES_USER_MEAL_ID_FLOOR` объявлен в
    `docker-compose.yml` (default `1000000`).
  * `ca7d3b04` — бэкап/рестор пользовательских рецептов, чтобы
    они переживали `go-clean`: `backupRecipe()` пишет в
    `/app/backups/realtime/recipes.jsonl` на каждый POST/PUT/DELETE;
    `restoreRecipes()` + `restoreRecipePhotos()` подняты в
    `restoreAll()` админ-контейнера (по образцу
    `restoreReviews` + `restoreJobPhotos`); `exportStorageObjects`
    в `snapshot-export-service.js` теперь включает bucket
    `recipe-photos`, чтобы 3-часовые снапшоты покрывали и
    метаданные `storage.objects` для фото рецептов.

**Догон-фиксы UI:**
* `OwnedRecipesStore.ensureLoaded()` бэкфилит реестр всеми
  существующими записями `recipes` с `id >= 1_000_000` — иначе
  рецепты, созданные до v7-миграции, не получали owner-кнопок.
* `FavoritesStore.idsForLang()` лениво триггерит `ensureLoaded()`
  для запрошенного языка, плюс `RecipeListLoader` прогревает
  избранное для текущего `appLang.value` сразу после открытия
  БД — чтобы при старте бейджи рисовали залитое сердце на
  ранее сохранённых карточках, а не контурное.

**Тесты:** `flutter analyze` — без issues; `flutter test` —
прежние две unrelated regressions в `recipe_repository_test.dart`
остаются (флаки от порядка тестов, не связаны с фичей).

## AddRecipePage: догон-фикс safe-area при добавлении ингредиента

**Date:** 2026-04-30

После первого фикса (`SafeArea(top: false)` + auto-favorite,
commit `1a20e05`) пользователь сообщил, что safe-area-баг не
полностью устранён: при нажатии «+» в строке ингредиента новая
строка появляется ниже viewport-а, а кнопка «Сохранить» уходит
под клавиатуру.

Корни — два, оба про скролл:
* ListView не подкручивался после `setState` — новая строка
  оставалась за нижним краем.
* `padding` был статическим (`EdgeInsets.all(AppSpacing.lg)`) и
  не учитывал `MediaQuery.viewInsets.bottom`. `SafeArea` покрывает
  `viewPadding`, но не `viewInsets` клавиатуры — отсюда «форма
  убегает под клавиши».

Фикс в [recipe_list/lib/ui/add_recipe_page.dart](../recipe_list/lib/ui/add_recipe_page.dart):
* `ScrollController _scrollController` пробрасывается в `ListView`.
* После `_addIngredientRow` `addPostFrameCallback` → `animateTo(
  maxScrollExtent, 220ms, easeOut)`.
* Bottom padding ListView-а считается как
  `AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom`.

Подробности — [docs/add-recipe-visibility.md](add-recipe-visibility.md)
(раздел «Догон-фикс»).

## AddRecipePage: SafeArea + видимость нового рецепта

**Date:** 2026-04-30

Два дефекта по фидбеку пользователя; полный разбор —
[docs/add-recipe-visibility.md](add-recipe-visibility.md).

* **Safe-area:** body `AddRecipePage` уезжал под home-indicator на
  iPhone — кнопка «Сохранить» и поле Instructions срезались
  системным жестом. Фикс: обернули body в `SafeArea(top: false, …)`
  (AppBar уже занимает верхний inset). Боковые inset-ы тоже
  включены — для landscape с notch.
* **Видимость нового рецепта:** после сохранения карточка
  появлялась только на главной (через `Navigator.pop` результат)
  и только при сохранении из главной; в избранном её не было
  никогда. Сервер исправно записывал рецепт и запускал ленивый
  translation-cascade, но UI этого не показывал. Фикс: ввели
  глобальную шину `newRecipeCreatedNotifier` (новый файл
  `lib/data/recipe_events.dart`), `AddRecipePage._save` после
  успешного `createRecipe(...)` дополнительно: (а) авто-помечает
  рецепт избранным в текущем языке через
  `favoritesStoreNotifier.value?.add(...)` — `saved_at = now()`
  кладёт карточку наверх вкладки «Избранное», (б) публикует
  событие в шину. `RecipeListPage` слушает шину и вставляет
  карточку в начало `_displayed` независимо от того, с какой
  страницы был открыт `AddRecipePage`.

**Тесты:** `flutter test` — те же 79 проходят, две прежние
unrelated regressions в `recipe_repository_test.dart`
(см. предыдущую запись) остаются.

## Favorites: добавлены FAB-ы прокрутки наверх и «новый рецепт»

**Date:** 2026-04-30

Запрос: «can you add the same fabs as on the main list to the
favorites list?». На главной ленте уже есть две плавающих кнопки —
scroll-to-top (справа) и add-recipe (слева). На странице
`FavoritesPage` их не было; пользователю приходилось скроллить
длинный список руками и возвращаться на главную, чтобы добавить
рецепт.

* `recipe_list_page.dart`: классы `_ScrollToTopFab` и `_AddRecipeFab`
  стали публичными (`ScrollToTopFab`, `AddRecipeFab`), чтобы
  переиспользовать их без копипасты. Все колл-сайты обновлены.
* `recipe_list_page.dart`: при переходе на вкладку «Избранное»
  теперь пробрасываются `api` и `repository`
  (`FavoritesPage(api: widget.api, repository: widget.repository)`),
  без `const`.
* `favorites_page.dart`: конструктор принимает опциональные
  `RecipeApi? api` и `RecipeRepository? repository` — это
  обратно совместимо с тестами, которые конструируют
  `FavoritesPage()` без аргументов.
* `favorites_page.dart`: `ScrollController _scrollController`,
  слушатель `_onScroll` показывает/прячет FAB при `offset > 200`,
  тело страницы обёрнуто в `Stack` с `Positioned.fill` контентом
  и двумя FAB-ами в нижних углах с отступом `AppSpacing.lg`.
  `AddRecipeFab` рендерится только когда `widget.api != null`
  (в холодных юнит-тестах api не пробрасывается).
* `_openAddRecipe(context)` — push `AddRecipePage(api, repository)`,
  возврат рецепта не нужен: `favoritesStoreNotifier` сам перерисует
  список, когда пользователь поставит сердце на странице деталей.

**Тесты:** `favorites_page_test.dart` + `favorites_survives_reload_test.dart`
проходят (6/6) — благодаря необязательным параметрам
конструктора `FavoritesPage()` совместимость не сломана.

**Commit:** `691e93b`.

## Reload «висит навсегда»: timeout, whenComplete, расширенные кэш-капы

**Date:** 2026-04-30

После релиза favorites пользователь сообщил: «нажимаю reload в
шапке — спиннер крутится 5+ минут». Подробный разбор —
`docs/reload-hang-after-favorites.md`.

* **Не виновата favorites:** диф `7b478ec..27b862e` показал,
  что сама фича reload-пайплайн не трогает. Корень — три
  совпавших фактора: (а) аддитивная миграция v5→v6 теперь
  сохраняет кэш между релизами, (б) LRU-эвикция выгрызает
  «дыры» в `recipes` ниже `categoryCacheThreshold` и reload
  проваливается в `_seedFromCategories` → 14 последовательных
  `/filter/c?lang=ru&full=1`, (в) production-сервер деградировал
  по переводам (Gemini timeout, publicLT 429), отвечает по 30–60 c
  на категорию.
* **Фикс reload-пайплайна** в `recipe_list_loader.dart`:
  - `_runLoad(forceReseed: true).timeout(Duration(seconds: 60))`
    — общий бюджет на reload.
  - `.whenComplete(() => reloadingFeed.value = false)` —
    спиннер гарантированно тухнет в любом исходе. Раньше сброс
    был только в `.then`/`.catchError`; если future не
    разрешался — спиннер крутился вечно.
  - `widget.api.filterByCategory(cat).timeout(Duration(seconds: 12))`
    в `_seedFromCategories`: одна медленная категория не
    утаскивает весь бюджет.
* **Кэш-капы** в `recipe_repository.dart`:
  - `kDefaultByteCap`: 64 MB → 256 MB,
  - `cap` (rows): 8000 → 20 000.
  С аддитивной миграцией кэш живёт постоянно; старый бюджет
  64 MB вытесняется слишком быстро, оставляя категории ниже
  порога. С новыми капами полная лента в 10 языках +
  избранное + хвост ранее просмотренных укладывается без
  частой эвикции, и reload отвечает из кэша.
* **Тесты:** 5 favorites-survival + reload-ticker зелёные;
  `default caps` обновлён под новые значения.

## Избранное: бейдж сердца, страница favorites, локальный поиск

**Date:** 2026-05-02

Реализована фича «избранное» из `docs/spec/favorites.md` /
`todo/15-favorites.md`. Избранное хранится по языку — рецепт,
добавленный в RU, не показывается на EN, и наоборот.

* **Chunk A — БД и стор.** `recipe_list/lib/data/local/recipe_db.dart`:
  `kRecipeDbSchemaVersion` поднята до 6, добавлена таблица
  `favorites(recipe_id, lang, saved_at)` c составным PK + индексом
  `idx_favorites_lang_saved_at`. Миграция v5→v6 — additive
  (`applyFavoritesSchema`), кэш рецептов сохраняется.
  `recipe_list/lib/data/repository/favorites_store.dart` — обёртка:
  кэш id-шников по языкам в памяти + ValueListenable, INNER JOIN
  с `recipes` для `list()`, `orphanIds()` для тел, удалённых
  LRU-eviction. Глобальный `favoritesStoreNotifier` пробрасывается
  в UI через `RecipeListLoader._defaultRepoBuilder`.
* **Chunk B — бейдж на карточке.** В `recipe_card.dart` добавлен
  `FavoriteBadge` (top-right, симметрично YouTube-бейджу): тап
  переключает `Icons.favorite_border` ↔ `Icons.favorite` (зелёный
  `AppColors.primary`), пишет в `FavoritesStore` на текущем
  `appLang`. Без стора рендерится outlined и `onTap == null`.
* **Chunk C — бейдж на странице деталей.** Hero-image обёрнут
  в `Stack`; тот же `FavoriteBadge` повешен top-right. Реюз
  виджета из `recipe_card.dart`.
* **Chunk D — таб «Избранное».** Новый `lib/ui/favorites_page.dart`:
  `SearchAppBar` c флагом `disableLangAndReload` (через расширенный
  `AppPageBar`) — кнопки переключения языка и reload показываются
  faded (`Opacity 0.38`) и не реагируют на тап (`IgnorePointer`).
  Поиск работает только локально по `recipe.name` (case-fold
  substring), без обращения к API. Empty / no-matches placeholder
  через slang `s.favoritesEmpty` (10 локалей) и `s.searchNoMatches`.
  Bottom-nav таб favorites пушит страницу из `RecipeListPage`.
* **Chunk E — гарантии и логи.** Регрессия
  `test/favorites_survives_reload_test.dart`: favorite живёт при
  переоткрытии БД; полное удаление `recipes` (имитация LRU-evict
  при reload) не трогает `favorites`, id остаётся в `orphanIds`.

`flutter test` зелёный по новым тестам (favorites_store, миграция
v5→v6, recipe_card_favorite, recipe_details_favorite, favorites_page,
favorites_survives_reload). Два пред-существующих фейла в
`recipe_repository_test.dart` не связаны с изменениями.

---

## Шапка экрана: единый стиль 40×40 для back / reload / flag / lang

**Date:** 2026-04-30

Косметика общего `AppPageBar`. Все четыре действия в шапке теперь
делят один визуальный язык: круги 40×40 с шагом `AppSpacing.sm`
(8 px) между ними.

* `recipe_list/lib/ui/lang_icon_button.dart`: флаг теперь круглый
  40×40 (`ClipOval` + `BoxFit.cover`) вместо прежнего 24×16
  `ClipRRect` со скруглением 2 px — флаг визуально парный с
  лейбл-кружком языка. Внешний горизонтальный padding снят: зазор
  между кнопками задаёт родительский `Row`/`AppBar`.
* `recipe_list/lib/ui/reload_icon_button.dart`: внешний padding
  снят, добавлен `BorderSide(width: 1, color: Colors.black)` на
  `CircleBorder` — у muted-кружка теперь явная граница.
* `recipe_list/lib/ui/app_page_bar.dart`:
  * Стандартный `IconButton` со «стрелкой назад» заменён на тот же
    40×40 `Material` + `CircleBorder` 1 px чёрный + `surfaceMuted`
    fill + глиф `chevron_left`, что и у reload. `leadingWidth = 56`
    отбивает кружок от края экрана на `AppSpacing.sm`.
  * Между reload и lang добавлен `SizedBox(width: AppSpacing.sm)`,
    когда оба видимы, — итоговая тройка справа (reload · flag ·
    lang) идёт с равным шагом.

`flutter analyze` без замечаний.

---

## Details-page lang cycle: bound latency, short-circuit dead tiers, defer background retranslate

**Date:** 2026-04-30

Bug: открыть рецепт (например, Borscht) с UI на итальянском, нажать
флаг турецкого на странице деталей. Спиннер крутится 3–4 минуты,
затем страница рендерится с турецким UI и **итальянским контентом**.
Flutter logs: `DioException ... status code 504`.

**Root cause.** При смене `appLang.value` срабатывают два слушателя
одновременно: `RecipeDetailsPage._onLangChanged` (фокусный
`/lookup` одного рецепта) и `RecipeListLoader._onLangChanged`
(`_retranslate` всей ленты, ~200 рецептов, 8-way parallel). Под
капотом обоих — один Node-процесс. Когда MyMemory и публичный
LibreTranslate в 429-burst (типично в проде), каждое предложение
проваливается в локальный self-hosted LibreTranslate, который
CPU-насыщается выше ~2 in flight (видели ~170s/sentence). Пока ~100
list-feed lookup'ов крутят очередь локального LT, фокусный
details-`/lookup` ждёт коннекта; nginx режет апстрим по
`proxy_read_timeout` и возвращает 504. Подробности в
[docs/details-lang-cycle-504.md](details-lang-cycle-504.md).

**Семь скоординированных правок** (см. todo/14):

Server (`mahallem_ist@ded65274`):
1. `translateLongField`: жёсткий 25 s-deadline на всё поле; по
   таймауту возвращаем исходник uncached.
2. `translateLongField`: `pLimit(2)` на fan-out предложений
   (был `Promise.all`). Локальный LT перестаёт CPU-душиться.
3. MyMemory + публичный LibreTranslate: 60-секундный cool-down
   после первого 429/403/5xx — следующий вызов в окне отдаёт
   `exhausted` за O(1), не платя 10/12 s timeout.
4. nginx `proxy_read_timeout` 240 → 300 s для `/recipes`
   (defense-in-depth позади (1)).

Client (`recipe_list`):
5. `RecipeDetailsPage._onLangChanged`: при провале фокусного
   `/lookup` повторяем запрос на `en` — пользователь видит
   когерентный английский под новым флагом, а не «застывший»
   итальянский. Зеркалит fallback из `_retranslate` (47c942c).
6. Глобальный `activeDetailsCount: ValueNotifier<int>`,
   инкремент/декремент в details `initState`/`dispose`.
   `RecipeListLoader._onLangChanged` пропускает
   `_retranslate` целиком, если `activeDetailsCount > 0` —
   откладывает в `_pendingBackgroundLang`. Когда счётчик падает
   до нуля и язык всё ещё расходится — добивает retranslate.
7. `feed_config.dart`: `translateConcurrencyBackground = 2`.
   Воркеры `_retranslate` дополнительно проверяют счётчик и
   выходят, если пользователь толкнул details mid-run.

**Что НЕ покрыто** (латентные риски): TheMealDB outage; Gemini
quota fully exhausted; локальный LT OOM; гонка двух одновременных
lookup'ов одного и того же id. Зафиксировано в docs/details-lang-cycle-504.md.

**Validated:** `flutter analyze` clean; node tests 18/20 baseline
сохранена.

**Deploy:** `mahallem_ist@ded65274` — pending
`docker compose up -d --build user-portal` + `nginx -s reload`
на 72.61.181.62.

---

## Turkish residue: drop `tr` from echo gate, English fallback on lookup miss

**Date:** 2026-04-29

Bug: при переключении на турецкий лента почти всегда оставалась
итальянской (последний посещённый язык). Воспроизводилось каждый
раз, не «иногда».

**Root cause #1 — `tr` в LATIN_TARGET echo gate (server).**
`_isEchoTranslation` в
[`mahallem_ist/local_user_portal/routes/recipes.js`](https://github.com/novogod/mahallem_ist/commit/004d473b)
для языков `LATIN_TARGET = {es, fr, de, it, tr}` отбрасывал перевод,
если в нём встречался любой word-boundary англизм из списка
(`turn|stir|combine|...`). Турецкий MT-вывод регулярно содержит эти
маркеры даже когда 90% текста переведено корректно (живой пример:
`52765` → «turn enchilada caserole on…» — `turn` ловится).
Перевод **отдаётся клиенту, но не персистится** — следующий заход
снова идёт в Gemini (2–8 c). Кэш никогда не прогревается.

Фактическое покрытие до фикса: tr=311/599 (52%) против en=599 (100%),
de=573 (96%). Половина ленты на каждом заходе требовала свежего
перевода.

**Root cause #2 — таймауты + previous-language fallback (client).**
`_retranslate` в [`recipe_list/lib/ui/recipe_list_loader.dart`](https://github.com/AndreyProkhorov/otus_dz/commit/47c942c)
имел `perCallTimeout = 12s` и `deadline = 120s` при concurrency 8.
При spike-латенции Gemini под параллельной нагрузкой отдельные
рецепты упирались в 12-секундный таймаут → в массиве `translated[]`
оставалась карточка из `prev.recipes` (Italian). Пользователь видел
ровно «остаток предыдущего языка».

**Fix:**
- Server (`004d473b`): `LATIN_TARGET = {es, fr, de, it}` — `tr`
  убран. Перевод с английскими маркерами теперь персистится и в
  следующий раз отдаётся из кэша мгновенно. Ожидаемое покрытие
  через день браузинга — ≥95%.
- Client (`47c942c`): после неудачного `lookup(id, target_lang)`
  пробуем `lookup(id, en)` и подставляем английский. Английский
  100%-покрыт серверно, fallback почти никогда не падает.
  Также `perCallTimeout: 12s → 25s`, `deadline: 120s → 240s`.

**Verified live:** `id=52765` (раньше отвергался) персистится после
одного `/lookup`. Покрытие сразу нудьнуло 311 → 317 на проверочном
трафике.

**Deploy hiccup:** первая попытка перезапуска контейнера через `docker
run` упала на отсутствующем `.env`. Откатились на `docker compose up
-d --build user-portal` из `local_docker_admin_backend/` — service
был недоступен ~30 c.

## Recipe search: substring across locales, always upstream

**Date:** 2026-04-29

Bug: пользователь видит «Polish Chicken Soup» в ленте, набирает
`soup` в search-баре — автокомплит пуст и в локальном кэше, и в
ответе сервера. Две причины, обе закрыты одним проходом.

**Root cause #1 — server SQL prefix-only + lang-gated.**
`RecipeRepository.searchByName` в [`mahallem_ist/local_user_portal/routes/recipes.js`](https://github.com/novogod/mahallem_ist/commit/b1f02b11)
выбирал `LOWER(i18n->'<langKey>'->>'strMeal') LIKE 'q%'`. Для
русского клиента `langKey='ru'`, а у TheMealDB-рецепта, который ещё
никто не открывал на ru, `i18n.ru` отсутствует → выражение даёт
NULL → строка отфильтровывается **до** того, как `_ensureLang`
успевает перевести.

**Root cause #2 — upstream только при cache miss.**
TheMealDB опрашивался только если локальный кэш вернул `<5` рядов;
свежие upstream-only рецепты не попадали в подсказки.

**Fix server (mahallem_ist `b1f02b11`):**

```sql
SELECT id, i18n FROM recipes
 WHERE EXISTS (
   SELECT 1 FROM jsonb_object_keys(i18n) k
   WHERE LOWER(i18n->k->>'strMeal') LIKE $1 ESCAPE '\'
 )
 ORDER BY popularity DESC, fetched_at DESC LIMIT 20
```

- `LIKE '%q%'` (substring) вместо `LIKE 'q%'` (prefix).
- `EXISTS` по `jsonb_object_keys(i18n)` — матч по любой
  сохранённой локали, так что английский рецепт находится при
  русском UI и наоборот.
- Upstream `search.php` теперь дёргается **всегда** (TheMealDB
  English-only, для не-латиницы просто вернётся пусто — безвредно).
- `tests/recipes.test.js`: фейк-БД получил handler для нового SQL,
  два кейса `searchByName` обновлены под always-upstream + substring
  фикстуры. 18/20 (пара echo-gate baseline остаётся).

**Fix client (otus_dz `5f49577`):**

`lib/ui/recipe_list_page.dart`: убран post-фильтр
`startsWith(prefix)` поверх ответа сервера — доверяем серверной
выборке. Локальный fallback `_localPrefix` теперь использует
`contains` вместо `startsWith` (имя оставлено для совместимости).

**Deploy & smoke:**

```text
$ ssh prod 'git pull && docker compose up -d --build user-portal'
$ curl -s 'https://mahallem.ist/recipes/search?q=soup&lang=ru' | jq
hits=20
  - Красный гороховый суп
  - Росол (польский куриный суп)   ← Polish Chicken Soup
  - …
```

## Gemini re-enable on prod

**Date:** 2026-04-29

В `local_docker_admin_backend/docker-compose.yml` сервис
`user-portal` имел `DISABLE_GEMINI: "1"` как kill-switch на время
квотных проблем. Снят (`mahallem_ist 1ea0eef5`), `GEMINI_API_KEY`
оставлен как есть; `docker compose up -d user-portal` на проде,
проверка `docker exec` показала `DISABLE_GEMINI=[]` и
`GEMINI_API_KEY=<set>`, в логах нет kill-switch warning. Tier-6
переводы снова работают для нелатинских локалей.

## Add-recipe form: ingredient row UX polish

**Date:** 2026-04-29

Серия мелких правок строки ингредиента в
`recipe_list/lib/ui/add_recipe_page.dart`, чтобы placeholder /
helperText не переполняли узкие колонки на телефонах.

- `b3ddf3a`: helperText layout fix — overflow ellipsis вместо
  visual overflow.
- `f1600d0`: helper-стиль уменьшен до 10 sp, height 1.2,
  `AppColors.textSecondary`.
- `4438c20`: `qty:unit = 7:3`, новый ARB-ключ
  `addRecipeIngredientQtyShort` (10 локалей, ru: «Кол.»).
- `cdfe418`: количество ужато ×4 (`name flex 11`, qty `flex 3`,
  чтобы соответствовать realistic input «100»).
- `4fe6c73`: финальная форма `name:qty:unit = 10:3:3` с
  hintText на всех трёх (`Sugar/100/g`-style examples), helperText
  только на name (full label) и qty («Кол.»). 3 новых ARB-ключа
  (`addRecipeIngredientNameHint`, `addRecipeIngredientQtyHint`,
  `addRecipeIngredientMeasureHint`) во все 10 локалей; slang
  пере-сгенерирован.

## Recipe photo upload (file picker → storage-api → imgproxy)

**Date:** 2026-05-13

Закрыта «следующая фаза» add-recipe: теперь форма принимает фото
файлом (камера/галерея), а не URL-строкой. План — все 14 чанков
из [`todo/recipe_photo_upload.md`](./todo/recipe_photo_upload.md);
prod-redeploy (chunk 15) откладывается до явного запроса.

**mahallem_ist (chunks 1–8):**

- Миграция `20260429_create_recipe_photos_bucket.sql` — `storage.buckets`
  row + 3 RLS-политики (public read, authenticated write/delete);
  смонтирована в `local_docker_admin_backend/docker-compose.yml`
  (`09.76-recipe-photos-bucket.sql`).
- `utils/storage-upload.js`, `utils/backup-service.js` — ветка
  `recipe-photos` в `backupStorageObjectEntry` + `backupRecipePhotoFile`,
  чтобы новые файлы попадали в backup-кэш go-clean.
- `routes/recipes.js`: `recipePhotoUpload` (multer disk-storage,
  10 MB, jpeg/png/webp), `RecipeRepository.updateUserMealThumb`,
  multipart-ветка `POST /recipes` (rollback-стратегия:
  insert → upload → patch; при провале upload — оставляем
  `pending://upload`-плейсхолдер и 502). `multipartLimiter` 5 req/min
  отдельно от общего limiter (он раздут до 1200 req/min под list-loader).
- DI-хук `opts.uploadToStorage` на `recipesRoute` — позволяет тестам
  подменять storage без сети. Tests suite 18 / 2 baseline.
- `lib/jobs/cleanup-orphan-recipe-photos.js` — еженедельный sweep
  файлов без ссылок из `recipes.i18n.en.strMealThumb` (старше 24 ч),
  hooked в `server.js` рядом с warmup. Disable
  `RECIPES_PHOTOS_CLEANUP_DISABLED=1`.

**otus_dz (chunks 9–13):**

- `pubspec.yaml`: `image_picker ^1.0.7`, `flutter_image_compress ^2.2.0`.
  iOS Info.plist + AndroidManifest permissions. `flutter pub get`.
- `lib/utils/photo_downscaler.dart` — `downscaleForUpload(XFile)`:
  1600×1600 q80 JPEG, EXIF strip; second pass 1280×1280 q60 если
  >5 MB; кидает `StateError('photo_too_large')`.
- `lib/data/api/recipe_api.dart` — `createRecipeWithPhoto(Recipe, File)`
  собирает `FormData{meal: jsonEncode(_mealToJson), photo: MultipartFile}`
  и слепит на тот же `''`-эндпоинт. JSON-only `createRecipe` остался
  как fallback.
- `lib/ui/add_recipe_page.dart` — `_PhotoPicker` (160×160 dp превью,
  bottom-sheet «Камера / Галерея», SnackBar при denied/too-large).
  `_save()` диспатчит на multipart, если `_pickedPhoto != null`. URL
  TextField остался только под `kIsWeb`.
- `lib/utils/imgproxy.dart` — `imgproxyUrl(src, w, h)`:
  `<origin>/imgproxy/insecure/resize:fit:w:h:0/<base64url(src)>`.
  Применён в `RecipeCard` (600×338) и `RecipeDetailsPage` (1200×675).
- 7 новых i18n-ключей + `a11y.addRecipePhotoPicker` × 10 локалей,
  slang regenerated. Tests `flutter test --no-pub`: 59 / 2 baseline,
  `flutter analyze` чистый.

**Production redeploy (chunk 15, 2026-04-29):**

- Step 0: prod (`72.61.181.62`, `/root/mahallem/mahallem_ist`) был
  чистым на `79daf8b3`; локально запушены 7 коммитов до `9be75b50`.
- `git pull origin main` на хосте (fast-forward).
- Миграция применена через `docker exec -i mahallem-db psql -U postgres
  < .../20260429_create_recipe_photos_bucket.sql` →
  `INSERT 0 1` + 3 политики (`Public can view recipe photos`,
  `Service role can upload to recipe-photos`,
  `Service role can delete recipe photos`).
- `docker compose up -d --build user-portal` — образ пересобран,
  контейнер пере-recreated и стартанул чисто.
- Smoke: `curl -L --post301 --post302 -F meal=… -F photo=@… https://mahallem.ist/recipes`
  → `201 {"id":1000000,"meal":{…,"strMealThumb":"/storage/v1/object/public/recipe-photos/recipes/1000000/…jpg"}}`.
  `HEAD` на тот же URL → `200 image/jpeg`, `content-length` совпадает
  с исходником (124423 байт). Тестовая строка и файл удалены сразу
  после проверки.

**Follow-up: nginx trailing-slash fix (mahallem `ca0c895b`):**

В первичном smoke-тесте `POST https://mahallem.ist/recipes` уходил
в 301 (`Location: http://mahallem.ist:4001/recipes/`) — проблема в
двух-уровневом nginx: внешний (host) терминирует TLS и проксирует
на `127.0.0.1:4001`; внутренний (`mahallem-nginx`, контейнер) имел
`location /recipes/` со слешем, и nginx авто-301-ил `/recipes` →
`/recipes/`. Клиенты по RFC 7231 даунгрейдят `POST → GET` на 301,
плюс редирект собирался абсолютным URL'ом из внутреннего listener'а,
светил `:4001` и сбрасывал scheme на `http`.

Исправлено в `local_docker_admin_backend/nginx/conf.d/user-portal.conf`:

- `location /recipes/` → `location /recipes` (без авто-редиректа,
  по-прежнему ловит `/recipes/page`, `/recipes/lookup/:id` и пр.);
- `absolute_redirect off; port_in_redirect off;` на server-scope —
  любые будущие авто-редиректы будут относительными и сохранят
  публичный TLS-хост.

Деплой: `git pull` на хосте + `docker exec mahallem-nginx nginx -t`
+ `nginx -s reload` (перезагрузка nginx без рестарта). Re-smoke
плоским `curl -X POST` (без `--post301`) → 201 с публичным URL.

**Follow-up: align object key with avatars/job-photos (mahallem `edd38526`):**

Изначально я генерировал ключ как `recipes/<id>/<6-byte-hex>.jpg`,
тогда как в проекте давно действует свой паттерн (см.
`project_docs/AVATAR_PHOTOS_FLOW_DOCUMENTATION.md` и
`project_docs/JOB_PHOTOS_FLOW_DOCUMENTATION.md`):

```
avatars/<userId>/avatar_<timestamp>_<random>.jpg
job-photos/<jobId>/<role>_<timestamp>_<random>.jpg   # role=problem|resolution
```

Привёл `recipe-photos` к той же форме:

```
recipes/<id>/photo_<timestamp>_<random6>.<ext>
```

Что это даёт: tooling/audit-grep'ы по `_<ts>_<rand>` теперь ловят
и recipe-photos; объекты сортируются по времени без джойна на
`storage.objects.created_at`; role-префикс `photo_` оставляет
место под `cover_`/`step1_` если в будущем понадобится несколько
фото на рецепт. Cleanup-запрос подходил под bucket-уровень
(`LIKE '%/recipe-photos/%'`) и переход не задел.

Re-smoke: `POST https://mahallem.ist/recipes` → 201,
`strMealThumb=/storage/v1/object/public/recipe-photos/recipes/1000000/photo_1777507021938_8b1018.jpg`.

**Docs catch-up (otus_dz `3bddcee`):**

`docs/recipe-photo-upload.md` приведён в соответствие с задеплоенным
кодом — оригинальный draft показывал `recipes/<id>/<hex>.jpg`,
теперь TL;DR-шаг 3 и пример в §2.2 описывают актуальную форму
ключа (`Date.now()` + 6-hex random + `safeExt` allowlist).

Добавлен новый §2.2.1 «Форма ключа объекта (object-key convention)»
с кросс-bucket-таблицей (avatars / job-photos / recipe-photos),
полевым разбором (`<entityId>`, `<role>`, `<unix-ms>`, `<random>`,
`<ext>`), что **не** кладётся в ключ (PII, HEIC) и зачем — это
канонический ответ на вопрос «как мы именуем объекты в storage»,
чтобы при добавлении следующего bucket не пришлось снова всё
вспоминать. В `docs/todo/recipe_photo_upload.md` чанк 5 acceptance
example обновлён под новый формат URL и ссылается на §2.2.1.

## Add-recipe: fix overflowing ingredient row labels (otus `b3ddf3a`)

**Date:** 2026-04-29

Симптом, увиденный на боевом устройстве: в форме «+ рецепт»
строка ингредиента (`name | qty | unit | № | +/−`) на узких
экранах сжимала qty/unit до ~80–100 dp; плавающий
Material-`labelText` («Кол-во», «Мера») не помещался и
обрезался троеточием, поле де-факто становилось безымянным.

Что сделал в [`_IngredientRowField`](../recipe_list/lib/ui/add_recipe_page.dart):

1. **Убрал колонку с номером строки** (целое 1…20). Сервер
   и так упорядочивает ингредиенты по индексу массива
   `i18n.<lang>.ingredients[]` — UI-номер ничего не нёс,
   только съедал ~24 dp ширины и мешал глазу.
2. **Перенёс подписи из `labelText` в `helperText`**
   (`helperMaxLines: 2`). Подпись стала мелким текстом *под*
   полем, не конкурирует за ширину инпута и спокойно
   переносится в две строки на длинных локализациях
   (немецкий, курдский). ARB-ключи
   (`addRecipeIngredientName/Qty/Measure`) переиспользованы
   как есть, без правок локалей.
3. Удалил неиспользуемый параметр `index` конструктора
   `_IngredientRowField` и его прокидку из `build()`.

`flutter analyze lib/ui/add_recipe_page.dart` → No issues.

## Add-recipe feature + Russian docs

**Date:** 2026-04-29

Добавлена пользовательская история «нажать `+` → заполнить форму →
сохранить рецепт». На главном экране вторая FAB-кнопка зеркально
прижата к левому нижнему углу (`Positioned(left:…)`), открывает
`AddRecipePage` (Form + 6 контроллеров, парсер ингредиентов
`name | measure` до 20 шт). После успеха клиент вызывает
`RecipeApi.createRecipe` (POST `/recipes` на mahallem-бэкенде; для
TheMealDB-бэкенда метод проваливает запрос с `StateError`),
зеркалит результат в sqflite через `RecipeRepository.upsertAll` и
вставляет рецепт в начало `_displayed` без полной перезагрузки
ленты.

### Клиент (`otus_dz_2`, main)

- **`5202acb`** — FAB `+` в `recipe_list_page.dart`, `AddRecipePage`,
  `RecipeApi.createRecipe`, `a11y.addRecipe` + 13 ключей формы во
  всех 10 локалях, slang regenerate, `docs/add-recipe-feature.md`,
  `docs/themealdb-add-recipe-investigation.md`.
- **`20064ae` / `fef22ff`** — переписаны оба doc-файла на русский
  для аудитории «преподаватель Flutter-школы Otus»; ASCII-диаграмма
  заменена на Mermaid `sequenceDiagram`.

### Сервер (`mahallem_ist`, main)

- **`ca6cd882`** — `RecipeRepository.createUserMeal(meal)`
  (id-floor `RECIPES_USER_MEAL_ID_FLOOR=1_000_000`, INSERT в
  `i18n.en`, eviction); `app.post('/recipes', …)` под существующим
  `limiter` + `authMiddleware`; 2 теста (id-allocation + reject
  without `strMeal`/`strMealThumb`).

### Исследование TheMealDB upstream

`docs/themealdb-add-recipe-investigation.md` — почему пользователь-
ские рецепты живут только в нашей Postgres + sqflite:

* у бесплатного v1 все эндпоинты GET-only;
* у v2 рекламная фраза «adding your own meals and images» без
  опубликованного контракта (PayPal-подписка + переписка);
* даже при наличии write-endpoint — не пытались бы (provenance,
  локали, юридика, обратимость);
* решение: `id ≥ 1_000_000`, отдаём через те же
  `/recipes/page|search|lookup`, перевод лениво через `_ensureLang`.

### Проверки

* `flutter analyze` — чисто.
* `flutter test --no-pub` — 56 / 2 (тот же baseline).
* `node --test tests/recipes.test.js` — 12 / 2 (тот же baseline +
  два новых теста зелёные).

### Что вынесено за рамки

Загрузка фото файлом (нужен object storage), edit/delete
(`POST /recipes` всегда выделяет новый id), премодерация,
production-redeploy mahallem.

---

## todo/01–13 + 99: full recipes-pipeline refactor

**Date:** 2026-04-29

Прошли все чанки из `todo/` последовательно (`flutter analyze` чисто
+ baseline тестов сохранён + push после каждого чанка). Базовые
pre-existing fails (`cache hit at threshold`, `network error empty
cache`, два English-residue теста на ноде) не трогались — они и были
в зелёной базе до серии.

### Клиент (`otus_dz_2`, ветка main)

- **todo/01 — `31d9a29`**: `RecipeRepository` defaults: byteCap
  64 MB, rowCap 8000.
- **todo/02 — `a849eba`**: `_runLoad` сохраняет предыдущую ленту
  при offline reload + SnackBar.
- **todo/03 — `b655b47`**: reload affordance — вращающаяся иконка
  + `LinearProgressIndicator` под `AppPageBar`.
- **todo/04 — `ad559f0`**: `FeedConfig` вынесен из
  `RecipeListLoader`, читает `--dart-define`.
- **todo/05 — `6b063c4`**: `pickCategoriesFor` помнит прошлый
  набор и избегает повторов между нажатиями reload.
- **todo/06 — `0411a10`**: streaming feed — `_publishPartialFeed`
  отдаёт переведённые порции по мере готовности.
- **todo/08 — `acabf46`**: `RecipeApi.fetchPage` + флаг
  `USE_BULK_PAGE` (по умолчанию выключено).
- **todo/11 — `8d6a0a4`**: per-language LRU partitioning — 60/40
  split active/others, batch=32.
- **todo/12 — `8404825`**: `recipes.instructions` вынесено в
  `recipe_bodies(id, lang)` + cascade trigger;
  `RecipeRepository.getInstructions(id, lang)`; `RecipeDetailsPage`
  лениво подгружает тело через `FutureBuilder` + shimmer.
  Schema v5.
- **todo/13 — `33812cb`**: опциональный `appReloadTicker` +
  `requestAppReload()`; `ReloadIconButton({bool global = false})`.

### Сервер (`mahallem_ist`, ветка main)

- **todo/07 — `901d8f7a`**: `GET /recipes/page?lang&offset&limit` —
  bulk endpoint поверх `RecipeRepository`.
- **todo/09 — `2640d8b1`**: L1 Redis cache
  (`lib/cache/redis-recipes.js`) — `getOrSet` cache-aside,
  fail-open; `recipeKey` / `filterKey` / `pageKey`; обёрнуты
  `/recipes/lookup/:id`, `/recipes/filter`, `/recipes/page`.
  Compose: `redis` сервис с
  `--maxmemory ${RECIPES_REDIS_MAXMEMORY:-1500mb}
  --maxmemory-policy allkeys-lru`, БД `/4`.
- **todo/10 — `a88083d9`**: `lib/jobs/warmup-recipes.js` —
  `runWarmup` (popularity DESC, concurrency=16) +
  `scheduleWarmupOnStart` запускается из `server.js` (skip при
  `WARMUP_ON_START=0`).
- **todo/99 — `ec1ddedf`**: rollback escape hatch —
  `REDIS_DISABLED=1` в `getOrSet` форсирует bypass без redeploy;
  `docs/recipes-rollout.md` для оператора.

### Проверки

```bash
# client
cd recipe_list && flutter analyze        # No issues
flutter test --no-pub                    # 53 pass, 2 baseline fail

# server
cd local_user_portal && node --test tests/**/*.test.js
                                         # 24 pass, 2 baseline fail
docker compose -f local_docker_admin_backend/docker-compose.yml config -q
                                         # ok
```

### Rollback levers (без redeploy)

- **`REDIS_DISABLED=1`** — `getOrSet` обходит Redis на каждом
  запросе.
- **`WARMUP_ON_START=0`** — пропускает прогрев при следующем
  рестарте.
- **`--dart-define=USE_BULK_PAGE=0`** — клиент возвращается на
  category fan-out.

---

## Reload button + categories/translation-buffer docs

**Date:** 2026-04-29

### Что сделано

1. В `AppPageBar.actions` появилась кнопка ⟳ «обновить ленту» слева от
   языковой кнопки. Соответствует дизайн-системе (40 dp,
   `CircleBorder`, фон `surfaceMuted`, иконка `Icons.refresh` цвета
   `primaryDark`). Видна только на экране списка
   (`SearchAppBar(showReload: true)` в `recipe_list_page.dart`); на
   деталях не показывается.
2. В `i18n.dart` добавлены глобальный `ValueNotifier<int>
   reloadFeedTicker` и хелпер `requestFeedReload()`. Кнопка
   инкрементирует тикер; `RecipeListLoader` слушает и зовёт
   `_runLoad(forceReseed: true)`, который пропускает ранний выход «в
   локальной БД ≥ 50 рецептов — отдай как есть» и снова прогоняет
   `_seedFromCategories(...)` со свежим случайным отбором 10 категорий.
   Запросы `/recipes/filter?c=<cat>&lang=…&full=1` идут к
   `mahallem-user-portal`, который дальше работает по штатному
   cascade `cache → glossary → MyMemory → public LT → local LT →
   Gemini` (Gemini сейчас отключён через `DISABLE_GEMINI=1`).
3. Локализация ключа `a11y.reloadFeed` для всех 10 локалей; slang
   перегенерирован (`dart run slang`).
4. Документация:
   - `docs/categories.md` — как сейчас собирается список категорий
     и что именно делает кнопка «обновить».
   - `docs/translation-buffer.md` — слой кэшей сейчас (Postgres
     `translation_cache` без ограничений + клиентский sqflite 5 MB / 2000
     строк) и рекомендации по запрошенному 1–1.5 GB FILO-буферу
     (Redis `allkeys-lru`, новый bulk endpoint `/recipes/page`,
     поднятие клиентского `byteCap` до 64 MB).

### Comprehensive check

- `flutter analyze` → no issues.
- `flutter test` → проходит 35/37; падают те же два теста, что были
  и до правок (`cache hit at threshold`, `network error empty cache
  offline=true`). К новой кнопке отношения не имеют.

### Файлы

- `recipe_list/lib/i18n.dart`
- `recipe_list/lib/i18n/*.i18n.json` (10 файлов)
- `recipe_list/lib/i18n/strings*.g.dart` (regenerated)
- `recipe_list/lib/ui/app_page_bar.dart`
- `recipe_list/lib/ui/search_app_bar.dart`
- `recipe_list/lib/ui/recipe_list_page.dart`
- `recipe_list/lib/ui/recipe_list_loader.dart`
- `recipe_list/lib/ui/reload_icon_button.dart` (новый)
- `docs/categories.md` (новый)
- `docs/translation-buffer.md` (новый)

### Сопутствующие правки (server-side, mahallem)

В этот же rev попадают (в отдельном репозитории `mahallem_ist`):

- `local_user_portal/utils/translate-recipe.js`: kill-switch
  `DISABLE_GEMINI=1` — пропускает Gemini-tier и Gemini fallback,
  оставляя `cache → glossary → MyMemory → public LT → local LT`.
- `local_docker_admin_backend/docker-compose.yml`: env-переменная
  `DISABLE_GEMINI: "1"` для контейнера `mahallem-user-portal`.

---

## i18n plural resolvers, Android back-callback, details lookup timeout, server rate-limit raise

**Date:** 2026-04-29

### Симптомы

1. `Resolver for <lang = tr> not specified!` (и аналогично для `ku`/`fa`/`ar`) —
   slang не имеет встроенных plural-резолверов для этих локалей, и приложение
   шумело предупреждениями при каждом форматировании множественного числа.
2. Android logcat: `OnBackInvokedCallback is not enabled for the application`.
3. На холодном языке детали рецепта не успевали приехать —
   `DioException [receive timeout] ... 0:01:00.000000`. Полная инструкция через
   Gemini не укладывалась в дефолтный `receiveTimeout=60s`.
4. После переключения языка списка `/lookup` отвечал `429 Too Many Requests` —
   серверный `express-rate-limit` пускал только 60 req/min/IP, а
   `recipe_list_loader` (8 параллельных воркеров × ~213 рецептов) выжигал
   окно до того, как пользователь открывал детали.

### Что сделано

- `lib/i18n.dart`: новая `_registerPluralResolvers()` зовётся один раз перед
  `LocaleSettings.setLocaleSync` и регистрирует `setPluralResolverSync` для
  `tr`/`ku` (oneOrOther), `fa` (`n<=1?one:other`) и полный CLDR-набор для
  `ar` (zero/one/two/few/many/other по `n%100`).
- `android/app/src/main/AndroidManifest.xml`: добавлен
  `android:enableOnBackInvokedCallback="true"` на `<application>` —
  системная подсветка свайпа «назад» теперь работает корректно и без шума.
- `lib/ui/recipe_details_page.dart`: `_onLangChanged` зовёт
  `api.lookup(..., timeout: const Duration(seconds: 120))` вместо дефолтных
  60s, чтобы холодный full-instructions перевод через Gemini успевал доехать.
- Сервер `mahallem-user-portal` (`local_user_portal/routes/recipes.js`):
  default `RECIPES_RATE_LIMIT` поднят с **60 → 1200 req/min/IP** и
  снабжён комментарием почему. Переменная окружения по-прежнему может
  переопределить значение. Файл задеплоен в контейнер
  (`docker cp` + `docker restart`); nginx upstream-таймауты на `/recipes/`
  уже были 240s, так что менять их не пришлось.

### Проверка

- Hot-restart на iOS-симуляторе: цикл по всем 10 локалям проходит без
  «Resolver for <lang ...> not specified!» и без 429 на `/lookup`.
- `docker logs mahallem-user-portal`: контейнер `healthy`, активные
  `translateBest [en→fa] via gemini`, кэш заполняется.
- `flutter test --no-pub`: остаются только два предсуществующих
  fail-теста (`cache hit at threshold`, `network error empty cache offline=true`),
  не связанные с этой задачей.

### Файлы

- `recipe_list/lib/i18n.dart`
- `recipe_list/android/app/src/main/AndroidManifest.xml`
- `recipe_list/lib/ui/recipe_details_page.dart`
- `mahallem_ist/local_user_portal/routes/recipes.js` (отдельный репозиторий)

---

## RTL/long-translation overflow on the list & details pages — added `AppMetrics` from `MediaQuery`

**Date:** 2026-04-29

### Симптом

На курдском (и в меньшей мере немецком) Flutter ругался
`A RenderFlex overflowed by 125/136 pixels on the right`:

- В карточке списка `_Badges` рендерился через `Row` с явным
  `SizedBox(width: AppSpacing.sm)` между чипами категории и кухни.
  Длинная курдская комбинация (например, «خواردن لە دەریا» +
  «ئیتالیایی») не помещалась в ширину карточки.
- На странице рецепта блок ингредиентов держал колонку «мера»
  фиксированной шириной `89` (`SizedBox(width: 89)`). Курдские
  меры («کاشوویەک»/«قاشوویەک نان…») вылазили за правую границу.

### Что нарушалось

Дизайн-система задавала размеры константами в пикселях («Figma 428»),
без учёта реальной ширины экрана и текстового масштабирования. Любой
длинный перевод (RTL, немецкий, французский) ломал лэйаут.

### Решение

1. Добавил класс **`AppMetrics`** в `recipe_list/lib/ui/app_theme.dart`.
   Источник правды — `MediaQuery.of(context)`. Поля:
   - `screenWidth`, `screenHeight`, `textScale`, `viewPadding` (raw);
   - `scale = screenWidth / 428` — коэффициент vs Figma-базовой;
   - `pagePadding = (screenWidth * 0.0374).clamp(12, 24)`;
   - `contentWidth = screenWidth - pagePadding * 2`;
   - `measureColumnWidth = (contentWidth * 0.26).clamp(72, 140)`
     — заменил магическое `89`. На 428-экране даёт ~96 px (с запасом),
     на узких сжимается, на широких — расширяется;
   - `iconSm/iconMd/iconLg` — пропорциональные доли с clamp.
2. **`recipe_card.dart`** `_Badges`: `Row` → `Wrap`
   (`spacing: sm`, `runSpacing: xs`). Длинные пары категория+кухня
   переносятся на вторую строку вместо overflow.
3. **`recipe_details_page.dart`** `_IngredientsBlock`:
   `SizedBox(width: 89)` → `SizedBox(width: AppMetrics.of(context).measureColumnWidth)`,
   `softWrap: true` на `Text(ing.measure)`. Курдские меры теперь
   переносятся внутри своей колонки.
4. **`test/recipe_repository_test.dart`** `_FakeApi.lookup`:
   обновил сигнатуру до `{AppLang? lang, Duration? timeout}` под
   текущий `RecipeApi.lookup` (стало required по invalid_override).

### Гарантии

- Все размеры, способные переполниться при длинных переводах,
  читаются через `AppMetrics.of(context)`, а не магические числа.
- `Wrap` гарантирует, что бейджи никогда не вызовут `RenderFlex
  overflow`.
- `clamp` ограничивает измерения разумными min/max — на iPad/больших
  экранах ничего не «разъедется», на iPhone SE ничего не схлопнется
  до нечитаемого.

### Файлы

- `recipe_list/lib/ui/app_theme.dart` — добавлен `AppMetrics`.
- `recipe_list/lib/ui/recipe_card.dart` — `_Badges` через `Wrap`.
- `recipe_list/lib/ui/recipe_details_page.dart` — `measureColumnWidth`.
- `recipe_list/test/recipe_repository_test.dart` — fake-сигнатура.

---

## Language switch hung minutes/forever — removed client residue retry, server read-side purge, added worker pool + deadline

**Date:** 2026-04-29

### Симптом

При переключении языка лоадер мог висеть 19+ минут (особенно `it`,
иногда `es`). Иногда показывал 100% и не уходил в список. Иногда
оставался в предыдущем языке (стейл-контент).

### Причины (несколько слоёв нарушений `docs/translation-pipeline.md`)

1. **Клиентский unbounded residue-retry** в `recipe_list_loader.dart`
   и `recipe_details_page.dart` — `while (true)` с эвристикой
   `recipeLooksUntranslated` (latin/total ≥0.15 и т.п.). Док
   утверждает что серверный `_isEchoTranslation` авторитетен;
   клиентская повторная валидация не сходилась для легитимных
   переводов с латиницей (имена собственные, единицы измерения).
2. **Wave-batches вместо worker pool**: `Future.wait` на батч из 8
   ждал самый медленный запрос — 7 воркеров простаивали. Один
   медленный `/lookup` стопорил всю фазу.
3. **Нет per-call timeout**: dio receiveTimeout = 60 с.
4. **Нет общего deadline** на фазу перевода.
5. **Серверный read-side purge** в `routes/recipes.js _ensureLang`:
   на каждом чтении пере-валидировал `i18n[lang]` через
   `_isEchoTranslation` и удалял "плохие" блобы. Это нарушает
   контракт «No cache rewrites. Server-side translation_cache is
   immutable; client-side recipes is functionally immutable». Для
   итальянского (а часть рецептов — `Pasta Carbonara`, `Tiramisu`
   с byte-equal `strMeal/strCategory` к английскому → ECHO_RATIO_SHORT_MAX)
   и для любого языка где LT-вывод оставлял English-marker слова
   (`the|and|with|until|...`) кэш постоянно вытирался: каждый
   тап языка → re-translate с нуля.

### Фикс

**Клиент** (`recipe_list/lib/`):
- `ui/recipe_list_loader.dart`: убран `while (true)` residue-retry;
  убран импорт `translation_quality.dart`. Wave-batches заменены
  на worker-pool из `_translateConcurrency=8` воркеров с общей
  курсорной очередью. Добавлен общий deadline на фазу перевода —
  120 с. Per-call timeout — 12 с. Добавлены `_translateSeq` cancel
  token и `.catchError` чтобы `_translating=false` всегда сбрасывался.
- `ui/recipe_details_page.dart`: убран retry-loop, оставлен один
  `/lookup` за переключение, по доку «If `/lookup` fails, the
  previous-language copy stays on screen».
- `data/api/recipe_api.dart`: `lookup` принимает опциональный
  `Duration? timeout` → прокидывается в `dio.get` как `Options(receiveTimeout: ...)`.
- `data/repository/recipe_repository.dart`: `lookup` принимает и
  пробрасывает `timeout`.

**Сервер** (`mahallem_ist/local_user_portal/routes/recipes.js`):
- `_ensureLang`: read-path возвращает `row.i18n[lang]` без
  ре-валидации. Гейт остаётся только при write (после translate).
  Это восстанавливает «stored forever, never overwritten» из доков.

### Результат

- Холодный язык: bounded ~120 с (worst-case, обычно гораздо быстрее).
- Тёплый язык: bulk-SELECT из локального sqflite, sub-50 ms.
- Любой переведённый и сохранённый рецепт остаётся в кэше навсегда —
  и на сервере, и на клиенте.

---

## German page showed Spanish — sqflite cache schema bump v3→v4

**Date:** 2026-04-29

### Симптом

Пользователь сообщил, что на странице деталей при переключении на
немецкий показывается испанский текст. На сервере данные чистые —
полный скан `recipes.i18n.de` (12 самых длинных строк + regex по
fingerprint-словам `añad/horno/también/ñ/¡/¿/aceite/cucharad/sartén`)
не нашёл ни одной испанской строки под `lang='de'`; в `translation_cache`
для `target_lang='de'` тоже только одна легитимная запись с испанским
заимствованием (`arroz al horno`).

### Причина

Отравленный **локальный sqflite-кэш на устройстве**: строки, попавшие
туда во время предыдущих итераций пайплайна (до перехода на
`gemini-2.5-flash-lite`), хранились под `(id, lang='de')` и
`lookupManyCached` возвращал их напрямую без переsanity-чека.
`recipeLooksUntranslated` не ловит испанский-как-немецкий, потому что
испанский — латиница и проходит эвристику.

### Фикс

`recipe_list/lib/data/local/recipe_db.dart`: `kRecipeDbSchemaVersion`
3 → 4. Существующий `onUpgrade` дропает и пересоздаёт таблицу
`recipes`, поэтому при следующем запуске приложения кэш выбрасывается
и каждая карточка перекачивается с уже исправленного сервера. Тот же
паттерн, что использовался на границах v1→v2 и v2→v3.

Коммит: `recipe_list@5d4b49e`.

Дополнительно: `recipe_list/lib/data/translation_quality.dart` —
заглушены `// ignore: deprecated_member_use` для двух конструкторов
`RegExp(...)` (deprecation касается будущего `final`-запечатывания
класса, не самого конструктора).

## translation pipeline — gemini-2.5-flash-lite, cache purge, details lang switch

**Date:** 2026-04-29

### Контекст

После канонизации 6-tier каскада (cache → glossary → MyMemory →
public LibreTranslate → self-hosted LibreTranslate → Gemini) Gemini
постоянно отдавал HTTP 429 на `gemini-2.5-flash` (RPM-капнут даже на
платном плане). Параллельно поломалась смена языка на экране деталей —
кнопка «не работала», а кэш `translation_cache` оказался отравлен
сотнями echo-строк (English-for-French/Spanish/German/Italian/Turkish),
которые держали страницу на исходном языке.

### Что сделано

#### Сервер (`mahallem_ist@0b32a998`)

- `local_user_portal/utils/gemini-client.js` line 204: `TRANSLATE_URL`
  переключён с `gemini-2.5-flash` на `gemini-2.5-flash-lite`.
  Flash-lite имеет существенно более высокий RPD-потолок (на платном
  ключе фактически unlimited) и в smoke-тесте на длинных рецептных
  блоках выдаёт чистый персидский/арабский/курдский.
- `docs/translation-pipeline.md`: модель в таблице engine assignment
  обновлена.
- Образ user-portal **пересобран** через `docker compose up -d --build
  user-portal`. Без `--build` контейнер запускался от старого образа,
  потому что исходники запекаются в image (а не bind-mount). Прежние
  деплои с `--force-recreate` не подхватывали изменения.

#### Чистка отравленного `translation_cache`

```sql
DELETE FROM translation_cache
WHERE length(source_text) > 60
  AND length(translated_text) > 60
  AND left(translated_text, 40) = left(source_text, 40)
  AND target_lang IN ('fr','es','de','it','tr','ru','ar','fa','ku');
-- DELETE 235  (193 fr, 13 es, 12 de, 9 tr, 8 it)
```

После чистки рецепты заново прошли через flash-lite-каскад и
страница `/recipes/lookup/52772?lang=fr` стала отдавать французский
текст вместо английского эха.

#### Клиент (`otus_dz@12baa67`)

- `recipe_list/lib/data/translation_quality.dart` (новый): вынесена
  shared-эвристика `recipeLooksUntranslated`, ровно ту же используют
  и лоадер, и экран деталей — клиент и сервер видят одинаковый
  «echo»-критерий.
- `recipe_list/lib/ui/recipe_details_page.dart`:
  - При смене `appLang` поверх контента поднимается полупрозрачный
    `CircularProgressIndicator` overlay — пользователь видит, что
    переключение реально идёт, и не наблюдает «застывший» текст
    старого языка пока сервер фолбэчит между движками.
  - Bounded retry (3 раунда) на `RecipeApi.lookup`, если ответ всё
    ещё проходит `recipeLooksUntranslated`. Совпадает с
    `_residueRetryRounds = 3` в `RecipeListLoader`.
  - Монотонный `_translateSeq` отбрасывает поздние ответы старого
    языка — двойной/быстрый клик по флагу больше не «возвращает»
    предыдущий перевод.
- `recipe_list/lib/ui/recipe_list_loader.dart`: убран приватный
  `_looksUntranslated`, теперь делегирует в shared-helper.

### Эмпирическая проверка

| Шаг | Результат |
| --- | --- |
| `curl /recipes/lookup/52772?lang=fa` | `فر را روی دمای ۱۷۵ درجه سانتیگراد گرم کنید…` |
| `curl /recipes/lookup/52772?lang=ar` | `سخن کردن فر تا دمای ۳۵۰ درجه فارنهایت…` |
| `curl /recipes/lookup/52772?lang=ku` | `سەردانەکە گەرم بکە بۆ ٣٥٠° فهرنهایت…` |
| `curl /recipes/lookup/52772?lang=fr` (после purge) | `préchauffer le four à 350° f…` |
| 22 параллельных flash-lite-вызова | 0 × HTTP 429, все 200 OK |
| Тап по флагу на details | overlay → текст в новом языке за ≤2 раунда |

### Предупреждение для будущих деплоев

`docker compose up -d --force-recreate user-portal` **не достаточен**:
исходники запечены в `local_docker_admin_backend-user-portal:latest`,
mount-ятся только `backups/` и `avatars/`. Любое изменение JS-кода
требует `docker compose up -d --build user-portal`.

## translation pipeline — strict sequential 4-tier contract + docs

**Date:** 2026-04-28

### Что сделано

Канонизирован сквозной контракт перевода `app ↔ mahallem` ровно по
схеме «in-app DB → mahallem.recipes.i18n → translation_cache →
engines», без каскадов и без перезаписей.

- На стороне сервера (`mahallem_ist@7fe530b8`):
  - `cacheTranslation`: `INSERT … ON CONFLICT DO NOTHING` —
    переводы пишутся ровно один раз и живут вечно.
  - `translateBest`: 6-уровневый каскад схлопнут в 2 движка
    (primary + Gemini fallback). MyMemory и публичный LibreTranslate
    выкинуты — оба заквочены 429.
  - Engine assignment: `ar/fa/ku → Gemini`, остальные →
    локальный LibreTranslate, fallback Gemini только если primary
    его уже не использовал.
- На стороне приложения (`recipe_list/main`) дополнительных правок
  не потребовалось — `RecipeRepository.lookupManyCached` + `lookup` +
  `_LoadingScreen` уже соответствуют контракту.

### Документация

- [docs/translation-pipeline.md](translation-pipeline.md) —
  end-to-end контракт «1→2→3→4» с ASCII-диаграммой и file-map.
- [docs/translation-pipeline-analysis.md](translation-pipeline-analysis.md) —
  пошаговый аудит реализации; deferred P3 hygiene items
  (никакие из них не блокируют контракт).

### Эмпирическая проверка

| Шаг | Результат |
| --- | --- |
| iOS (iPhone 16e), cold install, lang=ru | `recipes.db` 884 KB, 219 ru-строк |
| Android (Pixel 8 API 34), cold install, lang=ru | `recipes.db` 780 KB, 200 ru-строк |
| 1-й `/recipes/lookup/52764?lang=ku` (нет `i18n.ku`) | HTTP 200 за 26.5 s, 34 Gemini-вызова, `i18n.ku` записан |
| 2-й тот же запрос (должен взять `recipes.i18n.ku` напрямую) | HTTP 200 за **6.6 ms**, нулевые движки в логах |
| Лог-доказательство движка | `🍳 translateBest [en→ku] via gemini: "olive oil" → "ڕۆنی زەیتوون"` |

## recipe_list — лоадер на смене языка + параллельный fetch промахов

**Date:** 2026-04-28

### Что было не так

При тапе по языковой кнопке UI оставался на старой ленте и постепенно
подменял карточки по мере прихода переводов из mahallem (`api.lookup`).
Для языков с холодным кэшем (de, it, tr, fa, ku) это выглядело как
«кнопка не работает» — новые карточки приезжали по одной за секунду
и часть лежала старым языком минуту-другую.

### Что сделано (Flutter, `lib/ui/recipe_list_loader.dart`)

- Добавлен флаг `_translating`. Он включается в `_onLangChanged` и
  выключается, когда `_retranslate` целиком резолвится. Пока
  `_translating == true`, `build` принудительно возвращает
  `_LoadingScreen` с прогресс-баром — никакой «частично переведённой»
  ленты пользователь не видит.
- `_retranslate` больше не публикует промежуточные `_lastResult` через
  `setState` (это и было источником мигания). Прогресс отдаётся только
  в `_stage` и считывается лоадером.
- Промахи кэша добиваются батчами по `_translateConcurrency = 8` через
  `Future.wait`. Сервер LibreTranslate капнут на 6 параллельных
  переводов (`local_user_portal/utils/lt-limit.js`), 8 клиентских
  запросов держат ровно «один в очереди» и не валят LT.

### Серверный fallback (status check)

`local_user_portal/utils/translate-recipe.js::translateBest` уже
реализует цепочку:

1. `getCachedTranslation` — `translation_cache` в Postgres.
2. `getGlossaryTranslation` — ручная глоссарий-таблица.
3. `Promise.allSettled([translateWithMyMemory, translateLT])` —
   MyMemory параллельно с локальным LibreTranslate (LT-капнутый
   контейнер `mahallem-translate`).
4. `evaluateCandidate` + round-trip score; победитель кешируется,
   проигравший выбраковывается.
5. Echo-guard на `translateField` — если оба движка «эхом»
   возвращают source (или для non-Latin target оставляют > 15 %
   латиницы), вызывается `geminiTranslateText` как last-resort
   fallback (gemini-2.5-flash).

TODO (не делается этим коммитом, но просили): добавить
`libretranslate.com` (публичный SaaS) между MyMemory и локальным LT,
чтобы при exhausted MyMemory лимите сначала пробовать публичный
SaaS, а локальный контейнер использовать как третью ступень.
Сейчас локальный контейнер и MyMemory идут параллельно.

## recipe_list — mahallem по умолчанию + UX-полировка поиска и деталей

**Date:** 2026-04-28

### Бэкенд по умолчанию

- `lib/data/api/recipe_api_config.dart`: mahallem (`https://mahallem.ist/recipes`)
  теперь дефолт для всех платформ. Запуск `flutter run` без
  `--dart-define` сразу получает переводы. Передача
  `--dart-define=MAHALLEM_RECIPES_BASE=` (пустая строка) форсит
  fallback на TheMealDB; кастомный URL — переопределение того же define.

### Поиск: кэш + API параллельно, без short-circuit

- `lib/data/repository/recipe_repository.dart`: `searchByName` запускает
  локальный `name_lower LIKE 'prefix%'` и `RecipeApi.searchByName`
  одновременно, мерджит по id (кэш — первым, API-добор — после),
  upsert-ит новинки. Прежнее правило «≥5 локальных совпадений → сеть
  не дёргать» убрано: пользователь всегда видит максимум совпадений,
  включая свежие с сервера.

### Поисковая выпадашка: на весь экран и скроллится

- `lib/ui/search_app_bar.dart`: убран `BoxConstraints(maxHeight: 320)`
  у `SearchPredictions`, `ListView.separated` без `shrinkWrap` —
  список нормально прокручивается.
- `lib/ui/recipe_list_page.dart`: оверлей подсказок теперь
  `Positioned.fill` (раньше `top:0`), занимает всю высоту тела
  страницы, пока поле поиска в фокусе.

### Деталка рецепта: таблица ингредиентов

- `lib/ui/recipe_details_page.dart`: первый столбец оставлен на
  фиксированных 89px; во втором столбце `Text` теперь начинается
  с трёх неразрывных пробелов `'   ${ing.name}'`, чтобы длинные
  переведённые названия (особенно RU/AR/FA) не наезжали на
  колонку с количеством.

## docs — Production endpoints для перевода (mahallem.ist)

**Date:** 2026-04-29

### Что было не так

В `docs/i18n_proposal.md` фигурировал URL
`http://mahallem-translate:5000/translate` — это адрес контейнера
**внутри docker-сети разработческой машины**. С телефона на
мобильной сети туда не достучаться.

### Что в проде на самом деле (проверено по
`mahallem_ist/project_docs` и `hostinger-deployment/`)

- **Public Node API gateway:** `https://mahallem.ist` — Nginx :443
  (Frankfurt, IP `72.61.181.62`, Let's Encrypt wildcard
  `*.mahallem.ist`) → `127.0.0.1:4001` (`local_user_portal`).
- **Admin:** `https://admin.mahallem.ist` → `127.0.0.1:3000`.
- **LibreTranslate:** `http://mahallem-translate:5000` — **только
  internal docker network**, нет host-port mapping, нет DNS.
  Источник: `DOCKER_NETWORK_AND_ROUTING_ARCHITECTURE.md` раздел
  "Internal-Only Services". `LIBRETRANSLATE_URL` env-override.
- **MyMemory:** outbound HTTPS из Node-процесса к
  `api.mymemory.translated.net`, подпись
  `de=support@mahallem.ist`.

Телефон **никогда** не вызывает LibreTranslate напрямую.

### Что обновлено

- [docs/i18n_proposal.md](i18n_proposal.md): §4 переписан под
  production-топологию — добавлена таблица "что где живёт", блок-
  схема с Nginx Frankfurt → Node :4001 → docker-internal
  LibreTranslate. §5.2 endpoints теперь абсолютные URL под
  `https://mahallem.ist/recipes/...`.
- [docs/todo/search_api_deploy.md](todo/search_api_deploy.md): §B
  ставит `RecipeApi.baseUrl` на `https://mahallem.ist/recipes/...`,
  предлагает переключение через `--dart-define`. §C добавляет
  пункт "mount routes inside `local_user_portal` под /recipes",
  Nginx-блок `location /recipes/`, проверку
  `LIBRETRANSLATE_URL` и порта (5000 vs 5050) на live-хосте.

### Решение по доменам

* Стартуем с `https://mahallem.ist/recipes/...` — переиспользуем
  существующий vhost, TLS-серт, фаервол. Нулевые расходы.
* Переезд на `https://api.mahallem.ist/recipes/...` — опционально,
  когда recipe-API получит свои зависимости. Это +1 server block
  Nginx + 1 DNS A-запись, серт уже покрыт wildcard'ом.

---

## docs — Перевод без Google: LibreTranslate + MyMemory

**Date:** 2026-04-29

### Описание

Приложение нацелено на Россию, где сервисы Google (включая Gemini /
Cloud Translation) работают нестабильно и часто блокируются. Мы
полностью убрали Google из path перевода и переехали на стек,
который уже крутится в `mahallem_ist` Docker (см. их
`TRANSLATION_SYSTEM_IMPLEMENTATION.md`,
`DYNAMIC_TRANSLATION_SYSTEM.md`,
`SMART_BACKGROUND_TRANSLATION.md`):

- **Primary:** LibreTranslate (self-hosted, контейнер
  `mahallem-translate:5000`, open-source, без обращения к Google).
  Поддерживает 8 из 10 платформенных языков mahallem (`en, ru, tr,
  es, fr, de, it, uk`) — нам сейчас нужно только `en/ru`.
- **Fallback:** MyMemory (`api.mymemory.translated.net`), free tier
  с почтой `support@mahallem.ist`. Также основной провайдер для
  `fa, ar, ku`, если когда-либо понадобятся.
- **Glossary** + **permanent translation_cache** в Postgres —
  скопировано один-в-один с mahallem.
- **Background retry cron** (10 мин), как в mahallem
  `SMART_BACKGROUND_TRANSLATION`: подбирает рецепты с NULL-полями,
  до 10 повторов.

### Что обновлено

- [docs/i18n_proposal.md](i18n_proposal.md): §1 цели — добавлено
  "no Google services". §4 целиком переписан с Gemini на
  LibreTranslate + MyMemory, добавлены §4.4 glossary и §4.5
  permanent cache. §8 migration plan обновлён. §9 open questions —
  цена и Play Integrity переосмыслены под self-hosted MT.
- [docs/todo/search_api_deploy.md](todo/search_api_deploy.md): §D
  Translation pipeline переписан под LT + MyMemory, добавлены
  заметки про lowercase quirk, echo-guard через fallback, glossary
  и явное "do not introduce any Google product".
- [docs/search_predictions.md](search_predictions.md): упоминание
  Gemini заменено на LibreTranslate + MyMemory.

### Почему именно так

1. **Russia-friendly:** ни один HTTP-запрос на горячем пути не
   уходит к google.com / generativelanguage.googleapis.com.
   LibreTranslate физически крутится у нас, MyMemory — итальянский
   сервис, доступный из RU.
2. **Zero new infra:** контейнер `mahallem-translate` уже есть.
   Postgres-таблицы `translation_cache` и `translation_glossary`
   уже существуют в `mahallem_ist`. Мы только добавляем
   `translateRecipe(meal)` поверх существующего
   `lib/utils/translation.js`.
3. **Цена:** marginal cost = CPU mahallem-translate, который мы и
   так платим. MyMemory — free tier 50K chars/day, для 2 000
   рецептов одноразовый прогон ~50K вызовов в LT, MyMemory
   практически не задействован.
4. **Масштабируется на 10 языков mahallem:** изменений в коде
   приложения не требуется — только новые ARB-файлы и
   подколлекции `i18n.<lang>.*` в MongoDB.

### Что НЕ менялось

- Сама архитектура MongoDB-буфера 2000/200, eviction policy,
  endpoints `/recipes/*`, sync 15 мин, образ Drift на телефоне —
  всё как раньше. Поменялась только реализация переводящего
  модуля внутри Node-сервиса.

---

## recipe_list — Online prefix-предсказания + filter-by-pick

**Date:** 2026-04-29

### Описание

Авто-подсказки в `SearchAppBar` теперь дёргают онлайн API
(TheMealDB), а не фильтруют то, что уже в памяти страницы. Дропдаун
скроллится, показывает только рецепты, чьи имена **начинаются** с
введённого префикса (case-insensitive). Тап по подсказке — а равно и
keyboard submit — заменяет основной список загруженными совпадениями
(работает как фильтр с дозагрузкой). Очистка поля возвращает базовый
список.

### Что сделано

- [recipe_list/lib/ui/recipe_list_page.dart](recipe_list/lib/ui/recipe_list_page.dart):
  состояние переписано — `_runPredictionQuery(prefix)` дёргает
  `RecipeApi.searchByName`, фильтрует по `startsWith`, защищается
  от race condition через `_lastQueryInFlight`. Тап по подсказке
  подставляет имя в поле и подменяет `_displayed`. Очистка через ✕
  возвращает `widget.recipes`. Если `api == null` (тесты) — фолбэк
  локальный startsWith-фильтр.
- [recipe_list/lib/ui/search_app_bar.dart](recipe_list/lib/ui/search_app_bar.dart):
  у `SearchPredictions` появился флаг `loading`, `maxHeight` поднят
  до 320, добавлен `Scrollbar` поверх `ListView.separated` —
  длинные списки прокручиваются.
- Документ
  [docs/search_predictions.md](docs/search_predictions.md): описание
  state machine, race-handling, связи с MongoDB-буфером и Gemini.
- Чек-лист
  [docs/todo/search_api_deploy.md](docs/todo/search_api_deploy.md):
  что осталось сделать на клиенте, что — в `mahallem_ist` (API,
  Mongo, перевод, auth, тесты, rollout).

### Проверки

- `flutter analyze` — 0 issues.
- `flutter test` — 17/17 passed (тест "search field filters list on
  submit" продолжает проходить через локальный фолбэк).

---

## recipe_list — Search AppBar и language toggle в шапке

**Date:** 2026-04-29

### Описание

Заменили глобальный `LangFab` на полноценный AppBar у списка рецептов.
Шапка содержит back-кнопку слева, поле поиска с выпадающими подсказками
по центру и круглый переключатель `RU` / `EN` справа. На splash-экране
AppBar нет, поэтому переключатель языка появляется ровно после анимации
перехода с splash на список — раньше FAB был виден поверх splash.

### Что сделано

- Удалён [recipe_list/lib/ui/lang_fab.dart](recipe_list/lib/ui/lang_fab.dart)
  и `Positioned`-обёртка в `main.dart`.
- Новый
  [recipe_list/lib/ui/lang_icon_button.dart](recipe_list/lib/ui/lang_icon_button.dart):
  40×40 круг, `AppColors.primary`, текст Roboto 800/14 белым, для
  `AppBar.actions`.
- Новый
  [recipe_list/lib/ui/search_app_bar.dart](recipe_list/lib/ui/search_app_bar.dart):
  `SearchAppBar` (`PreferredSizeWidget`) — leading back, title `TextField`
  с иконкой 🔍 и кнопкой ✕, actions `LangIconButton`. Дополнительно
  `SearchPredictions` — `Material(elevation: 4)` dropdown под шапкой с
  топ-5 совпадений, fallback `S.searchNoMatches`.
- [recipe_list/lib/ui/recipe_list_page.dart](recipe_list/lib/ui/recipe_list_page.dart)
  переведён на `StatefulWidget`. Локальный фильтр по `recipe.name`,
  debounce 250 мс на live-подсказки, submit (Enter / IME search) или тап
  по подсказке применяют фильтр / открывают экран деталей.
- В [recipe_list/lib/ui/recipe_details_page.dart](recipe_list/lib/ui/recipe_details_page.dart)
  добавлен `LangIconButton` в `actions`. Back-кнопка приходит из
  `AppBar.automaticallyImplyLeading`.
- Расширен `S`: `searchHint`, `searchClear`, `searchNoMatches`.
- Документ
  [docs/search_appbar.md](docs/search_appbar.md) описывает компоненты,
  состояние, поведение и направления развития (remote-предсказания,
  история поиска, переход на Material 3 `SearchAnchor`).

### Проверки

- `flutter analyze` — 0 issues.
- `flutter test` — 17/17 passed (новый кейс «search field filters list
  on submit»).

---

## recipe_list — Переключатель языка RU/EN + предложение по live-переводам

**Date:** 2026-04-29

### Описание

Введён первичный i18n-каркас: `AppLang { ru, en }`, глобальный
`ValueNotifier`, обёртка `AppLangScope` поверх `MaterialApp.home`,
объект `S.of(context)` со всеми статическими строками UI. В верхнем
левом углу появилась круглая FAB-кнопка `LangFab` (56×56, фон
`AppColors.primary`, текст `RU`/`EN` Roboto 900/18 белым) — поверх
любого экрана, цикл RU↔EN по тапу.

### Что сделано

- [recipe_list/lib/i18n.dart](recipe_list/lib/i18n.dart): enum,
  `appLang`, `cycleAppLang`, `AppLangScope`, `S` со всеми текущими
  строками (навбар, snackbar, empty/error, экран деталей, плюрализация
  ингредиентов RU/EN).
- [recipe_list/lib/ui/lang_fab.dart](recipe_list/lib/ui/lang_fab.dart):
  круглый FAB с `Material(shape: CircleBorder)` + `InkWell`.
- [recipe_list/lib/main.dart](recipe_list/lib/main.dart): `home`
  обёрнут в `AppLangScope`, `LangFab` помещён `Positioned(top:0,left:0)`
  внутрь корневого `Stack` с `SafeArea` и `EdgeInsets.all(AppSpacing.md)`.
- Все hard-coded русские строки в `app_bottom_nav_bar.dart`,
  `recipe_list_page.dart`, `recipe_list_loader.dart`,
  `recipe_details_page.dart`, `recipe_card.dart` заменены на вызовы `S`.
- [docs/i18n_proposal.md](docs/i18n_proposal.md): план перехода к
  живым переводам через Gemini API. Ключ берём из `mahallem_ist`
  (`local_docker_admin_backend/.env` → `GEMINI_API_KEY`), но **не**
  встраиваем в клиент — только через тонкий прокси (OWASP A02/A07).
  Описаны кэш по sha256, батчинг, какие поля переводить, fallback при
  ошибках, и миграция статических строк на штатный `gen-l10n` потом.

### Проверки

- `flutter analyze` — 0 issues.
- `flutter test` — 16/16 passed.

---

## recipe_list — Нижний навбар (logIn-вариант)

**Date:** 2026-04-29

### Описание

Добавлен bottom navbar по `docs/design_system.md` §6, которого не было
в текущей реализации.

### Что сделано

- Новый виджет [recipe_list/lib/ui/app_bottom_nav_bar.dart](recipe_list/lib/ui/app_bottom_nav_bar.dart):
  4 вкладки `logIn`-варианта (Рецепты / Холодильник / Избранное / Профиль),
  высота 60 dp, белый фон, тень `AppShadows.navBar`, активная вкладка
  `#2ECC71`, неактивные `#C2C2C2`, подписи Roboto 400/10/23, иконки 24 dp.
- Иконки временно из Material-набора (`local_pizza_outlined`,
  `kitchen_outlined`, `favorite_border`, `person_outline`) — SVG-ассеты
  `assets/icons/nav/` ещё не добавлены (см. §10 design_system).
- `RecipeListPage` теперь рендерит `AppBottomNavBar(current: recipes)`;
  тап по неактивной вкладке показывает SnackBar «в разработке».
- Тест `does not show a global "Рецепты" header` уточнён: теперь проверяет
  только отсутствие `AppBar` (текст «Рецепты» легитимно приходит из
  навбара).

### Контроль качества

- `flutter analyze` — 0 issues.
- `flutter test` — 16/16 passed.

---

## recipe_list — Страница рецепта по гайдлайну и чистка анализа

**Date:** 2026-04-29

### Описание

Привели экран деталей рецепта в соответствие с `docs/design_system.md` §9l
после жалобы «серый текст на сером фоне нечитаем».

### Что сделано

- **`RecipeDetailsPage`** переписан под спеку §9l:
  - фон `#FFFFFF` вместо `#ECECEC`;
  - hero-фото 396×220 (`AspectRatio 396/220`), радиус 5 dp;
  - AppBar `«Рецепт»` Roboto 400/20 `#165932` (§9a);
  - заголовок страницы — Roboto 500/24 `#000` (`AppTextStyles.pageTitle`);
  - подзаголовки секций — Roboto 500/16 `#165932`
    (`AppTextStyles.sectionTitle`);
  - блок ингредиентов — белый контейнер с обводкой `#797676` w=3, две
    колонки: меры (89 dp, Roboto 400/13/27 `#797676`) и названия
    (Roboto 500/14/27 `#000`);
  - кнопки YouTube / Источник — primary filled и outline w=3, радиус 25
    (§9g).
- **Дизайн-токены**: в `app_theme.dart` добавлены
  `AppColors.textSecondary` (`#797676`) и текстовые стили `pageTitle`,
  `sectionTitle`, `ingredientName`, `ingredientQty`.
- **Причина бага**: на странице деталей использовался стиль
  `AppTextStyles.inputHint` (`#C2C2C2` — токен плейсхолдера логин-формы)
  поверх `AppColors.surfaceMuted` (`#ECECEC`). На white-фоне с правильным
  `textSecondary` текст контрастен.
- **Анализатор**: в `recipe_list/analysis_options.yaml` добавлен
  `analyzer.exclude: [docs/**, ../docs/**]`, чтобы общая папка `docs/` не
  попадала в анализ пакета.
- **Форматирование**: автоформаттер ужал `SlideTransition` в `main.dart`.

### Контроль качества

- `flutter analyze` — 0 issues.
- `flutter test` — 16/16 passed.

---

## recipe_list — Интеграция с TheMealDB и редизайн карточки

**Date:** 2026-04-29

### Описание

Подключили `recipe_list` к публичному API `https://www.themealdb.com/api/json/v1/1`
вместо локального `RecipeManager`. Полностью переработали модель `Recipe` и
карточку, чтобы вытащить максимум доступных данных. Добавлен экран деталей.

### Сделано

- **Зависимости**: добавлены `dio: ^5.7.0` и `url_launcher: ^6.3.0`. Прописано
  разрешение `INTERNET` в `AndroidManifest.xml`.
- **Модель `Recipe`**: удалены `duration`/`description`. Введены
  `category`, `area`, `tags: List<String>`, `instructions`,
  `ingredients: List<RecipeIngredient>`, `youtubeUrl?`, `sourceUrl?`. Класс
  `RecipeIngredient { name, measure }` с `==`/`hashCode`.
  Фабрики `Recipe.fromMealDb` (полный объект, ходит по `strIngredient1..20`/
  `strMeasure1..20`, разбивает `strTags` по запятой) и `Recipe.fromMealDbLite`
  (только id/name/photo для ответов `filter.php`). Геттер `isLite` —
  определяет, нужно ли догружать детали.
- **Слой данных**: `lib/data/api/meal_db_client.dart` — `Dio` с baseUrl и
  таймаутами 10 сек; `lib/data/api/recipe_api.dart` — методы `searchByName`,
  `filterByCategory/Area/Ingredient`, `lookup(id)`, `random()`.
  `RecipeManager` и его тест удалены.
- **`RecipeCard`**: фото 16:9 с авто-добавлением суффикса `/medium`; оверлей
  YouTube (открывается через `url_launcher`); бейджи category/area; чипы
  `#tag` (до 3 + `+N`); счётчик ингредиентов с русской плюрализацией. Lite
  — только фото и название.
- **`RecipeDetailsPage`** (новый): фото, бейджи, теги, ингредиенты с мерами,
  инструкция, кнопки «Открыть на YouTube» и «Источник».
- **`RecipeListPage`**: при тапе на lite-карточку догружает детали через
  `RecipeApi.lookup(id)` и пушит детали.
- **`RecipeListLoader`**: stateful, грузит `searchByName(query: 'a')` по
  умолчанию, показывает progress / retry-button по ошибке.

### Тесты

- `recipe_test.dart` — фабрики на реальной фикстуре `lookup.php?i=52772`
  (полный + lite, пропуск пустых ингредиентов, парсинг тегов).
- `recipe_card_test.dart` — full и lite режимы, onTap.
- `recipe_list_page_test.dart` — обновлены фикстуры под новые поля.
- `recipe_api_test.dart` (новый) — мок `Dio.httpClientAdapter`, проверка
  `searchByName`, `filterByCategory`, `lookup`.
- Итог: `flutter analyze` — 0 issues, `flutter test` — 16/16 pass.

---

## recipe_list — Splash 1:1 с Figma-прототипом

**Date:** 2026-04-28

### Описание

Точная подгонка splash-экрана и перехода в список рецептов под прототип Figma
(frame `135:691` → `102:3`).

### Что исправлено

- **Градиент**: был `top → bottom` сплошной — заменён на точные значения
  `GRADIENT_LINEAR` из Figma. Handle-точки `(0.7266, 0.2068) → (0.5643, 1.0)`,
  стопы `[0.188, 1.0]`, цвета `#2ECC71 → #165932`. В Flutter переведено в
  `Alignment(0.4533, -0.5864) → Alignment(0.1285, 1.0)` —
  яркий верхне-правый угол, тёмный низ.
- **Логотип «OTUS / FOOD»**: был сплошной чёрный текст. По макету `TEXT`
  имеет `isMask=true, maskType=ALPHA` поверх 283×283 `IMAGE`-прямоугольника.
  Скачана исходная фотография по `imageRef` из Figma, уменьшена до 800px
  (`assets/images/splash_food.jpg`, 127 КБ) и применена через
  `ShaderMask` + `BlendMode.srcIn` + `ImageShader` — буквы стали «окнами»
  в фотографию поверх градиента.
- **Переход splash → список**: был `AnimatedSwitcher` + `FadeTransition` 600 мс.
  В Figma interaction: `AFTER_TIMEOUT 1.5с → MOVE_IN / TOP, 0.7с,
  EASE_IN_AND_OUT`. Реализовано как `Stack` со splash-фоном и
  `SlideTransition` (`Offset(0, -1) → Offset.zero`, `Curves.easeInOut`,
  700 мс), запускаемый по `Future.delayed(1500ms)`.

### Файлы

- `recipe_list/lib/ui/app_theme.dart` — точные значения `kSplashGradient`,
  `AppDurations.splash = 1500ms`, новая `AppDurations.splashTransition = 700ms`.
- `recipe_list/lib/ui/splash_page.dart` — `StatefulWidget`, загрузка
  `AssetImage` в `ui.Image`, `ShaderMask` с `ImageShader` (cover-матрица).
- `recipe_list/lib/main.dart` — `_AppRoot` на `AnimationController` +
  `SlideTransition`, splash остаётся под списком во время переезда.
- `recipe_list/assets/images/splash_food.jpg` — фото-подложка для маски.
- `recipe_list/pubspec.yaml` — регистрация ассета.

### Проверка

- `flutter analyze` — 0 issues.
- `flutter test` — 14/14 passed.

---

## vertical_layout — Размещение объектов по вертикали

**Date:** 2026-03-20

### Описание

Домашнее задание: реализация простого менеджера размещения объектов по вертикали
с использованием `dart:ui`.

### Что реализовано

- **BoxConstraints** — модель ограничений (min/max), передаётся от родителя к
  ребёнку; метод `constrain()` для вычисления допустимого размера.
- **LayoutObject** — абстрактный класс с методами `layout()`, `paint()`,
  `hitTest()`, `onTap()`.
- **VerticalLayoutManager** — управляющий класс: раскладывает детей сверху вниз,
  левый край выровнен по одной линии. При изменении размеров любого объекта все
  позиции пересчитываются автоматически.
- **ColoredRectangle** — цветной прямоугольник с закруглёнными углами; тап
  циклически переключает пресеты (цвет + размер).
- **GradientEllipse** — эллипс с градиентом; тап переключает обычный / увеличенный
  размер.
- **Application** — привязка к `dart:ui` через
  `WidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first`;
  обработка `onMetricsChanged`, `onPointerDataPacket`, рендеринг через
  `SceneBuilder`.
- Внешние ограничения: `(0, 0)` — минимум, `physicalSize / devicePixelRatio` —
  максимум.
- Юнит-тесты: BoxConstraints, VerticalLayoutManager, ColoredRectangle.

### Критерии оценки

| Критерий | Баллы | Статус |
|---|---|---|
| Механизм оценки размера объекта | 3 | ✅ |
| Управляющий класс вертикального позиционирования | 2 | ✅ |
| Автопересчёт позиций при изменении размеров | 2 | ✅ |
| Структурный объект + изменение свойств при взаимодействии | 2 | ✅ |
| Форматирование кода по правилам Dart | 1 | ✅ |

### Изменения (2026-03-20, update 2)

- **Рефакторинг `main()`**: вся логика привязки к `dart:ui` перенесена
  непосредственно в функцию `main()` — `WidgetsFlutterBinding.ensureInitialized()`,
  получение `platformDispatcher.views.first`, создание объектов, подключение
  коллбеков (`onMetricsChanged`, `onPointerDataPacket`), запуск первого кадра.
  Класс `Application` теперь принимает `view` и `manager` как параметры.
- **Android-эмулятор**: установлен ARM64 system image
  (`system-images;android-34;google_apis_playstore;arm64-v8a`), создан AVD
  `Pixel_8_API_34_arm64`, обновлён эмулятор до v36.4.10 с нативными
  `darwin-aarch64` бинарниками — приложение успешно запущено на эмуляторе.
- **Git remote**: обновлён URL на `https://github.com/novogod/otus_dz_2.git`.

### Структура

```
vertical_layout/
├── lib/
│   └── main.dart          # Всё приложение: constraints, layout objects,
│                           # vertical layout manager, Application, main()
└── test/
    └── widget_test.dart   # Юнит-тесты для BoxConstraints,
                           # VerticalLayoutManager, ColoredRectangle
```

---

## recipe_list — Создание страницы списка рецептов

**Date:** 2026-04-26

### Цель

Прокручиваемый виджет со списком рецептов в стиле Otus Food App
([Figma эскизы](https://www.figma.com/file/alUTMeT3w9XlbNf3orwyFA/Otus-Food-App?node-id=135%3A691),
[Figma прототип](https://www.figma.com/proto/alUTMeT3w9XlbNf3orwyFA/Otus-Food-App?node-id=102%3A3&scaling=scale-down&page-id=0%3A1&starting-point-node-id=135%3A691)).
Схема данных — [Swagger foodapi 0.2.0](https://app.swaggerhub.com/apis/dzolotov/foodapi/0.2.0).

### План реализации (тестируемые чанки)

Каждый чанк — независимая, тестируемая единица. Чанки можно реализовывать и
коммитить по очереди.

#### Чанк 1 — модель `Recipe` (соответствует схеме Swagger foodapi)

Поля по схеме `Recipe` из foodapi:

- `id: int`
- `name: String`
- `duration: int` (мин)
- `photo: String` (URL)
- `description: String`

**Тесты:**

- `Recipe.fromJson` корректно парсит валидный JSON.
- `Recipe.toJson` сериализует все поля.
- Round-trip: `fromJson(toJson(r)) == r`.

#### Чанк 2 — `RecipeManager` (источник данных)

- Класс с методом `Future<List<Recipe>> getRecipes()`.
- Возвращает константный список (>= 5 рецептов) с тестовыми данными.
- В будущем будет заменён на HTTP-клиент → возвращаемый тип `Future` уже сейчас.
- Реализован как простой класс (не singleton) — будет внедряться через конструктор
  виджета.

**Тесты:**

- `getRecipes()` возвращает непустой список.
- Все элементы имеют непустые `name` и валидные `id` (> 0).
- `id` уникальны.
- Возвращаемое значение — `Future<List<Recipe>>`.

#### Чанк 3 — виджет `RecipeCard`

`StatelessWidget`, отображает один рецепт по дизайну Figma:

- Фотография (через `Image.network`, со скруглением углов).
- Название рецепта.
- Длительность приготовления с иконкой часов.
- Скруглённая карточка с тенью.

**Тесты (widget tests):**

- При передаче `Recipe` карточка содержит текст с названием.
- Отображается длительность в формате `XX мин`.
- При тапе вызывается `onTap` (через `InkWell`).

#### Чанк 4 — виджет `RecipeListPage`

`StatelessWidget`, принимает `List<Recipe>` через конструктор:

- Прокручиваемый список (`ListView.builder`).
- Заголовок «Рецепты» в `AppBar`.
- Каждый элемент — `RecipeCard`.
- Поддержка пустого состояния («Нет рецептов»).

**Тесты:**

- Передан список из 3 рецептов → отображаются 3 `RecipeCard`.
- Пустой список → отображается заглушка «Нет рецептов».
- Список прокручивается (используется `Scrollable`).

#### Чанк 5 — `MaterialApp` + тема

- Точка входа `main()` → `runApp(const RecipeApp())`.
- `RecipeApp` — `StatefulWidget` (или `FutureBuilder` обёртка), который вызывает
  `RecipeManager.getRecipes()` и передаёт результат в `RecipeListPage`.
- Тема: цвета, шрифты, скругления — по Figma (основной цвет `#2ECC71`,
  фон `#FFFFFF`, акцентный текст `#165932`).
- `Scaffold` с `AppBar`.

**Тесты:**

- Smoke test: приложение собирается и стартовый экран — `RecipeListPage`.
- Тема имеет ожидаемый primary color.

### Критерии оценки

| Критерий | Баллы | Статус |
|---|---|---|
| Менеджер и коллекция тестовых данных | 3 | ⏳ |
| Виджет списка рецептов | 3 | ⏳ |
| MaterialApp + Scaffold + настроенная тема | 3 | ⏳ |
| Форматирование по правилам Dart | 1 | ⏳ |

Минимум для зачёта: 6 баллов.

### Структура

```
recipe_list/
├── pubspec.yaml               # зависимости и метаданные пакета
├── analysis_options.yaml      # правила линтера (flutter_lints)
├── lib/
│   ├── main.dart              # точка входа, MaterialApp + тема (Чанк 5)
│   ├── models/
│   │   └── recipe.dart        # модель Recipe (Чанк 1)
│   ├── data/
│   │   └── recipe_manager.dart # менеджер с константным списком (Чанк 2)
│   └── ui/
│       ├── recipe_card.dart   # карточка одного рецепта (Чанк 3)
│       └── recipe_list_page.dart # страница со списком (Чанк 4)
├── test/
│   ├── recipe_test.dart       # тесты модели Recipe (3 теста)
│   ├── recipe_manager_test.dart # тесты RecipeManager (4 теста)
│   ├── recipe_card_test.dart  # widget-тесты RecipeCard (3 теста)
│   └── recipe_list_page_test.dart # widget-тесты RecipeListPage (4 теста)
├── android/                   # сгенерировано flutter create
├── ios/                       # сгенерировано flutter create
└── web/                       # сгенерировано flutter create
```

### Запуск

```bash
cd recipe_list
flutter pub get
flutter analyze            # 0 issues
flutter test               # 14/14 passed
flutter run -d emulator-5554   # Android
flutter run -d chrome          # web
```

## recipe_list — Дизайн-система и splash из Figma

**Date:** 2026-04-28

### Описание

Применены 4 замечания ревьюера к `recipe_list` и проведён полный рефакторинг
под дизайн-систему, выгруженную напрямую из Figma REST API
(file `alUTMeT3w9XlbNf3orwyFA`, frames `135:691`, `102:3`, `116:33`,
`118:76`, `121:584` и компонент-сеты `121:443`, `121:169`, `145:551`,
`145:579`).

### Замечания ревьюера

1. Имитированная сетевая задержка `RecipeManager` уменьшена до 400 мс
   (было 1 200 мс).
2. Тема разделена: `app_theme.dart` экспортирует `AppTheme.light` и
   токены (`AppColors`, `AppTextStyles`, `AppRadii`, `AppSpacing`,
   `AppShadows`, `AppDurations`, `kSplashGradient`).
3. Карточка рецепта переверстана 1:1 по Figma — фото `149×136` слева
   на всю высоту, скруглены только левые углы (5 dp), цвет названия
   `#000000`, длительность `#2ECC71`.
4. На экране списка убран глобальный заголовок «Рецепты» — на макете
   его нет; добавлен соответствующий тест.

### Дизайн-система

- [docs/design_system.md](../docs/design_system.md) — единый источник
  правды (палитра, типографика Roboto, сетка 428×926 dp, навбар в двух
  раскладках logIn/logOut, шаг рецепта 3 состояния, чекбокс, like,
  бейдж «Закладка», экраны login/register/profile/favorites/recipe
  details/cooking/list+FAB).
- Сырые Figma JSON-дампы в репозитории не хранятся (
  `docs/figma/` и `recipe_list/docs/figma/` добавлены в `.gitignore`),
  скрипт воспроизведения выгрузки в `mktemp` приведён в §13 документа.
- Токен Figma хранится локально в `.figma_env`
  (`chmod 600`, в `.gitignore`).

### Splash-экран

- `lib/ui/splash_page.dart` — full-screen `LinearGradient`
  `#2ECC71 → #165932`, центрированный логотип «OTUS\nFOOD»
  Roboto w900 95/82.
- `lib/main.dart` управляет переходом: 2 с splash → `AnimatedSwitcher`
  с `FadeTransition` 600 мс на `RecipeListLoader`.

### Структура (изменения)

```
recipe_list/
└── lib/
    ├── main.dart                  # _AppRoot со splash → list переходом
    └── ui/
        ├── app_theme.dart         # NEW: токены DS + AppTheme.light
        ├── splash_page.dart       # NEW: splash 1:1 по frame 135:691
        ├── recipe_list_loader.dart # NEW: FutureBuilder + loading/error
        ├── recipe_list_page.dart  # без AppBar, surfaceMuted фон
        └── recipe_card.dart       # фото слева 149×136, типографика DS

docs/
├── design_system.md               # NEW: дизайн-система (~330 строк)
├── foodapi_alternative.md         # NEW
├── foodapi_dzolotov.md            # NEW
└── todo/                          # NEW: рабочие заметки
```

### Запуск и проверки

```bash
cd recipe_list
flutter analyze    # No issues found
flutter test       # 14/14 passed
```
