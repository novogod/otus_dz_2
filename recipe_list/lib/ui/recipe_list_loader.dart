import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth/admin_session.dart';
import '../config/feed_config.dart';
import '../data/api/recipe_api.dart';
import '../data/api/recipe_api_config.dart';
import '../data/local/recipe_db.dart';
import '../data/repository/favorites_store.dart';
import '../data/repository/owned_recipes_store.dart';
import '../data/repository/recipe_repository.dart';
import '../i18n.dart';
import '../models/recipe.dart';
import 'app_theme.dart';
import 'recipe_details_page.dart' show activeDetailsCount;
import 'recipe_list_page.dart';

/// Загружает список рецептов и поднимает локальный кэш.
///
/// Параллельно с первым `searchByName` открывает sqflite-БД,
/// создаёт [RecipeRepository] и кладёт начальную выдачу в кэш —
/// это делает повторное открытие приложения мгновенным даже без
/// сети (см. §B6/B7 docs/todo/search_api_deploy.md).
///
/// Если открытие БД упало (например, в widget-тестах без
/// path_provider), репозиторий остаётся `null` и страница
/// работает по старому пути «прямой `RecipeApi`».
class RecipeListLoader extends StatefulWidget {
  final RecipeApi api;
  final Future<List<Recipe>> Function(RecipeApi api)? loader;

  /// Если задан — переопределяет создание репозитория. В тестах
  /// сюда передают `(_) async => null`, чтобы пропустить sqflite.
  final Future<RecipeRepository?> Function(RecipeApi api)? repositoryBuilder;

  /// Tunables for the feed (seed target, pick count, etc.). Defaults
  /// pick up `--dart-define` overrides. See [FeedConfig].
  final FeedConfig config;

  RecipeListLoader({
    super.key,
    RecipeApi? api,
    this.loader,
    this.repositoryBuilder,
    FeedConfig? config,
  }) : api = api ?? RecipeApi(),
       config = config ?? FeedConfig.fromDartDefine();

  /// Чистая функция для unit-тестов: вернуть `count` случайных
  /// категорий из `pool`, по возможности избегая совпадений с
  /// `exclude`. Если оставшийся пул короче `count`, перетасовываем
  /// весь `pool` целиком (см. todo/05).
  @visibleForTesting
  static List<String> pickCategoriesFor({
    required int count,
    required List<String> pool,
    required List<String> exclude,
  }) {
    final remaining = pool.where((c) => !exclude.contains(c)).toList()
      ..shuffle();
    final base = remaining.length >= count ? remaining : ([...pool]..shuffle());
    return base.take(count).toList(growable: false);
  }

  @override
  State<RecipeListLoader> createState() => _RecipeListLoaderState();
}

class _RecipeListLoaderState extends State<RecipeListLoader> {
  late Future<_LoadResult> _future;
  final ValueNotifier<_LoadStage> _stage = ValueNotifier(
    const _LoadStage.initial(),
  );

  /// Последний успешно загруженный результат — нужен, чтобы на
  /// смене языка переводить ровно те же рецепты в том же порядке
  /// (никакого re-seed + shuffle).
  _LoadResult? _lastResult;

  /// `true`, пока идёт перевод ленты на новый язык. Используется
  /// в `build`, чтобы принудительно показать `_LoadingScreen` с
  /// прогресс-индикатором и НЕ мигать частично-переведённой лентой
  /// до тех пор, пока все карточки не приедут из mahallem-кэша/MT.
  bool _translating = false;

  /// Монотонный счётчик попыток перевода. Если пользователь жмёт
  /// кнопку языка ещё раз, пока предыдущая `_retranslate` не
  /// доехала, последний результат не должен перезаписать новый.
  int _translateSeq = 0;

  /// Язык, на который надо будет перевести ленту, как только
  /// пользователь вернётся со страницы деталей. Если пользователь
  /// сменил язык, сидя в деталях, мы НЕ запускаем `_retranslate`
  /// прямо сейчас (он бы засатурировал сервер и `/lookup`
  /// деталей упал бы по 504 — см. docs/details-lang-cycle-504.md).
  /// Запоминаем язык и запускаем `_retranslate`, когда счётчик
  /// `activeDetailsCount` опускается до нуля.
  AppLang? _pendingBackgroundLang;

