import 'package:flutter/material.dart';

import '../models/recipe.dart';
import 'app_theme.dart';
import 'recipe_card.dart';

/// Страница со списком рецептов. Принимает готовый список через конструктор —
/// загрузка данных вынесена выше (см. `RecipeListLoader`).
class RecipeListPage extends StatelessWidget {
  final List<Recipe> recipes;

  const RecipeListPage({super.key, required this.recipes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: recipes.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final recipe = recipes[index];
                  return RecipeCard(
                    recipe: recipe,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Открыт рецепт: ${recipe.name}'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.no_meals, size: 64, color: AppColors.textInactive),
          SizedBox(height: AppSpacing.md),
          Text(
            'Нет рецептов',
            style: TextStyle(fontSize: 16, color: AppColors.textInactive),
          ),
        ],
      ),
    );
  }
}
