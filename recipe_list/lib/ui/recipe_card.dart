import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/admin_session.dart';
import '../data/api/recipe_api.dart';
import '../data/repository/favorites_store.dart';
import '../data/repository/owned_recipes_store.dart';
import '../data/repository/rating_store.dart';
import '../i18n.dart';
import '../models/recipe.dart';
import '../utils/imgproxy.dart';
import 'app_theme.dart';
import 'registration_required_snackbar.dart';
import 'web_share/web_action_buttons.dart';

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
                            // Author chip. Prefers the server-projected
                            // creator metadata; when the local cache row
                            // was written before `attachSocialSignals`
                            // shipped (or the projection failed) but we
                            // still know the current user authored this
                            // recipe, hydrate the chip from
                            // `/recipes/users/me` so the author signal
                            // is never silently missing on the author's
                            // own card. Wrapped in a
                            // [ValueListenableBuilder] so the chip
                            // appears as soon as the profile finishes
                            // loading after a fresh login.
                            ValueListenableBuilder<UserProfileSnapshot?>(
                              valueListenable: myProfileNotifier,
                              builder: (context, me, _) {
                                String? name = recipe.creatorDisplayName;
                                String? avatar = recipe.creatorAvatarPath;
                                int? added = recipe.creatorRecipesAdded;
                                final isMine = isCurrentUserAuthor(recipe);
                                if ((name == null || name.isEmpty) &&
                                    isMine &&
                                    me != null &&
                                    (me.displayName ?? '').isNotEmpty) {
                                  name = me.displayName;
                                  avatar = me.avatarPath;
                                  added = me.recipesAdded;
                                }
                                if (name == null || name.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.sm,
                                  ),
                                  child: _AuthorChip(
                                    name: name,
                                    avatarPath: avatar,
                                    recipesAdded: added,
                                  ),
                                );
                              },
                            ),
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
              creatorUserId: recipe.creatorUserId,
              // chunk H of user-card-and-social-signals.md: when the
              // server has projected favoritesCount, render a pill
              // with the number; otherwise the badge collapses to
              // its legacy 32×32 square.
              favoritesCount: recipe.favoritesCount,
              showCount: true,
            ),
          ),
        ),
        Positioned(
          top: outerPadding.top + AppSpacing.sm,
          left: outerPadding.left + AppSpacing.sm,
          child: ValueListenableBuilder<bool>(
            valueListenable: adminLoggedInNotifier,
            builder: (context, isAdmin, _) {
              if (onEdit == null && onDelete == null) {
                return const SizedBox.shrink();
              }
              return ValueListenableBuilder<UserProfileSnapshot?>(
                valueListenable: myProfileNotifier,
                builder: (context, _, __) {
                  // Server-authoritative: the creatorUserId projected
                  // by attachSocialSignals is matched against the
                  // current /recipes/users/me id via
                  // [isCurrentUserAuthor]. The per-device
                  // OwnedRecipesStore was previously OR-ed into this
                  // gate, but its `ensureLoaded` backfill marks every
                  // cached user-recipe (id ≥ userMealIdFloor) as
                  // owned by THIS device — an anonymous visitor who
                  // simply opens a card has the row written to
                  // sqflite, the backfill flips it to "owned", and
                  // edit/delete buttons appear. Drop the local
                  // fallback entirely; only admins or the verified
                  // author may manage a recipe, on every device.
                  final canManage = isAdmin || isCurrentUserAuthor(recipe);
                  if (!canManage) return const SizedBox.shrink();
                  return _CardActions(onEdit: onEdit, onDelete: onDelete);
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
                  child: YoutubeBadge(url: recipe.youtubeUrl!),
                ),
              ),
            // Share badge anchored to the top-left of the photo,
            // mirroring [YoutubeBadge]'s circular shape and size
            // but tinted with the brand primary so the affordance
            // reads as "share this recipe" (rather than the global
            // app-share button in the AppBar). Tapping opens the
            // same dropdown / system share sheet, but pre-fills the
            // payload with the deep-link to *this* recipe.
            Positioned(
              left: AppSpacing.sm,
              top: AppSpacing.sm,
              child: PointerInterceptor(child: PhotoShareBadge(recipe: recipe)),
            ),
            // Star-rating pill on every photo (per
            // docs/prompts.md "stars on ALL recipe cards are
            // present and clickable"). Sits inline with the
            // YouTube badge at the bottom of the photo: when
            // YouTube is present we leave space for it on the
            // right; the pill anchors to the left.
            Positioned(
              left: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: PointerInterceptor(child: PhotoRatingPill(recipe: recipe)),
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

class YoutubeBadge extends StatelessWidget {
  final String url;

  const YoutubeBadge({super.key, required this.url});

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

/// Share badge anchored to the top-left of the recipe photo.
/// Mirrors [YoutubeBadge]'s circular 40dp / semi-transparent black
/// chrome, but the glyph is tinted with the brand primary green so
/// it reads as the "share this recipe" affordance rather than the
/// global AppBar share button. Tapping invokes [shareRecipe], which
/// opens the system share sheet (iOS/Android) or the social-network
/// dropdown (web) pre-filled with the deep-link to this recipe.
class PhotoShareBadge extends StatelessWidget {
  const PhotoShareBadge({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Material(
      color: Colors.black.withValues(alpha: 0.65),
      shape: const CircleBorder(),
      child: Tooltip(
        message: s.shareTooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => shareRecipe(context, recipe),
          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.sm),
            child: Icon(Icons.share, color: AppColors.primary, size: 22),
          ),
        ),
      ),
    );
  }
}

/// 5-star rating pill anchored to the bottom-left corner of every
/// recipe photo, inline with [YoutubeBadge]. Visual weight matches
/// the YouTube badge (semi-transparent black, white/primary glyphs)
/// so the two badges read as a pair.
///
/// Per docs/prompts.md "stars on ALL recipe cards are present and
/// clickable": always rendered, always interactive. Tapping a star
/// while logged out surfaces the registration-required snackbar;
/// while logged in, sends the vote through [RatingStore]. The vote
/// count is shown to the right of the stars.
class PhotoRatingPill extends StatelessWidget {
  const PhotoRatingPill({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RatingStore?>(
      valueListenable: ratingStoreNotifier,
      builder: (context, store, _) {
        final initial = RecipeRatingSnapshot(
          count: recipe.ratingsCount,
          sum: recipe.ratingsSum,
          my: recipe.myRating,
        );
        if (store == null) {
          return _PhotoRatingPillView(
            count: initial.count,
            sum: initial.sum,
            my: initial.my,
            onTap: null,
          );
        }
        return ValueListenableBuilder<RecipeRatingSnapshot>(
          valueListenable: store.watch(recipe.id, initial: initial),
          builder: (context, snap, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: userLoggedInNotifier,
              builder: (context, loggedIn, _) {
                return _PhotoRatingPillView(
                  count: snap.count,
                  sum: snap.sum,
                  my: snap.my,
                  onTap: (stars) async {
                    if (!loggedIn) {
                      showRegistrationRequiredSnackBar(context);
                      return;
                    }
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    try {
                      if (snap.my == stars) {
                        await store.clearMyRating(recipe.id);
                      } else {
                        await store.setMyRating(recipe.id, stars);
                      }
                    } catch (e) {
                      messenger?.showSnackBar(
                        SnackBar(
                          content: Text('Rating failed: $e'),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
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

class _PhotoRatingPillView extends StatelessWidget {
  const _PhotoRatingPillView({
    required this.count,
    required this.sum,
    required this.my,
    required this.onTap,
  });

  final int count;
  final int sum;
  final int? my;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    // Stars reflect the **weighted average** across all voters
    // (`sum / count`), with a half-filled star for the .5
    // increments. Previously the pill highlighted `my` (the
    // current user's vote), which made the card display the
    // viewer's own star count instead of the recipe's overall
    // rating — e.g. a recipe with two votes (5 and 3) showed 3
    // stars to the user who rated 3, rather than the actual
    // average of 4.
    final avg = count > 0 ? sum / count : 0.0;
    return Material(
      color: Colors.black.withValues(alpha: 0.65),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 40,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 1; i <= 5; i++)
                InkResponse(
                  onTap: onTap == null ? null : () => onTap!(i),
                  radius: 16,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Icon(
                      avg >= i
                          ? Icons.star_rounded
                          : avg >= i - 0.5
                          ? Icons.star_half_rounded
                          : Icons.star_outline_rounded,
                      size: 22,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: const TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Бейдж-сердце в правом верхнем углу карточки. Зеркалит размер и
/// визуальный вес [YoutubeBadge]: круг 40×40, полупрозрачный
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

  /// When true, always render the pill layout (number + heart),
  /// even when [favoritesCount] is zero. Per the spec the heart
  /// is always a pill with a visible count. Defaults to `true`.
  final bool showCount;

  /// Server-projected creator id from `attachSocialSignals`. When
  /// it equals [myProfileNotifier.value?.id] the heart short-circuits
  /// on un-favourite — authors cannot unfavourite their own recipes
  /// (cross-device, server-authoritative).
  final String? creatorUserId;

  const FavoriteBadge({
    super.key,
    required this.recipeId,
    this.creatorUserId,
    this.favoritesCount = 0,
    this.showCount = true,
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
                recipeId: recipeId,
                store: null,
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
                  recipeId: recipeId,
                  store: store,
                  onTap: () async {
                    if (!userLoggedInNotifier.value) {
                      await _showRegistrationRequired(context);
                      return;
                    }
                    // Owner-pin: a recipe authored on this device
                    // is permanently in favourites across every
                    // language. Tapping the heart on an owned
                    // recipe must not unfavourite it (per spec).
                    // We allow add (idempotent) but block remove.
                    // Server-authoritative: same author rule applies
                    // on every device the user signs in on, even when
                    // the local owned_recipes registry is empty.
                    final owned = ownedRecipesStoreNotifier.value;
                    final myId = myProfileNotifier.value?.id;
                    final creatorId = creatorUserId;
                    final isAuthor =
                        (creatorId != null &&
                            myId != null &&
                            creatorId == myId) ||
                        (owned != null && owned.isOwned(recipeId));
                    if (isFav && isAuthor) {
                      HapticFeedback.lightImpact();
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
  final int recipeId;
  final FavoritesStore? store;

  const _FavoriteBadgeView({
    required this.isFavorite,
    required this.onTap,
    required this.recipeId,
    this.favoritesCount = 0,
    this.showCount = false,
    this.store,
  });

  @override
  Widget build(BuildContext context) {
    // GestureDetector + HitTestBehavior.opaque вместо Material/InkWell:
    // на Flutter web (CanvasKit) вложенный InkWell внутри Stack поверх
    // другого InkWell не всегда получает тап — событие уходит в
    // родительский Material карточки. GestureDetector с opaque всегда
    // поглощает тап независимо от платформы.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: showCount ? _buildPill(context) : _buildSquare(),
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

  /// Dark pill `<count> ♡`. The count is bound to a per-recipe
  /// notifier owned by [FavoritesStore] so it stays in sync across
  /// every visible card the moment the user taps the heart, and is
  /// also persisted into `recipes.favorites_count` so reload from
  /// cache survives a process restart.
  Widget _buildPill(BuildContext context) {
    final isFav = isFavorite;
    final s = store;
    final Widget countText = s == null
        ? Text(
            '$favoritesCount',
            style: const TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.primary,
            ),
          )
        : ValueListenableBuilder<int>(
            valueListenable: s.countFor(recipeId, seed: favoritesCount),
            builder: (_, n, __) => Text(
              '$n',
              style: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          );
    return Semantics(
      label: isFav ? 'favorite-on' : 'favorite-off',
      button: true,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            countText,
            const SizedBox(width: 6),
            Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              size: 22,
              color: AppColors.primary,
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

/// Compact author row shown on the recipe card under the ingredient
/// count. Mirrors the larger [AddedByRow] used on the details page
/// (lib/ui/social/added_by_row.dart) but with a 40 dp avatar that
/// has its own elevation so it reads as a separate object on top of
/// the card surface. Hidden when the server hasn't projected
/// creator metadata.
class _AuthorChip extends StatelessWidget {
  const _AuthorChip({
    required this.name,
    required this.avatarPath,
    required this.recipesAdded,
  });

  final String name;
  final String? avatarPath;
  final int? recipesAdded;

  static const double _avatarSize = 40;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final added = recipesAdded;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Elevated avatar — Material elevation 2 (~card-secondary
        // shadow) so the avatar visually lifts above the card
        // surface while staying within the design system's
        // shadow vocabulary.
        Material(
          shape: const CircleBorder(),
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          color: AppColors.surfaceMuted,
          child: SizedBox(
            width: _avatarSize,
            height: _avatarSize,
            child: avatarPath == null
                ? const Icon(
                    Icons.person,
                    size: 22,
                    color: AppColors.textSecondary,
                  )
                : Image.network(
                    imgproxyUrl(avatarPath!, 80, 80),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person,
                      size: 22,
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: name,
                  style: const TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 20 / 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (added != null && added > 0)
                  TextSpan(
                    text: '  •  ${s.recipeAuthorRecipes(added)}',
                    style: const TextStyle(
                      fontFamily: AppTextStyles.fontFamily,
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                      height: 18 / 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
