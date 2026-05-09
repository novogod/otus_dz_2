import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../i18n.dart';
import 'app_theme.dart';

/// Кнопка переключения языка для размещения в `AppBar.actions`.
/// Состоит из двух элементов: SVG-флаг текущего языка и
/// круглая кнопка-переключатель с двухбуквенной подписью («RU/EN/ES/…»).
/// Тап
/// циклически переключает [appLang] по всему списку поддерживаемых
/// языков mahallem_ist (см. [AppLang]).
class LangIconButton extends StatelessWidget {
  const LangIconButton({super.key});

  static const double _kControlSize = 40;

  @override
  Widget build(BuildContext context) {
    // Подписываемся на appLang явно: AppLangScope живёт в `home`,
    // а pushed-маршруты (например, RecipeDetailsPage) находятся
    // ВЫШЕ home в Navigator-стеке и AppLangScope не получают.
    // Без этой подписки тап по кнопке на деталях не перерисовывает
    // флаг/лейбл — пользователь думает, что кнопка «не кликается».
    return ValueListenableBuilder<AppLang>(
      valueListenable: appLang,
      builder: (context, current, _) {
        final s = S.of(context);
        final next =
            AppLang.values[(current.index + 1) % AppLang.values.length];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Semantics(
            button: true,
            label: s.switchLanguageTo(next.label),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Флаг слева от кнопки.
                Container(
                  width: _kControlSize,
                  height: _kControlSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(width: 1, color: Colors.black),
                  ),
                  child: ClipOval(
                    child: SizedBox(
                      width: _kControlSize,
                      height: _kControlSize,
                      child: SvgPicture.asset(
                        current.flagAsset,
                        fit: BoxFit.cover,
                        semanticsLabel: s.flagOf(current.label),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(
                    side: BorderSide(width: 1, color: Colors.black),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(
                      side: BorderSide(width: 1, color: Colors.black),
                    ),
                    onTap: cycleAppLang,
                    child: SizedBox(
                      width: _kControlSize,
                      height: _kControlSize,
                      child: Center(
                        child: Text(
                          next.label,
                          style: const TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.surface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
