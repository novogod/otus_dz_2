import 'package:flutter/material.dart';

import '../i18n.dart';
import 'app_theme.dart';

/// Кнопка «обновить ленту» для размещения в `AppBar.actions` рядом
/// с [LangIconButton]. Совпадает по форме (40×40 круг) и системе
/// токенов с языковой кнопкой, но играет роль вторичного действия —
/// поэтому идёт на `surfaceMuted`-фоне с тёмно-зелёной иконкой
/// `primaryDark`. Тап увеличивает [reloadFeedTicker], на который
/// слушает `RecipeListLoader` и заново перебирает случайные
/// категории через mahallem-API (см. docs/categories.md и
/// docs/translation-buffer.md).
class ReloadIconButton extends StatelessWidget {
  const ReloadIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      child: Semantics(
        button: true,
        label: s.reloadFeed,
        child: Tooltip(
          message: s.reloadFeed,
          child: Material(
            color: AppColors.surfaceMuted,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: requestFeedReload,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.refresh,
                  size: 22,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