  @override
  void initState() {
    super.initState();
    _future = _runLoad().then((r) {
      _lastResult = r;
      return r;
    });
    appLang.addListener(_onLangChanged);
    activeDetailsCount.addListener(_onActiveDetailsChanged);
    reloadFeedTicker.addListener(_onReloadRequested);
  }

  @override
  void dispose() {
    appLang.removeListener(_onLangChanged);
    activeDetailsCount.removeListener(_onActiveDetailsChanged);
    reloadFeedTicker.removeListener(_onReloadRequested);
    _stage.dispose();
    super.dispose();
  }

  void _onActiveDetailsChanged() {
    if (!mounted) return;
    if (activeDetailsCount.value > 0) return;
    final pending = _pendingBackgroundLang;
    if (pending == null) return;
    if (pending != appLang.value) {
      _pendingBackgroundLang = null;
      return;
    }
    _pendingBackgroundLang = null;
    // Detail page popped, language still differs — run the deferred
    // retranslate now that the foreground is the list again.
    //
    // Этот колбэк часто прилетает прямо из `RecipeDetailsPage.dispose`
    // (когда пользователь нажал назад: декремент `activeDetailsCount`
    // случается, пока widget tree «locked» — фаза unmount). Если
    // вызвать `_onLangChanged()` синхронно — внутри он дёрнет
    // `setState`, и фреймворк бросит «setState() called when widget
    // tree was locked». Откладываем до следующего микротаска: к этому
    // моменту dispose-фаза завершится и tree снова будет writable.
    scheduleMicrotask(() {
      if (!mounted) return;
      _onLangChanged();
    });
  }

  /// Реакция на нажатие кнопки «обновить» в шапке. Полностью
  /// перезапускает seed: новый случайный набор категорий +
  /// попытка дотянуть свежие рецепты из mahallem-API. Кэш
  /// SQLite не вычищаем (категории с >= [_categoryCacheThreshold]
  /// строк по-прежнему обслуживаются локально), но «короткая
  /// дорога» через `listCached(...)` минуется — иначе кнопка
  /// возвращала бы те же 200 рецептов, что уже на экране.
  ///
  /// Жёсткие гарантии:
  /// * `reloadingFeed.value = false` сбрасывается в `whenComplete`,
  ///   даже если `_runLoad` упал/застрял — иначе спиннер «крутится
  ///   вечно» (наблюдалось в production: при деградации Gemini/LT
  ///   сервер отвечает на `/filter/c` ~30–60 c, 14 категорий
  ///   последовательно складываются в 5–14 минут).
  /// * Общий бюджет на reload — 60 c. По истечении показываем
  ///   предыдущую ленту + snackbar и завершаем future c TimeoutError.
  void _onReloadRequested() {
    if (!mounted) return;
    final seq = ++_translateSeq;
    final previous = _lastResult;
    // Lightweight UX: spinner on the icon + linear bar in AppBar.
    // Do NOT flip the global `_translating` (which would show the
    // full-screen `_LoadingScreen`) — keep the existing feed visible
    // while the reload is in flight. See todo/03.
    reloadingFeed.value = true;
    setState(() {
      _stage.value = const _LoadStage.initial();
      _future = _runReload()
          .timeout(const Duration(seconds: 60))
          .then((r) {
            if (seq != _translateSeq || !mounted) return r;
            _lastResult = r;
            setState(() {});
            return r;
          })
          .catchError((Object e, StackTrace st) {
            if (seq != _translateSeq || !mounted) {
              throw e;
            }
            // ignore: avoid_print
            print('[reload] _runLoad failed: $e');
            // Keep previous feed on screen instead of crashing the page.
            // Surface the offline / busy state via a SnackBar.
            if (previous != null) {
              setState(() {
                _future = Future<_LoadResult>.value(previous);
              });
              _showReloadFailureSnack(e);
              return previous;
            }
            // No previous feed — let the FutureBuilder render its error
            // state as before.
            setState(() {});
            throw e;
          })
          .whenComplete(() {
            // Спиннер должен потухнуть всегда: и в success, и в
            // error, и при stale-seq, и при `!mounted`. Раньше
            // сброс делался только в `.then` / `.catchError`;
            // если `_runLoad` повисал на сетевом ожидании внутри
            // `_seedFromCategories`, спиннер крутился сколь угодно.
            if (seq == _translateSeq) {
              reloadingFeed.value = false;
            }
          });
    });
  }

