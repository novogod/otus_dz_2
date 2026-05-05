// Parses every flag SVG asset with the same compiler that flutter_svg uses
// and asserts no warnings (`warningsAsErrors: true`). Guards against
// regressions like unsupported elements (e.g. <marker>, <pattern>, <filter>)
// silently dropping content.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

const _flagFiles = <String>[
  'de.svg',
  'es.svg',
  'fr.svg',
  'iq.svg',
  'ir.svg',
  'it.svg',
  'ru.svg',
  'sa.svg',
  'tr.svg',
  'us.svg',
];

void main() {
  for (final name in _flagFiles) {
    test('flag asset $name parses without SVG warnings', () {
      final file = File('assets/flags/$name');
      expect(file.existsSync(), isTrue, reason: '${file.path} not found');
      final source = file.readAsStringSync();

      expect(
        () => vg.encodeSvg(
          xml: source,
          debugName: name,
          warningsAsErrors: true,
          enableClippingOptimizer: false,
          enableMaskingOptimizer: false,
          enableOverdrawOptimizer: false,
        ),
        returnsNormally,
        reason: '$name produced parser warnings',
      );
    });
  }
}
