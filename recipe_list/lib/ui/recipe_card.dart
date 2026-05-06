import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/admin_session.dart';
import '../data/repository/favorites_store.dart';
import '../data/repository/owned_recipes_store.dart';
import '../i18n.dart';
import '../models/recipe.dart';
import '../utils/imgproxy.dart';
import 'app_theme.dart';
import 'registration_required_snackbar.dart';
import 'social/recipe_rating_row.dart';

/// Карточка рецепта TheMealDB.
///
/// Использует все поля, которые возвращает API: фото 16:9 + индикатор
/// YouTube, название, бейджи категории/кухни, чипы тегов, счётчик
/// ингредиентов. В lite-режиме (ответы `/filter.php`) рендерится
/// компактный вариант — только фото и название.
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final EdgeInsets outerPadding;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.outerPadding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.pagePadding,
      vertical: AppSpacing.sm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final lite = recipe.isLite;
    // FavoriteBadge is placed OUTSIDE the card's InkWell (as a Stack sibling).
    // This prevents the card tap from winning the gesture arena over the badge.
    // Flutter's defaultHitTestChildren stops at the first (topmost) hit, so when
    // the badge is tested first it is the only widget in the arena — card never fires.
    return Stack(
      children: [
        Padding(
          padding: outerPadding,
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
                              _IngredientCount(
                                count: recipe.ingredients.length,
                              ),
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
        ),
        // Badge is last (= topmost) so hit-test finds it first and the card is
        // never hit-tested for taps in this area.
        Positioned(
          top: outerPadding.top + AppSpacing.sm,
          right: outerPadding.right + AppSpacing.sm,
          child: PointerInterceptor(
            child: FavoriteBadge(
              recipeId: recipe.id,
              // chunk H of user-card-and-social-signals.md: when the
              // server has projected favoritesCount, render a pill
              // with the number; otherwise the badge collapses to
              // its legacy 32×32 square.
              favoritesCount: recipe.favoritesCount,
              showCount: true,
            ),
          ),
        ),
        // Compact rating overlay (chunk G §4.2: card shows
        // average + count, no interactive stars). Hidden when
        // there are no votes yet so cards stay clean.
        if (recipe.ratingsCount > 0)
          Positioned(
            top: outerPadding.top + AppSpacing.sm + 38,
            right: outerPadding.right + AppSpacing.sm,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppShadows.card,
                ),
                child: RecipeRatingRow(
                  count: recipe.ratingsCount,
                  sum: recipe.ratingsSum,
                  my: recipe.myRating,
                  onRate: null,
                  compact: true,
                ),
              ),
            ),
          ),
        Positioned(
          top: outerPadding.top + AppSpacing.sm,
          left: outerPadding.left + AppSpacing.sm,
          child: ValueListenableBuilder<OwnedRecipesStore?>(
            valueListenable: ownedRecipesStoreNotifier,
            builder: (context, ownedStore, _) {
              if (onEdit == null && onDelete == null) {
                return const SizedBox.shrink();
              }
              if (ownedStore == null) {
                return ValueListenableBuilder<bool>(
                  valueListenable: adminLoggedInNotifier,
                  builder: (context, isAdmin, _) {
                    if (!isAdmin) return const SizedBox.shrink();
                    return _CardActions(onEdit: onEdit, onDelete: onDelete);
                  },
                );
              }
              return ValueListenableBuilder<Set<int>>(
                valueListenable: ownedStore.ids,
                builder: (context, ownedIds, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: adminLoggedInNotifier,
                    builder: (context, isAdmin, _) {
                      final canManage = isAdmin || ownedIds.contains(recipe.id);
                      if (!canManage) return const SizedBox.shrink();
                      return _CardActions(onEdit: onEdit, onDelete: onDelete);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CardActions extends StatelessWidget {
  const _CardActions({required this.onEdit, required this.onDelete});

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onDelete != null)
            _AdminActionBadge(icon: Icons.delete_outline, onTap: onDelete!),
          if (onDelete != null && onEdit != null)
            const SizedBox(width: AppSpacing.xs),
          if (onEdit != null)
            _AdminActionBadge(icon: Icons.edit, onTap: onEdit!),
        ],
      ),
    );
  }
}

class _AdminActionBadge extends StatelessWidget {
  const _AdminActionBadge({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: Colors.white),
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
                child: PointerInterceptor(
                  child: _YoutubeBadge(url: recipe.youtubeUrl!),
                ),
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

  /// Total favorites this recipe has across all users (server-projected
  /// via [Recipe.favoritesCount]). Used by chunk H of
  /// user-card-and-social-signals.md to render a pill instead of the
  /// legacy square. Defaults to 0; with [showCount] off the value is
  /// ignored.
  final int favoritesCount;

  /// When true and `favoritesCount > 0`, render the pill layout
  /// (number + heart). Otherwise fall back to the legacy 32×32
  /// dark circle. Set to `false` for callers that just need the
  /// affordance (e.g. logged-out badge in lists where counts
  /// haven't shipped yet).
  final bool showCount;

  const FavoriteBadge({
    super.key,
    required this.recipeId,
    this.favoritesCount = 0,
    this.showCount = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FavoritesStore?>(
      valueListenable: favoritesStoreNotifier,
      builder: (context, store, _) {
        return ValueListenableBuilder<AppLang>(
          valueListenable: appLang,
          builder: (context, lang, _) {
            if (store == null) {
              return _FavoriteBadgeView(
                isFavorite: false,
                favoritesCount: favoritesCount,
                showCount: showCount,
                onTap: () async {
                  if (!userLoggedInNotifier.value) {
                    await _showRegistrationRequired(context);
                    return;
                  }
                  HapticFeedback.lightImpact();
                  final bootstrapped = await ensureFavoritesStoreInitialized();
                  if (bootstrapped == null) return;
                  await bootstrapped.toggle(recipeId, lang);
                },
              );
            }
            return ValueListenableBuilder<Set<int>>(
              valueListenable: store.idsForLang(lang),
              builder: (context, ids, _) {
                final isFav = ids.contains(recipeId);
                return _FavoriteBadgeView(
                  isFavorite: isFav,
                  favoritesCount: favoritesCount,
                  showCount: showCount,
                  onTap: () async {
                    if (!userLoggedInNotifier.value) {
                      await _showRegistrationRequired(context);
                      return;
                    }
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

  Future<void> _showRegistrationRequired(BuildContext context) async {
    if (!context.mounted) return;
    // Use the shared helper so the snackbar carries an explicit
    // safety Timer that force-closes after 4 s. The naked
    // `showSnackBar` path relied on `ScaffoldMessenger`'s built-in
    // auto-dismiss, which only fires when the slide-in animation
    // reaches `AnimationStatus.completed`. With multiple Scaffolds
    // mounted (AppShell + branch + LoginPage on root) and a
    // multi-line non-EN content, the messenger keeps re-hosting the
    // SnackBar and the animation never completes — so the timer
    // never starts and the snackbar hangs forever in non-EN locales.
    showRegistrationRequiredSnackBar(context);
  }
}

class _FavoriteBadgeView extends StatelessWidget {
  final bool isFavorite;
  final int favoritesCount;
  final bool showCount;
  final VoidCallback? onTap;

  const _FavoriteBadgeView({
    required this.isFavorite,
    required this.onTap,
    this.favoritesCount = 0,
    this.showCount = false,
  });

  @override
  Widget build(BuildContext context) {
    // GestureDetector + HitTestBehavior.opaque вместо Material/InkWell:
    // на Flutter web (CanvasKit) вложенный InkWell внутри Stack поверх
    // другого InkWell не всегда получает тап — событие уходит в
    // родительский Material карточки. GestureDetector с opaque всегда
    // поглощает тап независимо от платформы.
    final renderPill = showCount && favoritesCount > 0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: renderPill ? _buildPill(context) : _buildSquare(),
    );
  }

  /// Legacy 32×32 dark-translucent circle. Kept for the
  /// "no count to show" / logged-out path so we don't regress
  /// existing visual tests beyond the chunk-H scope.
  Widget _buildSquare() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xA6000000), // Colors.black.withValues(alpha:0.65)
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: isFavorite ? AppColors.primary : Colors.white,
          size: 24,
          semanticLabel: isFavorite ? 'favorite-on' : 'favorite-off',
        ),
      ),
    );
  }

  /// Light pill `<count> ♡`. Spec: §5.2 of
  /// docs/user-card-and-social-signals.md.
  /// Height 32, horizontal padding 12, full-pill radius 16,
  /// surface@0.92 background, 1 px textInactive border, card shadow.
  Widget _buildPill(BuildContext context) {
    return Semantics(
      label: isFavorite ? 'favorite-on' : 'favorite-off',
      button: true,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.textInactive),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$favoritesCount',
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: isFavorite ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: isFavorite ? AppColors.primary : AppColors.textSecondary,
            ),
          ],
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
