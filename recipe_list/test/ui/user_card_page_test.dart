// Widget tests for UserCardPage (chunk D of
// docs/user-card-and-social-signals.md).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/auth/admin_session.dart';
import 'package:recipe_list/i18n.dart';
import 'package:recipe_list/i18n/strings.g.dart';
import 'package:recipe_list/ui/user_card_page.dart';

Widget _wrap(Widget child) {
  return TranslationProvider(
    child: MaterialApp(
      supportedLocales: const [Locale('en')],
      locale: const Locale('en'),
      home: child,
    ),
  );
}

void _resetAuth() {
  adminLoggedInNotifier.value = false;
  userLoggedInNotifier.value = false;
  currentUserLoginNotifier.value = null;
  currentUserTokenNotifier.value = null;
}

void main() {
  setUp(() {
    _resetAuth();
    userLoggedInNotifier.value = true;
    currentUserLoginNotifier.value = 'alice@example.com';
  });
  tearDown(_resetAuth);

  testWidgets('renders display-name field, language picker and Edit button', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const UserCardPage()));
    await tester.pump();

    final s = S.of(tester.element(find.byType(UserCardPage)));
    expect(find.text(s.profileDisplayName), findsOneWidget);
    expect(find.text(s.profileLanguage), findsOneWidget);
    expect(find.text(s.profileEdit), findsOneWidget);
    expect(find.text(s.profileLogout), findsOneWidget);
    // Display-name pre-fills with the current user's login.
    expect(find.text('alice@example.com'), findsOneWidget);
  });

  testWidgets('Edit button toggles into Save mode', (tester) async {
    await tester.pumpWidget(_wrap(const UserCardPage()));
    await tester.pump();

    final s = S.of(tester.element(find.byType(UserCardPage)));
    await tester.tap(find.text(s.profileEdit));
    await tester.pump();
    expect(find.text(s.profileSave), findsOneWidget);
    expect(find.text(s.profileEdit), findsNothing);
  });

  testWidgets('post-signup mode shows Skip/Add and finish-setup title', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const UserCardPage(isPostSignup: true)));
    await tester.pump();

    final s = S.of(tester.element(find.byType(UserCardPage)));
    expect(find.text(s.profileFinishSetup), findsOneWidget);
    expect(find.text(s.profileSkip), findsOneWidget);
    expect(find.text(s.profileAdd), findsOneWidget);
    // Logout button is hidden during onboarding.
    expect(find.text(s.profileLogout), findsNothing);
  });
}
