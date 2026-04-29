import 'package:sqflite/sqflite.dart';

import '../../i18n.dart';
import '../../models/recipe.dart';
import '../api/recipe_api.dart';
import '../local/recipe_db.dart';

/// Результат поискового запроса в репозитории — список рецептов
/// плюс флаги для UI: что приехало из локального кэша и был ли
/// сетевой сбой.
class RecipeSearchResult {
  final List<Recipe> recipes;

  /// `true`, если все рецепты пришли из локальной БД и сеть не
  /// дёргалась.
  final bool fromCache;

  /// `true`, если попытались сходить в сеть, но получили ошибку
  /// (и в кэше тоже было пусто). UI показывает offline-баннер.
  final bool offline;

  const RecipeSearchResult({
    required this.recipes,
    required this.fromCache,
    required this.offline,
  });
}

/// Фасад между UI и слоями данных:
///
/// 1. Локальный sqflite-кэш с LRU-вытеснением (`cap = 200`).
/// 2. [RecipeApi] поверх TheMealDB / mahallem.
///
/// Логика поиска:
/// * Сперва `name_lower LIKE 'prefix%'` по таблице `recipes`
///   с фильтром `lang = ?`. Если нашлось `>= cacheHitThreshold`
///   совпадений — возвращаем их и обновляем `last_used_at` (LRU
///   touch). Сеть не трогаем.
/// * Иначе — `RecipeApi.searchByName(query: prefix, lang: lang)`,
///   найденные рецепты upsert-ятся в кэш, лишнее вытесняется.
/// * Если сеть упала и в кэше нашлось `0` — возвращаем пустой
///   список и `offline=true`.
/// Фасад между UI и слоями данных:
///
/// 1. Локальный sqflite-кэш с LRU-вытеснением по двум лимитам:
///    количество строк `cap` и суммарный размер `byteCap` (≈5 MB).
/// 2. [RecipeApi] поверх TheMealDB / mahallem.
///
/// Логика поиска:
/// * Сперва `name_lower LIKE 'prefix%'` по таблице `recipes`
///   с фильтром `lang = ?`. Если нашлось `>= cacheHitThreshold`
///   совпадений — возвращаем их и обновляем `last_used_at` (LRU
///   touch). Сеть не трогаем.
/// * Иначе — `RecipeApi.searchByName(query: prefix, lang: lang)`,
///   найденные рецепты upsert-ятся в кэш, лишнее вытесняется.
/// * Если сеть упала и в кэше нашлось `0` — возвращаем пустой
///   список и `offline=true`.
class RecipeRepository {
  /// 5 MB — бюджет локального кэша по дефолту. При превышении
  /// вытесняем LRU-редко используемые карточки, пока сумма
  /// `byte_size` не вернётся под лимит.
  static const int kDefaultByteCap = 5 * 1024 * 1024;

  final Database _db;
  final RecipeApi _api;
  final int cap;
  final int byteCap;
  final int cacheHitThreshold;
  final DateTime Function() _now;

  RecipeRepository({
    required Database db,
    required RecipeApi api,
    this.cap = 2000,
    this.byteCap = kDefaultByteCap,
    this.cacheHitThreshold = 5,
    DateTime Function()? now,
  }) : _db = db,
       _api = api,
       _now = now ?? DateTime.now;

  Future<RecipeSearchResult> searchByName(String prefix, AppLang lang) async {
    final p = prefix.trim().toLowerCase();
    if (p.isEmpty) {
      return const RecipeSearchResult(
        recipes: [],
        fromCache: true,
        offline: false,
      );
    }
    final cacheHits = await _localPrefix(p, lang);
    if (cacheHits.length >= cacheHitThreshold) {
      await _touch(cacheHits.map((r) => r.id).toList(), lang);
      return RecipeSearchResult(
        recipes: cacheHits,
        fromCache: true,
        offline: false,
      );
    }

    try {
      final fetched = await _api.searchByName(query: prefix, lang: lang);
      // TheMealDB отдаёт по подстроке — оставляем только startsWith,
      // как и раньше делал UI.
      final filtered = fetched
          .where((r) => r.name.toLowerCase().startsWith(p))
          .toList(growable: false);
      await _upsertAll(filtered, lang);
      return RecipeSearchResult(
        recipes: filtered,
        fromCache: false,
        offline: false,
      );
    } on Object {
      return RecipeSearchResult(
        recipes: cacheHits,
        fromCache: true,
        offline: cacheHits.isEmpty,
      );
    }
  }

  Future<Recipe?> lookup(int id, AppLang lang) async {
    final rows = await _db.query(
      'recipes',
      where: 'id = ? AND lang = ?',
      whereArgs: [id, lang.name],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      await _touch([id], lang);
      final cached = readRecipe(rows.first);
      if (!cached.isLite) return cached;
    }
    try {
      final fetched = await _api.lookup(id, lang: lang);
      if (fetched != null) await _upsert(fetched, lang);
      return fetched;
    } on Object {
      // Если сети нет, но в кэше есть хоть lite-копия — возвращаем её.
      return rows.isEmpty ? null : readRecipe(rows.first);
    }
  }

