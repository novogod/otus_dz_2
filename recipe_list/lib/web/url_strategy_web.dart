// Web implementation of `enablePathUrlStrategy`. Selected by the
// conditional import in `main.dart` when `dart.library.js_interop`
// is available. Switches go_router from hash-URL routing
// (`/#/recipes/123`) to clean path routing (`/recipes/123`) so that
// canonical share-links land directly on the deep-linked page.
import 'package:flutter_web_plugins/url_strategy.dart' as fwp;

void enablePathUrlStrategy() => fwp.usePathUrlStrategy();
