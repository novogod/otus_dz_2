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
class ReloadIconButton extends StatefulWidget {
  /// When true, tap fires [requestAppReload] which fans out to feed,
  /// favorites and the source page. Defaults to false (feed-only),
  /// keeping the existing AppBar button untouched. See todo/13.
  final bool global;

  const ReloadIconButton({super.key, this.global = false});

  @override
  State<ReloadIconButton> createState() => _ReloadIconButtonState();
}

class _ReloadIconButtonState extends State<ReloadIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    reloadingFeed.addListener(_syncSpin);
    _syncSpin();
  }

  @override
  void dispose() {
    reloadingFeed.removeListener(_syncSpin);
    _spin.dispose();
    super.dispose();
  }

  void _syncSpin() {
    if (reloadingFeed.value) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
      _spin.value = 0;
    }
  }

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
              onTap: widget.global ? requestAppReload : requestFeedReload,
              child: SizedBox(
                width: 40,
                height: 40,
                child: RotationTransition(
                  turns: _spin,
                  child: const Icon(
                    Icons.refresh,
                    size: 22,
                    color: AppColors.primaryDark,
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
