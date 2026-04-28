import 'package:flutter/material.dart';

import '../data/api/recipe_api.dart';
import '../models/recipe.dart';
import 'app_bottom_nav_bar.dart';
import 'app_theme.dart';
import 'recipe_card.dart';
import 'recipe_details_page.dart';

/// Страница со списком рецептов. Принимает готовый список через конструктор —
/// загрузка данных вынесена выше (см. `RecipeListLoader`).
///
/// При тапе на карточку открывает экран деталей. Если карточка lite
/// (поля категории/инструкций пустые), сначала вызывает
/// [RecipeApi.lookup], чтобы догрузить полную версию рецепта.
class RecipeListPage extends StatelessWidget {
  final List<Recipe> recipes;
  final RecipeApi? api;

  const RecipeListPage({super.key, required this.recipes, this.api});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        bottom: false,
        child: recipes.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final recipe = recipes[index];
                  return RecipeCard(
                    recipe: recipe,
                    onTap: () => _openDetails(context, recipe),
                  );
                },
              ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        current: AppNavTab.recipes,
        onTap: (tab) => _onNavTap(context, tab),
      ),
    );
  }

  void _onNavTap(BuildContext context, AppNavTab tab) {
    if (tab == AppNavTab.recipes) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Этот раздел пока в разработке'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<void> _openDetails(BuildContext context, Recipe recipe) async {
    Recipe full = recipe;
    if (recipe.isLite && api != null) {
      final fetched = await api!.lookup(recipe.id);
      if (fetched != null) full = fetched;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeDetailsPage(recipe: full),
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
