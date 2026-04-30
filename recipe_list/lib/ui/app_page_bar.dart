import 'package:flutter/material.dart';

import '../i18n.dart';
import 'app_theme.dart';
import 'lang_icon_button.dart';
import 'reload_icon_button.dart';

/// Унифицированный AppBar для всех экранов приложения. Реализует
/// общий дизайн из `docs/design_system.md`: белый фон, тёмно-зелёный
/// foreground, без elevation, кнопка «назад» слева и переключатель
/// языка справа c фиксированным «двойным» отступом от края экрана.
///
/// Конкретные экраны передают свой [title] (например, поле поиска
/// для ленты или подпись «Рецепт» для деталей) — всё остальное в
/// шапке одинаковое и живёт в одном месте, чтобы любые правки
/// дизайна (отступы, цвета, кнопки) автоматически применялись ко
/// всем экранам.
class AppPageBar extends StatelessWidget implements PreferredSizeWidget {
  /// Виджет, который рендерится в роли [AppBar.title]. Может быть
  /// `Text` (детали) или поисковое поле (лента).
  final Widget title;

  /// Если `true` — заголовок центрируется (детали). Для поиска
  /// заголовок занимает всю строку и центрировать его не нужно.
  final bool centerTitle;

  /// Сжимать ли горизонтальный slot под `title`. У поискового поля
  /// уже есть свой `FractionallySizedBox` — там нужен `0`. У
  /// текстового заголовка — стандартное `NavigationToolbar.kMiddleSpacing`.
  final double titleSpacing;

  /// Кастомный обработчик «назад». Когда `null`, используем
  /// `Navigator.maybePop`.
  final VoidCallback? onBack;

  /// Показывать ли кнопку «обновить ленту» слева от переключателя
  /// языка. По умолчанию `false` — экраны деталей и т.п. её не
  /// показывают; список рецептов включает её явно. См.
  /// docs/categories.md и docs/translation-buffer.md.
  final bool showReload;

  const AppPageBar({
    super.key,
    required this.title,
    this.centerTitle = true,
    this.titleSpacing = NavigationToolbar.kMiddleSpacing,
    this.onBack,
    this.showReload = false,
  });

  /// Удвоенный отступ от кнопки языка до правого края экрана.
  /// Внутри [LangIconButton] есть собственный horizontal-padding
  /// (`AppSpacing.sm`), плюс этот SizedBox — итого 8 + 24 = 32 px,
  /// то есть ровно вдвое больше «дефолтного» 16 px.
  static const double _trailingGap = AppSpacing.xl;

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + _kReloadProgressHeight);

  /// Высота полоски `LinearProgressIndicator` под шапкой. См.
  /// todo/03 и docs/categories.md §9.7.
  static const double _kReloadProgressHeight = 2;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Шапка всегда раскладывается слева-направо, даже на ar/fa/ku.
    // По дизайну back живёт слева, переключатель языка — справа,
    // и при переходе на RTL мы НЕ хотим, чтобы Material зеркалил
    // эти позиции. Текстовое содержимое (заголовки, hint поиска)
    // продолжает определять direction само по своему контенту.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryDark,
        elevation: 0,
        titleSpacing: titleSpacing,
        centerTitle: centerTitle,
        leading: IconButton(
          tooltip: s.back,
          icon: const Icon(Icons.chevron_left, color: AppColors.primaryDark),
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        ),
        title: title,
        actions: [
          if (showReload) const ReloadIconButton(),
          const LangIconButton(),
          const SizedBox(width: _trailingGap),
        ],
        bottom: showReload
            ? const _ReloadProgressBar(height: _kReloadProgressHeight)
            : null,
      ),
    );
  }
}

/// Тонкая полоска прогресса под `AppPageBar`, видимая только пока
/// идёт reload (`reloadingFeed.value == true`). Заменяет
/// full-screen `_LoadingScreen` на лёгкий индикатор, не перекрывая
/// уже отрисованную ленту.
class _ReloadProgressBar extends StatelessWidget
    implements PreferredSizeWidget {
  final double height;
  const _ReloadProgressBar({required this.height});

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: reloadingFeed,
      builder: (context, busy, _) {
        if (!busy) return SizedBox(height: height);
        return SizedBox(
          height: height,
          child: const LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: AppColors.surfaceMuted,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
          ),
        );
      },
    );
  }
}
