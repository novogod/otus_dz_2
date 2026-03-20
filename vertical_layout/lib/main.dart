import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;

// ---------------------------------------------------------------------------
// BoxConstraints — min/max size passed from parent to child during layout.
// ---------------------------------------------------------------------------
class BoxConstraints {
  final double minWidth;
  final double minHeight;
  final double maxWidth;
  final double maxHeight;

  const BoxConstraints({
    this.minWidth = 0,
    this.minHeight = 0,
    this.maxWidth = double.infinity,
    this.maxHeight = double.infinity,
  });

  /// Clamp [size] so it satisfies these constraints.
  ui.Size constrain(ui.Size size) {
    return ui.Size(
      size.width.clamp(minWidth, maxWidth),
      size.height.clamp(minHeight, maxHeight),
    );
  }

  /// Remaining vertical space after [used] pixels consumed.
  BoxConstraints copyWithReducedHeight(double used) {
    return BoxConstraints(
      minWidth: minWidth,
      minHeight: 0,
      maxWidth: maxWidth,
      maxHeight: max(0, maxHeight - used),
    );
  }
}

// ---------------------------------------------------------------------------
// LayoutObject — base class: measures itself and paints at a given offset.
// ---------------------------------------------------------------------------
abstract class LayoutObject {
  /// Current size after the last layout pass.
  ui.Size size = ui.Size.zero;

  /// Position set by the layout manager.
  ui.Offset offset = ui.Offset.zero;

  /// Compute desired size given [constraints]. Store result in [size].
  ui.Size layout(BoxConstraints constraints);

  /// Paint the object on [canvas] at [offset].
  void paint(ui.Canvas canvas, ui.Offset offset);

  /// Whether [point] (in global coords) hits this object.
  bool hitTest(ui.Offset point) {
    return ui.Rect.fromLTWH(
      offset.dx,
      offset.dy,
      size.width,
      size.height,
    ).contains(point);
  }

  /// Called when the object is tapped. Returns true if it changed.
  bool onTap() => false;
}

// ---------------------------------------------------------------------------
// ColoredRectangle — a rounded rectangle with preferred size and color.
// Tapping cycles through a list of color + size presets.
// ---------------------------------------------------------------------------
class ColoredRectangle extends LayoutObject {
  double preferredWidth;
  double preferredHeight;
  ui.Color color;

  int _presetIndex = 0;

  static final List<_RectPreset> _presets = [
    _RectPreset(200, 80, const ui.Color(0xFFE53935)),
    _RectPreset(260, 100, const ui.Color(0xFF1E88E5)),
    _RectPreset(180, 60, const ui.Color(0xFF43A047)),
    _RectPreset(300, 120, const ui.Color(0xFFFDD835)),
    _RectPreset(150, 90, const ui.Color(0xFF8E24AA)),
  ];

  ColoredRectangle({
    required this.preferredWidth,
    required this.preferredHeight,
    required this.color,
  }) {
    _presetIndex = _presets.indexWhere(
      (p) =>
          p.width == preferredWidth &&
          p.height == preferredHeight &&
          p.color == color,
    );
    if (_presetIndex < 0) _presetIndex = 0;
  }

  @override
  ui.Size layout(BoxConstraints constraints) {
    size = constraints.constrain(ui.Size(preferredWidth, preferredHeight));
    return size;
  }

  @override
  void paint(ui.Canvas canvas, ui.Offset offset) {
    final paint = ui.Paint()..color = color;
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
        const ui.Radius.circular(8),
      ),
      paint,
    );

    // Label showing the current size.
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(textAlign: ui.TextAlign.center, fontSize: 14),
          )
          ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF)))
          ..addText('${size.width.toInt()} × ${size.height.toInt()}  (tap me)');
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: size.width));
    canvas.drawParagraph(
      paragraph,
      ui.Offset(offset.dx, offset.dy + (size.height - 18) / 2),
    );
  }

  @override
  bool onTap() {
    _presetIndex = (_presetIndex + 1) % _presets.length;
    final preset = _presets[_presetIndex];
    preferredWidth = preset.width;
    preferredHeight = preset.height;
    color = preset.color;
    return true;
  }
}

