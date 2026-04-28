import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/api/recipe_api.dart';
import '../data/api/recipe_api_config.dart';
import '../data/local/recipe_db.dart';
import '../data/repository/recipe_repository.dart';
import '../i18n.dart';
import '../models/recipe.dart';
import 'app_theme.dart';
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

  RecipeListLoader({
    super.key,
    RecipeApi? api,
    this.loader,
    this.repositoryBuilder,
  }) : api = api ?? RecipeApi();

  @override
  State<RecipeListLoader> createState() => _RecipeListLoaderState();
}

class _RecipeListLoaderState extends State<RecipeListLoader> {
  late Future<_LoadResult> _future;
  final ValueNotifier<_LoadStage> _stage = ValueNotifier(
    const _LoadStage.initial(),
  );

  @override
  void initState() {
    super.initState();
    _future = _runLoad();
    appLang.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    appLang.removeListener(_onLangChanged);
    _stage.dispose();
    super.dispose();
  }

  void _onLangChanged() {
    if (!mounted) return;
    setState(() {
      _stage.value = const _LoadStage.initial();
      _future = _runLoad();
    });
  }

  /// Полный список категорий TheMealDB. При каждом открытии
  /// экрана берём случайные 10 (`_seedPickCount`) — это даёт
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

  static const int _seedPickCount = 10;
  static const int _categoryCacheThreshold = 10;

  /// Берём [_seedPickCount] случайных категорий из [_allCategories],
  /// сохраняя порядок рандома вызова. Разные открытия экрана
  /// дают разные ленты.
  static List<String> _pickCategories() {
    final pool = [..._allCategories]..shuffle();
    return pool.take(_seedPickCount).toList(growable: false);
  }

  static const int _seedTarget = 200;

  Future<_LoadResult> _runLoad() async {
    final repo = await (widget.repositoryBuilder ?? _defaultRepoBuilder)(
      widget.api,
    );
    final lang = appLang.value;

    if (repo != null) {
      _stage.value = const _LoadStage.openingCache();
    }

    // mahallem: всегда идём через категории (DB-first, со случайной
    // ротацией набора на каждом открытии). Сеть подключается только
    // если для какой-то категории локально мало рецептов.
    if (widget.api.backend == RecipeBackend.mahallem) {
      final recipes = await _seedFromCategories(repo, lang);
      return _LoadResult(recipes: recipes, repository: repo);
    }

    // Cache-first для не-mahallem бэкендов: если в локальной БД уже
    // есть >=50 рецептов под текущий язык — показываем их сразу.
    if (repo != null) {
      final cachedCount = await repo.countFor(lang);
      if (cachedCount >= 50) {
        final cached = await repo.listCached(lang, limit: _seedTarget);
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

    // TheMealDB: одно слово возвращает полные карточки.
    _stage.value = _LoadStage.fetching(
      category: 'recipes',
      done: 0,
      total: 1,
      loaded: 0,
      target: 0,
    );
    final recipes = await widget.api.searchByName(query: 'c', lang: lang);
    await _persist(repo, recipes, lang);
    return _LoadResult(recipes: recipes, repository: repo);
  }

  Future<List<Recipe>> _seedFromCategories(
    RecipeRepository? repo,
    AppLang lang,
  ) async {
    final categories = _pickCategories();
    final accumulator = <int, Recipe>{};

    // 1) Первый проход — всё из локальной БД. UI оживает
    //    без сети, если кэш хотя бы частично покрывает выбранные категории.
    if (repo != null) {
      for (final cat in categories) {
        final cached = await repo.listCachedByCategory(cat, lang, limit: 50);
        for (final r in cached) {
          accumulator[r.id] = r;
        }
      }
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
        target: _seedTarget,
      );

      if (repo != null) {
        final localCount = await repo.countForCategory(cat, lang);
        if (localCount >= _categoryCacheThreshold) continue;
      }

      try {
        final batch = await widget.api.filterByCategory(cat);
        for (final r in batch) {
          accumulator[r.id] = r;
        }
        if (repo != null && batch.isNotEmpty) {
          try {
            await repo.upsertAll(batch, lang);
          } on Object {
            // кэш не критичен
          }
        }
      } on Object {
        // одна категория не приехала — пробуем следующую
      }
      if (accumulator.length >= _seedTarget) break;
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
      return RecipeRepository(db: db, api: api);
    } on Object {
      return null;
    }
  }

  void _retry() {
    setState(() {
      _stage.value = const _LoadStage.initial();
      _future = _runLoad();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LoadResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _LoadingScreen(stage: _stage);
        }
        if (snapshot.hasError) {
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
        final result = snapshot.data!;
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
              final progress = hasProgress
                  ? (st.loaded / st.target).clamp(0.0, 1.0)
                  : null;
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
                      backgroundColor: AppColors.surface,
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
                        ? s.loadingStage(st.category, st.done, st.total)
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
                          backgroundColor: AppColors.surface,
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
