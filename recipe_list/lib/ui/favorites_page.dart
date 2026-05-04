import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../auth/admin_session.dart';
import '../data/api/recipe_api.dart';
import '../data/recipe_events.dart';
import '../data/repository/favorites_store.dart';
import '../data/repository/owned_recipes_store.dart';
import '../data/repository/recipe_repository.dart';
import '../i18n.dart';
import '../models/recipe.dart';
import 'add_recipe_page.dart';
import 'app_bottom_nav_bar.dart';
import 'app_theme.dart';
import 'login_page.dart';
import 'recipe_card.dart';
import 'recipe_details_page.dart';
import 'recipe_list_page.dart';
import 'search_app_bar.dart';
import 'signup_page.dart';

/// Экран «Избранное» (chunk D из todo/15).
///
/// - Источник данных: [FavoritesStore.list] на текущий [appLang].
/// - Если стор ещё не инициализирован, показываем placeholder
///   «нет избранного» — обычное состояние при первом запуске
///   до открытия БД.
/// - Поиск работает только локально по уже отобранным избранным
///   (case-fold по `recipe.name`), без обращений к API.
/// - В шапке кнопки переключения языка и `reload` — faded и не
///   кликаемы, чтобы не уводить пользователя со «своих рецептов»
///   в чужой язык, где избранное другое.
class FavoritesPage extends StatefulWidget {
  /// API и репозиторий прокидываются из [RecipeListPage], чтобы
  /// FAB «добавить рецепт» мог открыть [AddRecipePage]
  /// с тем же бэкендом, что и главная лента. Оба поля
  /// nullable — в тестах / в «холодном» режиме (без API)
  /// FAB добавления просто не рендерится.
  final RecipeApi? api;
  final RecipeRepository? repository;