  /// Reload-specific load path. Reload должен дать пользователю
  /// «свежий» вид без 14-fan-out на `/recipes/filter` (после
  /// деградации Gemini это была гарантированная 60 c-таймаут-ловушка
  /// → snackbar «Нет сети.»). Стратегия:
  ///   1) пробуем `/recipes/page` (тот же путь, что cold-start);
  ///      успех — локально перетасовываем для свежего вида и
  ///      персистим в SQLite;
  ///   2) если page недоступен — падаем в `_runLoad(forceReseed:
  ///      true)`, который заведёт ленту через `_seedFromCategories`.
  /// См. docs/reload-no-network.md.
  Future<_LoadResult> _runReload() async {
    final repo = await (widget.repositoryBuilder ?? _defaultRepoBuilder)(
      widget.api,
    );
    final lang = appLang.value;
    if (widget.api.backend == RecipeBackend.mahallem &&
        widget.config.useBulkPage) {
      try {
        final page = await widget.api.fetchPage(
          lang: lang,
          limit: widget.config.seedTarget,
        );
        if (page.recipes.isNotEmpty) {
          final shuffled = List<Recipe>.from(page.recipes)..shuffle();
          await _persist(repo, shuffled, lang);
          return _LoadResult(recipes: shuffled, repository: repo);
        }
      } on Object catch (e) {
        // ignore: avoid_print
        print('[reload] /recipes/page failed, falling back: $e');
      }
    }
    return _runLoad(forceReseed: true);
  }

