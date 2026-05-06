import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/config/feed_config.dart';

void main() {
  group('FeedConfig', () {
    test('defaults match documented values', () {
      const c = FeedConfig();
      expect(c.seedTarget, 200);
      expect(c.seedPickCount, 10);
      expect(c.categoryCacheThreshold, 10);
      expect(c.translateConcurrency, 8);
    });

    test('fromDartDefine returns documented defaults when no -D flags', () {
      final c = FeedConfig.fromDartDefine();
      expect(c.seedTarget, 200);
      expect(c.seedPickCount, 10);
      expect(c.categoryCacheThreshold, 10);
      expect(c.translateConcurrency, 8);
    });

    test('custom values are honored', () {
      const c = FeedConfig(seedTarget: 20, seedPickCount: 3);
      expect(c.seedTarget, 20);
      expect(c.seedPickCount, 3);
      expect(c.categoryCacheThreshold, 10);
      expect(c.translateConcurrency, 8);
    });

    test('useBulkPage defaults to true', () {
      const c = FeedConfig();
      expect(c.useBulkPage, isTrue);
      final fromDefine = FeedConfig.fromDartDefine();
      expect(fromDefine.useBulkPage, isTrue);
    });
  });
}
