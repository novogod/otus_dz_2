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

  /// Категории-сидеры для mahallem-бэкенда. Берём 8 самых
  /// крупных — суммарно даёт >250 уникальных рецептов TheMealDB,
  /// что покрывает кэш-кэп 200.
  static const _seedCategories = <String>[
    'Chicken',
    'Beef',
    'Seafood',
    'Dessert',
    'Vegetarian',
    'Pasta',
    'Pork',
    'Lamb',
  ];

  static const int _seedTarget = 200;

  Future<_LoadResult> _runLoad() async {
    final repo = await (widget.repositoryBuilder ?? _defaultRepoBuilder)(
      widget.api,
    );
    final lang = appLang.value;

    // Cache-first: если в локальной БД уже есть >=50 рецептов под
    // текущий язык — показываем их сразу. Это и есть "preloaded
    // mongo db" из ТЗ: при повторном открытии приложение работает
    // мгновенно и без сети.
    if (repo != null) {
      _stage.value = const _LoadStage.openingCache();
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

    if (widget.api.backend == RecipeBackend.mahallem) {
      final recipes = await _seedFromCategories(repo, lang);
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
    final accumulator = <int, Recipe>{};
    for (var i = 0; i < _seedCategories.length; i++) {
      final cat = _seedCategories[i];
      _stage.value = _LoadStage.fetching(
        category: cat,
        done: i,
        total: _seedCategories.length,
        loaded: accumulator.length,
        target: _seedTarget,
      );
      try {
        final batch = await widget.api.filterByCategory(cat);
        for (final r in batch) {
          accumulator[r.id] = r;
        }
        // Пишем порционно, чтобы при сбое следующей категории
        // уже накопленное было в кэше для следующего запуска.
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
    return accumulator.values.toList(growable: false);
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
                  CircularProgressIndicator(value: progress),
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
