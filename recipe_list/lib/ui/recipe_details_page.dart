import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/recipe.dart';
import 'app_theme.dart';

/// Экран деталей рецепта. Показывает фото, категорию/кухню, теги,
/// ингредиенты с мерами, инструкцию и ссылки на YouTube/источник.
class RecipeDetailsPage extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailsPage({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(title: Text(recipe.name)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              recipe.photo,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.surfaceMuted,
                alignment: Alignment.center,
                child: const Icon(Icons.restaurant, size: 48),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recipe.category != null || recipe.area != null)
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      if (recipe.category != null) _meta(recipe.category!),
                      if (recipe.area != null) _meta(recipe.area!),
                    ],
                  ),
                if (recipe.tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    recipe.tags.map((t) => '#$t').join('  '),
                    style: AppTextStyles.inputHint,
                  ),
                ],
                if (recipe.ingredients.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Ингредиенты',
                    style: AppTextStyles.recipeTitle,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final ing in recipe.ingredients)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Text('• '),
                          Expanded(child: Text(ing.name)),
                          if (ing.measure.isNotEmpty)
                            Text(
                              ing.measure,
                              style: AppTextStyles.inputHint,
                            ),
                        ],
                      ),
                    ),
                ],
                if (recipe.instructions != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Инструкция',
                    style: AppTextStyles.recipeTitle,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(recipe.instructions!),
                ],
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (recipe.youtubeUrl != null)
                      FilledButton.icon(
                        onPressed: () => _open(recipe.youtubeUrl!),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('YouTube'),
                      ),
                    if (recipe.sourceUrl != null)
                      OutlinedButton.icon(
                        onPressed: () => _open(recipe.sourceUrl!),
                        icon: const Icon(Icons.link),
                        label: const Text('Источник'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _meta(String text) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: 2,
    ),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.primary),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: AppTextStyles.fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 12,
        color: AppColors.primaryDark,
      ),
    ),
  );

  static Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
