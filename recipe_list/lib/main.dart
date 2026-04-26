import 'package:flutter/material.dart';

import 'data/recipe_manager.dart';
import 'models/recipe.dart';
import 'ui/recipe_list_page.dart';

void main() {
  runApp(const RecipeApp());
}

/// Корневой виджет приложения.
///
/// Создаёт [MaterialApp] с темой по дизайну Otus Food App и в качестве
/// домашнего экрана подаёт [RecipeListPage], получая список рецептов из
/// [RecipeManager].
class RecipeApp extends StatelessWidget {
  static const Color primaryGreen = Color(0xFF2ECC71);
  static const Color darkGreen = Color(0xFF165932);
  static const Color subtitleGrey = Color(0xFF797676);
  static const Color background = Color(0xFFFFFFFF);

  const RecipeApp({super.key, this.manager = const RecipeManager()});

  final RecipeManager manager;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Otus Food',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          primary: primaryGreen,
          secondary: darkGreen,
          surface: background,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: darkGreen,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: darkGreen,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        textTheme: const TextTheme(
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: darkGreen,
          ),
          bodyMedium: TextStyle(fontSize: 14, color: subtitleGrey),
        ),
      ),
      home: _RecipeListLoader(manager: manager),
    );
  }
}

/// Загружает список рецептов через [RecipeManager] и подаёт его в
/// [RecipeListPage].
class _RecipeListLoader extends StatelessWidget {
  final RecipeManager manager;

  const _RecipeListLoader({required this.manager});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Recipe>>(
      future: manager.getRecipes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Ошибка загрузки: ${snapshot.error}')),
          );
        }
        return RecipeListPage(recipes: snapshot.data ?? const []);
      },
    );
  }
}
