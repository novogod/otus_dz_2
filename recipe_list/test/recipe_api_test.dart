import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/data/api/meal_db_client.dart';
import 'package:recipe_list/data/api/recipe_api.dart';

/// Подменяет HTTP-транспорт Dio: возвращает заранее заданные ответы по
/// пути запроса. Достаточно для юнит-тестов парсинга `RecipeApi`.
class _StubAdapter implements HttpClientAdapter {
  final Map<String, Object?> responses;

  _StubAdapter(this.responses);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = responses[options.path] ?? const {'meals': null};
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }
}

void main() {
  RecipeApi makeApi(Map<String, Object?> responses) {
    final dio = Dio(BaseOptions(baseUrl: MealDbClient.baseUrl));
    dio.httpClientAdapter = _StubAdapter(responses);
    return RecipeApi(client: MealDbClient(dio: dio));
  }

  test('searchByName parses full meal payload', () async {
    final api = makeApi({
      '/search.php': {
        'meals': [
          {
            'idMeal': '52772',
            'strMeal': 'Teriyaki Chicken Casserole',
            'strCategory': 'Chicken',
            'strArea': 'Japanese',
            'strMealThumb': 'https://example.com/p.jpg',
            'strInstructions': '...',
            'strTags': 'Meat,Casserole',
            'strYoutube': 'https://yt.com/x',
            'strSource': null,
            'strIngredient1': 'soy sauce',
            'strMeasure1': '3/4 cup',
          },
        ],
      },
    });

    final list = await api.searchByName(query: 'a');
    expect(list, hasLength(1));
    expect(list.first.name, 'Teriyaki Chicken Casserole');
    expect(list.first.category, 'Chicken');
    expect(list.first.tags, ['Meat', 'Casserole']);
    expect(list.first.ingredients, hasLength(1));
  });

  test('filterByCategory parses lite payload', () async {
    final api = makeApi({
      '/filter.php': {
        'meals': [
          {
            'idMeal': '1',
            'strMeal': 'A',
            'strMealThumb': 'https://example.com/a.jpg',
          },
          {
            'idMeal': '2',
            'strMeal': 'B',
            'strMealThumb': 'https://example.com/b.jpg',
          },
        ],
      },
    });

    final list = await api.filterByCategory('Seafood');
    expect(list, hasLength(2));
    expect(list.first.isLite, isTrue);
    expect(list.first.name, 'A');
  });

  test('lookup returns null for empty meals', () async {
    final api = makeApi({
      '/lookup.php': {'meals': null},
    });
    expect(await api.lookup(0), isNull);
  });
}
