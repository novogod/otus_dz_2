import 'package:flutter/material.dart';

import '../i18n.dart';
import 'app_theme.dart';

/// Круглая кнопка-«FAB» в левом верхнем углу для переключения языка
/// UI между RU и EN. Цвет фона — `AppColors.primary` (`#2ECC71`),
/// текст — белый. Размер 56×56 dp как у штатного `FloatingActionButton`
/// (см. `docs/design_system.md` §9b — основной FAB на главном экране).
class LangFab extends StatelessWidget {
  const LangFab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Semantics(
      button: true,
      label: 'Switch language to ${s.langLabel == 'RU' ? 'EN' : 'RU'}',
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: AppColors.navBarShadow,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: cycleAppLang,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Center(
              child: Text(
                s.langLabel,
                style: const TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.surface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
