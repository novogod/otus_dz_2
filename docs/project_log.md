# Project Log

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