  const FavoritesPage({super.key, this.api, this.repository});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String _query = '';
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    recipeDeletedNotifier.addListener(_onRecipeChanged);
    recipeUpdatedNotifier.addListener(_onRecipeChanged);
  }

  /// Owner-flow: перерисовываем избранное при удалении
  /// или редактировании, чтобы FutureBuilder подхватил
  /// свежие данные из sqflite (см. docs/owner-edit-delete.md).
  void _onRecipeChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    final shouldShow = _scrollController.hasClients
        ? _scrollController.offset > 200
        : false;
    if (shouldShow != _showScrollToTop) {
      setState(() => _showScrollToTop = shouldShow);
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    recipeDeletedNotifier.removeListener(_onRecipeChanged);
    recipeUpdatedNotifier.removeListener(_onRecipeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: SearchAppBar(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: (q) => setState(() => _query = q),
        onSubmitted: (q) => setState(() => _query = q),
        disableLangAndReload: true,
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: ValueListenableBuilder<FavoritesStore?>(
                valueListenable: favoritesStoreNotifier,
                builder: (context, store, _) {
                  if (store == null) {
                    return const _FavoritesEmpty();
                  }
                  return ValueListenableBuilder<AppLang>(
                    valueListenable: appLang,
                    builder: (context, lang, _) {
                      return ValueListenableBuilder<Set<int>>(
                        valueListenable: store.idsForLang(lang),
                        builder: (context, _, _) {
                          return FutureBuilder<List<Recipe>>(
                            future: store.list(lang),
                            builder: (context, snap) {
                              if (!snap.hasData) {
                                return const SizedBox.shrink();
                              }
                              final all = snap.data!;
                              if (all.isEmpty) {
                                return const _FavoritesEmpty();
                              }
                              final filtered = _filter(all, _query);
                              if (filtered.isEmpty) {
                                return const _NoMatches();
                              }
                              return _buildFavoritesCollection(filtered);
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            // FAB «к началу списка» — те же координаты и поведение,
            // что и на главной (см. RecipeListPage).
            Positioned(
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: IgnorePointer(
                ignoring: !_showScrollToTop,
                child: AnimatedOpacity(
                  opacity: _showScrollToTop ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: ScrollToTopFab(onPressed: _scrollToTop),
                ),
              ),
            ),
            // FAB «добавить рецепт» — виден только если страница
            // получила api/repository (как и на главной ленте).
            // В тестах без бэкенда FAB просто не появляется.
            if (widget.api != null)
              Positioned(
                left: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: AddRecipeFab(onPressed: () => _openAddRecipe(context)),
              ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        current: AppNavTab.favorites,
        onTap: (tab) => _onNavTap(context, tab),
      ),
    );
  }

  static List<Recipe> _filter(List<Recipe> source, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return source;
    return source
        .where((r) => r.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  Widget _buildFavoritesCollection(List<Recipe> list) {
    if (!kIsWeb) {
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final recipe = list[i];
          return RecipeCard(
            recipe: recipe,
            onTap: () => _openDetails(context, recipe),
            onEdit: () => _openEditRecipe(context, recipe),
            onDelete: () => _confirmAndDeleteFromCard(context, recipe),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.md;
        const minCardWidth = 300.0;
        const maxCardWidth = 420.0;
        final available = (constraints.maxWidth - AppSpacing.pagePadding * 2)
            .clamp(0.0, double.infinity);

        int columns = ((available + spacing) / (maxCardWidth + spacing))
            .ceil()
            .clamp(1, 8);
        double itemWidth = (available - spacing * (columns - 1)) / columns;
        while (columns > 1 && itemWidth < minCardWidth) {
          columns -= 1;
          itemWidth = (available - spacing * (columns - 1)) / columns;
        }

        final childAspectRatio = itemWidth / (itemWidth * 0.5625 + 176);

        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.sm,
            AppSpacing.pagePadding,
            AppSpacing.sm,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final recipe = list[i];
            return RecipeCard(
              recipe: recipe,
              outerPadding: EdgeInsets.zero,
              onTap: () => _openDetails(context, recipe),
              onEdit: () => _openEditRecipe(context, recipe),
              onDelete: () => _confirmAndDeleteFromCard(context, recipe),
            );
          },
        );
      },
    );
  }

  void _openDetails(BuildContext context, Recipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        // Пробрасываем api/repository, иначе на странице деталей
        // lazy-load `instructions` из `recipe_bodies` не сработает
        // (FutureBuilder живёт в ветке `widget.repository != null`),
        // и из избранного открывался бы рецепт без инструкций —
        // FavoritesStore.list джойнит только `recipes`, тело
        // подгружается лениво уже на странице деталей.
        builder: (_) => RecipeDetailsPage(
          recipe: recipe,
          api: widget.api,
          repository: widget.repository,
          originTab: AppNavTab.favorites,
        ),
      ),
    );
  }

  Future<void> _openAddRecipe(BuildContext context) async {
    if (!userLoggedInNotifier.value) {
      _showFavoritesRegistrationRequired(context);
      return;
    }
    final api = widget.api;
    if (api == null) return;
    await Navigator.of(context).push<Recipe>(
      MaterialPageRoute<Recipe>(
        builder: (_) => AddRecipePage(api: api, repository: widget.repository),
      ),
    );
    // Новый рецепт не попадает автоматически в избранное — список
    // обновится сам через `favoritesStoreNotifier`, когда
    // пользователь нажмёт сердце на странице деталей.
  }

  void _showFavoritesRegistrationRequired(BuildContext context) {
    final s = S.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(s.favoritesRegistrationRequired),
          action: SnackBarAction(
            label: s.signUp,
            onPressed: () async {
              final created = await openSignUpPage(context);
              if (!context.mounted || !created) return;
              await openLoginPage(context);
            },
          ),
        ),
      );
  }

  Future<void> _openEditRecipe(BuildContext context, Recipe recipe) async {
    await Navigator.of(context).push<Recipe>(
      MaterialPageRoute<Recipe>(
        builder: (_) => AddRecipePage(
          api: widget.api,
          repository: widget.repository,
          existing: recipe,
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteFromCard(
    BuildContext context,
    Recipe recipe,
  ) async {
    final s = S.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.adminDeleteTitle),
        content: Text(s.adminDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.dismiss),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.adminDeleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final api = widget.api;
    if (api == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.addRecipeError)));
      return;
    }
    try {
      await api.deleteRecipe(recipe.id);
      await widget.repository?.deleteById(recipe.id);
      await favoritesStoreNotifier.value?.removeAcrossLangs(recipe.id);
      await ownedRecipesStoreNotifier.value?.remove(recipe.id);
      recipeDeletedNotifier.value = recipe.id;
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.addRecipeError)));
    }
  }

  void _onNavTap(BuildContext context, AppNavTab tab) {
    if (tab == AppNavTab.favorites) return;
    if (tab == AppNavTab.recipes) {
      Navigator.of(context).maybePop();
      return;
    }
    if (tab == AppNavTab.profile) {
      openProfilePage(context);
      return;
    }
    final s = S.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(s.tabComingSoon),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

class _FavoritesEmpty extends StatelessWidget {
  const _FavoritesEmpty();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          s.favoritesEmpty,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          s.searchNoMatches,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
