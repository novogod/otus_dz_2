import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../i18n.dart';
import '../../models/recipe.dart';
import '../api/recipe_api.dart';
import '../local/recipe_db.dart';

/// Глобальный держатель текущего [FavoritesStore]. Заполняется
/// фабрикой репозитория (`RecipeListLoader._defaultRepoBuilder`)
/// после открытия БД и читается виджетами карточки и страницы
/// деталей. До инициализации `value == null` — в этом случае UI
/// рендерит контурное сердце и тап ничего не делает.
///
/// В тестах можно подсунуть готовый стор:
/// `favoritesStoreNotifier.value = FavoritesStore(db: testDb);`.
final ValueNotifier<FavoritesStore?> favoritesStoreNotifier =
    ValueNotifier<FavoritesStore?>(null);

/// Стор избранного: тонкая обёртка вокруг таблицы `favorites` плюс
/// кэш id-шников по языкам в памяти, чтобы UI (бейдж сердца на
/// карточке) перерисовывался без лишних обращений к БД.
///
/// Хранение по языкам — сознательное упрощение (см.
/// [docs/favorites.md](../../../docs/favorites.md)): пара
/// `(recipe_id, lang)` уникальна, переключение языка показывает
/// только избранное, сохранённое в этом языке.
///
/// Содержимое избранного (имя, фото, ингредиенты) живёт в таблицах
/// `recipes` / `recipe_bodies` — стор делает к ним JOIN при сборке
/// списка для экрана. Если строка вытеснилась LRU-кэшем, при
/// необходимости можно догрузить её через [RecipeApi.lookup]
/// (это делает экран избранного, не сам стор).
class FavoritesStore {
  final Database _db;
  final DateTime Function() _now;

  /// Кэш id по языкам. Создаётся лениво на первый запрос,
  /// инвалидируется только через [add] / [remove], которые
  /// поддерживают его в актуальном состоянии.
  final Map<AppLang, ValueNotifier<Set<int>>> _idsByLang = {};

  FavoritesStore({required Database db, DateTime Function()? now})
    : _db = db,
      _now = now ?? DateTime.now;

  /// Возвращает живой [ValueListenable] множества id, отмеченных
  /// в данном языке. Виджет-сердце слушает его и перерисовывается
  /// при добавлении / удалении.
  ValueListenable<Set<int>> idsForLang(AppLang lang) => _ensureNotifier(lang);

  /// Текущий снимок множества (без подписки).
  Set<int> snapshotForLang(AppLang lang) =>
      Set<int>.unmodifiable(_ensureNotifier(lang).value);

  /// Подгружает множество id для языка из БД, если ещё не подгружено.
  /// Полезно вызвать при старте приложения для текущего языка
  /// (UI получит готовое значение без мерцания).
  Future<Set<int>> ensureLoaded(AppLang lang) async {
    final notifier = _ensureNotifier(lang);
    if (notifier.value.isNotEmpty || _loadedLangs.contains(lang)) {
      return notifier.value;
    }
    final rows = await _db.query(
      'favorites',
      columns: const ['recipe_id'],
      where: 'lang = ?',
      whereArgs: [lang.name],
    );
    final ids = {for (final r in rows) r['recipe_id']! as int};
    notifier.value = ids;
    _loadedLangs.add(lang);
    return ids;
  }

  final Set<AppLang> _loadedLangs = <AppLang>{};

  /// `true`, если рецепт отмечен в данном языке.
  Future<bool> isFavorite(int recipeId, AppLang lang) async {
    final ids = await ensureLoaded(lang);
    return ids.contains(recipeId);
  }

  /// Добавляет рецепт в избранное в данном языке. Идемпотентно:
  /// повторный вызов обновляет `saved_at`, но не плодит строки
  /// (PK = `(recipe_id, lang)`).
  Future<void> add(int recipeId, AppLang lang) async {
    await _db.insert('favorites', {
      'recipe_id': recipeId,
      'lang': lang.name,
      'saved_at': _now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await ensureLoaded(lang);
    final notifier = _ensureNotifier(lang);
    if (!notifier.value.contains(recipeId)) {
      notifier.value = {...notifier.value, recipeId};
    }
  }

  /// Удаляет рецепт из избранного в данном языке.
  Future<void> remove(int recipeId, AppLang lang) async {
    await _db.delete(
      'favorites',
      where: 'recipe_id = ? AND lang = ?',
      whereArgs: [recipeId, lang.name],
    );
    await ensureLoaded(lang);
    final notifier = _ensureNotifier(lang);
    if (notifier.value.contains(recipeId)) {
      final next = {...notifier.value}..remove(recipeId);
      notifier.value = next;
    }
  }

  /// Удаляет рецепт из избранного во всех языках. Используется
  /// owner-delete-flow-ом: рецепт исчез с сервера → не должен
  /// висеть в избранном ни на одной локали.
  Future<void> removeAcrossLangs(int recipeId) async {
    await _db.delete(
      'favorites',
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
    );
    for (final entry in _idsByLang.entries) {
      if (entry.value.value.contains(recipeId)) {
        final next = {...entry.value.value}..remove(recipeId);
        entry.value.value = next;
      }
    }
  }

  /// Переключает состояние избранного: если рецепт был — удаляет,
  /// иначе добавляет. Возвращает новое состояние (`true` = в
  /// избранном).
  Future<bool> toggle(int recipeId, AppLang lang) async {
    final isFav = await isFavorite(recipeId, lang);
    if (isFav) {
      await remove(recipeId, lang);
      return false;
    }
    await add(recipeId, lang);
    return true;
  }

  /// Список избранных рецептов в данном языке, в порядке
  /// `saved_at DESC` (последние добавленные сверху). Делает JOIN
  /// с `recipes`; если для строки нет тела в кэше — рецепт всё
  /// равно вернётся, но без `instructions`. Чанк D достаёт тело
  /// уже на странице деталей через `RecipeRepository.getInstructions`.
  Future<List<Recipe>> list(AppLang lang) async {
    final rows = await _db.rawQuery(
      'SELECT r.* '
      'FROM favorites f '
      'INNER JOIN recipes r '
      '  ON r.id = f.recipe_id AND r.lang = f.lang '
      'WHERE f.lang = ? '
      'ORDER BY f.saved_at DESC',
      [lang.name],
    );
    return rows.map(readRecipe).toList(growable: false);
  }

  /// id избранных, у которых нет соответствующей строки в `recipes`
  /// (например, из-за LRU-вытеснения). Экран избранного использует
  /// это, чтобы добрать тела через `RecipeApi.lookup`.
  Future<List<int>> orphanIds(AppLang lang) async {
    final rows = await _db.rawQuery(
      'SELECT f.recipe_id AS id '
      'FROM favorites f '
      'LEFT JOIN recipes r '
      '  ON r.id = f.recipe_id AND r.lang = f.lang '
      'WHERE f.lang = ? AND r.id IS NULL '
      'ORDER BY f.saved_at DESC',
      [lang.name],
    );
    return rows.map((r) => r['id']! as int).toList(growable: false);
  }

  ValueNotifier<Set<int>> _ensureNotifier(AppLang lang) =>
      _idsByLang.putIfAbsent(lang, () => ValueNotifier<Set<int>>(<int>{}));
}