  /// Bulk cache-only lookup: для каждого id вернёт перевод под `lang`
  /// из локальной БД, либо `null`, если перевода ещё нет. Сеть НЕ
  /// трогается. Используется на смене языка, чтобы мгновенно перерисовать
  /// уже скачанные карточки, а сеть гонять только за промахами.
  Future<Map<int, Recipe>> lookupManyCached(List<int> ids, AppLang lang) async {
    if (ids.isEmpty) return const {};
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await _db.query(
      'recipes',
      where: 'id IN ($placeholders) AND lang = ?',
      whereArgs: [...ids, lang.name],
    );
    final out = <int, Recipe>{};
    for (final r in rows) {
      final rec = readRecipe(r);
      if (!rec.isLite) out[rec.id] = rec;
    }
    if (out.isNotEmpty) {
      await _touch(out.keys.toList(growable: false), lang);
    }
    return out;
  }

  /// Используется фоновым прогревом / тестами.
  Future<void> upsertAll(List<Recipe> recipes, AppLang lang) =>
      _upsertAll(recipes, lang);

  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM recipes;');
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Сколько рецептов в кэше под выбранный язык.
  Future<int> countFor(AppLang lang) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM recipes WHERE lang = ?;',
      [lang.name],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Сколько рецептов в кэше под язык `lang` в категории `category`.
  /// Используется лоадером, чтобы понять, пора ли идти в сеть за
  /// свежими рецептами данной категории.
  Future<int> countForCategory(String category, AppLang lang) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM recipes '
      'WHERE lang = ? AND category = ? COLLATE NOCASE;',
      [lang.name, category],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Рецепты одной категории из локальной БД, отсортированные
  /// по LRU-свежести. Сеть не трогается.
  Future<List<Recipe>> listCachedByCategory(
    String category,
    AppLang lang, {
    int limit = 50,
  }) async {
    final rows = await _db.query(
      'recipes',
      where: 'lang = ? AND category = ? COLLATE NOCASE',
      whereArgs: [lang.name, category],
      orderBy: 'last_used_at DESC',
      limit: limit,
    );
    return rows.map(readRecipe).toList(growable: false);
  }

  /// Сумма `byte_size` по всем языкам. Используется для
  /// бюджетного LRU-вытеснения.
  Future<int> totalBytes() async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(byte_size), 0) AS b FROM recipes;',
    );
    final v = rows.first['b'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  /// Топ-N рецептов из кэша для языка [lang], отсортированных
  /// LRU-новизной (свежие — первыми). Используется как мгновенный
  /// preload на старте: UI показывает 200 локальных карточек ещё
  /// до похода в сеть.
  Future<List<Recipe>> listCached(AppLang lang, {int limit = 200}) async {
    final rows = await _db.query(
      'recipes',
      where: 'lang = ?',
      whereArgs: [lang.name],
      orderBy: 'last_used_at DESC',
      limit: limit,
    );
    return rows.map(readRecipe).toList(growable: false);
  }

  Future<void> _upsertAll(List<Recipe> recipes, AppLang lang) async {
    if (recipes.isEmpty) return;
    final ts = _now().millisecondsSinceEpoch;
    final batch = _db.batch();
    for (final r in recipes) {
      batch.insert(
        'recipes',
        writeRecipe(r, lang: lang.name, lastUsedAt: ts),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    await _evictIfOverCap();
  }

  Future<void> _upsert(Recipe r, AppLang lang) => _upsertAll([r], lang);

  Future<List<Recipe>> _localPrefix(String prefixLower, AppLang lang) async {
    final escaped = prefixLower
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final rows = await _db.query(
      'recipes',
      where: r"lang = ? AND name_lower LIKE ? ESCAPE '\'",
      whereArgs: [lang.name, '$escaped%'],
      orderBy: 'name_lower ASC',
    );
    return rows.map(readRecipe).toList(growable: false);
  }

  Future<void> _touch(List<int> ids, AppLang lang) async {
    if (ids.isEmpty) return;
    final ts = _now().millisecondsSinceEpoch;
    final placeholders = List.filled(ids.length, '?').join(',');
    await _db.rawUpdate(
      'UPDATE recipes SET last_used_at = ? '
      'WHERE lang = ? AND id IN ($placeholders);',
      [ts, lang.name, ...ids],
    );
  }

  Future<void> _evictIfOverCap() async {
    // 1) Сначала жёсткий байт-бюджет: вытесняем LRU-строки
    //    пачками по 32, пока суммарный размер не вернётся под порог.
    var bytes = await totalBytes();
    while (bytes > byteCap) {
      final removed = await _db.rawDelete(
        'DELETE FROM recipes WHERE rowid IN ('
        'SELECT rowid FROM recipes ORDER BY last_used_at ASC LIMIT 32'
        ');',
      );
      if (removed == 0) break;
      bytes = await totalBytes();
    }

    // 2) Страховочный лимит по числу строк (защита от
    //    бесконечного роста индексов, если byte_size окажется занижен).
    final total = await count();
    if (total > cap) {
      final overflow = total - cap;
      await _db.rawDelete(
        'DELETE FROM recipes WHERE rowid IN ('
        'SELECT rowid FROM recipes ORDER BY last_used_at ASC LIMIT ?'
        ');',
        [overflow],
      );
    }
  }
}
