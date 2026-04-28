import 'package:flutter/material.dart';

import '../data/api/recipe_api.dart';
import '../i18n.dart';
import '../models/recipe.dart';
import 'app_theme.dart';
import 'recipe_list_page.dart';

/// Загружает список рецептов из TheMealDB и отображает loading / error / data.
///
/// По умолчанию использует `searchByName(query: 'a')` — это самый
/// простой способ получить «много» полных рецептов одним запросом.
class RecipeListLoader extends StatefulWidget {
  final RecipeApi api;
  final Future<List<Recipe>> Function(RecipeApi api)? loader;

  RecipeListLoader({super.key, RecipeApi? api, this.loader})
    : api = api ?? RecipeApi();

  @override
  State<RecipeListLoader> createState() => _RecipeListLoaderState();
}

class _RecipeListLoaderState extends State<RecipeListLoader> {
  late Future<List<Recipe>> _future;

  @override
  void initState() {
    super.initState();
    _future = (widget.loader ?? _defaultLoader)(widget.api);
  }

  static Future<List<Recipe>> _defaultLoader(RecipeApi api) =>
      api.searchByName(query: 'a', lang: appLang.value);

  void _retry() {
    setState(() {
      _future = (widget.loader ?? _defaultLoader)(widget.api);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Recipe>>(
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
        return RecipeListPage(
          recipes: snapshot.data ?? const [],
          api: widget.api,
        );
      },
    );
  }
}
