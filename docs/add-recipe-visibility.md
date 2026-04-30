# AddRecipePage: фиксы видимости и safe-area

**Date:** 2026-04-30

## Контекст

Пользовательский фидбек после релиза favorites-фич:

> **(1)** Add recipe page overlaps safe area.
> **(2)** When I save recipe it should appear on the top of the
> list, on the top of the favorite, sent to mahallem for
> translation and loaded to mahallem recipes DB.

Два независимых дефекта в [recipe_list/lib/ui/add_recipe_page.dart](../recipe_list/lib/ui/add_recipe_page.dart),
оба имеют простые точечные фиксы.

---

## Баг 1: форма уезжает под home-indicator

### Симптом

На iPhone (физических устройствах с notch + home-indicator) и на
Android-устройствах с жестовой навигацией нижняя часть формы
`AddRecipePage` (поле `Instructions`, ингредиенты, кнопка
«Сохранить») уходит под системный жест и обрезается полупрозрачной
полоской home-indicator. На iPad и в эмуляторе без insets-ов
проблема не воспроизводилась — при ручной проверке на симуляторе
её и не заметили.

### Причина

В `AddRecipePage.build` body Scaffold-а был обёрнут только в
`AbsorbPointer → Form → ListView`:

```dart
body: AbsorbPointer(
  absorbing: _saving,
  child: Form(
    key: _formKey,
    child: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [...],
    ),
  ),
),
```

Скаффолд по умолчанию **не** добавляет `MediaQuery.padding.bottom`
к нижнему inset-у body, если внутри нет `SafeArea`. AppBar
учитывает верхний inset через `PreferredSize`, но нижний — нет.
Контент уходит под `viewPadding.bottom`.

### Фикс

Оборачиваем body в `SafeArea(top: false, child: ...)`. `top: false`
сознательно — AppBar уже занимает status-bar-зону, дублировать
inset не нужно. Боковые inset-ы тоже включены (на устройствах с
landscape с notch — например, iPhone на боку — это даёт
дополнительный отступ слева/справа).

```dart
body: SafeArea(
  top: false,
  child: AbsorbPointer(
    absorbing: _saving,
    child: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [...],
      ),
    ),
  ),
),
```

ListView сам уже растягивается на доступный размер, поэтому
`SafeArea` корректно «вытянет» нижний край за home-indicator.
Кнопка «Сохранить», находящаяся последней в списке, теперь
полностью видна и кликается без перехвата системным жестом.

### Почему модальный photo-source-sheet не страдал этим багом

`showModalBottomSheet` уже оборачивал содержимое в `SafeArea`
(см. `_showPhotoSourceSheet` line 192). Это и подсказало
направление фикса: единый паттерн для всех Scaffold-body,
где есть скроллируемая форма.

### Догон-фикс: «+ ингредиента» убегает за нижний край

После первого фикса (`SafeArea(top: false)`) пользователь
сообщил, что баг **частично остался**: при нажатии «+» в строке
ингредиента новая строка появляется ниже видимой области, а
кнопка «Сохранить» снова уезжает под клавиатуру / home-indicator.

Причины — две, обе про скролл:

1. **ListView не догонял рост контента.** `setState` добавлял
   `_IngredientRow` в список, ListView перерисовывался, но
   позиция скролла оставалась прежней; новая строка попадала
   за нижний край viewport-а и вообще не была видна, пока
   пользователь не догадывался дотянуть пальцем.
2. **Padding не учитывал клавиатуру.** Когда фокус был в одном
   из полей ингредиента, `MediaQuery.viewInsets.bottom` ≈ 280–340 dp
   (высота клавиатуры). `SafeArea` покрывает только
   `viewPadding` (home-indicator), но **не** `viewInsets`
   (клавиатура). В итоге последняя строка визуально лежала
   под клавишами.

Фикс:

* Добавили `final ScrollController _scrollController` и
  передали его в `ListView`. После `_addIngredientRow` —
  `WidgetsBinding.instance.addPostFrameCallback`,
  `animateTo(maxScrollExtent, …)`. Это гарантирует, что
  свежевставленная строка попадает в нижний край viewport-а.
* Padding ListView-а стал динамическим:
  ```dart
  padding: EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.lg,
    AppSpacing.lg,
    AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
  ),
  ```
  Когда клавиатура поднята, нижний padding растёт ровно на её
  высоту — последняя строка и кнопка «Сохранить» остаются
  выше клавиш и доступны для тапа.

Эти две правки не пересекаются с уже добавленным `SafeArea` —
он всё ещё нужен для случая «клавиатура свёрнута, есть
home-indicator».

---

## Баг 2: сохранённый рецепт не виден ни в ленте, ни в избранном

### Симптом

Пользователь нажимает «Сохранить» → видит snackbar
«Рецепт сохранён» → возвращается на главную/избранное → **рецепта
нигде нет**.

Воспроизводилось:

* при сохранении из FAB-а на `RecipeListPage` (главная лента) —
  рецепт **появлялся** на верху ленты, **но** при переходе во
  вкладку «Избранное» его там не было;
* при сохранении из нового FAB-а на `FavoritesPage` —
  рецепт **не появлялся ни в избранном, ни в главной ленте**;
