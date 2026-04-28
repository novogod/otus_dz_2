import 'package:flutter/material.dart';

/// Дизайн-система Otus Food App, выгруженная из Figma
/// (file `alUTMeT3w9XlbNf3orwyFA`). Подробности и ссылки на узлы —
/// в `docs/design_system.md`.
///
/// Используйте `AppColors`, `AppTextStyles`, `AppRadii`, `AppShadows`,
/// `AppSpacing` и `AppTheme.light` во всех экранах вместо магических
/// чисел и цветовых литералов.

/// Цветовые токены.
class AppColors {
  AppColors._();

  /// Бренд-зелёный. Акценты, активный таб, длительность рецепта.
  static const Color primary = Color(0xFF2ECC71);

  /// Тёмный бренд-зелёный. Кнопка «Войти», нижний край градиента splash.
  static const Color primaryDark = Color(0xFF165932);

  /// Тёмно-зелёный из палитры Figma (резерв).
  static const Color mainGreenDeep = Color(0xFF2D490C);

  /// Лаймовый акцент из палитры Figma (резерв).
  static const Color accentLime = Color(0xFF66A71A);

  /// Фон списка рецептов и нейтральных экранов.
  static const Color surfaceMuted = Color(0xFFECECEC);

  /// Фон карточек, навбара, инпутов.
  static const Color surface = Color(0xFFFFFFFF);

  /// Основной текст (название рецепта, заголовки).
  static const Color textPrimary = Color(0xFF000000);

  /// Вторичный текст (количества ингредиентов, обводка ингредиент-блока,
  /// тело неактивного шага). Figma `#797676`.
  static const Color textSecondary = Color(0xFF797676);

  /// Неактивный текст / плейсхолдеры / неактивный таб навбара.
  static const Color textInactive = Color(0xFFC2C2C2);

  /// Тень карточки рецепта: rgba(149,146,146,0.10).
  static const Color cardShadow = Color(0x1A959292);

  /// Тень нижнего навбара: rgba(0,0,0,0.25).
  static const Color navBarShadow = Color(0x40000000);
}

/// Радиусы скруглений.
class AppRadii {
  AppRadii._();

  /// Карточка рецепта и фото внутри неё.
  static const double card = 5;

  /// Поля ввода на login-экране.
  static const double input = 10;

  /// Основная кнопка login-экрана.
  static const double button = 25;

  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius cardLeft = BorderRadius.only(
    topLeft: Radius.circular(card),
    bottomLeft: Radius.circular(card),
  );
}

/// Базовые отступы.
class AppSpacing {
  AppSpacing._();

  static const double unit = 4;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Боковые поля контента — `(428 - 396) / 2`.
  static const double pagePadding = 16;
}

/// Тени.
class AppShadows {
  AppShadows._();

  /// Тень карточки рецепта (Figma: blur 4, offset 0/4, alpha 0.10).
  static const List<BoxShadow> card = [
    BoxShadow(color: AppColors.cardShadow, offset: Offset(0, 4), blurRadius: 4),
  ];

  /// Тень нижнего навбара (Figma: blur 8, offset 0/0, alpha 0.25).
  static const List<BoxShadow> navBar = [
    BoxShadow(
      color: AppColors.navBarShadow,
      offset: Offset(0, 0),
      blurRadius: 8,
    ),
  ];
}

/// Текстовые стили (Roboto, числа из Figma).
class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Roboto';

  /// Splash-логотип «OTUS FOOD».
  static const TextStyle splashLogo = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w900,
    fontSize: 95,
    height: 82 / 95,
    color: AppColors.textPrimary,
  );

  /// Заголовок «Otus.Food» на login-экране.
  static const TextStyle brandTitle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 30,
    height: 23 / 30,
    color: AppColors.surface,
  );

  /// Название рецепта в карточке списка.
  static const TextStyle recipeTitle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 22,
    height: 1.0,
    color: AppColors.textPrimary,
  );

  /// Заголовок страницы рецепта (Figma 24/22 #000).
  static const TextStyle pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 24,
    height: 22 / 24,
    color: AppColors.textPrimary,
  );

  /// Подзаголовок секции на странице рецепта («Ингредиенты»,
  /// «Шаги приготовления»). Figma 16/23 #165932.
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    height: 23 / 16,
    color: AppColors.primaryDark,
  );

  /// Название ингредиента в блоке ингредиентов.
  static const TextStyle ingredientName = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 27 / 14,
    color: AppColors.textPrimary,
  );

  /// Количество в блоке ингредиентов.
  static const TextStyle ingredientQty = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 27 / 13,
    color: AppColors.textSecondary,
  );

  /// Длительность рецепта в карточке.
  static const TextStyle recipeMeta = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 18.75 / 16,
    color: AppColors.primary,
  );

  /// Подпись на основной кнопке.
  static const TextStyle buttonLabel = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    height: 23 / 16,
    color: AppColors.surface,
  );

  /// Плейсхолдеры и подсказки в инпутах.
  static const TextStyle inputHint = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 23 / 16,
    color: AppColors.textInactive,
  );

  /// Вторичные ссылки.
  static const TextStyle secondaryLink = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 23 / 14,
    color: AppColors.surface,
  );

  /// Подписи табов в нижнем навбаре.
  static const TextStyle tabLabel = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 10,
    height: 23 / 10,
  );
}

/// Длительности анимаций.
class AppDurations {
  AppDurations._();

  /// Время показа splash до начала перехода. Из Figma
  /// (frame `135:691`, interaction `AFTER_TIMEOUT` = 1.5с).
  static const Duration splash = Duration(milliseconds: 1500);

  /// Длительность перехода splash → список (Figma transition
  /// `MOVE_IN`/`TOP`, duration `0.7с`, easing `EASE_IN_AND_OUT`).
  static const Duration splashTransition = Duration(milliseconds: 700);

  /// Общий fade для Material-переходов.
  static const Duration fade = Duration(milliseconds: 600);

  static const Duration short = Duration(milliseconds: 200);
}

/// Градиент splash-экрана. Выгружен из Figma (frame `135:691`,
/// fill `GRADIENT_LINEAR`).
///
/// Направление: верх-правый угол → низ (со смещением влево).
/// Цвета: `#2ECC71` (stop на 0.188) → `#165932` (stop на 1.0).
const Gradient kSplashGradient = LinearGradient(
  // Figma gradientHandlePositions[0] = (0.7266, 0.2068)
  // -> Alignment(2*x-1, 2*y-1) = (0.4533, -0.5864)
  begin: Alignment(0.4533, -0.5864),
  // Figma gradientHandlePositions[1] = (0.5643, 1.0000)
  // -> Alignment(0.1285, 1.0)
  end: Alignment(0.1285, 1.0),
  colors: [AppColors.primary, AppColors.primaryDark],
  stops: [0.188, 1.0],
);

/// Тема приложения.
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: AppTextStyles.fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.primaryDark,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.surfaceMuted,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
    ),
    textTheme: const TextTheme(
      titleLarge: AppTextStyles.brandTitle,
      titleMedium: AppTextStyles.recipeTitle,
      bodyLarge: AppTextStyles.recipeMeta,
      bodyMedium: AppTextStyles.inputHint,
      labelLarge: AppTextStyles.buttonLabel,
      labelSmall: AppTextStyles.tabLabel,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
    ),
  );
}
