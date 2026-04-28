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

  @override
  void initState() {
    super.initState();
    _future = _runLoad();
    appLang.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    appLang.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() {
    if (!mounted) return;
    setState(() {
      _future = _runLoad();
    });
  }

  Future<_LoadResult> _runLoad() async {
    final repo = await (widget.repositoryBuilder ?? _defaultRepoBuilder)(
      widget.api,
    );
    final recipes = await (widget.loader ?? _defaultLoader)(widget.api);
    if (repo != null && recipes.isNotEmpty) {
      try {
        await repo.upsertAll(recipes, appLang.value);
      } on Object {
        // Кэш не критичен — игнорируем ошибки записи.
      }
    }
    return _LoadResult(recipes: recipes, repository: repo);
  }

  static Future<List<Recipe>> _defaultLoader(RecipeApi api) async {
    if (api.backend == RecipeBackend.mahallem) {
      // mahallem-search требует prefix.length>=2 + локаль-зависимый
      // индекс — сложно подобрать seed для RU с холодным кэшем,
      // поэтому смешиваем несколько категорий через /filter
      // (lite-выдача, но многоязычная и без префикс-проблем).
      const categories = ['Chicken', 'Beef', 'Dessert', 'Seafood'];
      final batches = await Future.wait(
        categories.map(
          (c) => api.filterByCategory(c).catchError((_) => <Recipe>[]),
        ),
      );
      // Чередуем по одной из каждой категории (round-robin),
      // чтобы при скролле не было длинного блока однотипных карточек.
      final mixed = <Recipe>[];
      var i = 0;
      while (mixed.length < 60) {
        var added = false;
        for (final batch in batches) {
          if (i < batch.length) {
            mixed.add(batch[i]);
            added = true;
          }
        }
        if (!added) break;
        i++;
      }
      return mixed;
    }
    // TheMealDB: одно слово возвращает полные карточки.
    return api.searchByName(query: 'c', lang: appLang.value);
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
      _future = _runLoad();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LoadResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.surfaceMuted,
            body: Center(child: CircularProgressIndicator()),
          );
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
        return RecipeListPage(
          recipes: result.recipes,
          api: widget.api,
          repository: result.repository,
        );
      },
    );
  }
}

class _LoadResult {
  final List<Recipe> recipes;
  final RecipeRepository? repository;

  _LoadResult({required this.recipes, required this.repository});
}