class _RectPreset {
  final double width;
  final double height;
  final ui.Color color;
  _RectPreset(this.width, this.height, this.color);
}

// ---------------------------------------------------------------------------
// GradientEllipse — a different shape to show variety.
// Tapping toggles between normal and expanded size.
// ---------------------------------------------------------------------------
class GradientEllipse extends LayoutObject {
  double preferredWidth;
  double preferredHeight;
  final double _baseWidth;
  final double _baseHeight;
  ui.Color colorA;
  ui.Color colorB;
  bool _expanded = false;

  GradientEllipse({
    required this.preferredWidth,
    required this.preferredHeight,
    required this.colorA,
    required this.colorB,
  }) : _baseWidth = preferredWidth,
       _baseHeight = preferredHeight;

  @override
  ui.Size layout(BoxConstraints constraints) {
    size = constraints.constrain(ui.Size(preferredWidth, preferredHeight));
    return size;
  }

  @override
  void paint(ui.Canvas canvas, ui.Offset offset) {
    final rect = ui.Rect.fromLTWH(
      offset.dx,
      offset.dy,
      size.width,
      size.height,
    );
    final paint = ui.Paint()
      ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [
        colorA,
        colorB,
      ]);
    canvas.drawOval(rect, paint);

    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(textAlign: ui.TextAlign.center, fontSize: 14),
          )
          ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF)))
          ..addText('${size.width.toInt()} × ${size.height.toInt()}  (tap me)');
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: size.width));
    canvas.drawParagraph(
      paragraph,
      ui.Offset(offset.dx, offset.dy + (size.height - 18) / 2),
    );
  }

  @override
  bool onTap() {
    _expanded = !_expanded;
    if (_expanded) {
      preferredWidth = _baseWidth * 1.4;
      preferredHeight = _baseHeight * 1.4;
    } else {
      preferredWidth = _baseWidth;
      preferredHeight = _baseHeight;
    }
    return true;
  }
}

// ---------------------------------------------------------------------------
// VerticalLayoutManager — lays out children top‑to‑bottom, left‑aligned.
// Automatically recalculates positions when child sizes change.
// ---------------------------------------------------------------------------
class VerticalLayoutManager {
  final List<LayoutObject> children;
  final double padding;

  VerticalLayoutManager({required this.children, this.padding = 16});

  /// Run layout: pass constraints to each child, place them vertically.
  void layout(BoxConstraints constraints) {
    double yOffset = padding;
    for (final child in children) {
      final remaining = constraints.copyWithReducedHeight(yOffset);
      child.layout(remaining);
      child.offset = ui.Offset(padding, yOffset);
      yOffset += child.size.height + padding;
    }
  }

  /// Paint all children onto [canvas].
  void paint(ui.Canvas canvas) {
    for (final child in children) {
      child.paint(canvas, child.offset);
    }
  }

  /// Forward a tap to the first hit child. Returns true if relayout needed.
  bool handleTap(ui.Offset point) {
    for (final child in children) {
      if (child.hitTest(point)) {
        return child.onTap();
      }
    }
    return false;
  }
}

// ---------------------------------------------------------------------------
// Application — ties dart:ui rendering loop to the VerticalLayoutManager.
// ---------------------------------------------------------------------------
class Application {
  final ui.FlutterView view;
  final VerticalLayoutManager manager;

  Application({required this.view, required this.manager});

  void scheduleFrame() {
    ui.PlatformDispatcher.instance.scheduleFrame();
    ui.PlatformDispatcher.instance.onBeginFrame = _onBeginFrame;
    ui.PlatformDispatcher.instance.onDrawFrame = _onDrawFrame;
  }

  void _onBeginFrame(Duration timeStamp) {
    // Reserved for animation timing if needed.
  }

