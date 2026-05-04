import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'recipe_list_loader.dart';
import 'splash_page.dart';

/// Связка «splash → лента рецептов» (бывший `_AppRoot` из `main.dart`).
///
/// Показывает [SplashPage] на `AppDurations.splash` (Figma
/// `AFTER_TIMEOUT` 1.5с), затем выполняет переход на список с
/// `MOVE_IN`/`BOTTOM`, `EASE_IN_AND_OUT`, `0.7с` (Figma frame
/// `135:691` → `102:3`).
///
/// Splash при этом остаётся на месте — список «въезжает» сверху
/// и заслоняет его.
///
/// На чанке A рефакторинга (`docs/go-router-shell-refactor.md`)
/// этот виджет стал телом единственной реальной ветки `recipes`
/// внутри `StatefulShellRoute.indexedStack`. Глобальный ключ
/// [splashAndRecipesKey] остаётся механизмом перезапуска
/// splash-последовательности (см. `restartApp` в `main.dart`).
class SplashAndRecipes extends StatefulWidget {
  const SplashAndRecipes({super.key});

  @override
  State<SplashAndRecipes> createState() => SplashAndRecipesState();
}

class SplashAndRecipesState extends State<SplashAndRecipes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  /// Ключ для `RecipeListLoader`, чтобы при перезапуске
  /// последовательности (см. [restart]) Flutter создал новый
  /// State и заново прогнал весь load-pipeline.
  Key _loaderKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.splashTransition,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 1), // въезд снизу (Figma MOVE_IN/BOTTOM)
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future<void>.delayed(AppDurations.splash, () {
      if (mounted) _controller.forward();
    });
  }

  /// Перезапускает splash-последовательность. Сбрасывает
  /// SlideTransition в начало, пересоздаёт [RecipeListLoader]
  /// через новый ключ и снова ждёт `AppDurations.splash`,
  /// после чего «въезжает» поверх splash. Используется
  /// «back»-кнопкой на списке (см. `SearchAppBar.onBack`).
  void restart() {
    if (!mounted) return;
    _controller.reset();
    setState(() {
      _loaderKey = UniqueKey();
    });
    Future<void>.delayed(AppDurations.splash, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Material нужен, чтобы Text внутри splash/list получил
    // DefaultTextStyle темы вместо debug-fallback (жёлтое
    // подчёркивание, неверный вес).
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Сплеш всегда внизу стека — он не двигается во время
          // перехода MOVE_IN, его лишь перекрывает поверх список.
          const Positioned.fill(child: SplashPage()),
          // Список «въезжает» снизу, заслоняя splash. Переключатель
          // языка живёт в его AppBar — пока splash, кнопки нет.
          Positioned.fill(
            child: SlideTransition(
              position: _slide,
              child: RecipeListLoader(key: _loaderKey),
            ),
          ),
        ],
      ),
    );
  }
}
