import 'package:flutter/foundation.dart';

import '../models/recipe.dart';

/// Глобальная шина «только что создан рецепт». Эмитится из
/// [AddRecipePage] после успешного `POST /recipes` и записи
/// в локальный кэш. Слушатели:
///
/// * [RecipeListPage] — добавляет карточку в начало `_displayed`,
///   чтобы новый рецепт был виден на главной ленте независимо от
///   того, с какой страницы (главная / избранное) был открыт
///   AddRecipePage.
/// * [FavoritesPage] получает обновление неявно — рецепт сразу
///   помечается избранным, и `FavoritesStore.idsForLang` дёргает
///   ребилд списка.
///
/// Используем `ValueNotifier<Recipe?>` вместо `Stream`, чтобы не
/// тащить `dart:async`-подписки в виджеты — `ValueListenableBuilder`
/// и `addListener` уже привычны в проекте.
///
/// Слушатель должен сравнивать `recipe.id` с последним обработанным,
/// чтобы не реагировать на тот же event дважды (значение в
/// notifier-е сохраняется до следующей записи).
final ValueNotifier<Recipe?> newRecipeCreatedNotifier = ValueNotifier<Recipe?>(
  null,
);