  void _onDrawFrame() {
    final physicalSize = view.physicalSize;
    final dpr = view.devicePixelRatio;
    final logicalWidth = physicalSize.width / dpr;
    final logicalHeight = physicalSize.height / dpr;

    // Root constraints: min (0, 0), max = screen size.
    final constraints = BoxConstraints(
      minWidth: 0,
      minHeight: 0,
      maxWidth: logicalWidth,
      maxHeight: logicalHeight,
    );

    // Layout pass — positions are recalculated every frame.
    manager.layout(constraints);

    // Paint pass.
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Dark background.
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, logicalWidth, logicalHeight),
      ui.Paint()..color = const ui.Color(0xFF212121),
    );

    // Info line.
    final infoBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 11))
      ..pushStyle(ui.TextStyle(color: const ui.Color(0x99FFFFFF)))
      ..addText(
        'Screen: ${physicalSize.width.toInt()}×${physicalSize.height.toInt()} '
        'phys  •  Tap objects to change size/color',
      );
    final infoParagraph = infoBuilder.build()
      ..layout(ui.ParagraphConstraints(width: logicalWidth));
    canvas.drawParagraph(infoParagraph, const ui.Offset(4, 2));

    manager.paint(canvas);

    final picture = recorder.endRecording();

    // Build and render scene with device-pixel-ratio scaling.
    final sceneBuilder = ui.SceneBuilder()
      ..pushTransform(_scaleMatrix(dpr))
      ..addPicture(ui.Offset.zero, picture)
      ..pop();

    view.render(sceneBuilder.build());
  }

  void handlePointerData(ui.PointerDataPacket packet) {
    for (final data in packet.data) {
      if (data.change == ui.PointerChange.up) {
        final dpr = view.devicePixelRatio;
        final logicalPos = ui.Offset(
          data.physicalX / dpr,
          data.physicalY / dpr,
        );
        if (manager.handleTap(logicalPos)) {
          scheduleFrame(); // sizes changed → relayout + repaint
        }
      }
    }
  }

  /// Create a 4×4 scale matrix suitable for SceneBuilder.pushTransform.
  Float64List _scaleMatrix(double scale) {
    final m = Float64List(16);
    m[0] = scale; // scaleX
    m[5] = scale; // scaleY
    m[10] = 1; // scaleZ
    m[15] = 1; // w
    return m;
  }
}

// ---------------------------------------------------------------------------
// Entry point — binding to platformDispatcher.views.first, creating objects.
// ---------------------------------------------------------------------------
void main() {
  // 1. Initialise the binding and obtain the primary FlutterView.
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final ui.FlutterView view = binding.platformDispatcher.views.first;

  // 2. Create at least 3 layout objects (4 here for variety).
  final children = <LayoutObject>[
    ColoredRectangle(
      preferredWidth: 200,
      preferredHeight: 80,
      color: const ui.Color(0xFFE53935),
    ),
    ColoredRectangle(
      preferredWidth: 260,
      preferredHeight: 100,
      color: const ui.Color(0xFF1E88E5),
    ),
    GradientEllipse(
      preferredWidth: 220,
      preferredHeight: 70,
      colorA: const ui.Color(0xFFFF6F00),
      colorB: const ui.Color(0xFFFDD835),
    ),
    ColoredRectangle(
      preferredWidth: 180,
      preferredHeight: 60,
      color: const ui.Color(0xFF43A047),
    ),
  ];

  // 3. Create the vertical layout manager.
  final manager = VerticalLayoutManager(children: children);

  // 4. Create the application (rendering + hit-testing logic).
  final app = Application(view: view, manager: manager);

  // 5. Wire up platform callbacks.
  //    - Redraw on window resize / device rotation.
  binding.platformDispatcher.onMetricsChanged = app.scheduleFrame;
  //    - Handle pointer (tap) events.
  binding.platformDispatcher.onPointerDataPacket = app.handlePointerData;

  // 6. Schedule the first frame.
  app.scheduleFrame();
}
