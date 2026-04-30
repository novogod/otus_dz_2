# 15 — Избранное: локальное хранение по языкам

**См.:** [docs/favorites.md](../docs/favorites.md). **Приоритет:** P1.
**Scope:** только `[client]`, серверных правок нет.

Цель: сохранять отмеченные пользователем избранные рецепты по языкам
в sqflite, давать к ним доступ через бейдж-сердце на карточке и
странице деталей и через вкладку «Избранное» в нижней навигации.

Реализация делится на **5 чанков**. Каждый чанк ложится отдельным
коммитом, тесты проходят перед переходом к следующему.

---

## Чанк A — Схема БД и стор (без UI)

### Изменения
* `recipe_list/lib/data/local/recipe_db.dart`:
  * Поднять `kRecipeDbSchemaVersion` с 5 до 6.
  * Дополнить `applyRecipeSchema`: `CREATE TABLE favorites (...)`,
    `CREATE INDEX favorites_by_lang_savedAt`.
  * `onUpgrade(5 → 6)`: тот же `CREATE TABLE` / индекс,
    идемпотентно.
* `recipe_list/lib/data/repository/favorites_store.dart` (новый):
  * `class FavoritesStore` с API из
    [docs/favorites.md](../docs/favorites.md), раздел «Управление
    состоянием».
  * Внутри — `Map<AppLang, ValueNotifier<Set<int>>>` плюс sqflite
    как backing store.

### Тесты
* `recipe_list/test/data/favorites_store_test.dart`:
  * Round-trip `add` → `isFavorite` → `remove`.
  * Изоляция по языкам: `add(id, en)` не видна в
    `idsForLang(tr)`.
  * `list(lang)` возвращает строки в порядке `saved_at DESC`.
* `recipe_list/test/data/recipe_db_migration_test.dart`:
  * Открыть фикстуру со схемой 5, ожидать апгрейд до 6, таблица
    `favorites` присутствует и пуста.

### Приёмка
* `flutter test test/data/` зелёный.

---

## Чанк B — Бейдж сердца на карточке рецепта

### Изменения
* `recipe_list/lib/ui/recipe_card.dart`:
  * Добавить `_FavoriteBadge` — зеркало `_YoutubeBadge`: тот же
    размер и позиция (правый верх изображения), полупрозрачный
    чёрный фон.
  * Контурное сердце (`Icons.favorite_border`, белое), пока не в
    избранном; заполненное (`Icons.favorite`, `AppColors.primary`)
    в избранном.
  * Подписан на `FavoritesStore.idsForLang(appLang.value)`.
  * `onTap`: переключить через стор; `HapticFeedback.lightImpact()`.
* Если на одной карточке оба бейджа — YouTube и Favorite —
  складываем их вертикально через `AppSpacing.xs`. Сердце
  ВЫШЕ YouTube (то есть самое верхнее в правом верхнем углу).

### Тесты
* `recipe_list/test/ui/recipe_card_favorite_test.dart`:
  * Pump карточки без избранного → видно контурное сердце.
  * Тап → в сторе появился id; виджет перерисован с заполненным
    сердцем.
  * Тап ещё раз → стор пуст; виджет вернулся к контурному.

### Приёмка
* `flutter analyze` чистый. Widget-тест зелёный.

---

## Чанк C — Бейдж сердца на странице деталей

### Изменения
* `recipe_list/lib/ui/recipe_details_page.dart`:
  * Тот же `_FavoriteBadge` поверх hero-изображения, в правом
    верхнем углу.
  * Переключение в деталях отражается на исходной карточке после
    возврата.

### Тесты
* `recipe_list/test/ui/recipe_details_favorite_test.dart`:
  * Отметить в деталях → pop → карточка показывает заполненное
    сердце.

### Приёмка
* Ручная проверка: отметить/снять в деталях, hot-restart,
  состояние сохранено.

---

## Чанк D — Вкладка и экран «Избранное»

### Изменения
* `recipe_list/lib/ui/favorites_page.dart` (новый):
  * Сетка в стиле `RecipeListPage`, источник —
    `FavoritesStore.list(appLang.value)`.
  * Пустое состояние: локализованная подсказка через
    `s.favoritesEmpty`.
  * Переиспользует `RecipeCard`.
  * AppBar: переиспользовать оболочку `SearchAppBar`. Добавить
    флаг (например, `disableLangAndReload: true`) или отрисовать
    favorites-вариант, в котором иконки language + reload
    обёрнуты в `Opacity(0.38) + IgnorePointer` — остаются
    видимыми для согласованности лэйаута, но инертны.
  * Поле поиска работает только локально: фильтр по in-memory
    списку через case-fold подстрочное совпадение по
    `recipe.name`. Без сетевых вызовов, без `searchByName`.
* `recipe_list/lib/main.dart` (или там, где живёт роутер нижней
  навигации): провязать `AppNavTab.favorites` на `FavoritesPage`.
* `recipe_list/lib/i18n/strings_*.g.dart`: добавить ключ
  `favoritesEmpty` для всех 10 локалей (после правки исходного
  `strings.i18n.yaml` запустить `slang build`).

### Тесты
* `recipe_list/test/ui/favorites_page_test.dart`:
  * Стор пуст → видна подсказка пустого состояния.
  * Два сохранённых → сетка рендерит 2 карточки в порядке
    `saved_at DESC`.
  * Смена `appLang` посреди теста перерисовывает контент.
  * Иконки language + reload присутствуют, но тап — no-op
    (проверяется через предка `IgnorePointer` или `onPressed: null`).
  * Ввод подстроки в поле поиска → остаются только подходящие
    избранные; сетевой вызов не происходит (mock API ожидает
    ноль обращений).

### Приёмка
* Тап по сердцу в нижней навигации ведёт на экран; иконки
  language + reload приглушены и инертны; поиск фильтрует
  избранное локально.

---

## Чанк E — Полировка и project_log

### Изменения
* `docs/project_log.md`: запись от 2026-04-30+ с резюме чанков
  A–D.
* Проверить, что кнопка reload на вкладке «Рецепты» НЕ трогает
  таблицу `favorites` — добавить регрессионный тест на то, что
  reload-flow сохраняет запись избранного.
* Ручной hot-restart прогон на iOS / Android / web.

### Тесты
* `recipe_list/test/data/favorites_survives_reload_test.dart`:
  * Добавить избранное → дёрнуть reload ленты
    (`requestFeedReload`) → избранное на месте.

### Приёмка
* `flutter analyze` чистый. Все новые тестовые файлы зелёные.
* `flutter test` baseline сохранён (существующие тесты не
  тронуты).

---

## Что НЕ делаем здесь

* Серверный endpoint избранного и синхронизация.
* UI миграции избранного между языками.
* Шаринг / экспорт избранного.
* Папки / коллекции.
