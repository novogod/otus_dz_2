import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/i18n.dart';

void main() {
  test('requestAppReload bumps appReloadTicker AND feed ticker (todo/13)', () {
    final feedBefore = reloadFeedTicker.value;
    final appBefore = appReloadTicker.value;
    requestAppReload();
    expect(appReloadTicker.value, appBefore + 1);
    expect(reloadFeedTicker.value, feedBefore + 1);
  });

  test('requestFeedReload does NOT touch appReloadTicker', () {
    final appBefore = appReloadTicker.value;
    final feedBefore = reloadFeedTicker.value;
    requestFeedReload();
    expect(reloadFeedTicker.value, feedBefore + 1);
    expect(appReloadTicker.value, appBefore);
  });

  test('appReloadTicker notifies subscribed listeners', () {
    var fires = 0;
    void onTick() => fires += 1;
    appReloadTicker.addListener(onTick);
    addTearDown(() => appReloadTicker.removeListener(onTick));
    requestAppReload();
    requestAppReload();
    expect(fires, 2);
  });
}
