import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Глобальный держатель текущего [OwnedRecipesStore]. Заполняется
/// фабрикой репозитория после открытия БД и читается виджетами,
/// которые показывают «свои» рецепты (кнопки edit/delete на
/// [RecipeDetailsPage]). До инициализации `value == null` — UI
/// просто не рисует кнопки владельца.
final ValueNotifier<OwnedRecipesStore?> ownedRecipesStoreNotifier =
    ValueNotifier<OwnedRecipesStore?>(null);

/// Локальный реестр рецептов, созданных на этом устройстве через
/// [AddRecipePage]. Персистится в sqflite (`owned_recipes`,
/// схема v7), переживает рестарт приложения. Сервер сейчас не
/// поддерживает per-user auth (см. docs/owner-edit-delete.md);
/// единственный признак «я хозяин» — то, что устройство помнит
/// факт создания.
class OwnedRecipesStore {
  OwnedRecipesStore({required Database db, DateTime Function()? now})
    : _db = db,
      _now = now ?? DateTime.now;

  final Database _db;
  final DateTime Function() _now;

  /// Кэш id в памяти. Обновляется через [add]/[remove]/[ensureLoaded].
  /// Виджет owner-кнопок слушает его и перерисовывается при изменении.
  final ValueNotifier<Set<int>> ids = ValueNotifier<Set<int>>({});
  bool _loaded = false;

  /// Floor id, ниже которого рецепт считается импортированным из
  /// TheMealDB и владельцем по определению быть не может. Должен
  /// совпадать с `RECIPES_USER_MEAL_ID_FLOOR` на бэкенде
  /// (см. docs/owner-edit-delete.md).
  static const int userMealIdFloor = 1000000;

  Future<Set<int>> ensureLoaded() async {
    if (_loaded) return ids.value;
    // Бэкфил: до v7-миграции таблица `owned_recipes` не существовала,
    // но сами пользовательские рецепты уже могли быть созданы (их id
    // ≥ [userMealIdFloor]). Один раз при первой загрузке заносим
    // такие записи в реестр, чтобы owner-кнопки появились на ранее
    // созданных рецептах.
    final ownedRows = await _db.query('owned_recipes', columns: const ['id']);
    final existing = {for (final r in ownedRows) r['id']! as int};
    final candidateRows = await _db.query(
      'recipes',
      columns: const ['id'],
      where: 'id >= ?',
      whereArgs: [userMealIdFloor],
    );
    final candidates = {for (final r in candidateRows) r['id']! as int};
    final missing = candidates.difference(existing);
    if (missing.isNotEmpty) {
      final batch = _db.batch();
      final nowMs = _now().millisecondsSinceEpoch;
      for (final id in missing) {
        batch.insert('owned_recipes', {
          'id': id,
          'created_at': nowMs,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    }
    ids.value = existing.union(candidates);
    _loaded = true;
    return ids.value;
  }

  bool isOwned(int recipeId) => ids.value.contains(recipeId);

  Future<void> add(int recipeId) async {
    await _db.insert('owned_recipes', {
      'id': recipeId,
      'created_at': _now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await ensureLoaded();
    if (!ids.value.contains(recipeId)) {
      ids.value = {...ids.value, recipeId};
    }
  }

  Future<void> remove(int recipeId) async {
    await _db.delete('owned_recipes', where: 'id = ?', whereArgs: [recipeId]);
    await ensureLoaded();
    if (ids.value.contains(recipeId)) {
      final next = {...ids.value}..remove(recipeId);
      ids.value = next;
    }
  }
}
