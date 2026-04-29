# Categories pipeline

> Status: 2026-04-29 — описывает текущее поведение `recipe_list_loader.dart`
> + кнопку «обновить ленту» из `AppPageBar`.

## TL;DR

* В коде зашит фиксированный список из 14 английских ключей-категорий
  (TheMealDB-совместимые имена).
* На каждом cold-start клиент случайно выбирает 10 из них и накапливает
  до 200 рецептов из mahallem-API через `/recipes/filter?c=<key>&lang=…`.
* Локальная sqflite-БД работает как L1-кэш: рецепты живут "вечно" под
  бюджетом 5 MB / 2000 строк, выкидывая LRU при переполнении.
* Кнопка ⟳ (Reload) в `AppPageBar.actions` рядом с языковой кнопкой
  принудительно перевыбирает 10 случайных категорий и тянет свежие
  рецепты из API, минуя короткий путь "≥ 50 рецептов в кэше — отдаём
  как есть".

---

## 1. Источник списка категорий

Файл: [recipe_list/lib/ui/recipe_list_loader.dart](../recipe_list/lib/ui/recipe_list_loader.dart#L249-L266)

```dart
static const _allCategories = <String>[
  'Beef', 'Breakfast', 'Chicken', 'Dessert', 'Goat', 'Lamb',
  'Miscellaneous', 'Pasta', 'Pork', 'Seafood', 'Side', 'Starter',
  'Vegan', 'Vegetarian',
];
static const int _seedPickCount = 10;
```

Английские ключи — стабильные имена категорий TheMealDB. Локализация
названий выполняется на лету через `S.of(context).localizedCategory(key)`
([i18n.dart §`_categoryNames`](../recipe_list/lib/i18n.dart)) — это
исключает сетевой round-trip ради подписи прогресс-бара.

## 2. Случайный отбор

```dart
static List<String> _pickCategories() {
  final pool = [..._allCategories]..shuffle();
  return pool.take(_seedPickCount).toList(growable: false);
}
```

Каждый вызов `_runLoad()` (cold start, language switch fall-through и
forced reload) пересеивает выбор. Раньше можно было увидеть на главной
"Сикен / Сикен / Сикен" — теперь 10 разных тегов почти всегда.

## 3. Cold-start пайплайн (`_seedFromCategories`)

Файл: [recipe_list/lib/ui/recipe_list_loader.dart](../recipe_list/lib/ui/recipe_list_loader.dart#L340-L411)

1. **Cache-first проход.** Для каждого выбранного `cat` забираем из
   sqflite до 50 уже сохранённых рецептов нужного языка
   (`repo.listCachedByCategory(cat, lang, limit: 50)`).
2. **Network fill.** Для категории, у которой локально лежит меньше
   `_categoryCacheThreshold = 10` рецептов, дёргаем
   `widget.api.filterByCategory(cat)` (под капотом —
   `GET /recipes/filter?c=<cat>&lang=<lang>` к
   `mahallem-user-portal`). Прогресс-бар обновляется до и после каждой
   категории, чтобы не "замирал".
3. **Persist.** Каждый отбатченный `filterByCategory` сразу пишется в
   локальную БД через `repo.upsertAll(batch, lang)`.
4. **Cap + shuffle.** Как только накопилось `_seedTarget = 200` рецептов
   (`accumulator.length`), цикл рвётся, и финальный список перетасуется,
   чтобы карточки не шли строго по категориям.

Дедупликация: ключ `accumulator` — `recipe.id`. Если несколько категорий
вернули один и тот же рецепт, в ленту он попадёт ровно один раз.

## 4. Ранний кэш-выход (`/_runLoad` short-circuit)

Если для текущего языка в локальной БД уже лежит ≥ 50 рецептов и
`forceReseed == false`, `_runLoad` возвращает кэшированные строки без
сетевых запросов. Это та оптимизация, которая должна *не* мешать
обновлению — отсюда `forceReseed`-флаг.

## 5. Кнопка «обновить ленту» (Reload)

Размещение: [recipe_list/lib/ui/app_page_bar.dart](../recipe_list/lib/ui/app_page_bar.dart)
— `AppBar.actions`, слева от `LangIconButton`, форма-в-форму с языковой
кнопкой (40 dp, `CircleBorder`), но цвета вторичного действия:

| Свойство   | Значение                              |
|------------|---------------------------------------|
| Размер     | 40 × 40 dp                            |
| Форма      | `CircleBorder()` (`Material` + `InkWell`) |
| Фон        | `AppColors.surfaceMuted` (`#ECECEC`)   |
| Иконка     | `Icons.refresh`, 22 dp                 |
| Цвет икoн. | `AppColors.primaryDark` (`#165932`)    |
| Отступы    | `AppSpacing.xs` снаружи, `_trailingGap` справа сохранён |
| A11y       | `Semantics(button: true, label: s.reloadFeed)` + `Tooltip` |

Поведение: тап вызывает
[`requestFeedReload()`](../recipe_list/lib/i18n.dart) → инкремент
`reloadFeedTicker`. `RecipeListLoader._onReloadRequested` слушает
этот `ValueNotifier<int>`, монотонным `_translateSeq` отбрасывает гонки
с предыдущим запросом и зовёт `_runLoad(forceReseed: true)`. На время
обновления показывается стандартный progress-stage из `_LoadingScreen`.

Локальный sqflite-кэш не чистится — категории, у которых уже > порога
рецептов, обслуживаются из БД, а недостающие догружаются по сети. Этим
кнопка дешевле "Сбросить и перезагрузить с нуля", но обеспечивает свежий
рандомный набор и подмешивает новые рецепты.

## 6. Почему зашитый список, а не `/recipes/categories`

* Endpoint `/recipes/categories` существует на сервере, но его ответ
  меняется редко (TheMealDB-категории стабильны годами).
* Зашитый список даёт детерминированную локализацию названий через
  slang-словарь. Сервер-API возвращает английские ключи.
* На split-brain (сервер добавил/удалил категорию) клиент попросту
  получит пустой `/filter?c=<key>&lang=…` или 404 — пайплайн уже
  устойчив к "одна категория не приехала, идём к следующей".

## 7. Соответствие docs/translation-pipeline.md

Cold-start через категории остаётся в рамках спецификации: каждый
отдельный рецепт проходит серверный cascade `cache → glossary → MyMemory
→ public LT → local LT → Gemini`. Принудительный reload не нарушает
"бессмертие" `translation_cache` — клиент пишет в свою sqflite, сервер
переиспользует уже накопленные строки.

## 8. Параметры конфигурации

| Параметр                  | Где                          | Значение |
|---------------------------|------------------------------|----------|
| `_allCategories`          | `recipe_list_loader.dart`    | 14 имён  |
| `_seedPickCount`          | то же                        | 10       |
| `_seedTarget`             | то же                        | 200      |
| `_categoryCacheThreshold` | то же                        | 10       |
| `_translateConcurrency`   | то же                        | 8        |
| Sqflite cap (rows / bytes)| `recipe_repository.dart`     | 2000 / 5 MB |

## 9. Известные ограничения / TODO

* Сервер `mahallem-user-portal` всё ещё обслуживает первый «холодный»
  язык за 30–90 секунд — пока просто бар прогресса, а не push-обновление.
* Кэш-eviction по байтам сейчас фиксирован на 5 MB; 200 рецептов на 10
  языках = до 50 MB; см. docs/translation-buffer.md, §«Recommendations».
* Кнопка не дёрнет SourcePage / FavoritesPage — намеренно: она про
  «обновить ленту», а не «обновить всё приложение».
