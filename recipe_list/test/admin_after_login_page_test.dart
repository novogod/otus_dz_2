import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_list/auth/admin_session.dart';
import 'package:recipe_list/i18n/strings.g.dart';
import 'package:recipe_list/ui/admin_after_login_page.dart';

void _resetAuth() {
  adminLoggedInNotifier.value = false;
  userLoggedInNotifier.value = false;
  currentRecipeAdminTokenNotifier.value = null;
  currentUserLoginNotifier.value = null;
}

Widget _wrap(Widget child) {
  return TranslationProvider(
    child: MaterialApp(
      supportedLocales: const [Locale('en')],
      locale: const Locale('en'),
      home: child,
    ),
  );
}

void main() {
  setUp(_resetAuth);
  tearDown(_resetAuth);

  testWidgets('hides dead admin surface after admin session is dropped', (
    tester,
  ) async {
    adminLoggedInNotifier.value = true;
    userLoggedInNotifier.value = true;
    currentUserLoginNotifier.value = 'admin@example.com';

    await tester.pumpWidget(
      _wrap(
        const AdminAfterLoginPage(
          adminLogin: 'admin@example.com',
          adminPassword: 'secret',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit recipes'), findsOneWidget);
    expect(
      find.text('Save admin login for Face ID / Fingerprint'),
      findsOneWidget,
    );

    adminLoggedInNotifier.value = false;
    userLoggedInNotifier.value = false;
    currentUserLoginNotifier.value = null;
    currentRecipeAdminTokenNotifier.value = null;
    await tester.pumpAndSettle();

    expect(find.text('Edit recipes'), findsNothing);
    expect(
      find.text('Save admin login for Face ID / Fingerprint'),
      findsNothing,
    );
    expect(find.text('Logout'), findsNothing);
  });
}
