// recipe_list/lib/utils/photo_downscaler.dart
//
// Единая точка сжатия / EXIF-strip-а для рецептной фотозагрузки.
// `image_picker` ненадёжен как resizer: на Android `maxWidth` /
// `maxHeight` иногда игнорируется (SAF / Photo Picker), `imageQuality`
// работает только для JPEG, и 12 МП-исходники с iPhone/Pixel могут
// прилететь как 5–10 МБ — выше bucket-cap (5 МБ).
//
// Поэтому picker вызывается без resize-параметров, а сжатие делает
// `flutter_image_compress` в этом файле. См. чанк 11.5 todo
// `recipe_photo_upload.md` и `docs/recipe-photo-upload.md` §2.4.1.

import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// `XFile` приходит транзитивно через `flutter_image_compress`,
// но семантически это тип `image_picker` — на стороне вызова
// (`AddRecipePage._pickPhoto`) `image_picker` импортируется явно.

const _kMaxBytes = 5 * 1024 * 1024;

/// Сжать выбранный пользователем файл под лимит bucket-а
/// `recipe-photos` (5 МБ) и привести к JPEG 1600×1600.
///
/// Возвращает временный файл — вызывающий код отвечает за удаление
/// (см. `AddRecipePage._save()` finally-ветку).
///
/// Бросает [StateError] с кодом:
///   * `'compress_failed'` — `flutter_image_compress` вернул null
///     (повреждённый файл / неподдерживаемый формат).
///   * `'photo_too_large'` — даже после двух проходов файл
///     остался > 5 МБ (panorama, RAW-derived и т.п.).
Future<File> downscaleForUpload(XFile src) async {
  final tmp = await getTemporaryDirectory();
  final outPath = p.join(
    tmp.path,
    'rcp_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );

  final r1 = await FlutterImageCompress.compressAndGetFile(
    src.path,
    outPath,
    minWidth: 1600,
    minHeight: 1600,
    quality: 80,
    format: CompressFormat.jpeg,
    keepExif: false, // privacy: удаляем GPS / timestamp.
  );
  if (r1 == null) {
    throw StateError('compress_failed');
  }

  final out = File(r1.path);
  if (await out.length() <= _kMaxBytes) return out;

  // Второй проход для очень больших исходников (panorama, RAW-derived).
  final r2 = await FlutterImageCompress.compressAndGetFile(
    out.path,
    out.path,
    minWidth: 1280,
    minHeight: 1280,
    quality: 60,
    format: CompressFormat.jpeg,
    keepExif: false,
  );
  if (r2 == null || await out.length() > _kMaxBytes) {
    // Не удаляем файл здесь — пусть вызывающий код решает (он
    // может попробовать перевыбрать другой источник).
    throw StateError('photo_too_large');
  }
  return out;
}
