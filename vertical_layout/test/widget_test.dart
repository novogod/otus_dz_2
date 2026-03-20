import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_layout/main.dart';

void main() {
  group('BoxConstraints', () {
    test('constrain clamps size to max', () {
      const c = BoxConstraints(maxWidth: 100, maxHeight: 50);
      final result = c.constrain(const ui.Size(200, 80));
      expect(result.width, 100);
      expect(result.height, 50);
    });

    test('constrain clamps size to min', () {
      const c = BoxConstraints(minWidth: 50, minHeight: 30);
      final result = c.constrain(const ui.Size(10, 10));
      expect(result.width, 50);
      expect(result.height, 30);
    });

    test('copyWithReducedHeight reduces max height', () {
      const c = BoxConstraints(maxHeight: 200);
      final reduced = c.copyWithReducedHeight(80);
      expect(reduced.maxHeight, 120);
    });
  });

  group('VerticalLayoutManager', () {
    test('positions children top-to-bottom, left-aligned', () {
      final children = [
        ColoredRectangle(
          preferredWidth: 100,
          preferredHeight: 40,
          color: const ui.Color(0xFFFF0000),
        ),
        ColoredRectangle(
          preferredWidth: 120,
          preferredHeight: 60,
          color: const ui.Color(0xFF00FF00),
        ),
        ColoredRectangle(
          preferredWidth: 80,
          preferredHeight: 30,
          color: const ui.Color(0xFF0000FF),
        ),
      ];

      final manager = VerticalLayoutManager(children: children, padding: 10);
      const constraints = BoxConstraints(maxWidth: 500, maxHeight: 500);
      manager.layout(constraints);

      // All left edges aligned at padding.
      expect(children[0].offset.dx, 10);
      expect(children[1].offset.dx, 10);
      expect(children[2].offset.dx, 10);

      // Vertical stacking: padding, child, padding, child, ...
      expect(children[0].offset.dy, 10);
      expect(children[1].offset.dy, 10 + 40 + 10);
      expect(children[2].offset.dy, 10 + 40 + 10 + 60 + 10);
    });

    test('recalculates positions after child size change', () {
      final rect = ColoredRectangle(
        preferredWidth: 100,
        preferredHeight: 40,
        color: const ui.Color(0xFFE53935),
      );
      final second = ColoredRectangle(
        preferredWidth: 100,
        preferredHeight: 50,
        color: const ui.Color(0xFF1E88E5),
      );
      final manager = VerticalLayoutManager(
        children: [rect, second],
        padding: 10,
      );
      const constraints = BoxConstraints(maxWidth: 500, maxHeight: 500);

      manager.layout(constraints);
      expect(second.offset.dy, 10 + 40 + 10);

      // Simulate tap → size changes.
      rect.onTap();
      manager.layout(constraints);

      // Second child position updated automatically.
      expect(second.offset.dy, 10 + rect.size.height + 10);
    });
  });

  group('ColoredRectangle', () {
    test('onTap cycles preset and changes properties', () {
      final rect = ColoredRectangle(
        preferredWidth: 200,
        preferredHeight: 80,
        color: const ui.Color(0xFFE53935),
      );
      final oldColor = rect.color;
      expect(rect.onTap(), isTrue);
      // After tap, at least one property should differ.
      final changed =
          rect.color != oldColor ||
          rect.preferredWidth != 200 ||
          rect.preferredHeight != 80;
      expect(changed, isTrue);
    });
  });
}
