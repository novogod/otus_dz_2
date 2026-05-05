import 'package:flutter/material.dart';

import '../i18n.dart';
import 'app_theme.dart';
import 'lang_icon_button.dart';
import 'reload_icon_button.dart';
import 'web_share/web_action_buttons.dart';

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

  /// Если `true` — кнопки переключения языка и `reload` отрисовываются
  /// faded (Opacity 0.38) и не реагируют на тапы (IgnorePointer). Нужно
  /// для табов, на которых смена языка/полная перезагрузка ленты
  /// бессмысленна — в первую очередь страница избранного (todo/15,
  /// chunk D).
  final bool disableLangAndReload;

  /// Если `true` — actions (reload/lang/share) полностью скрыты,
  /// освобождая горизонтальное пространство под `title`. Используется
  /// `SearchAppBar`, когда поле поиска получает фокус — пользователь
  /// печатает запрос, прочие кнопки в этот момент не нужны и только
  /// сжимают place для текста.
  final bool hideActions;

  const AppPageBar({
    super.key,
    required this.title,
    this.centerTitle = true,
    this.titleSpacing = NavigationToolbar.kMiddleSpacing,
    this.onBack,
    this.showReload = false,
    this.disableLangAndReload = false,
    this.hideActions = false,
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
        titleSpacing: titleSpacing,
        centerTitle: centerTitle,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: Center(
            child: Semantics(
              button: true,
              label: s.back,
              child: Tooltip(
                message: s.back,
                child: Material(
                  color: AppColors.surfaceMuted,
                  shape: const CircleBorder(
                    side: BorderSide(width: 1, color: Colors.black),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onBack ?? () => Navigator.of(context).maybePop(),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.chevron_left,
                        size: 22,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        leadingWidth: 40 + AppSpacing.sm + AppSpacing.sm,
        title: title,
        actions: hideActions
            ? const <Widget>[SizedBox(width: _trailingGap)]
            : [
                if (disableLangAndReload)
                  IgnorePointer(
                    child: Opacity(
                      opacity: 0.38,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showReload) const WebActionButtons(),
                          if (showReload) const ReloadIconButton(),
                          if (showReload) const SizedBox(width: AppSpacing.sm),
                          const LangIconButton(),
                          const SizedBox(width: _trailingGap),
                        ],
                      ),
                    ),
                  )
                else ...[
                  if (showReload) const WebActionButtons(),
                  if (showReload) const ReloadIconButton(),
                  if (showReload) const SizedBox(width: AppSpacing.sm),
                  const LangIconButton(),
                  const SizedBox(width: _trailingGap),
                ],
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
