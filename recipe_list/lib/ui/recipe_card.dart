import 'package:flutter/material.dart';

import '../models/recipe.dart';
import 'app_theme.dart';

/// Карточка рецепта в списке. Размеры и стили — из дизайн-системы
/// `app_theme.dart` (см. `docs/design_system.md`).
///
/// Layout по Figma (component `116:33`): фото слева на всю высоту карточки
/// (149 x 136), скруглены только левые углы; справа — название рецепта
/// (Roboto 500/22, чёрный) и время приготовления с иконкой часов
/// (Roboto 400/16, бренд-зелёный).
class RecipeCard extends StatelessWidget {
  static const double cardHeight = 136;
  static const double imageWidth = 149;

  final Recipe recipe;
  final VoidCallback? onTap;

  const RecipeCard({super.key, required this.recipe, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePadding,
        vertical: AppSpacing.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardAll,
          boxShadow: AppShadows.card,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadii.cardAll,
            child: SizedBox(
              height: cardHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: AppRadii.cardLeft,
                    child: SizedBox(
                      width: imageWidth,
                      height: cardHeight,
                      child: Image.network(
                        recipe.photo,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppColors.surfaceMuted,
                          child: const Icon(
                            Icons.restaurant,
                            size: 32,
                            color: AppColors.textInactive,
                          ),
                        ),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: AppColors.surfaceMuted,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            recipe.name,
                            style: AppTextStyles.recipeTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                '${recipe.duration} мин',
                                style: AppTextStyles.recipeMeta,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
