// Chunk J of docs/user-card-and-social-signals.md.
//
// Walks the post-signup user-card flow: page renders in
// edit-mode, displays Skip/Add and finish-setup title, the
// display-name field is editable, tapping Skip navigates to
// the recipes route. We don't go through the network signup
// dialog here — that's covered by the existing login_page
// widget test — but assert the redirect target is reachable.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_list/auth/admin_session.dart';
import 'package:recipe_list/i18n.dart';
import 'package:recipe_list/i18n/strings.g.dart';
import 'package:recipe_list/router/routes.dart';
import 'package:recipe_list/ui/user_card_page.dart';

GoRouter _router(Widget initial) {
  return GoRouter(
    initialLocation: Routes.profile,
    routes: <RouteBase>[
      GoRoute(path: Routes.profile, builder: (_, __) => initial),
      GoRoute(
        path: Routes.recipes,
        builder: (_, __) => const Scaffold(body: Text('RECIPES_HOME')),
      ),
    ],
  );
}

void main() {
  setUp(() {
    adminLoggedInNotifier.value = false;
    userLoggedInNotifier.value = true;
    currentUserLoginNotifier.value = 'newbie@example.com';
    currentUserTokenNotifier.value = null;
  });
  tearDown(() {
    userLoggedInNotifier.value = false;
    currentUserLoginNotifier.value = null;
  });

  testWidgets('post-signup → user card edit mode → Skip → recipes', (
    tester,
  ) async {
    final router = _router(
      const UserCardPage(isPostSignup: true, initialEditMode: true),
    );
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp.router(
          supportedLocales: const [Locale('en')],
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    final ctx = tester.element(find.byType(UserCardPage));
    final s = S.of(ctx);
    expect(find.text(s.profileFinishSetup), findsOneWidget);
    expect(find.text(s.profileSkip), findsOneWidget);
    expect(find.text(s.profileAdd), findsOneWidget);
    expect(find.text(s.profileLogout), findsNothing);

    // Display-name field is editable.
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'Newbie Smith');
    await tester.pump();
    expect(find.text('Newbie Smith'), findsOneWidget);

    // Skip → recipes home.
    await tester.tap(find.text(s.profileSkip));
    await tester.pumpAndSettle();
    expect(find.text('RECIPES_HOME'), findsOneWidget);
  });
}
