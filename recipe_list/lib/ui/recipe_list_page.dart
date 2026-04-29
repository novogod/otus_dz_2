import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api/recipe_api.dart';
import '../data/repository/recipe_repository.dart';
import '../i18n.dart';
import '../main.dart' show restartApp;
import '../models/recipe.dart';
import 'app_bottom_nav_bar.dart';
import 'app_theme.dart';
import 'recipe_card.dart';
import 'recipe_details_page.dart';
import 'search_app_bar.dart';

/// Страница со списком рецептов. Принимает готовый список через конструктор —
/// загрузка данных вынесена выше (см. `RecipeListLoader`).
///
/// Сама страница владеет:
/// * полем поиска в `AppBar` (см. [SearchAppBar]);
/// * выпадающим списком подсказок (см. [SearchPredictions]),
///   который при наличии [api] дёргает TheMealDB
///   `search.php?s=<prefix>` и показывает рецепты, имена которых
///   начинаются с этого префикса. Без [api] (в тестах) фолбэком
///   идёт префикс-фильтр по [recipes].
///
/// При submit / тапе по подсказке результаты замещают базовый
/// список (`recipes`), т.е. выбор подсказки = фильтр списка с
/// догрузкой с API. Сброс поля (клавиша ✕ внутри [SearchAppBar])
/// возвращает базовый список, который передал `RecipeListLoader`.
///
/// При тапе на карточку или на подсказку с полными данными открывает
/// экран деталей. Если карточка lite, сначала [RecipeApi.lookup].
class RecipeListPage extends StatefulWidget {
  final List<Recipe> recipes;
  final RecipeApi? api;

  /// Необязательный кэш-репозиторий. Если задан — все публичные
  /// поиски идут через [RecipeRepository.searchByName] (cache-first
  /// + флаг offline для баннера). Без репозитория —
  /// старый путь через [RecipeApi] напрямую (используется
  /// в widget-тестах).
  final RecipeRepository? repository;

  const RecipeListPage({
    super.key,
    required this.recipes,
    this.api,
    this.repository,
  });

  @override
  State<RecipeListPage> createState() => _RecipeListPageState();
}

class _RecipeListPageState extends State<RecipeListPage> {
  static const Duration _debounce = Duration(milliseconds: 300);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  /// Текущий префикс в поле поиска (без debounce). Используется
  /// для очистки подсказок, когда поле пустое.
  String _liveQuery = '';

  /// Результаты API для выпадающего списка, уже отфильтрованные
  /// по началу имени. Пустой список + включённый [_predictionsLoading]
  /// = спиннер внутри dropdown.
  List<Recipe> _predictionRecipes = const [];
  bool _predictionsLoading = false;

  /// Префикс последнего успешного запроса — используется для
  /// отбрасывания результатов устаревших запросов (race-condition).
  String _lastQueryInFlight = '';

  /// Выставляется, когда и локальный кэш, и сеть одновременно
  /// пусты: показываем вверху плашку «offline» (§B6).
  bool _offline = false;

  /// Рецепты, показанные в основном списке. По умолчанию совпадает
  /// с `widget.recipes`; после submit / выбора подсказки — результат
  /// фильтра (или API).
  late List<Recipe> _displayed = widget.recipes;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant RecipeListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Когда родитель (RecipeListLoader) на смене языка передаёт уже
    // переведённый список рецептов, обновляем `_displayed`, иначе
    // экран продолжит рисовать старый (англоязычный) кэш.
    // Если пользователь сейчас фильтрует по поиску — не трогаем
    // отфильтрованный набор, чтобы не сбросить выбор.
    if (!identical(oldWidget.recipes, widget.recipes) &&
        identical(_displayed, oldWidget.recipes)) {
      _displayed = widget.recipes;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Перерисовка для скрытия dropdown при потере фокуса.
    setState(() {});
  }

  /// Следит за controller-ом, чтобы реагировать на `controller.clear()`
  /// из [SearchAppBar] (клавиша ✕), когда onChanged не вызывается.
  void _onTextChanged() {
    if (_controller.text.isEmpty && _displayed != widget.recipes) {
      setState(() {
        _displayed = widget.recipes;
        _predictionRecipes = const [];
        _liveQuery = '';
      });
    }
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    final trimmed = value.trim();
    setState(() => _liveQuery = trimmed);
    if (trimmed.isEmpty) {
      setState(() {
        _predictionRecipes = const [];
        _predictionsLoading = false;
      });
      return;
    }
    _debounceTimer = Timer(_debounce, () => _runPredictionQuery(trimmed));
  }

