import 'package:flutter/material.dart';

import '../auth/admin_session.dart';
import '../i18n.dart';
import 'admin_users_page.dart';
import 'app_theme.dart';

Future<void> openAdminAfterLoginPage(
  BuildContext context, {
  required String adminLogin,
  required String adminPassword,
}) async {
  await Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) => AdminAfterLoginPage(
        adminLogin: adminLogin,
        adminPassword: adminPassword,
      ),
    ),
  );
}

class AdminAfterLoginPage extends StatelessWidget {
  const AdminAfterLoginPage({
    super.key,
    required this.adminLogin,
    required this.adminPassword,
  });

  final String adminLogin;
  final String adminPassword;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.adminPanelTitle), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AdminUsersPage(
                        adminLogin: adminLogin,
                        adminPassword: adminPassword,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.people_alt_outlined),
                label: Text(s.adminEditUsersList),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: () {
                  // Return to the food cards list (root route with recipe feed).
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.restaurant_menu),
                label: Text(s.adminEditCards),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: AppColors.surface,
                ),
                onPressed: () async {
                  await logoutAdmin();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(s.logoutButton)));
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.logout),
                label: Text(s.logoutButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
