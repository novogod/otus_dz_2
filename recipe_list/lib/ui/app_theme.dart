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

  /// Тень карточки рецепта. Базовый Figma-токен —
  /// `rgba(149,146,146,0.10)` (alpha 0x1A); для лучшей
  /// читаемости на сером scaffold-фоне затемняем в 1.4×
  /// → alpha 0x24 (≈ 0.14).
  static const Color cardShadow = Color(0x24959292);

  /// Тень нижнего навбара / FAB. Базовый Figma-токен —
  /// `rgba(0,0,0,0.25)` (alpha 0x40); затемнён в 1.4×
  /// → alpha 0x5A (≈ 0.35) для большей выраженности тени.
  static const Color navBarShadow = Color(0x5A000000);
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

/// Метрики экрана, зависящие от `MediaQuery`. Все размеры,
/// которые могут переполняться при длинных переводах
/// (например, на курдском или немецком), задавайте через
/// `AppMetrics.of(context)`, а не магическими числами в виджетах.
///
/// Базовая ширина — 428 (Figma). Все производные значения
/// масштабируются пропорционально текущей ширине экрана и
/// ограничиваются разумным минимумом/максимумом.
class AppMetrics {
  /// Базовая ширина из Figma.
  static const double baseWidth = 428;

  final double screenWidth;
  final double screenHeight;
  final double textScale;
  final EdgeInsets viewPadding;

  const AppMetrics._({
    required this.screenWidth,
    required this.screenHeight,
    required this.textScale,
    required this.viewPadding,
  });

  factory AppMetrics.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    return AppMetrics._(
      screenWidth: mq.size.width,
      screenHeight: mq.size.height,
      textScale: mq.textScaler.scale(1),
      viewPadding: mq.viewPadding,
    );
  }

  /// Коэффициент относительно базовой ширины Figma.
  double get scale => screenWidth / baseWidth;

  /// Боковые поля контента, масштабируемые от ширины экрана.
  double get pagePadding => (screenWidth * 0.0374).clamp(12.0, 24.0);

  /// Доступная ширина контента после боковых полей.
  double get contentWidth => screenWidth - pagePadding * 2;

  /// Ширина колонки «мера» в блоке ингредиентов. На базовом
  /// 428-экране даёт ~96px (с запасом vs прежних 89px), на узких
  /// экранах сжимается, на широких — увеличивается, чтобы курдские
  /// и немецкие меры не выходили за границу.
  double get measureColumnWidth => (contentWidth * 0.26).clamp(72.0, 140.0);

  /// Размеры иконок (мелкая/средняя/крупная).
  double get iconSm => (screenWidth * 0.0374).clamp(14.0, 20.0);
  double get iconMd => (screenWidth * 0.056).clamp(20.0, 28.0);
  double get iconLg => (screenWidth * 0.075).clamp(28.0, 40.0);
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
      // Material-elevation вместо ручного boxShadow на каждом
      // экране: scrolledUnderElevation срабатывает, когда под
      // AppBar-ом есть прокручиваемый контент, иначе — статичный
      // elevation. shadowColor берём из дизайн-системы
      // (`navBarShadow` × 1.4).
      elevation: 4,
      scrolledUnderElevation: 4,
      shadowColor: AppColors.navBarShadow,
      surfaceTintColor: AppColors.surface,
      centerTitle: true,
      // Заголовок страницы — docs/design_system.md §типографика
      // «Page title» (Roboto 500/24/22 `#000000`). Регистрируем
      // в теме целиком, чтобы экраны не пробрасывали
      // `style:` вручную и брали токен через Theme-канал.
      titleTextStyle: AppTextStyles.pageTitle,
      toolbarTextStyle: AppTextStyles.pageTitle,
    ),
    // Карточки рецептов и любые `Card`-обёртки на форме —
    // получают тень дизайн-системы через Material-elevation.
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: AppColors.surface,
      elevation: 4,
      shadowColor: AppColors.cardShadow,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardAll),
      margin: EdgeInsets.zero,
    ),
    // FAB (плюс на списке рецептов) — выраженная тень,
    // соответствует ручному `AppShadows.navBar` ранее.
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.surface,
      elevation: 6,
      focusElevation: 6,
      hoverElevation: 8,
      highlightElevation: 12,
      shape: CircleBorder(),
    ),
    // BottomNavigationBar (Material 2 API) — тень тёмная,
    // тот же токен `navBarShadow`. Цветовые токены оставляем
    // на уровне виджета (см. `AppBottomNavBar`).
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
    // NavigationBar (Material 3) — на случай миграции.
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.surface,
      shadowColor: AppColors.navBarShadow,
      elevation: 8,
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
    // Поля формы (`AddRecipePage` и т.п.). Согласно
    // `docs/design_system.md` §цвета: фон полей — белый
    // (`surface #FFFFFF`), активные акценты — `primaryDark
    // #165932` (бренд-зелёный достаточно тёмный, чтобы читался
    // на белом). Светло-зелёный `primary #2ECC71` на сером
    // `surfaceMuted #ECECEC` фоне scaffold-а имеет низкий
    // контраст — поэтому inputDecorationTheme заставляет фон
    // полей быть белым и подсвечивает фокус тёмно-зелёным.
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: TextStyle(color: AppColors.textSecondary),
      floatingLabelStyle: TextStyle(
        color: AppColors.primaryDark,
        fontWeight: FontWeight.w500,
      ),
      helperStyle: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        height: 1.35,
      ),
      helperMaxLines: 3,
      hintStyle: AppTextStyles.inputHint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.input)),
        borderSide: BorderSide(color: AppColors.textInactive),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.input)),
        borderSide: BorderSide(color: AppColors.textInactive),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.input)),
        borderSide: BorderSide(color: AppColors.primaryDark, width: 2),
      ),
    ),
  );
}
