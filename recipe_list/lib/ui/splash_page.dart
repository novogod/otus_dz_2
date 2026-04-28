import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Splash-экран по дизайну Figma (frame `135:691`).
///
/// Структура из макета:
/// 1. Фон — линейный градиент `#2ECC71 → #165932` (см. `kSplashGradient`),
///    направление: верхне-правый угол → низ.
/// 2. Поверх — лого «OTUS / FOOD», в котором буквы являются «окнами»
///    в фотографию еды (Figma: `TEXT` с `isMask=true, maskType=ALPHA`
///    поверх 283×283 `IMAGE`-прямоугольника `задний фон`).
///
/// Маска реализована через `ShaderMask` с `BlendMode.srcIn`: дочерний
/// `Text` задаёт форму, а `ImageShader` из `assets/images/splash_food.jpg`
/// заполняет эту форму содержимым фотографии.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  ui.Image? _foodImage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    const provider = AssetImage('assets/images/splash_food.jpg');
    final stream = provider.resolve(ImageConfiguration.empty);
    final completer = Completer<ui.Image>();
    final listener = ImageStreamListener(
      (info, _) => completer.complete(info.image),
      onError: (e, st) => completer.completeError(e, st),
    );
    stream.addListener(listener);
    try {
      final img = await completer.future;
      if (!mounted) return;
      setState(() => _foodImage = img);
    } finally {
      stream.removeListener(listener);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: kSplashGradient),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _MaskedLogo(image: _foodImage),
          ),
        ),
      ),
    );
  }
}

/// Лого «OTUS / FOOD», окрашенное фотографией еды через `ShaderMask`.
///
/// Пока картинка ещё грузится, лого на короткое время рисуется
/// сплошным `textPrimary` — это занимает первый кадр и не успевает
/// заметно мелькнуть (image precache завершается до показа splash).
class _MaskedLogo extends StatelessWidget {
  const _MaskedLogo({required this.image});

  final ui.Image? image;

  @override
  Widget build(BuildContext context) {
    // Набор стилей берём из бандлового Roboto Black (assets/fonts/Roboto-Black.ttf)
    // через fontFamily 'Roboto' — см. pubspec.yaml.
    final textStyle = AppTextStyles.splashLogo.copyWith(color: Colors.white);
    final textWidget = Text(
      'OTUS\nFOOD',
      textAlign: TextAlign.center,
      style: textStyle,
    );

    final img = image;
    if (img == null) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'OTUS\nFOOD',
          textAlign: TextAlign.center,
          style: textStyle.copyWith(color: AppColors.textPrimary),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (Rect bounds) {
          // Растягиваем картинку по bounding-box текста через
          // matrix-преобразование ImageShader.
          final scaleX = bounds.width / img.width;
          final scaleY = bounds.height / img.height;
          final scale = scaleX > scaleY ? scaleX : scaleY;
          final dx = bounds.left + (bounds.width - img.width * scale) / 2;
          final dy = bounds.top + (bounds.height - img.height * scale) / 2;
          final matrix = Matrix4.identity()
            ..translateByDouble(dx, dy, 0, 1)
            ..scaleByDouble(scale, scale, 1, 1);
          return ui.ImageShader(
            img,
            TileMode.clamp,
            TileMode.clamp,
            matrix.storage,
          );
        },
        child: textWidget,
      ),
    );
  }
}
