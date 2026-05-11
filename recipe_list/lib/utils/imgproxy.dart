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
//
// Важно: imgproxy и storage живут ТОЛЬКО на `mahallem.ist`.
// SPA-origin (`snackhack.app`, исторически также `recipies.mahallem.ist`)
// nginx-а storage/imgproxy не проксирует.
// Поэтому origin здесь всегда `https://mahallem.ist`, независимо
// от значения `RecipeApiConfig.mahallemBaseUrl`.

import 'dart:convert';

import '../data/api/recipe_api_config.dart' show RecipeApiConfig, RecipeBackend;

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

  const origin = 'https://mahallem.ist';

  // После массового rename могли остаться ссылки на
  // `recipies.mahallem.ist` (и для storage, и для imgproxy).
  // Канонизируем их на `mahallem.ist` до любой дальнейшей логики.
  // `snackhack.app` тоже матчим defensively — storage там не живёт,
  // но в БД могут осесть URL после миграции SPA-origin.
  final initialUri = Uri.tryParse(src);
  final hasAbsoluteSource =
      initialUri != null && initialUri.hasScheme && initialUri.host.isNotEmpty;
  if (hasAbsoluteSource &&
      (initialUri.host == 'recipies.mahallem.ist' ||
          initialUri.host == 'snackhack.app')) {
    final path = initialUri.path;
    if (path.startsWith('/storage/') || path.startsWith('/imgproxy/')) {
      src = initialUri.replace(host: 'mahallem.ist').toString();
    }
  }

  // Already proxied URL — don't wrap again.
  if (src.contains('/imgproxy/')) return src;

  final uri = Uri.tryParse(src);
  final isAbsolute = uri != null && uri.hasScheme && uri.host.isNotEmpty;

  // Превращаем относительный storage-URL в абсолютный — imgproxy
  // не умеет в `host`-relative пути.
  String absoluteSrc;
  if (!isAbsolute && src.startsWith('/')) {
    absoluteSrc = '$origin$src';
  } else if (isAbsolute &&
      (uri.host == 'recipies.mahallem.ist' || uri.host == 'snackhack.app') &&
      uri.path.startsWith('/storage/')) {
    // После массового rename ссылок источники могли указывать на
    // `recipies.mahallem.ist`/`snackhack.app`, тогда как storage/imgproxy
    // обслуживается с `mahallem.ist`.
    absoluteSrc = uri.replace(host: 'mahallem.ist').toString();
  } else {
    absoluteSrc = src;
  }

  final encoded = base64Url.encode(utf8.encode(absoluteSrc));
  // Без padding — imgproxy не ожидает `=`-хвостов в URL-safe base64.
  final stripped = encoded.replaceAll('=', '');
  return '$origin/imgproxy/insecure/resize:fit:$w:$h:0/$stripped';
}
