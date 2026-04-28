# Project Log

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
