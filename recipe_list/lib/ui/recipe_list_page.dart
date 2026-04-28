import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api/recipe_api.dart';
import '../i18n.dart';
import '../models/recipe.dart';
import 'app_bottom_nav_bar.dart';
import 'app_theme.dart';
import 'recipe_card.dart';
import 'recipe_details_page.dart';
import 'search_app_bar.dart';

/// Страница со списком рецептов. Принимает готовый список через конструктор —
/// загрузка данных вынесена выше (см. `RecipeListLoader`).
///
/// Сама страница теперь владеет:
/// * полем поиска в `AppBar` (см. [SearchAppBar]);
/// * локальным фильтром списка по подстроке имени;
/// * выпадающим списком подсказок (см. [SearchPredictions]) — top-5
///   совпадений локального списка, тап открывает экран деталей.
///
/// При тапе на карточку (как и на подсказку) открывает экран деталей.
/// Если карточка lite (поля категории/инструкций пустые), сначала вызывает
/// [RecipeApi.lookup], чтобы догрузить полную версию рецепта.
class RecipeListPage extends StatefulWidget {
  final List<Recipe> recipes;
  final RecipeApi? api;

  const RecipeListPage({super.key, required this.recipes, this.api});

  @override
  State<RecipeListPage> createState() => _RecipeListPageState();
}

class _RecipeListPageState extends State<RecipeListPage> {
  static const int _maxPredictions = 5;
  static const Duration _debounce = Duration(milliseconds: 250);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  /// Применённый (через submit) фильтр — управляет содержимым списка.
  String _appliedQuery = '';

  /// Текущий ввод (без debounce) — управляет содержимым подсказок.
  String _liveQuery = '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Перерисовка для скрытия dropdown при потере фокуса.
    setState(() {});
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      if (!mounted) return;
      setState(() => _liveQuery = value);
    });
  }

  void _onSubmitted(String value) {
    _debounceTimer?.cancel();
    setState(() {
      _liveQuery = value;
      _appliedQuery = value;
    });
    _focusNode.unfocus();
  }

  List<Recipe> _filtered() {
    if (_appliedQuery.trim().isEmpty) return widget.recipes;
    final q = _appliedQuery.toLowerCase();
    return widget.recipes
        .where((r) => r.name.toLowerCase().contains(q))
        .toList(growable: false);
  }

  List<Recipe> _predictions() {
    final q = _liveQuery.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return widget.recipes
        .where((r) => r.name.toLowerCase().contains(q))
        .take(_maxPredictions)
        .toList(growable: false);
  }

  bool get _showPredictions =>
      _focusNode.hasFocus && _liveQuery.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: SearchAppBar(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _onChanged,
        onSubmitted: _onSubmitted,
      ),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: filtered.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final recipe = filtered[index];
                        return RecipeCard(
                          recipe: recipe,
                          onTap: () => _openDetails(context, recipe),
                        );
                      },
                    ),
            ),
            if (_showPredictions)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: SearchPredictions(
                  items: _predictions(),
                  onTap: (recipe) {
                    _focusNode.unfocus();
                    _openDetails(context, recipe);
                  },
                ),
              ),
          ],
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

  Future<void> _openDetails(BuildContext context, Recipe recipe) async {
    Recipe full = recipe;
    if (recipe.isLite && widget.api != null) {
      final fetched = await widget.api!.lookup(recipe.id);
      if (fetched != null) full = fetched;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RecipeDetailsPage(recipe: full)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_meals, size: 64, color: AppColors.textInactive),
          const SizedBox(height: AppSpacing.md),
          Text(
            s.emptyList,
            style: const TextStyle(fontSize: 16, color: AppColors.textInactive),
          ),
        ],
      ),
    );
  }
}
