import 'package:flutter/material.dart';

/// Поддерживаемые языки UI. Сейчас всего два — переключаются FAB-ом
/// в верхнем левом углу.
enum AppLang { ru, en }

/// Глобальное хранилище текущего языка. Простейшее решение: один
/// `ValueNotifier`, на который подписываемся через
/// [AppLangScope]. В дальнейшем заменяется на `Riverpod`/`Bloc`,
/// либо на стандартный `Localizations` из Flutter.
final ValueNotifier<AppLang> appLang = ValueNotifier<AppLang>(AppLang.ru);

/// Переключает текущий язык на следующий из [AppLang].
void cycleAppLang() {
  final next =
      AppLang.values[(appLang.value.index + 1) % AppLang.values.length];
  appLang.value = next;
}

/// Подписывает поддерево на изменение `appLang` — после каждого тапа FAB
/// весь UI ниже [AppLangScope] перестроится.
class AppLangScope extends StatelessWidget {
  final Widget child;

  const AppLangScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: appLang,
      builder: (context, _, _) => child,
    );
  }
}

/// Жёстко зашитые переводы. Список ключей — все строки, которые сейчас
/// показываются пользователю в `recipe_list`. При расширении словарь
/// растёт; см. [docs/i18n_proposal.md] про живые переводы через Gemini.
@immutable
class S {
  const S._(this.lang);

  final AppLang lang;

  static S of(BuildContext context) {
    // Подписываемся явно — этого достаточно, потому что вверху дерева
    // всегда стоит [AppLangScope].
    return S._(appLang.value);
  }

  String _t(String ru, String en) => lang == AppLang.ru ? ru : en;

  // Bottom navbar.
  String get tabRecipes => _t('Рецепты', 'Recipes');
  String get tabFridge => _t('Холодильник', 'Fridge');
  String get tabFavorites => _t('Избранное', 'Favorites');
  String get tabProfile => _t('Профиль', 'Profile');
  String get tabComingSoon =>
      _t('Этот раздел пока в разработке', 'This section is coming soon');

  // List page.
  String get emptyList => _t('Нет рецептов', 'No recipes');
  String loadError(Object error) =>
      _t('Ошибка загрузки: $error', 'Failed to load: $error');
  String get retry => _t('Повторить', 'Retry');

  // Details page.
  String get recipeTitle => _t('Рецепт', 'Recipe');
  String get ingredientsHeader => _t('Ингредиенты', 'Ingredients');
  String get instructionsHeader => _t('Инструкция', 'Instructions');
  String get youtube => _t('YouTube', 'YouTube');
  String get source => _t('Источник', 'Source');

  // Card ingredient count.
  String ingredientCount(int n) {
    if (lang == AppLang.en) return n == 1 ? '1 ingredient' : '$n ingredients';
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return '$n ингредиент';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return '$n ингредиента';
    }
    return '$n ингредиентов';
  }

  // FAB label.
  String get langLabel => lang == AppLang.ru ? 'RU' : 'EN';
}
