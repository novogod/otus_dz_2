import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n.dart';
import '../models/recipe.dart';
import 'app_theme.dart';

/// Экран деталей рецепта. Реализует разметку из `docs/design_system.md`
/// §9l: белый фон, hero-фото 396×220, заголовок страницы 24/#000,
/// секционные подзаголовки 16/#165932, белый блок ингредиентов с
/// обводкой `#797676` и колонками qty/name.
class RecipeDetailsPage extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailsPage({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryDark,
        elevation: 0,
        title: Text(
          s.recipeTitle,
          style: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 20,
            height: 23 / 20,
            color: AppColors.primaryDark,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
            ),
            child: ClipRRect(
              borderRadius: AppRadii.cardAll,
              child: AspectRatio(
                aspectRatio: 396 / 220,
                child: Image.network(
                  recipe.photo,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.surfaceMuted,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.restaurant,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              AppSpacing.lg,
              AppSpacing.pagePadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.name, style: AppTextStyles.pageTitle),
                if (recipe.category != null || recipe.area != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (recipe.category != null) _Badge(recipe.category!),
                      if (recipe.area != null) _Badge(recipe.area!),
                    ],
                  ),
                ],
                if (recipe.tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    recipe.tags.map((t) => '#$t').join('  '),
                    style: const TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      height: 23 / 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (recipe.ingredients.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text(s.ingredientsHeader, style: AppTextStyles.sectionTitle),
                  const SizedBox(height: AppSpacing.md),
                  _IngredientsBlock(items: recipe.ingredients),
                ],
                if (recipe.instructions != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text(s.instructionsHeader, style: AppTextStyles.sectionTitle),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    recipe.instructions!,
                    style: const TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      height: 23 / 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                if (recipe.youtubeUrl != null || recipe.sourceUrl != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (recipe.youtubeUrl != null)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            foregroundColor: AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.button,
                              ),
                            ),
                          ),
                          onPressed: () => _open(recipe.youtubeUrl!),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(s.youtube),
                        ),
                      if (recipe.sourceUrl != null)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            side: const BorderSide(
                              color: AppColors.primaryDark,
                              width: 3,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.button,
                              ),
                            ),
                          ),
                          onPressed: () => _open(recipe.sourceUrl!),
                          icon: const Icon(Icons.link),
                          label: Text(s.source),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
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
          fontSize: 13,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

/// Блок ингредиентов: белый контейнер с обводкой `#797676` шириной 3 и
/// двумя колонками — мера слева, название справа. См. §9l.
class _IngredientsBlock extends StatelessWidget {
  final List<RecipeIngredient> items;

  const _IngredientsBlock({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardAll,
        border: Border.all(color: AppColors.textSecondary, width: 3),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final ing in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 89,
                    child: Text(
                      ing.measure,
                      style: AppTextStyles.ingredientQty,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      ing.name,
                      style: AppTextStyles.ingredientName,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
