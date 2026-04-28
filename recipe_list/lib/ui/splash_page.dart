import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Splash-экран по дизайну Figma (frame `135:691`):
/// градиент `#2ECC71 → #165932` (top → bottom), логотип «OTUS / FOOD»
/// крупным начертанием Roboto Black 95.
///
/// Используется как контент для перехода в основное приложение —
/// сам по себе не управляет навигацией, длительностью и фейдом
/// занимается родитель (см. `main.dart`).
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: kSplashGradient),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'OTUS\nFOOD',
                textAlign: TextAlign.center,
                style: AppTextStyles.splashLogo,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
