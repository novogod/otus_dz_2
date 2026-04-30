import 'package:flutter/material.dart';

import '../data/repository/favorites_store.dart';
import '../i18n.dart';
import '../models/recipe.dart';
import 'app_bottom_nav_bar.dart';
import 'app_theme.dart';
import 'recipe_card.dart';
import 'recipe_details_page.dart';
import 'search_app_bar.dart';

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
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
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
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final recipe = filtered[i];
                            return RecipeCard(
                              recipe: recipe,
                              onTap: () => _openDetails(context, recipe),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
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

  void _openDetails(BuildContext context, Recipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeDetailsPage(recipe: recipe),
      ),
    );
  }

  void _onNavTap(BuildContext context, AppNavTab tab) {
    if (tab == AppNavTab.favorites) return;
    if (tab == AppNavTab.recipes) {
      Navigator.of(context).maybePop();
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
