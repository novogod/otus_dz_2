import 'package:flutter/material.dart';

import '../auth/admin_session.dart';
import '../data/api/recipe_api.dart';
import '../i18n.dart';
import 'admin_users_page.dart';
import 'app_theme.dart';
import 'recipe_details_page.dart';

class AdminAddedRecipesPage extends StatefulWidget {
  const AdminAddedRecipesPage({
    super.key,
    required this.adminLogin,
    required this.adminPassword,
  });

  final String adminLogin;
  final String adminPassword;

  @override
  State<AdminAddedRecipesPage> createState() => _AdminAddedRecipesPageState();
}

class _AdminAddedRecipesPageState extends State<AdminAddedRecipesPage> {
  List<AdminAddedRecipeItem> _items = const [];
  bool _busy = false;
  int? _openingRecipeId;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _busy = true);
    try {
      final rows = await fetchRecipeAdminAddedRecipes(
        adminLogin: widget.adminLogin,
        adminPassword: widget.adminPassword,
      );
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loadError = null;
      });
    } catch (e, st) {
      debugPrint('[AdminAddedRecipesPage] _reload error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _items = const [];
        _loadError = 'Failed to load recipes added list: $e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openRecipe(AdminAddedRecipeItem item) async {
    if (_openingRecipeId != null) return;
    setState(() => _openingRecipeId = item.recipeId);
    try {
      final recipe = await RecipeApi().lookup(
        item.recipeId,
        lang: appLang.value,
      );
      if (!mounted) return;
      if (recipe == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Recipe card is not available right now.'),
            ),
          );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RecipeDetailsPage(recipe: recipe, api: RecipeApi()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Failed to open recipe card: $e')),
        );
    } finally {
      if (mounted) setState(() => _openingRecipeId = null);
    }
  }

  Future<void> _openCreator(AdminAddedRecipeItem item) async {
    if (item.creatorUserId == null || item.creatorUserId!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'User card is available only for user-created recipes.',
            ),
          ),
        );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminUsersPage(
          adminLogin: widget.adminLogin,
          adminPassword: widget.adminPassword,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recipes added',
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontWeight: FontWeight.w400,
            fontSize: 20,
            height: 23 / 20,
            color: AppColors.primaryDark,
          ),
        ),
        actions: [
          IconButton(
            tooltip: s.retry,
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _busy && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.pagePadding),
                  child: Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            : _items.isEmpty
            ? const Center(
                child: Text(
                  'No added recipes found yet.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final opening = _openingRecipeId == item.recipeId;
                  final creatorTitle =
                      (item.creatorName != null &&
                          item.creatorName!.trim().isNotEmpty)
                      ? item.creatorName!.trim()
                      : item.creatorEmail ?? 'Unknown user';
                  final createdAtLabel =
                      item.createdAt?.toLocal().toString() ?? '';

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.recipeName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'By: $creatorTitle',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if ((item.creatorEmail ?? '').isNotEmpty)
                            Text(
                              item.creatorEmail!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          if (createdAtLabel.isNotEmpty)
                            Text(
                              'Added: $createdAtLabel',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              OutlinedButton.icon(
                                onPressed: opening
                                    ? null
                                    : () => _openRecipe(item),
                                icon: opening
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.restaurant_menu),
                                label: const Text('Open recipe card'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _openCreator(item),
                                icon: const Icon(Icons.person_outline),
                                label: const Text('Open user card'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemCount: _items.length,
              ),
      ),
    );
  }
}
