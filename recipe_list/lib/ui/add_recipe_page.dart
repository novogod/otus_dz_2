import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/api/recipe_api.dart';
import '../data/api/recipe_api_config.dart';
import '../data/recipe_events.dart';
import '../data/repository/favorites_store.dart';
import '../data/repository/recipe_repository.dart';
import '../i18n.dart';
import '../models/recipe.dart';
import '../utils/photo_downscaler.dart';
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

  /// Контроллер ListView-а формы. Нужен, чтобы после добавления
  /// новой строки ингредиента прокрутить ленту вниз — иначе новая
  /// строка появляется ниже viewport-а (или под клавиатурой)
  /// и пользователь её не видит — визуально это выглядит как
  /// «form уехала за safe-area» (см. docs/add-recipe-visibility.md).
  final ScrollController _scrollController = ScrollController();

  bool _saving = false;
  bool _compressing = false;
  bool _photoTouched = false; // user pressed Save → show "required" error
  File? _pickedPhoto;

  /// Web-сборка не поддерживает `image_picker` через нативный путь —
  /// оставляем URL-fallback. На mobile/desktop URL-поле скрыто:
  /// фото обязательно выбирается через picker.
  bool get _allowUrlFallback => kIsWeb;

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
    _scrollController.dispose();
    _disposePickedPhoto();
    super.dispose();
  }

  /// Удаляет временный файл из downscaler-а (если есть). Вызываем
  /// при ре-пике, drop-е или dispose. Ошибки игнорируем — это
  /// best-effort cleanup в каталоге temp.
  void _disposePickedPhoto() {
    final f = _pickedPhoto;
    if (f != null) {
      try {
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  /// Новая строка ингредиента. Сервер канонизирует
  /// `strIngredient1..20` — больше не пускаем.
  void _addIngredientRow(int afterIndex) {
    setState(() {
      if (_ingredientRows.length >= 20) return;
      _ingredientRows.insert(afterIndex + 1, _IngredientRow());
    });
    // После вставки ListView вырастает; без принудительного
    // скролла новая строка рисуется ниже видимой области и
    //  выглядит как баг «form уходит за safe-area» (пользователь
    // не понимает, что список просто нужно докрутить).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
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

  /// Выбор фото с указанного источника (камера / галерея).
  /// На входе — `XFile` от `image_picker`, на выходе — сжатый
  /// JPEG ≤ 5 МБ (см. [downscaleForUpload]).
  Future<void> _pickPhoto(ImageSource source) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picker = ImagePicker();
      // Не задаём maxWidth/maxHeight/imageQuality — сжатие делает
      // [downscaleForUpload] для предсказуемого результата (см. чанк 11.5).
      final raw = await picker.pickImage(source: source);
      if (raw == null) return; // user cancelled

      if (!mounted) return;
      setState(() => _compressing = true);
      final compressed = await downscaleForUpload(raw);
      if (!mounted) {
        try {
          if (await compressed.exists()) await compressed.delete();
        } catch (_) {}
        return;
      }
      // Удаляем предыдущий tmp до подмены ссылки.
      _disposePickedPhoto();
      setState(() {
        _pickedPhoto = compressed;
        _compressing = false;
        _photoTouched = true;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _compressing = false);
      final code = e.code.toLowerCase();
      final msg =
          (code.contains('access_denied') || code.contains('permission'))
          ? s.addRecipePhotoErrorAccessDenied
          : s.addRecipeError;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _compressing = false);
      final msg = e.message == 'photo_too_large'
          ? s.addRecipePhotoErrorTooLarge
          : s.addRecipeError;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _compressing = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.addRecipeError)));
    }
  }

  /// Bottom-sheet «Откуда взять фото?» с пунктами camera / gallery /
  /// remove (последний только в filled-state).
  Future<void> _showPhotoSourceSheet() async {
    final s = S.of(context);
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  s.addRecipePhotoSourceTitle,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: Text(s.addRecipePhotoFromCamera),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(s.addRecipePhotoFromGallery),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              if (_pickedPhoto != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: AppColors.primaryDark,
                  ),
                  title: Text(s.addRecipePhotoRemove),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _clearPickedPhoto();
                  },
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  void _clearPickedPhoto() {
    _disposePickedPhoto();
    setState(() {
      _pickedPhoto = null;
      _photoTouched = true;
    });
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
    // Photo validation: на mobile нужен picked file; на web допустим
    // URL-fallback (см. [_allowUrlFallback]).
    final hasPicked = _pickedPhoto != null;
    final hasUrl = _photo.text.trim().isNotEmpty;
    if (!hasPicked && !(_allowUrlFallback && hasUrl)) {
      setState(() => _photoTouched = true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.addRecipePhotoRequired)));
      return;
    }
    setState(() => _saving = true);

    // Build draft. id is a placeholder — server assigns the real one.
    final draft = Recipe(
      id: 0,
      name: _name.text.trim(),
      // Server replaces strMealThumb after upload. Use placeholder
      // when uploading a file; send URL as-is on web fallback.
      photo: hasPicked ? 'pending://upload' : _photo.text.trim(),
      category: _category.text.trim().isEmpty ? null : _category.text.trim(),
      area: _area.text.trim().isEmpty ? null : _area.text.trim(),
      instructions: _instructions.text.trim().isEmpty
          ? null
          : _instructions.text.trim(),
      ingredients: _collectIngredients(),
    );

    try {
      final saved = hasPicked
          ? await api.createRecipeWithPhoto(draft, _pickedPhoto!)
          : await api.createRecipe(draft);
      // Mirror server-assigned row into the local cache so the new
      // recipe survives a cold start. Best-effort — failure here
      // doesn't roll back the server insert.
      try {
        await widget.repository?.upsertAll([saved], appLang.value);
      } catch (_) {}
      // Авто-добавление в избранное в текущем языке: пользователь
      // ожидает, что только что созданный рецепт окажется на
      // вершине вкладки «Избранное» (см.
      // docs/add-recipe-visibility.md). saved_at = now() ⇒ строка
      // встаёт первой по `ORDER BY saved_at DESC`.
      try {
        await favoritesStoreNotifier.value?.add(saved.id, appLang.value);
      } catch (_) {}
      // Эмитим в глобальную шину, чтобы [RecipeListPage] подхватил
      // карточку независимо от того, с какой страницы был открыт
      // AddRecipePage (главная или избранное).
      newRecipeCreatedNotifier.value = saved;
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppBar(title: Text(s.addRecipeTitle)),
        ),
      ),
      body: SafeArea(
        // AppBar уже учитывает верхний inset; нам нужны только
        // боковые и нижний — иначе кнопка Save и поле Instructions
        // на iPhone уходят под home-indicator и обрезаются
        // системным жестом (см. docs/add-recipe-visibility.md).
        top: false,
        child: AbsorbPointer(
          absorbing: _saving,
          child: Form(
            key: _formKey,
            child: ListView(
              controller: _scrollController,
              // Нижний padding учитывает клавиатуру (`viewInsets.bottom`)
              // — без этого новая строка ингредиента, добавленная
              // из-под открытой клавы, ложится под неё и пользователь
              // воспринимает это как «form провалилась за safe-area».
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
              ),
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
                // Photo picker (camera / gallery). На web — URL-fallback ниже.
                Semantics(
                  button: true,
                  label: s.addRecipePhotoPicker,
                  child: _PhotoPicker(
                    picked: _pickedPhoto,
                    loading: _compressing,
                    errorText:
                        (_photoTouched &&
                            _pickedPhoto == null &&
                            !_allowUrlFallback)
                        ? s.addRecipePhotoRequired
                        : null,
                    onTap: _compressing ? null : _showPhotoSourceSheet,
                    onClear: _pickedPhoto == null ? null : _clearPickedPhoto,
                  ),
                ),
                if (_allowUrlFallback) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _photo,
                    decoration: InputDecoration(labelText: s.addRecipePhoto),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                  ),
                ],
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

/// Одна строка ингредиента: `name | qty | unit | +/−`.
///
/// Раскладка подобрана так, чтобы длинные локализации
/// (немецкий, курдский) не переполнялись. Поля без `labelText`
/// (плавающий лейбл съедал место и обрезался троеточием на
/// узких полях qty/unit) — вместо этого названия идут мелким
/// шрифтом подписью под полем (`helperText`). Доли:
///   * `name` — flex 5 (занимает половину).
///   * `qty` — flex 2 (`keyboardType: numberWithOptions(decimal: true)`).
///   * `unit` — flex 3.
class _IngredientRowField extends StatelessWidget {
  const _IngredientRowField({
    required this.row,
    required this.showRemove,
    required this.onAdd,
    required this.onRemove,
  });

  final _IngredientRow row;
  final bool showRemove;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Подпись под полем — мельче дефолтного helperStyle (~12 sp),
    // чтобы caption-метка не отбирала визуального веса у самого
    // ввода и спокойно ложилась в две строки на длинных локалях.
    const helperStyle = TextStyle(
      fontSize: 10,
      height: 1.2,
      color: AppColors.textSecondary,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 10,
          child: TextFormField(
            controller: row.name,
            decoration: InputDecoration(
              hintText: s.addRecipeIngredientNameHint,
              helperText: s.addRecipeIngredientName,
              helperMaxLines: 2,
              helperStyle: helperStyle,
              isDense: true,
            ),
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Qty и unit равны по ширине (flex 3 каждое); placeholder
        // в каждом поле даёт живой пример формата ввода
        // («Сахар» / «100» / «г»). Под qty — короткая подпись
        // «Кол.»; unit — без helperText, контекст и placeholder
        // достаточны.
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: row.qty,
            decoration: InputDecoration(
              hintText: s.addRecipeIngredientQtyHint,
              helperText: s.addRecipeIngredientQtyShort,
              helperMaxLines: 1,
              helperStyle: helperStyle,
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: row.unit,
            decoration: InputDecoration(
              hintText: s.addRecipeIngredientMeasureHint,
              isDense: true,
            ),
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
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

/// Превью / placeholder фотографии рецепта. Размер 160×160 dp.
///
/// Состояния:
///   * empty: dashed-border placeholder с иконкой `add_a_photo`.
///     Тап → `onTap` (показывает bottom-sheet с camera/gallery).
///   * loading: тот же фрейм, по центру `CircularProgressIndicator`.
///   * filled: `Image.file` cover, в правом верхнем углу — `×`,
///     закрывающий выбор. Тап по картинке → `onTap` (replace).
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.picked,
    required this.loading,
    required this.errorText,
    required this.onTap,
    required this.onClear,
  });

  final File? picked;
  final bool loading;
  final String? errorText;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorText != null;
    final borderColor = hasError
        ? theme.colorScheme.error
        : AppColors.primaryDark.withValues(alpha: 0.6);
    final radius = BorderRadius.circular(AppSpacing.md);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: borderColor,
                        width: picked == null ? 1.5 : 1,
                      ),
                      color: picked == null
                          ? theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5)
                          : Colors.black,
                    ),
                    child: ClipRRect(
                      borderRadius: radius,
                      child: picked != null
                          ? Image.file(picked!, fit: BoxFit.cover)
                          : Center(
                              child: Icon(
                                Icons.add_a_photo_outlined,
                                size: 40,
                                color: hasError
                                    ? theme.colorScheme.error
                                    : AppColors.primaryDark,
                              ),
                            ),
                    ),
                  ),
                ),
                if (loading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x66000000),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (picked != null && onClear != null && !loading)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onClear,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