* при reload-е ленты рецепт всё-таки подгружался из БД сервера
  (translation cascade срабатывает по запросу), но это не то,
  чего пользователь ожидал.

### Причина

Цепочка из трёх связанных проблем:

1. **Прокидывание новой карточки делалось через `Navigator.pop`
   результата, а не через шину событий.** На главной
   `_openAddRecipe` ловил `await push<Recipe>(...)` и руками
   делал `_displayed = [created, ..._displayed]`. На FavoritesPage
   мы добавили FAB в прошлой итерации (commit `691e93b`), но
   результат push-а сознательно проигнорировали — рассчитывали,
   что пользователь поставит сердце вручную на странице деталей.
2. **Mahallem-сервер уже знает про рецепт** — `POST /recipes`
   срабатывает, рецепт пишется в `recipes`-таблицу
   (`docs/add-recipe-feature.md`). Перевод на остальные локали
   запускается **лениво**, на первый `GET /recipes/lookup/:id?lang=…`
   через `_ensureLang` (см. `docs/translation-pipeline.md`). Этот
   шаг и так работал — пользователь просто не имел способа в него
   зайти, потому что карточка не показывалась.
3. **Локальный sqflite-кэш обновлялся**, но **порядок отображения**
   на главной ленте не менялся: фид строится из категорийных
   запросов, а новый рецепт лежит вне категорий до первого
   reload-а.

### Фикс

Глобальная шина событий вместо передачи через pop-результат:

* Новый файл [recipe_list/lib/data/recipe_events.dart](../recipe_list/lib/data/recipe_events.dart):
  ```dart
  final ValueNotifier<Recipe?> newRecipeCreatedNotifier =
      ValueNotifier<Recipe?>(null);
  ```
* `AddRecipePage._save` после успешного `createRecipe(...)` /
  `createRecipeWithPhoto(...)` и `repository.upsertAll([saved])`:
  - `await favoritesStoreNotifier.value?.add(saved.id, appLang.value);`
    — авто-пометка избранным в текущем языке. `saved_at = now()` ⇒
    карточка попадает на верх вкладки «Избранное»
    (`ORDER BY saved_at DESC`).
  - `newRecipeCreatedNotifier.value = saved;` — публикация события.
* `RecipeListPage.initState` подписывается на нотифаер; в
  `_onNewRecipeCreated` сравнивает id с последним обработанным
  (`_lastConsumedNewRecipeId`), чтобы не вставить ту же карточку
  дважды, и делает `setState(_displayed = [created, ..._displayed])`.
* `RecipeListPage._openAddRecipe` теперь просто открывает
  `AddRecipePage` без чтения pop-результата — вся логика встраивания
  ушла в listener. Это работает одинаково и для главной, и для
  «Избранного», и для любого будущего входа в форму.

### Поведение после фикса

| Источник вызова AddRecipePage | Главная лента | Избранное |
|---|---|---|
| FAB на главной | новый рецепт сверху | новый рецепт сверху |
| FAB в избранном | новый рецепт сверху (когда пользователь вернётся) | новый рецепт сверху сразу |

Перевод и публикация на mahallem-сервер не менялись —
`api.createRecipe` уже делал нужный POST, `_ensureLang` на стороне
сервера переведёт рецепт при первом запросе на иностранной локали.

### Edge cases

* **Авто-favorite по языку.** Помечаем избранным **только** для
  `appLang.value` — пара `(recipe_id, lang)` уникальна по схеме
  v6 (см. [favorites.md](favorites.md)). Если пользователь
  переключится на другой язык, на той вкладке рецепта сразу
  не будет — это сознательная упрощённая модель.
* **dispose.** `RecipeListPage.dispose` снимает listener
  (`newRecipeCreatedNotifier.removeListener(_onNewRecipeCreated)`),
  чтобы старая страница не реагировала на события после
  ребилда (например, при смене языка `RecipeListLoader`
  пересоздаёт страницу).
* **Web-fallback (URL-фото).** Не изменился — auto-favorite
  и push в шину работают одинаково.
* **Холодный режим тестов.** `favoritesStoreNotifier.value`
  может быть `null` (стор не открыт), `try/catch` глотает
  исключение, save не падает.

---

## Тесты

* Запущен полный `flutter test`. Существующие два падающих теста
  в `recipe_repository_test.dart` (пороги кэша) не относятся к
  этой задаче (см. [reload-hang-after-favorites.md](reload-hang-after-favorites.md)).
* Новых тестов на AddRecipePage не добавляли — для проверки
  потребовался бы мок `RecipeApi.createRecipe`, которого пока в
  кодовой базе нет; ручная проверка на iOS-симуляторе с
  включённым home-indicator-ом подтвердила оба фикса.

## Файлы

* [recipe_list/lib/ui/add_recipe_page.dart](../recipe_list/lib/ui/add_recipe_page.dart)
* [recipe_list/lib/ui/recipe_list_page.dart](../recipe_list/lib/ui/recipe_list_page.dart)
* [recipe_list/lib/data/recipe_events.dart](../recipe_list/lib/data/recipe_events.dart) (новый)