  void _onSubmitted(String value) {
    _debounceTimer?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _displayed = widget.recipes;
        _predictionRecipes = const [];
        _liveQuery = '';
      });
      _focusNode.unfocus();
      return;
    }
    _runPredictionQuery(trimmed, applyToList: true);
    _focusNode.unfocus();
  }

  /// Дёргает API и отфильтровывает результат по началу имени
  /// (TheMealDB их отдаёт по подстроке, берём строже — startsWith).
  /// Если [api] = null (тесты), фильтрует локальный [widget.recipes].
  Future<void> _runPredictionQuery(
    String prefix, {
    bool applyToList = false,
  }) async {
    final repo = widget.repository;
    final api = widget.api;
    if (repo == null && api == null) {
      // Тестовый фолбэк: локальный префикс-фильтр по widget.recipes.
      final hits = _localPrefix(widget.recipes, prefix);
      setState(() {
        _predictionRecipes = hits;
        _predictionsLoading = false;
        if (applyToList) _displayed = hits;
      });
      return;
    }
    setState(() {
      _predictionsLoading = true;
      _lastQueryInFlight = prefix;
    });
    try {
      List<Recipe> hits;
      bool offline;
      if (repo != null) {
        final res = await repo.searchByName(prefix, appLang.value);
        hits = res.recipes
            .where((r) => r.name.toLowerCase().startsWith(prefix.toLowerCase()))
            .toList(growable: false);
        offline = res.offline;
      } else {
        final fetched = await api!.searchByName(
          query: prefix,
          lang: appLang.value,
        );
        hits = _localPrefix(fetched, prefix);
        offline = false;
      }
      if (!mounted) return;
      // Отбрасываем протухшие запросы: пользователь мог успеть
      // ввести больше букв, пока этот висел в полёте.
      if (_lastQueryInFlight != prefix) return;
      setState(() {
        _predictionRecipes = hits;
        _predictionsLoading = false;
        _offline = offline;
        if (applyToList) _displayed = hits;
      });
    } on Object {
      if (!mounted) return;
      if (_lastQueryInFlight != prefix) return;
      setState(() {
        _predictionRecipes = const [];
        _predictionsLoading = false;
        _offline = true;
        if (applyToList) _displayed = const [];
      });
    }
  }

  static List<Recipe> _localPrefix(List<Recipe> source, String prefix) {
    final p = prefix.toLowerCase();
    return source
        .where((r) => r.name.toLowerCase().startsWith(p))
        .toList(growable: false);
  }

  bool get _showPredictions => _focusNode.hasFocus && _liveQuery.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final list = _displayed;
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: SearchAppBar(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _onChanged,
        onSubmitted: _onSubmitted,
        showReload: true,
        // «Назад» на списке = перезапуск всей splash-последовательности
        // (см. `restartApp` в main.dart). Maybe-pop здесь бесполезен,
        // т.к. список — корень навигатора.
        onBack: restartApp,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (_offline)
              _OfflineBanner(onDismiss: () => setState(() => _offline = false)),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: list.isEmpty
                        ? const _EmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            itemCount: list.length,
                            itemBuilder: (context, index) {
                              final recipe = list[index];
                              return RecipeCard(
                                recipe: recipe,
                                onTap: () => _openDetails(context, recipe),
                              );
                            },
                          ),
                  ),
                  if (_showPredictions)
                    Positioned.fill(
                      child: SearchPredictions(
                        items: _predictionRecipes,
                        loading: _predictionsLoading,
                        onTap: (recipe) {
                          _onPredictionTap(recipe);
                        },
                      ),
                    ),
                ],
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
      final fetched = await widget.api!.lookup(recipe.id, lang: appLang.value);
      if (fetched != null) full = fetched;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeDetailsPage(recipe: full, api: widget.api),
      ),
    );
  }

  /// Тап по подсказке: работает как фильтр — заменяет основной
  /// список на все подгруженные с этим префиксом, подставляет
  /// имя в поле поиска, снимает фокус и скроллит список вверх.
  void _onPredictionTap(Recipe recipe) {
    _focusNode.unfocus();
    _controller.text = recipe.name;
    _controller.selection = TextSelection.collapsed(offset: recipe.name.length);
    setState(() {
      _liveQuery = recipe.name;
      _displayed = List<Recipe>.unmodifiable(_predictionRecipes);
    });
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

/// Плашка «нет сети» над списком — появляется, когда репозиторий
/// вернул `offline=true` (и кэш, и сеть промахнулись). См. §B6
/// docs/todo/search_api_deploy.md.
class _OfflineBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const _OfflineBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Material(
      color: AppColors.surfaceMuted,
      child: SafeArea(
        bottom: false,
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  s.offlineNotice,
                  style: const TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              IconButton(
                tooltip: s.dismiss,
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
