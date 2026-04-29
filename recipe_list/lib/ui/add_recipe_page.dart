import 'package:flutter/material.dart';

import '../data/api/recipe_api.dart';
import '../data/api/recipe_api_config.dart';
import '../data/repository/recipe_repository.dart';
import '../i18n.dart';
import '../models/recipe.dart';
import 'app_theme.dart';

/// Экран «Добавить рецепт». Доступен из FAB-а с плюсом на
/// [RecipeListPage] (см. design_system.md §9b/§9n). Заполняется
/// **на английском** — серверный cascade перевода (см.
/// `routes/recipes.js: _ensureLang` и
/// `docs/translation-pipeline.md`) сам подтянет остальные локали
/// при следующем `/recipes/lookup/:id?lang=…`.
///
/// Поток сохранения:
///   1. `RecipeApi.createRecipe` — POST на `/recipes`. Сервер
///      присваивает id ≥ 1_000_000, чтобы не конфликтовать с
///      идентификаторами TheMealDB (см.
///      `docs/add-recipe-feature.md`).
///   2. Возвращённый рецепт пишем в локальный sqflite через
///      `RecipeRepository.upsertAll([recipe], lang)`.
///   3. `Navigator.pop(recipe)` — список на предыдущем экране
///      добавит карточку наверх.
///
/// Если backend == TheMealDB или сеть недоступна — показываем
/// snackbar с ошибкой и НЕ пишем в локальный кэш (нет id).
class AddRecipePage extends StatefulWidget {
  const AddRecipePage({super.key, this.api, this.repository});

  final RecipeApi? api;
  final RecipeRepository? repository;

  @override
  State<AddRecipePage> createState() => _AddRecipePageState();
}

