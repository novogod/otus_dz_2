import 'package:flutter/material.dart';

import '../i18n.dart';
import 'app_theme.dart';

/// Кнопка переключения языка для размещения в `AppBar.actions`.
/// Круг 40×40, фон `AppColors.primary` (`#2ECC71`), текст «RU» / «EN»
/// Roboto 800/14 белым. Заменяет ранний `LangFab` (см. ветку
/// `feat/lang-fab`); живёт только внутри AppBar — на splash экране
/// AppBar ещё нет, поэтому кнопка появляется ровно после анимации
/// перехода с splash на список.
class LangIconButton extends StatelessWidget {
  const LangIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Semantics(
        button: true,
        label: 'Switch language to ${s.langLabel == 'RU' ? 'EN' : 'RU'}',
        child: Material(
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
                  s.langLabel,
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
      ),
    );
  }
}