  void _showReloadFailureSnack(Object error) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final isOffline = _isOfflineError(error);
    final text = isOffline
        ? S.of(context).offlineReloadUnavailable
        : S.of(context).reloadServerBusy;
    messenger.showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  /// Истинно «нет сети» только для DNS/connect/send-таймаута и
  /// `connectionError`. Receive-timeout, 5xx, общий 60s-budget
  /// `TimeoutException` — это «сервер занят», а не offline.
  bool _isOfflineError(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
          return true;
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.badResponse:
        case DioExceptionType.badCertificate:
        case DioExceptionType.cancel:
        case DioExceptionType.unknown:
          return false;
      }
    }
    return false;
  }

  /// Публикует частичный результат прямо в `_lastResult`, чтобы
  /// `FutureBuilder` (через `live = _lastResult ?? snapshot.data`)
  /// мгновенно перерисовал ленту с новой выборкой, не дожидаясь
  /// завершения всего `_runLoad`. См. todo/06.
  void _publishPartialFeed(List<Recipe> partial, RecipeRepository? repo) {
    if (!mounted || partial.isEmpty) return;
    setState(() {
      _lastResult = _LoadResult(recipes: partial, repository: repo);
    });
  }

  /// На смене языка НЕ перезапускаем seed (это бы переcлучайно
  /// перетасовало карточки и подменило ленту). Берём текущий
  /// `_lastResult` и переводим каждый рецепт по id через
  /// repo/api lookup в новом языке, сохраняя порядок. Если
  /// текущего результата ещё нет (первый load не успел) —
  /// падаем в обычный `_runLoad`.
  void _onLangChanged() {
    if (!mounted) return;
    final last = _lastResult;
    final seq = ++_translateSeq;
    // ignore: avoid_print
    print(
      '[lang] _onLangChanged -> ${appLang.value.name} '
      '(last=${last == null ? "null" : "${last.recipes.length} recipes"})',
    );
    // (6) If a recipe-details page is on top, skip the retranslate
    // entirely. The details page issues its own focused `/lookup`
    // and the user can't see the list anyway. Defer until the
    // details page pops. See docs/details-lang-cycle-504.md.
    if (activeDetailsCount.value > 0 &&
        last != null &&
        last.recipes.isNotEmpty) {
      _pendingBackgroundLang = appLang.value;
      // ignore: avoid_print
      print(
        '[lang] _onLangChanged deferred — details page on top '
        '(activeDetailsCount=${activeDetailsCount.value})',
      );
      return;
    }
    setState(() {
      _stage.value = const _LoadStage.initial();
      _translating = true;
      if (last == null || last.recipes.isEmpty) {
        _future = _runLoad()
            .then((r) {
              if (seq != _translateSeq || !mounted) return r;
              _lastResult = r;
              setState(() => _translating = false);
              return r;
            })
            .catchError((Object e, StackTrace st) {
              if (seq != _translateSeq || !mounted) {
                throw e;
              }
              // ignore: avoid_print
              print('[lang] _runLoad failed: $e');
              setState(() => _translating = false);
              throw e;
            });
      } else {
        _future = _retranslate(last, appLang.value)
            .then((r) {
              if (seq != _translateSeq || !mounted) return r;
              _lastResult = r;
              setState(() => _translating = false);
              return r;
            })
            .catchError((Object e, StackTrace st) {
              if (seq != _translateSeq || !mounted) {
                throw e;
              }
              // ignore: avoid_print
              print('[lang] _retranslate failed: $e');
              // Doc rule: "If `/lookup` fails, the previous-language copy
              // stays on screen". Drop the loader and keep _lastResult.
              setState(() => _translating = false);
              throw e;
            });
      }
    });
  }

  Future<_LoadResult> _retranslate(_LoadResult prev, AppLang lang) async {
    final repo = prev.repository;
    final ids = prev.recipes.map((r) => r.id).toList(growable: false);

    // ШАГ 1 — мгновенный кэш-проход. Достаём из локального sqflite все
    // переводы для (id, lang) одним запросом и тут же подменяем
    // `_lastResult` + `_future` уже-переведённой лентой. UI перерисуется
    // практически без задержки, если этот язык хоть раз посещался ранее.
    Map<int, Recipe> cached = const {};
    if (repo != null) {
      try {
        cached = await repo.lookupManyCached(ids, lang);
      } on Object {
        cached = const {};
      }
    }
    // Не публикуем частичный результат в _lastResult — экрану нужен или
    // фуллый перевод, или лоадер. Локальный буфер firstPass используем ниже,
    // чтобы оригинальный порядок + кэш-хиты слились с mahallem.lookup.
    final firstPass = [for (final r in prev.recipes) cached[r.id] ?? r];

    _stage.value = _LoadStage.fetching(
      category: 'recipes',
      done: cached.length,
      total: prev.recipes.length,
      loaded: cached.length,
      target: prev.recipes.length,
    );

    // ШАГ 2 — добиваем промахи сетью ПАРАЛЛЕЛЬНО (worker-pool, не волны).
    //
    // Раньше тут были волны `Future.wait` по 8 — но если в волне был
    // один медленный рецепт (Gemini cold start, LT очередь), 7 воркеров
    // простаивали до его таймаута. Сейчас держим N воркеров,
    // каждый берёт следующий индекс из общей очереди — стабильно
    // ~_translateConcurrency запросов в полёте.
    //
    // Дополнительно — общий deadline на всю фазу (§"Bounded latency"
    // в docs/translation-pipeline.md обещает N × 1–4 c parallelized
    // 8-wide; даже при 200 промахов это ~100 c). Если за 120 c всё
    // ещё что-то висит — закрываем фазу и оставляем оригиналы (см.
    // §"Offline tolerance": failed lookup leaves the previous-language
    // copy on screen). Сервер всё равно сохранит i18n[lang] forever
    // для тех, что доехали; в следующий заход lookupManyCached
    // подхватит их без сети.
    final translated = [...firstPass];
    final missed = <int>[
      for (var i = 0; i < prev.recipes.length; i++)
        if (!cached.containsKey(prev.recipes[i].id)) i,
    ];
    int done = cached.length;
    final total = prev.recipes.length;
    // Bumped from 120s/12s after diagnosing "Italian residue under TR"
    // (project_log 2026-04-29). With ~50% of TR recipes needing fresh
    // Gemini translation at 2–8s avg under 8-way parallel load, the
    // 12s per-call cap turned spikes into hard misses → user saw the
    // previous-language copy for the rest of the session.
    final deadline = DateTime.now().add(const Duration(seconds: 240));
    const perCallTimeout = Duration(seconds: 25);

    var cursor = 0;
    Future<void> worker() async {
      while (true) {
        if (DateTime.now().isAfter(deadline)) return;
        // (6+7) If user pushed a details page mid-retranslate, exit
        // workers so the foreground `/lookup` has the server to
        // itself. The deferred lang is recorded by `_onLangChanged`
        // → `_pendingBackgroundLang` and resumed on details pop.
        if (activeDetailsCount.value > 0) {
          _pendingBackgroundLang = lang;
          return;
        }
        final i = cursor++;
        if (i >= missed.length) return;
        final idx = missed[i];
        final original = prev.recipes[idx];
        Recipe? got;
        try {
          got = repo != null
              ? await repo.lookup(original.id, lang, timeout: perCallTimeout)
              : await widget.api.lookup(
                  original.id,
                  lang: lang,
                  timeout: perCallTimeout,
                );
        } on Object {
          got = null;
        }
        // Fallback: target-language lookup failed (timeout / 5xx / null).
        // Showing English under the new flag is far less confusing
        // than leaving the previous-language copy on screen — the user
        // explicitly asked for a different language. English is 100%
        // covered server-side, so this lookup almost never fails.
        if (got == null && lang != AppLang.en) {
          try {
            got = repo != null
                ? await repo.lookup(
                    original.id,
                    AppLang.en,
                    timeout: perCallTimeout,
                  )
                : await widget.api.lookup(
                    original.id,
                    lang: AppLang.en,
                    timeout: perCallTimeout,
                  );
          } on Object {
            got = null;
          }
        }
        if (got != null) {
          translated[idx] = got;
        }
        done++;
        _stage.value = _LoadStage.fetching(
          category: 'recipes',
          done: done,
          total: total,
          loaded: done,
          target: total,
        );
      }
    }

    await Future.wait(
      List.generate(
        activeDetailsCount.value > 0
            ? widget.config.translateConcurrencyBackground
            : widget.config.translateConcurrency,
        (_) => worker(),
      ),
    );

    // Per docs/translation-pipeline.md: server-side `_isEchoTranslation`
    // + `evaluateCandidate` are authoritative. The client must not
    // re-validate Latin-residue heuristics — legitimate translations
    // contain proper nouns ("Worcestershire"), units ("100 g"), and
    // brand names that would loop forever. Once every recipe has
    // returned from `/lookup` (whether translated, echoed, or fell
    // back to the previous-language copy), the loader resolves.
    return _LoadResult(recipes: translated, repository: repo);
  }

  /// Полный список категорий TheMealDB. При каждом открытии
  /// экрана берём случайные `widget.config.seedPickCount` — это даёт
  /// ротацию ленты вместо вечного Сикен.
  static const _allCategories = <String>[
    'Beef',
    'Breakfast',
    'Chicken',
    'Dessert',
    'Goat',
    'Lamb',
    'Miscellaneous',
    'Pasta',
    'Pork',
    'Seafood',
    'Side',
    'Starter',
    'Vegan',
    'Vegetarian',
  ];

  /// Категории, выбранные предыдущим вызовом `_pickCategories`.
  /// Используются, чтобы две подряд перезагрузки не показывали
  /// одну и ту же случайную выборку (см. todo/05 и
  /// docs/categories.md §9.5).
  List<String> _lastPickedCategories = const [];

  /// Берём `widget.config.seedPickCount` случайных категорий из
  /// [_allCategories], исключая последний набор. Если в пуле
  /// осталось меньше требуемого — fallback на полный shuffle, чтобы
  /// не зависнуть.
  List<String> _pickCategories() {
    final picked = RecipeListLoader.pickCategoriesFor(
      count: widget.config.seedPickCount,
      pool: _allCategories,
      exclude: _lastPickedCategories,
    );
    _lastPickedCategories = picked;
    return picked;
  }

  Future<_LoadResult> _runLoad({bool forceReseed = false}) async {
    final repo = await (widget.repositoryBuilder ?? _defaultRepoBuilder)(
      widget.api,
    );
    final lang = appLang.value;

    if (repo != null) {
      _stage.value = const _LoadStage.openingCache();
    }

    // mahallem: cache-first. Если для текущего языка в локальной
    // БД уже лежит >=50 рецептов — отдаём их сразу, без сети и без
    // splash «готовим коллекцию». Это критично при переключении
    // языка: пользователь не должен ждать перевод заново каждый раз,
    // когда уже один раз прокачал язык. Кэш живёт «вечно» (LRU
    // вытеснение по 5 MB / 2000 строк, перевод не выкидывается,
    // пока не упрёмся в бюджет).
    if (widget.api.backend == RecipeBackend.mahallem) {
      if (repo != null && !forceReseed) {
        final cachedCount = await repo.countFor(lang);
        if (cachedCount >= 50) {
          final cached = await repo.listCached(
            lang,
            limit: widget.config.seedTarget,
          );
          return _LoadResult(recipes: cached, repository: repo);
        }
      }
      // Холодный язык (или жывый reseed по кнопке «обновить») —
      // заводим ленту через категории.
      // Cold-start fast path (todo/08): one bulk request to
      // /recipes/page replaces 14× /filter fan-out. Reload still
      // uses categories so the user sees a fresh random shuffle.
      if (widget.config.useBulkPage && !forceReseed) {
        try {
          final page = await widget.api.fetchPage(
            lang: lang,
            limit: widget.config.seedTarget,
          );
          if (page.recipes.isNotEmpty) {
            await _persist(repo, page.recipes, lang);
            return _LoadResult(recipes: page.recipes, repository: repo);
          }
        } on Object {
          // Bulk endpoint unavailable — fall through to legacy path.
        }
      }
      final recipes = await _seedFromCategories(
        repo,
        lang,
        onPartial: (partial) => _publishPartialFeed(partial, repo),
      );
      return _LoadResult(recipes: recipes, repository: repo);
    }

    // Cache-first для не-mahallem бэкендов: если в локальной БД уже
    // есть >=50 рецептов под текущий язык — показываем их сразу.
    if (repo != null && !forceReseed) {
      final cachedCount = await repo.countFor(lang);
      if (cachedCount >= 50) {
        final cached = await repo.listCached(
          lang,
          limit: widget.config.seedTarget,
        );
        return _LoadResult(recipes: cached, repository: repo);
      }
    }

    // Cold start: тянем рецепты из сети, обновляя прогресс на UI.
    final loader = widget.loader;
    if (loader != null) {
      final recipes = await loader(widget.api);
      await _persist(repo, recipes, lang);
      return _LoadResult(recipes: recipes, repository: repo);
    }

    // TheMealDB fallback: use a multi-letter seed query. Some
    // proxies/backends reject one-letter prefixes (e.g. `q=c`
    // -> `prefix_too_short`), which would produce an empty feed.
    _stage.value = _LoadStage.fetching(
      category: 'recipes',
      done: 0,
      total: 1,
      loaded: 0,
      target: 0,
    );
    final recipes = await widget.api.searchByName(query: 'chicken', lang: lang);
    await _persist(repo, recipes, lang);
    return _LoadResult(recipes: recipes, repository: repo);
  }

  Future<List<Recipe>> _seedFromCategories(
    RecipeRepository? repo,
    AppLang lang, {
    void Function(List<Recipe> partial)? onPartial,
  }) async {
    final categories = _pickCategories();
    final accumulator = <int, Recipe>{};

    void publish() {
      if (onPartial == null || accumulator.isEmpty) return;
      final snapshot = accumulator.values.toList(growable: false);
      onPartial(snapshot);
    }

    // 1) Первый проход — всё из локальной БД. UI оживает
    //    без сети, если кэш хотя бы частично покрывает выбранные категории.
    if (repo != null) {
      for (final cat in categories) {
        final cached = await repo.listCachedByCategory(cat, lang, limit: 50);
        for (final r in cached) {
          accumulator[r.id] = r;
        }
      }
      // Ранний показ кэша: пользователь видит карточки до первой
      // сетевой выдачи (см. todo/06 и docs/categories.md §9.1d).
      publish();
    }

    // 2) Второй проход — добираем недобранные категории из сети.
    //    Категорию с >= [_categoryCacheThreshold] локальных рецептов
    //    в сеть не трогаем — это явный cache-hit в духе TЗ.
    for (var i = 0; i < categories.length; i++) {
      final cat = categories[i];
      _stage.value = _LoadStage.fetching(
        category: cat,
        done: i,
        total: categories.length,
        loaded: accumulator.length,
        target: widget.config.seedTarget,
      );

      if (repo != null) {
        final localCount = await repo.countForCategory(cat, lang);
        if (localCount >= widget.config.categoryCacheThreshold) continue;
      }

      try {
        // Per-category client cap: при деградации Gemini/LT сервер
        // отвечает на `/filter/c?lang=ru&full=1` ~30–60 c. Без
        // клиентского таймаута 14 категорий последовательно складываются
        // в 5–14 минут и спиннер reload «висит». Скипаем медленную
        // категорию и идём дальше; общий бюджет reload — 60 c (см.
        // `.timeout` в `_onReloadRequested`).
        final batch = await widget.api
            .filterByCategory(cat)
            .timeout(const Duration(seconds: 12));
        var added = false;
        for (final r in batch) {
          if (accumulator.containsKey(r.id)) continue;
          accumulator[r.id] = r;
          added = true;
        }
        if (repo != null && batch.isNotEmpty) {
          try {
            await repo.upsertAll(batch, lang);
          } on Object {
            // кэш не критичен
          }
        }
        // Стримим частичный результат после каждой непустой
        // категории — лента «оживает» с первой же ответившей
        // категорией, не дожидаясь полного цикла.
        if (added) publish();
      } on Object {
        // одна категория не приехала — пробуем следующую
      }
      // Обновляем прогресс-бар сразу после категории, иначе он
      // «замирает» до начала следующей итерации.
      _stage.value = _LoadStage.fetching(
        category: cat,
        done: i + 1,
        total: categories.length,
        loaded: accumulator.length,
        target: widget.config.seedTarget,
      );
      if (accumulator.length >= widget.config.seedTarget) break;
    }
    // Перемешиваем итоговую выборку, чтобы лента не выглядела
    // «50 куриных, потом 50 говяжьих» — категории заходят
    // последовательно, и без shuffle первая категория из
    // случайного набора всегда занимает верх списка.
    final list = accumulator.values.toList();
    list.shuffle();
    return list;
  }

  Future<void> _persist(
    RecipeRepository? repo,
    List<Recipe> recipes,
    AppLang lang,
  ) async {
    if (repo == null || recipes.isEmpty) return;
    try {
      await repo.upsertAll(recipes, lang);
    } on Object {
      // кэш не критичен
    }
  }

  static Future<RecipeRepository?> _defaultRepoBuilder(RecipeApi api) async {
    try {
      final db = await openRecipeDatabase();
      // Глобальный стор избранного шарит ту же БД (chunk A/B
      // todo/15). Карточка/страница деталей слушают
      // [favoritesStoreNotifier] и перерисовываются при toggle.
      favoritesStoreNotifier.value ??= FavoritesStore(db: db);
      await bootstrapAdminSession(db: db);
      // Прогреваем избранное для текущего языка, иначе сразу после
      // старта `FavoriteBadge` слушает пустой нотифаер и рисует
      // контурное сердце для уже сохранённых рецептов до тех пор,
      // пока пользователь не зайдёт в /favorites (где вызовется
      // ensureLoaded).
      try {
        await favoritesStoreNotifier.value!.ensureLoaded(appLang.value);
      } on Object {
        // прогрев не критичен — fallback нарисует контурное сердце
      }
      // Стор  owned-рецептов живёт в той же БД;
      //  [RecipeDetailsPage] слушает [ownedRecipesStoreNotifier],
      //  чтобы рисовать кнопки edit/delete только
      //  владельцу (см. docs/owner-edit-delete.md).
      if (ownedRecipesStoreNotifier.value == null) {
        final store = OwnedRecipesStore(db: db);
        await store.ensureLoaded();
        ownedRecipesStoreNotifier.value = store;
      }
      return RecipeRepository(db: db, api: api);
    } on Object catch (e) {
      // ignore: avoid_print
      print('[repo] local db bootstrap failed: $e');
      return null;
    }
  }

  void _retry() {
    setState(() {
      _stage.value = const _LoadStage.initial();
      _future = _runLoad().then((r) {
        _lastResult = r;
        return r;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LoadResult>(
      future: _future,
      // Передаём последний успешный результат как initialData — это
      // не даёт FutureBuilder сбрасывать снимок при смене `_future`
      // (например, при тапе по языковой кнопке: перевод идёт в
      // фоне, а на экране остаётся прежняя лента в новом UI-языке
      // slang — без полноэкранного «Готовим коллекцию рецептов»).
      initialData: _lastResult,
      builder: (context, snapshot) {
        // While a language switch is in flight (`_translating == true`)
        // we force the loading screen so the user never sees a
        // partially-translated list. Progress comes via `_stage`
        // updates from `_retranslate`.
        if (_translating) {
          return _LoadingScreen(stage: _stage);
        }
        final live = _lastResult ?? snapshot.data;
        if (live == null && snapshot.connectionState != ConnectionState.done) {
          return _LoadingScreen(stage: _stage);
        }
        if (snapshot.hasError && live == null) {
          final s = S.of(context);
          return Scaffold(
            backgroundColor: AppColors.surfaceMuted,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.loadError(snapshot.error ?? ''),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.inputHint,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(onPressed: _retry, child: Text(s.retry)),
                  ],
                ),
              ),
            ),
          );
        }
        final result = live ?? snapshot.data!;
        if (result.recipes.isEmpty) {
          final s = S.of(context);
          return Scaffold(
            backgroundColor: AppColors.surfaceMuted,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.emptyList,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.recipeTitle,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      s.emptyHint,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.inputHint,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(onPressed: _retry, child: Text(s.retry)),
                  ],
                ),
              ),
            ),
          );
        }
        return RecipeListPage(
          recipes: result.recipes,
          api: widget.api,
          repository: result.repository,
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  final ValueListenable<_LoadStage> stage;
  const _LoadingScreen({required this.stage});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ValueListenableBuilder<_LoadStage>(
            valueListenable: stage,
            builder: (context, st, _) {
              final hasProgress = st.target > 0;
              // Прогресс-бар берёт МАКСИМУМ из «прошли категорий» и
              // «получили рецептов из таргета». Категории идут
              // последовательно: пока первая `filterByCategory` не
              // вернётся, accumulator=0, и привязка только к рецептам
              // даёт «мертвый» бар на 30+ секунд. Категория же
              // всегда монотонно растёт — пользователь видит, что
              // приложение живо.
              final categoryProgress = (st.total > 0)
                  ? (st.done / st.total).clamp(0.0, 1.0)
                  : 0.0;
              final recipeProgress = hasProgress
                  ? (st.loaded / st.target).clamp(0.0, 1.0)
                  : 0.0;
              final progress = (st.kind == _LoadStageKind.fetching)
                  ? (categoryProgress > recipeProgress
                        ? categoryProgress
                        : recipeProgress)
                  : (hasProgress ? recipeProgress : null);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Круговой индикатор по design_system.md §12:
                  // CircularProgressIndicator(color: primary). 56×56
                  // с увеличенным stroke — заметнее на surfaceMuted.
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 5,
                      color: AppColors.primary,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.18,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    s.loadingTitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.recipeTitle,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    st.kind == _LoadStageKind.openingCache
                        ? s.loadingFromCache
                        : st.kind == _LoadStageKind.fetching
                        ? s.loadingStage(
                            s.localizedCategory(st.category),
                            st.done,
                            st.total,
                          )
                        : '',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.inputHint,
                  ),
                  if (hasProgress) ...[
                    const SizedBox(height: AppSpacing.sm),
                    // Линейный прогресс-бар: дополнение к кругу,
                    // визуально показывает «сколько ещё осталось»
                    // (см. design_system.md — primary для прогресса).
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          color: AppColors.primary,
                          // Слегка затонированный primary вместо
                          // чисто-белого: при 0% было видно «полную»
                          // полоску, потому что белый track сливался
                          // со светлым фоном экрана.
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      s.loadingProgress(st.loaded, st.target),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.inputHint,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _LoadStageKind { initial, openingCache, fetching }

class _LoadStage {
  final _LoadStageKind kind;
  final String category;
  final int done;
  final int total;
  final int loaded;
  final int target;

  const _LoadStage._({
    required this.kind,
    this.category = '',
    this.done = 0,
    this.total = 0,
    this.loaded = 0,
    this.target = 0,
  });

  const _LoadStage.initial() : this._(kind: _LoadStageKind.initial);
  const _LoadStage.openingCache() : this._(kind: _LoadStageKind.openingCache);
  const _LoadStage.fetching({
    required String category,
    required int done,
    required int total,
    required int loaded,
    required int target,
  }) : this._(
         kind: _LoadStageKind.fetching,
         category: category,
         done: done,
         total: total,
         loaded: loaded,
         target: target,
       );
}

class _LoadResult {
  final List<Recipe> recipes;
  final RecipeRepository? repository;

  _LoadResult({required this.recipes, required this.repository});
}
