import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/data/api/meal_db_client.dart';
import 'package:recipe_list/data/api/recipe_api.dart';
import 'package:recipe_list/data/api/recipe_api_config.dart';
import 'package:recipe_list/i18n.dart';
class _StubAdapter implements HttpClientAdapter {
  final Map<String, Object?> responses;
  final List<RequestOptions> calls = [];
  _StubAdapter(this.responses);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    final body = responses[options.path] ?? const {'recipes': []};
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
  RecipeApi makeMahallemApi(_StubAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.httpClientAdapter = adapter;
    return RecipeApi(
      client: MealDbClient(dio: dio, backend: RecipeBackend.mahallem),
    );
  }

  test('fetchPage parses recipes/nextOffset/total and forwards lang', () async {
    final adapter = _StubAdapter({
      '/page': {
        'recipes': [
          {
            'idMeal': '1',
            'strMeal': 'A',
            'strCategory': 'Beef',
            'strArea': 'British',
            'strInstructions': 'Cook.',
            'strMealThumb': 'https://x/1.jpg',
          },
          {
            'idMeal': '2',
            'strMeal': 'B',
            'strCategory': 'Beef',
            'strArea': 'British',
            'strInstructions': 'Cook.',
            'strMealThumb': 'https://x/2.jpg',
          },
        ],
        'nextOffset': 2,
        'total': 5,
      },
    });
    final api = makeMahallemApi(adapter);
    final page = await api.fetchPage(lang: AppLang.ru, limit: 2);
    expect(page.recipes, hasLength(2));
    expect(page.recipes.first.name, 'A');
    expect(page.nextOffset, 2);
    expect(page.total, 5);
    expect(adapter.calls.single.path, '/page');
    expect(adapter.calls.single.queryParameters, {
      'offset': '0',
      'limit': '2',
      'lang': 'ru',
    });
  });

  test('fetchPage returns empty page when backend is mealDb', () async {
    final adapter = _StubAdapter(const {});
    final dio = Dio(BaseOptions(baseUrl: MealDbClient.baseUrl));
    dio.httpClientAdapter = adapter;
    final api = RecipeApi(
      client: MealDbClient(dio: dio, backend: RecipeBackend.mealDb),
    );
    final page = await api.fetchPage(lang: AppLang.en);
    expect(page.recipes, isEmpty);
    expect(page.nextOffset, isNull);
    expect(adapter.calls, isEmpty);
  });

  test('fetchPage tolerates missing nextOffset/total', () async {
    final adapter = _StubAdapter({
      '/page': {
        'recipes': [
          {
            'idMeal': '7',
            'strMeal': 'X',
            'strCategory': 'Pasta',
            'strArea': 'Italian',
            'strInstructions': '',
            'strMealThumb': '',
          },
        ],
      },
    });
    final api = makeMahallemApi(adapter);
    final page = await api.fetchPage(lang: AppLang.en);
    expect(page.recipes, hasLength(1));
    expect(page.nextOffset, isNull);
    expect(page.total, 1);
  });
}
