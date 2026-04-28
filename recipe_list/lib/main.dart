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

/// Показывает splash на `AppDurations.splash`, затем плавно
/// (`AppDurations.fade`) сменяет его на список рецептов.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(AppDurations.splash, () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppDurations.fade,
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _splashDone
          ? const RecipeListLoader(key: ValueKey('home'))
          : const SplashPage(key: ValueKey('splash')),
    );
  }
}
