import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/repository/favorites_store.dart';
import '../i18n.dart';
import '../models/recipe.dart';
import '../utils/imgproxy.dart';
import 'app_theme.dart';

/// Карточка рецепта TheMealDB.
///
/// Использует все поля, которые возвращает API: фото 16:9 + индикатор
/// YouTube, название, бейджи категории/кухни, чипы тегов, счётчик
/// ингредиентов. В lite-режиме (ответы `/filter.php`) рендерится
/// компактный вариант — только фото и название.
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;

  const RecipeCard({super.key, required this.recipe, this.onTap});

  @override
  Widget build(BuildContext context) {
    final lite = recipe.isLite;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Photo(recipe: recipe),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.name,
                        style: AppTextStyles.recipeTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!lite) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _Badges(recipe: recipe),
                        if (recipe.tags.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _Tags(tags: recipe.tags),
                        ],
                        if (recipe.ingredients.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _IngredientCount(count: recipe.ingredients.length),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  final Recipe recipe;

  const _Photo({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(AppRadii.card),
        topRight: Radius.circular(AppRadii.card),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _thumbUrl(recipe.photo),
              fit: BoxFit.cover,
              // На web-CanvasKit Image.network декодирует через
              // canvas → требует CORS, который не отдаёт ни imgproxy,
              // ни внешние CDN. fallback-стратегия рендерит
              // картинку как <img>-элемент, как на native.
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (_, _, _) => Image.network(
                recipe.photo,
                fit: BoxFit.cover,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.surfaceMuted,
                  child: const Icon(
                    Icons.restaurant,
                    size: 32,
                    color: AppColors.textInactive,
                  ),
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
            if (recipe.youtubeUrl != null)
              Positioned(
                right: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: _YoutubeBadge(url: recipe.youtubeUrl!),
              ),
            Positioned(
              right: AppSpacing.sm,
              top: AppSpacing.sm,
              child: FavoriteBadge(recipeId: recipe.id),
            ),
          ],
        ),
      ),
    );
  }

  /// TheMealDB поддерживает суффиксы `/preview`, `/small`, `/medium`,
  /// `/large` для оптимизации трафика. Для recipe-photos из mahallem-стораджа
  /// пропускаем URL через imgproxy: thumbnail 600×338 dp → ~80 КБ JPEG.
  static String _thumbUrl(String url) {
    if (url.startsWith('/storage/') || url.contains('/recipe-photos/')) {
      return imgproxyUrl(url, 600, 338);
    }
    if (url.endsWith('/medium') ||
        url.endsWith('/small') ||
        url.endsWith('/large') ||
        url.endsWith('/preview')) {
      return url;
    }
    return '$url/medium';
  }
}

class _YoutubeBadge extends StatelessWidget {
  final String url;

  const _YoutubeBadge({required this.url});

  Future<void> _launch() async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.65),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _launch,
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.sm),
          child: Icon(Icons.play_arrow, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

/// Бейдж-сердце в правом верхнем углу карточки. Зеркалит размер и
/// визуальный вес [_YoutubeBadge]: круг 40×40, полупрозрачный
/// чёрный фон, белый/зелёный глиф.
///
/// Слушает [favoritesStoreNotifier] и нотифаер по текущему языку
/// (`appLang`), чтобы перерисоваться при добавлении/удалении из
/// любого экрана. Если стор ещё не инициализирован
/// (БД не открыта), рендерит контурное сердце и no-op на тап.
class FavoriteBadge extends StatelessWidget {
  final int recipeId;

  const FavoriteBadge({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FavoritesStore?>(
      valueListenable: favoritesStoreNotifier,
      builder: (context, store, _) {
        return ValueListenableBuilder<AppLang>(
          valueListenable: appLang,
          builder: (context, lang, _) {
            if (store == null) {
              return _FavoriteBadgeView(isFavorite: false, onTap: null);
            }
            return ValueListenableBuilder<Set<int>>(
              valueListenable: store.idsForLang(lang),
              builder: (context, ids, _) {
                final isFav = ids.contains(recipeId);
                return _FavoriteBadgeView(
                  isFavorite: isFav,
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await store.toggle(recipeId, lang);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _FavoriteBadgeView extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback? onTap;

  const _FavoriteBadgeView({required this.isFavorite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.65),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? AppColors.primary : Colors.white,
            size: 24,
            semanticLabel: isFavorite ? 'favorite-on' : 'favorite-off',
          ),
        ),
      ),
    );
  }
}

class _Badges extends StatelessWidget {
  final Recipe recipe;

  const _Badges({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (recipe.category != null) {
      children.add(_Badge(label: recipe.category!));
    }
    if (recipe.area != null) {
      children.add(_Badge(label: recipe.area!));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    // `Wrap` вместо `Row` — длинные переводы (курдский/немецкий)
    // не должны вылетать за карточку.
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: children,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontWeight: FontWeight.w500,
          fontSize: 12,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

class _Tags extends StatelessWidget {
  static const int _maxVisible = 3;
  final List<String> tags;

  const _Tags({required this.tags});

  @override
  Widget build(BuildContext context) {
    final visible = tags.take(_maxVisible).toList();
    final extra = tags.length - visible.length;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final t in visible) _Chip(text: '#$t'),
        if (extra > 0) _Chip(text: '+$extra'),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;

  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 12,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _IngredientCount extends StatelessWidget {
  final int count;

  const _IngredientCount({required this.count});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      children: [
        const Icon(
          Icons.shopping_basket_outlined,
          size: 16,
          color: AppColors.primary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(s.ingredientCount(count), style: AppTextStyles.recipeMeta),
      ],
    );
  }
}
