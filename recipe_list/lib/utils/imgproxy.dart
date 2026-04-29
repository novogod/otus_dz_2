// recipe_list/lib/utils/imgproxy.dart
//
// Клиентский helper для построения thumbnail-URL через imgproxy
// на стороне `mahallem_ist`. Сервер уже использует ту же схему в
// `local_user_portal/utils/getImgproxyUrl.js` для job-photos —
// здесь повторяем её для recipe-photos, чтобы карточки рецепта
// тянули 60–80 КБ JPEG вместо 1–5 МБ оригинала.
//
// Формат URL (unsigned, поскольку endpoint `/imgproxy/insecure/...`
// проксируется nginx-ом без подписи):
//   https://mahallem.ist/imgproxy/insecure/resize:fit:<w>:<h>:0/<base64url(src)>
//
// `src` должен быть полным абсолютным URL — imgproxy сам сходит
// по нему. Для относительных storage-путей (`/storage/v1/...`)
// клеим хост mahallem перед base64-кодированием.

import 'dart:convert';

import '../data/api/recipe_api_config.dart';

/// Возвращает thumbnail-URL для отображения [src] в превью
/// размером [w]×[h] dp.
///
/// Для backend == mealDb или невалидного [src] возвращается
/// исходный URL без обёртки — TheMealDB-картинки уже
/// thumbnail-friendly (~50 КБ), и встраивать там imgproxy
/// бессмысленно (мы не контролируем CDN).
String imgproxyUrl(String src, int w, int h) {
  if (src.isEmpty || src.startsWith('pending://')) return src;
  if (RecipeApiConfig.backend != RecipeBackend.mahallem) return src;

  final origin = _mahallemOrigin();
  if (origin == null) return src;

  // Превращаем относительный storage-URL в абсолютный — imgproxy
  // не умеет в `host`-relative пути.
  final absoluteSrc = src.startsWith('/') ? '$origin$src' : src;

  final encoded = base64Url.encode(utf8.encode(absoluteSrc));
  // Без padding — imgproxy не ожидает `=`-хвостов в URL-safe base64.
  final stripped = encoded.replaceAll('=', '');
  return '$origin/imgproxy/insecure/resize:fit:$w:$h:0/$stripped';
}

/// Origin (`scheme://host[:port]`) из `mahallemBaseUrl`.
/// `https://mahallem.ist/recipes` → `https://mahallem.ist`.
String? _mahallemOrigin() {
  final base = RecipeApiConfig.mahallemBaseUrl;
  if (base.isEmpty) return null;
  final uri = Uri.tryParse(base);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  final port =
      (uri.hasPort &&
          !((uri.scheme == 'http' && uri.port == 80) ||
              (uri.scheme == 'https' && uri.port == 443)))
      ? ':${uri.port}'
      : '';
  return '${uri.scheme}://${uri.host}$port';
}
