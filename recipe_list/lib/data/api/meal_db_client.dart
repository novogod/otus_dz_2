import 'package:dio/dio.dart';

/// Базовый HTTP-клиент TheMealDB.
///
/// База: `https://www.themealdb.com/api/json/v1/1`.
class MealDbClient {
  static const String baseUrl = 'https://www.themealdb.com/api/json/v1/1';

  final Dio dio;

  MealDbClient({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              responseType: ResponseType.json,
            ),
          );
}
