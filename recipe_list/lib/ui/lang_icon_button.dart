import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../i18n.dart';
import 'app_theme.dart';

/// Кнопка переключения языка для размещения в `AppBar.actions`.
/// Состоит из двух элементов: SVG-флаг текущего языка (24×16) и
/// круг 40×40 с двухбуквенной подписью («RU/EN/ES/…»). Тап
/// циклически переключает [appLang] по всему списку поддерживаемых
/// языков mahallem_ist (см. [AppLang]).
class LangIconButton extends StatelessWidget {
  const LangIconButton({super.key});

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
                // Флаг слева от кнопки. Круглая 40×40-обрезка SVG
                // под cover, чтобы заполнить тот же круг, что и
                // соседняя кнопка-«RU/EN/…» — флаг и кнопка
                // зрительно выровнены как пара одинаковых
                // кружков.
                ClipOval(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: SvgPicture.asset(
                      current.flagAsset,
                      fit: BoxFit.cover,
                      semanticsLabel: s.flagOf(current.label),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: cycleAppLang,
                    child: SizedBox(
                      width: 40,
                      height: 40,
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
