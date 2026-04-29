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
  final _ingredients = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _photo.dispose();
    _category.dispose();
    _area.dispose();
    _instructions.dispose();
    _ingredients.dispose();
    super.dispose();
  }

  /// Парсит textarea-вид «name | measure» в список
  /// [RecipeIngredient]. Пустые строки игнорируются. Если
  /// разделителя нет — вся строка идёт в `name`, `measure` пустой.
  List<RecipeIngredient> _parseIngredients(String raw) {
    final lines = raw.split('\n');
    final out = <RecipeIngredient>[];
    for (final l in lines) {
      final t = l.trim();
      if (t.isEmpty) continue;
      final i = t.indexOf('|');
      if (i < 0) {
        out.add(RecipeIngredient(name: t, measure: ''));
      } else {
        out.add(
          RecipeIngredient(
            name: t.substring(0, i).trim(),
            measure: t.substring(i + 1).trim(),
          ),
        );
      }
      if (out.length >= 20) break; // server canonicalizes 1..20
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
      ingredients: _parseIngredients(_ingredients.text),
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
                decoration: InputDecoration(labelText: s.addRecipeInstructions),
                maxLines: 6,
                minLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _ingredients,
                decoration: InputDecoration(
                  labelText: s.addRecipeIngredientsLabel,
                ),
                maxLines: 8,
                minLines: 3,
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
