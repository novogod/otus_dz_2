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
///    количество строк `cap` (20000) и суммарный размер `byteCap` (256 MB).
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
  /// 256 MB — бюджет локального кэша по дефолту. При превышении
  /// вытесняем LRU-редко используемые карточки, пока сумма
  /// `byte_size` не вернётся под лимит. Расчёт: при росте ленты
  /// (~600 рецептов на 10 языках × ~15 KB с инструкциями + переводы
  /// в `recipe_bodies`) набирается ~90 MB; +хвост из ранее
  /// просмотренных рецептов и избранного — упираться в потолок
  /// должно происходить редко, а не на каждом ребуте. До бампа
  /// были 64 MB / 8000 rows: при включении favorites (доп. строки
  /// сохраняются «вечно») кэш быстрее вытесняется по LRU, ленту
  /// в текущем языке режет ниже порога `categoryCacheThreshold`,
  /// и reload сваливается в дорогой fan-out по категориям.
  static const int kDefaultByteCap = 256 * 1024 * 1024;

  final Database _db;
  final RecipeApi _api;
  final int cap;
  final int byteCap;
  final int cacheHitThreshold;
  final DateTime Function() _now;

  RecipeRepository({
    required Database db,
    required RecipeApi api,
    this.cap = 20000,
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

    // Стреляем в локальный кэш и в API одновременно — без short-circuit'а
    // «достаточно кэша». Так пользователь всегда получает максимум
    // совпадений: и то, что уже было оффлайн, и свежак с сервера.
    final cacheFuture = _localSubstring(p, lang);
    final apiFuture = _api
        .searchByName(query: prefix, lang: lang)
        .catchError((Object _) => const <Recipe>[]);

    final cacheHits = await cacheFuture;
    List<Recipe> apiHits = const [];
    var apiFailed = false;
    try {
      apiHits = await apiFuture;
    } on Object {
      apiFailed = true;
    }

    // Дедуп по id, кэш — первым (LRU «свежак»), затем то, что докинула сеть.
    final seen = <int>{};
    final merged = <Recipe>[];
    for (final r in cacheHits) {
      if (seen.add(r.id)) merged.add(r);
    }
    for (final r in apiHits) {
      if (seen.add(r.id)) merged.add(r);
    }

    if (cacheHits.isNotEmpty) {
      await _touch(cacheHits.map((r) => r.id).toList(), lang);
    }
    if (apiHits.isNotEmpty) {
      await _upsertAll(apiHits, lang);
    }

    return RecipeSearchResult(
      recipes: merged,
      fromCache: apiHits.isEmpty,
      offline: apiFailed && cacheHits.isEmpty,
    );
  }

  Future<Recipe?> lookup(int id, AppLang lang, {Duration? timeout}) async {
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
      final fetched = await _api.lookup(id, lang: lang, timeout: timeout);
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

  /// Удаляет все локали рецепта из локального кэша. Триггер
  /// [_kBodyCascadeTrigger] подберёт `recipe_bodies`, поэтому
  /// явный delete из тела не нужен. Используется owner-flow-ом,
  /// см. docs/owner-edit-delete.md.
  Future<void> deleteById(int id) async {
    await _db.delete('recipes', where: 'id = ?', whereArgs: [id]);
  }

  /// Lazy-loads the heavy HTML instructions blob from `recipe_bodies`
  /// (todo/12). Returns `null` when the row was evicted by the LRU or
  /// the recipe was inserted lite (no instructions). Touches
  /// `last_used_at` on the parent row so reading the body keeps the
  /// recipe alive.
  Future<String?> getInstructions(int id, AppLang lang) async {
    final rows = await _db.query(
      'recipe_bodies',
      columns: ['instructions'],
      where: 'id = ? AND lang = ?',
      whereArgs: [id, lang.name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    await _touch([id], lang);
    final v = rows.first['instructions'];
    return v is String ? v : null;
  }

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
      // todo/12: persist heavy `instructions` blob in a sibling
      // table so list-row reads stay light. We only insert when
      // the recipe actually carries instructions; otherwise keep
      // any existing body untouched (e.g. lite list-row payload
      // shouldn't wipe the cached body).
      if (r.instructions != null && r.instructions!.isNotEmpty) {
        batch.insert(
          'recipe_bodies',
          writeRecipeBody(r, lang: lang.name),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
    await _evictIfOverCap(activeLang: lang);
  }

  Future<void> _upsert(Recipe r, AppLang lang) => _upsertAll([r], lang);

  Future<List<Recipe>> _localSubstring(String needleLower, AppLang lang) async {
    final escaped = needleLower
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final rows = await _db.query(
      'recipes',
      where: r"lang = ? AND name_lower LIKE ? ESCAPE '\'",
      whereArgs: [lang.name, '%$escaped%'],
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

  /// Бюджетное LRU-вытеснение с разделением по языку (todo/11).
  ///
  /// Активному языку выделяем 60 % от `byteCap`, остальным — 40 % на
  /// всех. Сначала режем «прочие языки» по LRU, и только если этого
  /// не хватило — вытесняем самые старые строки активного языка.
  /// Это значит, что переключение языка не выкидывает прогретый
  /// основной кэш пользователя.
  ///
  /// Если [activeLang] не передан, поведение совместимо со старым
  /// глобальным LRU.
  Future<void> _evictIfOverCap({AppLang? activeLang}) async {
    if (activeLang == null) {
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
    } else {
      // 60 / 40 split. Округляем вниз: чуть жёстче, чем нужно.
      final activeBudget = (byteCap * 6) ~/ 10;
      final othersBudget = byteCap - activeBudget;

      // 1) Срезаем «другие языки» по LRU, пока не уложимся в их 40 %.
      var othersBytes = await _bytesFor(activeLang, isActive: false);
      while (othersBytes > othersBudget) {
        final removed = await _db.rawDelete(
          'DELETE FROM recipes WHERE rowid IN ('
          'SELECT rowid FROM recipes WHERE lang <> ? '
          'ORDER BY last_used_at ASC LIMIT 32'
          ');',
          [activeLang.name],
        );
        if (removed == 0) break;
        othersBytes = await _bytesFor(activeLang, isActive: false);
      }

      // 2) Если активный язык сам перерос свой бюджет — режем его LRU.
      var activeBytes = await _bytesFor(activeLang, isActive: true);
      while (activeBytes > activeBudget) {
        final removed = await _db.rawDelete(
          'DELETE FROM recipes WHERE rowid IN ('
          'SELECT rowid FROM recipes WHERE lang = ? '
          'ORDER BY last_used_at ASC LIMIT 32'
          ');',
          [activeLang.name],
        );
        if (removed == 0) break;
        activeBytes = await _bytesFor(activeLang, isActive: true);
      }
    }

    // 3) Страховочный лимит по числу строк (защита от
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

  Future<int> _bytesFor(AppLang lang, {required bool isActive}) async {
    final rows = await _db.rawQuery(
      isActive
          ? 'SELECT COALESCE(SUM(byte_size), 0) AS b FROM recipes WHERE lang = ?;'
          : 'SELECT COALESCE(SUM(byte_size), 0) AS b FROM recipes WHERE lang <> ?;',
      [lang.name],
    );
    final v = rows.first['b'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }
}
