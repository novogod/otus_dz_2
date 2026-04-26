import '../models/recipe.dart';

/// Менеджер источника данных для рецептов.
///
/// На текущем этапе возвращает константный список. В дальнейшем будет заменён
/// на HTTP-клиент к foodapi — поэтому метод [getRecipes] уже сейчас
/// асинхронный (`Future<List<Recipe>>`).
class RecipeManager {
  const RecipeManager();

  static const List<Recipe> _recipes = [
    Recipe(
      id: 1,
      name: 'Лазанья с грибами и сыром',
      duration: 60,
      photo:
          'https://images.unsplash.com/photo-1574894709920-11b28e7367e3?w=600',
      description:
          'Классическая итальянская лазанья с шампиньонами, сыром моцарелла '
          'и соусом бешамель. Запекается до золотистой корочки.',
    ),
    Recipe(
      id: 2,
      name: 'Тефтели по-шведски',
      duration: 45,
      photo:
          'https://images.unsplash.com/photo-1529042410759-befb1204b468?w=600',
      description:
          'Нежные тефтели из говядины и свинины в сливочном соусе, '
          'подаются с картофельным пюре и брусничным джемом.',
    ),
    Recipe(
      id: 3,
      name: 'Пирог с сезонными фруктами',
      duration: 90,
      photo: 'https://images.unsplash.com/photo-1464195244916-405fa0a82545?w=600',
      description:
          'Воздушный песочный пирог с яблоками, грушами и корицей. '
          'Идеальный десерт к чаю.',
    ),
    Recipe(
      id: 4,
      name: 'Бринбейк с черникой',
      duration: 50,
      photo:
          'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=600',
      description:
          'Запечённый творожный десерт со свежей черникой и ванильным '
          'соусом. Лёгкий и полезный.',
    ),
    Recipe(
      id: 5,
      name: 'Тыквенный суп-пюре',
      duration: 30,
      photo:
          'https://images.unsplash.com/photo-1476718406336-bb5a9690ee2a?w=600',
      description:
          'Бархатистый суп из запечённой тыквы со сливками, чесноком '
          'и тыквенными семечками для подачи.',
    ),
    Recipe(
      id: 6,
      name: 'Овощной киш с козьим сыром',
      duration: 75,
      photo:
          'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600',
      description:
          'Открытый французский пирог на песочном тесте с помидорами, '
          'цуккини и козьим сыром.',
    ),
  ];

  Future<List<Recipe>> getRecipes() async {
    // Имитация задержки сети (минимальная) для консистентности с будущим API.
    return Future.value(List.unmodifiable(_recipes));
  }
}
