import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/data/api/meal_db_client.dart';
import 'package:recipe_list/data/api/recipe_api.dart';
import 'package:recipe_list/data/api/recipe_api_config.dart';
import 'package:recipe_list/i18n.dart';
import 'package:recipe_list/models/recipe.dart';

/// Подменяет HTTP-транспорт Dio: возвращает заранее заданные ответы по
/// пути запроса. Достаточно для юнит-тестов парсинга `RecipeApi`.
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
  RecipeApi makeApi(
    Map<String, Object?> responses, {
    RecipeBackend backend = RecipeBackend.mealDb,
    _StubAdapter? capture,
  }) {
    final dio = Dio(BaseOptions(baseUrl: MealDbClient.baseUrl));
    dio.httpClientAdapter = capture ?? _StubAdapter(responses);
    return RecipeApi(
      client: MealDbClient(dio: dio, backend: backend),
    );
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

  group('mahallem backend', () {
    test(
      'searchByName uses /search?q=&lang= and forwards AppLang.ru',
      () async {
        final adapter = _StubAdapter({
          '/search': {'meals': null},
        });
        final api = makeApi(
          const {},
          backend: RecipeBackend.mahallem,
          capture: adapter,
        );
        await api.searchByName(query: 'chick', lang: AppLang.ru);
        expect(adapter.calls, hasLength(1));
        expect(adapter.calls.single.path, '/search');
        expect(adapter.calls.single.queryParameters, {
          'q': 'chick',
          'lang': 'ru',
        });
      },
    );

    test('lookup hits /lookup/:id?lang=', () async {
      final adapter = _StubAdapter({
        '/lookup/52772': {'meals': null},
      });
      final api = makeApi(
        const {},
        backend: RecipeBackend.mahallem,
        capture: adapter,
      );
      await api.lookup(52772, lang: AppLang.en);
      expect(adapter.calls.single.path, '/lookup/52772');
      expect(adapter.calls.single.queryParameters, {'lang': 'en'});
    });

    test('mealDb backend ignores lang and keeps /search.php?s=', () async {
      final adapter = _StubAdapter({
        '/search.php': {'meals': null},
      });
      final api = makeApi(const {}, capture: adapter);
      await api.searchByName(query: 'a', lang: AppLang.ru);
      expect(adapter.calls.single.path, '/search.php');
      expect(adapter.calls.single.queryParameters, {'s': 'a'});
    });

    test(
      'createRecipeWithPhoto sends multipart with meal JSON + photo file',
      () async {
        final adapter = _StubAdapter({
          '': {
            'id': 1000123,
            'meal': {
              'idMeal': '1000123',
              'strMeal': 'Babushka Pirog',
              'strMealThumb':
                  '/storage/v1/object/public/recipe-photos/recipes/1000123/abcdef.jpg',
            },
          },
        });
        final api = makeApi(
          const {},
          backend: RecipeBackend.mahallem,
          capture: adapter,
        );

        final photoBytes = Uint8List.fromList([
          0xFF,
          0xD8,
          0xFF,
          0xE0,
          0x00,
          0x10,
        ]);
        try {
          final out = await api.createRecipeWithPhoto(
            const Recipe(
              id: 0,
              name: 'Babushka Pirog',
              photo: 'pending://upload',
              instructions: 'Bake.',
              category: 'Dessert',
              area: 'Russian',
              tags: [],
              ingredients: [],
            ),
            photoBytes,
            'pic.jpg',
          );
          expect(out.id, 1000123);
          expect(
            out.photo,
            startsWith('/storage/v1/object/public/recipe-photos/'),
          );

          final call = adapter.calls.single;
          expect(call.path, '');
          expect(call.method, 'POST');
          expect(
            (call.contentType ?? '').toLowerCase(),
            startsWith('multipart/form-data'),
          );
          expect(call.data, isA<FormData>());
          final form = call.data as FormData;
          final fieldNames = form.fields.map((e) => e.key).toSet();
          expect(fieldNames, contains('meal'));
          final mealField = form.fields
              .firstWhere((e) => e.key == 'meal')
              .value;
          final decoded = jsonDecode(mealField) as Map<String, dynamic>;
          expect(decoded['strMeal'], 'Babushka Pirog');
          expect(decoded['strCategory'], 'Dessert');
          expect(decoded['strArea'], 'Russian');
          expect(decoded['strMealThumb'], 'pending://upload');
          final photoNames = form.files.map((e) => e.key).toSet();
          expect(photoNames, contains('photo'));
        } finally {
          // no temp files to clean up (bytes-based upload)
        }
      },
    );
  });
}
