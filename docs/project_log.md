# Project Log

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
