import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/photo_downscaler.dart';
import 'app_theme.dart';

/// User's choice from the photo source bottom sheet.
enum PhotoPickerAction { camera, gallery, remove }

/// Reusable bottom sheet showing camera / gallery / (optional) remove
/// options. Returns the chosen action, or `null` if the sheet was
/// dismissed by tapping outside / the back gesture.
///
/// Used by both [AddRecipePage] (recipe photo) and `UserCardPage`
/// (avatar) so the two flows look identical. The caller decides what
/// to do with the action — `AddRecipePage` keeps its own state-driven
/// pick-and-compress because it needs to track a native `File` for
/// cleanup; the avatar flow can call [pickAndCompressPhoto] below.
Future<PhotoPickerAction?> showPhotoPickerSheet(
  BuildContext context, {
  required String title,
  required String cameraLabel,
  required String galleryLabel,
  String? removeLabel,
}) {
  return showModalBottomSheet<PhotoPickerAction>(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(cameraLabel),
              onTap: () => Navigator.of(ctx).pop(PhotoPickerAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(galleryLabel),
              onTap: () => Navigator.of(ctx).pop(PhotoPickerAction.gallery),
            ),
            if (removeLabel != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.primaryDark,
                ),
                title: Text(removeLabel),
                onTap: () => Navigator.of(ctx).pop(PhotoPickerAction.remove),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );
}

/// Result of [pickAndCompressPhoto].
class PickedPhoto {
  PickedPhoto({required this.bytes, required this.filename});
  final Uint8List bytes;
  final String filename;
}

/// Possible failure modes surfaced from [pickAndCompressPhoto] so
/// callers can show a localised snackbar without having to inspect
/// platform exceptions themselves.
enum PhotoPickError { accessDenied, tooLarge, generic }

/// High-level helper used by surfaces that just need raw JPEG bytes
/// (e.g. avatar upload). Picks an image from [source], compresses on
/// native via [downscaleForUpload], reads bytes on web, and returns
/// the result. Throws nothing — failures are surfaced via [onError].
///
/// `AddRecipePage` does NOT use this directly because it tracks a
/// native `File` separately for filesystem cleanup; this helper is
/// for callers that only care about the bytes.
Future<PickedPhoto?> pickAndCompressPhoto({
  required ImageSource source,
  ImagePicker? picker,
  void Function(PhotoPickError error)? onError,
}) async {
  try {
    final p = picker ?? ImagePicker();
    final raw = await p.pickImage(source: source);
    if (raw == null) return null; // user cancelled
    if (kIsWeb) {
      final rawBytes = await raw.readAsBytes();
      // PWA / web: image_picker не сжимает, а iPhone-камера выдаёт
      // 4–10 МБ JPEG-и, что превышает серверный 5 МБ multer-cap.
      // Гоним через canvas-downscaler (flutter_image_compress_web).
      final bytes = await downscaleBytesForUpload(rawBytes);
      final rawName = raw.name.isNotEmpty ? raw.name : 'photo.jpg';
      // Renormalise extension to .jpg — после downscaler формат всегда JPEG.
      final base = rawName.contains('.')
          ? rawName.substring(0, rawName.lastIndexOf('.'))
          : rawName;
      return PickedPhoto(bytes: bytes, filename: '$base.jpg');
    }
    final compressed = await downscaleForUpload(raw);
    final bytes = await compressed.readAsBytes();
    // Best-effort cleanup of the temp file — the caller already has
    // the bytes in memory.
    try {
      if (await compressed.exists()) await compressed.delete();
    } catch (_) {}
    final name = raw.name.isNotEmpty ? raw.name : 'photo.jpg';
    return PickedPhoto(bytes: bytes, filename: name);
  } on PlatformException catch (e) {
    final code = e.code.toLowerCase();
    final kind = (code.contains('access_denied') || code.contains('permission'))
        ? PhotoPickError.accessDenied
        : PhotoPickError.generic;
    onError?.call(kind);
    return null;
  } on StateError catch (e) {
    final kind = e.message == 'photo_too_large'
        ? PhotoPickError.tooLarge
        : PhotoPickError.generic;
    onError?.call(kind);
    return null;
  } catch (_) {
    onError?.call(PhotoPickError.generic);
    return null;
  }
}
