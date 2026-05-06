import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../auth/admin_session.dart';
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

/// Гарантирует, что глобальный [FavoritesStore] инициализирован.
///
/// Нужен как fail-safe для web: если репозиторий не поднялся в
/// `RecipeListLoader` (например, при временной ошибке открытия БД),
/// сердце не должно оставаться «мертвым» с `onTap: null`.
///
/// Возвращает готовый стор либо `null`, если инициализация не удалась.
Future<FavoritesStore?> ensureFavoritesStoreInitialized() async {
  final existing = favoritesStoreNotifier.value;
  if (existing != null) {
    try {
      await existing.ensureLoaded(appLang.value);
    } on Object {
      // Прогрев не критичен: стор уже есть, UI может работать.
    }
    return existing;
  }

  try {
    final db = await openRecipeDatabase();
    final store = FavoritesStore(db: db);
    favoritesStoreNotifier.value = store;
    try {
      await store.ensureLoaded(appLang.value);
    } on Object {
      // Не блокируем работу бейджа из-за ошибки прогрева.
    }
    return store;
  } on Object catch (e) {
    debugPrint('[favorites] store init failed: $e');
    return null;
  }
}

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
  final Map<AppLang, String?> _remoteSyncKeyByLang = {};
  String? _sessionCacheKey;

  /// Per-recipe live favorite-count notifier. Lets the heart pill
  /// reflect real-time deltas after [add] / [remove] without
  /// waiting for a `/page` refresh, and stays consistent with the
  /// value persisted into the `recipes.favorites_count` column so
  /// reload-from-cache shows the same number.
  final Map<int, ValueNotifier<int>> _countByRecipe = {};

  FavoritesStore({required Database db, DateTime Function()? now})
    : _db = db,
      _now = now ?? DateTime.now;

  /// Возвращает живой [ValueListenable] множества id, отмеченных
  /// в данном языке. Виджет-сердце слушает его и перерисовывается
  /// при добавлении / удалении. Если язык ещё не загружался,
  /// триггерит фоновую загрузку из БД (fire-and-forget) — иначе
  /// при смене языка бейджи на список секунду рисовали бы
  /// контурные сердца до первого захода в /favorites.
  ValueListenable<Set<int>> idsForLang(AppLang lang) {
    _syncSessionContext();
    return _ensureNotifier(lang);
  }

  /// Текущий снимок множества (без подписки).
  Set<int> snapshotForLang(AppLang lang) {
    _syncSessionContext();
    return Set<int>.unmodifiable(_ensureNotifier(lang).value);
  }

  /// Подгружает множество id для языка из БД, если ещё не подгружено.
  /// Полезно вызвать при старте приложения для текущего языка
  /// (UI получит готовое значение без мерцания).
  Future<Set<int>> ensureLoaded(AppLang lang) async {
    _syncSessionContext();
    final notifier = _ensureNotifier(lang);
    final currentSyncKey = _currentRemoteSyncKey();
    final needsRemoteSync =
        canSyncFavoritesRemotely &&
        _remoteSyncKeyByLang[lang] != currentSyncKey;
    if (!needsRemoteSync &&
        (notifier.value.isNotEmpty || _loadedLangs.contains(lang))) {
      return notifier.value;
    }

    if (needsRemoteSync) {
      try {
        final remoteIds = await fetchRemoteFavorites(lang);
        await _db.transaction((txn) async {
          await txn.delete(
            'favorites',
            where: 'lang = ?',
            whereArgs: [lang.name],
          );
          final savedAt = _now().millisecondsSinceEpoch;
          for (final recipeId in remoteIds) {
            await txn.insert('favorites', {
              'recipe_id': recipeId,
              'lang': lang.name,
              'saved_at': savedAt,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        });
        notifier.value = remoteIds;
        _loadedLangs.add(lang);
        _remoteSyncKeyByLang[lang] = currentSyncKey;
        return remoteIds;
      } on Object catch (e) {
        debugPrint('[favorites] remote sync failed, using local cache: $e');
      }
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
    _remoteSyncKeyByLang[lang] = currentSyncKey;
    return ids;
  }

  final Set<AppLang> _loadedLangs = <AppLang>{};

  /// `true`, если рецепт отмечен в данном языке.
  Future<bool> isFavorite(int recipeId, AppLang lang) async {
    final ids = await ensureLoaded(lang);
    return ids.contains(recipeId);
  }

  /// Live favorites count for [recipeId]. The first call seeds the
  /// notifier with [seed] (the server-projected count from the last
  /// `/page` or `/lookup` payload). Subsequent calls reuse the same
  /// notifier — they do NOT reset to a stale seed — so optimistic
  /// deltas applied via [add] / [remove] are preserved across
  /// rebuilds. The stored value is also persisted into
  /// `recipes.favorites_count` so reload from cache survives a
  /// process restart.
  ValueListenable<int> countFor(int recipeId, {required int seed}) {
    final existing = _countByRecipe[recipeId];
    if (existing != null) return existing;
    final notifier = ValueNotifier<int>(seed < 0 ? 0 : seed);
    _countByRecipe[recipeId] = notifier;
    return notifier;
  }

  /// Bumps both the in-memory notifier (if any) and the cached
  /// `recipes.favorites_count` row across all languages by [delta].
  /// Idempotent: clamps at zero.
  Future<void> _bumpRecipeFavCount(int recipeId, int delta) async {
    if (delta == 0) return;
    try {
      await _db.rawUpdate(
        'UPDATE recipes SET favorites_count = MAX(0, favorites_count + ?) '
        'WHERE id = ?',
        [delta, recipeId],
      );
    } on Object catch (e) {
      debugPrint('[favorites] bump cache failed: $e');
    }
    final notifier = _countByRecipe[recipeId];
    if (notifier != null) {
      final next = notifier.value + delta;
      notifier.value = next < 0 ? 0 : next;
    }
  }

  /// Добавляет рецепт в избранное в данном языке. Идемпотентно:
  /// повторный вызов обновляет `saved_at`, но не плодит строки
  /// (PK = `(recipe_id, lang)`).
  Future<void> add(int recipeId, AppLang lang) async {
    _syncSessionContext();
    await ensureLoaded(lang);
    final notifier = _ensureNotifier(lang);
    final wasMember = notifier.value.contains(recipeId);
    await _db.insert('favorites', {
      'recipe_id': recipeId,
      'lang': lang.name,
      'saved_at': _now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (!wasMember) {
      notifier.value = {...notifier.value, recipeId};
      await _bumpRecipeFavCount(recipeId, 1);
    }
    try {
      await setRemoteFavorite(recipeId: recipeId, lang: lang, favorite: true);
    } on Object catch (e) {
      debugPrint('[favorites] remote add failed: $e');
    }
  }

  /// Удаляет рецепт из избранного в данном языке.
  Future<void> remove(int recipeId, AppLang lang) async {
    _syncSessionContext();
    await ensureLoaded(lang);
    final notifier = _ensureNotifier(lang);
    final wasMember = notifier.value.contains(recipeId);
    await _db.delete(
      'favorites',
      where: 'recipe_id = ? AND lang = ?',
      whereArgs: [recipeId, lang.name],
    );
    if (wasMember) {
      final next = {...notifier.value}..remove(recipeId);
      notifier.value = next;
      await _bumpRecipeFavCount(recipeId, -1);
    }
    try {
      await setRemoteFavorite(recipeId: recipeId, lang: lang, favorite: false);
    } on Object catch (e) {
      debugPrint('[favorites] remote remove failed: $e');
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
    _syncSessionContext();
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
    await ensureLoaded(lang);
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

  String? _currentRemoteSyncKey() {
    if (!canSyncFavoritesRemotely) return null;
    final login = currentUserLoginNotifier.value;
    final token = currentUserTokenNotifier.value;
    if (login == null || login.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    return '$login::$token';
  }

  void _syncSessionContext() {
    final nextSessionKey = _currentSessionCacheKey();
    if (_sessionCacheKey == nextSessionKey) return;
    _sessionCacheKey = nextSessionKey;
    _loadedLangs.clear();
    _remoteSyncKeyByLang.clear();
    for (final notifier in _idsByLang.values) {
      if (notifier.value.isNotEmpty) {
        notifier.value = <int>{};
      }
    }
    if (canSyncFavoritesRemotely) {
      final lang = appLang.value;
      unawaited(ensureLoaded(lang));
    }
  }

  String _currentSessionCacheKey() {
    final login = currentUserLoginNotifier.value;
    final token = currentUserTokenNotifier.value ?? '';
    if (!userLoggedInNotifier.value || login == null || login.isEmpty) {
      return 'guest';
    }
    return '$login::$token';
  }
}
