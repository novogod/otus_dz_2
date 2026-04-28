import 'package:flutter/material.dart';

import 'ui/app_theme.dart';
import 'ui/recipe_list_loader.dart';
import 'ui/splash_page.dart';

void main() => runApp(const RecipeApp());

/// Корневой виджет приложения. Точка входа максимально короткая —
/// тема, splash и загрузка данных вынесены в отдельные виджеты.
class RecipeApp extends StatelessWidget {
  const RecipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Otus Food',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _AppRoot(),
    );
  }
}

/// Показывает splash на `AppDurations.splash` (Figma `AFTER_TIMEOUT` 1.5с),
/// затем выполняет переход на список рецептов с `MOVE_IN`/`TOP`,
/// `EASE_IN_AND_OUT`, `0.7с` (Figma frame `135:691` → `102:3`).
///
/// MOVE_IN / TOP в Figma — это «новый экран въезжает сверху, наплывая
/// поверх предыдущего». Splash при этом остаётся на месте.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.splashTransition,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1), // въезд сверху
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

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
          // перехода MOVE_IN, его лишь перекрывает сверху список.
          const Positioned.fill(child: SplashPage()),
          // Список «въезжает» сверху, заслоняя splash.
          Positioned.fill(
            child: SlideTransition(
              position: _slide,
              child: const RecipeListLoader(),
            ),
          ),
        ],
      ),
    );
  }
}