class _AddRecipePageState extends State<AddRecipePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _photo = TextEditingController();
  final _category = TextEditingController();
  final _area = TextEditingController();
  final _instructions = TextEditingController();
  final List<_IngredientRow> _ingredientRows = [_IngredientRow()];

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _photo.dispose();
    _category.dispose();
    _area.dispose();
    _instructions.dispose();
    for (final r in _ingredientRows) {
      r.dispose();
    }
    super.dispose();
  }

  /// Новая строка ингредиента. Сервер канонизирует
  /// `strIngredient1..20` — больше не пускаем.
  void _addIngredientRow(int afterIndex) {
    setState(() {
      if (_ingredientRows.length >= 20) return;
      _ingredientRows.insert(afterIndex + 1, _IngredientRow());
    });
  }

  void _removeIngredientRow(int index) {
    if (_ingredientRows.length <= 1) return;
    setState(() {
      _ingredientRows.removeAt(index).dispose();
    });
  }

  /// Собирает [_IngredientRow]-ы в [RecipeIngredient]. `measure`
  /// на сервере — единая строка, поэтому склеиваем
  /// `"$qty $unit"` с разделителем-пробелом.
  List<RecipeIngredient> _collectIngredients() {
    final out = <RecipeIngredient>[];
    for (final r in _ingredientRows) {
      final n = r.name.text.trim();
      if (n.isEmpty) continue;
      final q = r.qty.text.trim();
      final u = r.unit.text.trim();
      final parts = <String>[if (q.isNotEmpty) q, if (u.isNotEmpty) u];
      out.add(RecipeIngredient(name: n, measure: parts.join(' ')));
      if (out.length >= 20) break;
    }
    return out;
  }

  Future<void> _save() async {
    final s = S.of(context);
    if (!_formKey.currentState!.validate()) return;
    final api = widget.api;
    if (api == null || RecipeApiConfig.backend != RecipeBackend.mahallem) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.addRecipeError)));
      return;
    }
    setState(() => _saving = true);

    // Build draft. id is a placeholder — server assigns the real one.
    final draft = Recipe(
      id: 0,
      name: _name.text.trim(),
      photo: _photo.text.trim(),
      category: _category.text.trim().isEmpty ? null : _category.text.trim(),
      area: _area.text.trim().isEmpty ? null : _area.text.trim(),
      instructions: _instructions.text.trim().isEmpty
          ? null
          : _instructions.text.trim(),
      ingredients: _collectIngredients(),
    );

    try {
      final saved = await api.createRecipe(draft);
      // Mirror server-assigned row into the local cache so the new
      // recipe survives a cold start. Best-effort — failure here
      // doesn't roll back the server insert.
      try {
        await widget.repository?.upsertAll([saved], appLang.value);
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.addRecipeSuccess)));
      Navigator.of(context).pop(saved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.addRecipeError)));
    }
  }

  String? _required(String? v) {
    final s = S.of(context);
    if (v == null || v.trim().isEmpty) return s.addRecipeRequired;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.addRecipeTitle)),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                s.addRecipeEnglishHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: s.addRecipeName),
                validator: _required,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _photo,
                decoration: InputDecoration(labelText: s.addRecipePhoto),
                keyboardType: TextInputType.url,
                validator: _required,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _category,
                decoration: InputDecoration(labelText: s.addRecipeCategory),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _area,
                decoration: InputDecoration(labelText: s.addRecipeArea),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _instructions,
                decoration: InputDecoration(
                  labelText: s.addRecipeInstructions,
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
                minLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),
              // Ингредиенты: динамический список строк [name|qty|unit].
              // Справа от каждой строки — номер (1…20) и кнопка «+»,
              // вставляющая новую строку ниже текущей. Сервер
              // ожидает `strMeasureN` одной строкой, поэтому
              // qty + unit склеиваются в [_collectIngredients].
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.xs,
                  bottom: AppSpacing.sm,
                ),
                child: Text(
                  s.addRecipeIngredientsLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              for (var i = 0; i < _ingredientRows.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _IngredientRowField(
                    row: _ingredientRows[i],
                    index: i,
                    showRemove: _ingredientRows.length > 1,
                    onAdd: () => _addIngredientRow(i),
                    onRemove: () => _removeIngredientRow(i),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? s.addRecipeSaving : s.addRecipeSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Контроллеры одной строки ингредиента. Держим отдельно
/// от [State], чтобы `setState(() => _ingredientRows.insert/removeAt)`
/// не терял введённые значения в соседних строках.
class _IngredientRow {
  final TextEditingController name = TextEditingController();
  final TextEditingController qty = TextEditingController();
  final TextEditingController unit = TextEditingController();

  void dispose() {
    name.dispose();
    qty.dispose();
    unit.dispose();
  }
}

/// Одна строка ингредиента: `name | qty | unit | № | +/−`.
///
/// Раскладка подобрана так, чтобы длинные локализации
/// (немецкий, курдский) не переполнялись. Доли:
///   * `name` — flex 5 (занимает половину).
///   * `qty` — flex 2 (`keyboardType: numberWithOptions(decimal: true)`).
///   * `unit` — flex 3.
class _IngredientRowField extends StatelessWidget {
  const _IngredientRowField({
    required this.row,
    required this.index,
    required this.showRemove,
    required this.onAdd,
    required this.onRemove,
  });

  final _IngredientRow row;
  final int index;
  final bool showRemove;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: TextFormField(
            controller: row.name,
            decoration: InputDecoration(
              labelText: s.addRecipeIngredientName,
              isDense: true,
            ),
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: row.qty,
            decoration: InputDecoration(
              labelText: s.addRecipeIngredientQty,
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: row.unit,
            decoration: InputDecoration(
              labelText: s.addRecipeIngredientMeasure,
              isDense: true,
            ),
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Номер строки 1…20, выравнян с серединой input-а
        // (`isDense: true` → высота ~48). Используем фиксированный
        // pad, чтобы лейблы инпутов не сбивали вертикаль.
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: SizedBox(
            width: 24,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        // Кнопка «+» добавляет строку ниже текущей. Если
        // строк больше одной, иконка `×` появляется слева.
        if (showRemove)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: IconButton(
              tooltip: s.addRecipeIngredientRemove,
              icon: const Icon(Icons.close, size: 18),
              color: AppColors.textSecondary,
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton(
            tooltip: s.addRecipeIngredientAdd,
            icon: const Icon(Icons.add_circle, size: 24),
            color: AppColors.primaryDark,
            visualDensity: VisualDensity.compact,
            onPressed: onAdd,
          ),
        ),
      ],
    );
  }
}
