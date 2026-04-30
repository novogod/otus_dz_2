import 'package:flutter/material.dart';

import '../i18n.dart';
import '../models/recipe.dart';
import 'app_page_bar.dart';
import 'app_theme.dart';

/// Виджет AppBar со строкой поиска (`title`), кнопкой «назад» (`leading`)
/// и переключателем языка (`actions`). Всё «обвес» (back, lang, отступы)
/// делегируется общему [AppPageBar] — здесь специфично только поле
/// поиска как `title`.
///
/// Сам список предсказаний (dropdown) не входит в [PreferredSize] —
/// он рендерится в теле страницы, чтобы перекрывать список рецептов
/// и адаптировать высоту под количество совпадений.
class SearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Контроллер поля поиска. Управляется снаружи (страницей), чтобы
  /// можно было программно очистить/заполнить значение.
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onBack;

  /// Показывать ли в шапке кнопку «обновить ленту» рядом с
  /// переключателем языка. На экране списка `true`, на других
  /// сценариях, где AppBar c поиском не используется, — не нужна.
  final bool showReload;

  /// Если `true` — кнопки смены языка / `reload` отрисовываются
  /// faded и не кликаются. Используется на табе избранного
  /// (todo/15, chunk D).
  final bool disableLangAndReload;

  const SearchAppBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    this.onBack,
    this.showReload = false,
    this.disableLangAndReload = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AppPageBar(
      onBack: onBack,
      titleSpacing: 0,
      centerTitle: false,
      showReload: showReload,
      disableLangAndReload: disableLangAndReload,
      title: Center(
        child: FractionallySizedBox(
          widthFactor: 0.85,
          child: _SearchField(
            controller: controller,
            focusNode: focusNode,
            hint: s.searchHint,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 14,
            color: AppColors.textInactive,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AppColors.textSecondary,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: S.of(context).searchClear,
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Выпадающий список предсказаний под поисковой строкой. Размещается
/// в теле страницы поверх ListView рецептов. Прокручивается, если
/// результатов больше, чем умещается в `maxHeight`.
class SearchPredictions extends StatelessWidget {
  final List<Recipe> items;
  final ValueChanged<Recipe> onTap;

  /// Показывать индикатор загрузки вместо списка / "no matches".
  /// Используется, пока летит запрос к API.
  final bool loading;

  const SearchPredictions({
    super.key,
    required this.items,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Material(
      color: AppColors.surface,
      elevation: 4,
      shadowColor: AppColors.navBarShadow,
      // Высоту не ограничиваем — родитель растягивает выпадашку на всю
      // доступную высоту тела экрана через `Positioned.fill`, а
      // `ListView.separated` ниже сам прокручивается.
      child: SizedBox.expand(
        child: loading && items.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : items.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  s.searchNoMatches,
                  style: const TextStyle(
                    fontFamily: AppTextStyles.fontFamily,
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            : Scrollbar(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.surfaceMuted),
                  itemBuilder: (context, index) {
                    final r = items[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.search,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      title: Text(
                        r.name,
                        style: const TextStyle(
                          fontFamily: AppTextStyles.fontFamily,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onTap(r),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
