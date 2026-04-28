import 'package:flutter/material.dart';

import '../data/recipe_manager.dart';
import '../models/recipe.dart';
import 'app_theme.dart';
import 'recipe_list_page.dart';

/// Загружает список рецептов и отображает состояния loading / error / data.
/// Тема и точка входа от него не зависят — `main.dart` остаётся коротким.
class RecipeListLoader extends StatelessWidget {
  final RecipeManager manager;

  const RecipeListLoader({super.key, this.manager = const RecipeManager()});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Recipe>>(
      future: manager.getRecipes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.surfaceMuted,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.surfaceMuted,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Ошибка загрузки: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.inputHint,
                ),
              ),
            ),
          );
        }
        return RecipeListPage(recipes: snapshot.data ?? const []);
      },
    );
  }
}
