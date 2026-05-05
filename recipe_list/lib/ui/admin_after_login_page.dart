import 'package:flutter/material.dart';

import '../auth/admin_session.dart';
import '../i18n.dart';
import 'admin_added_recipes_page.dart';
import 'admin_users_page.dart';
import 'app_theme.dart';

Future<void> openAdminAfterLoginPage(
  BuildContext context, {
  required String adminLogin,
  required String adminPassword,
  bool replaceCurrent = true,
}) async {
  final route = MaterialPageRoute<void>(
    builder: (_) => AdminAfterLoginPage(
      adminLogin: adminLogin,
      adminPassword: adminPassword,
    ),
  );
  if (replaceCurrent) {
    await Navigator.of(context).pushReplacement(route);
  } else {
    await Navigator.of(context).push(route);
  }
}

class AdminAfterLoginPage extends StatefulWidget {
  const AdminAfterLoginPage({
    super.key,
    required this.adminLogin,
    required this.adminPassword,
  });

  final String adminLogin;
  final String adminPassword;

  @override
  State<AdminAfterLoginPage> createState() => _AdminAfterLoginPageState();
}

class _AdminAfterLoginPageState extends State<AdminAfterLoginPage> {
  bool _busy = false;
  bool _biometricSaved = false;

  // §9a top-bar title: Roboto 400/20, #165932
  static const _titleStyle = TextStyle(
    fontFamily: AppTextStyles.fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 20,
    height: 23 / 20,
    color: AppColors.primaryDark,
  );

  // §9g primary filled: radius 25, bg #165932, text Roboto 500/16 white, h 48
  static final _primaryButtonStyle = FilledButton.styleFrom(
    backgroundColor: AppColors.primaryDark,
    foregroundColor: AppColors.surface,
    minimumSize: const Size(double.infinity, 48),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadii.button)),
    ),
    textStyle: AppTextStyles.buttonLabel,
  );

  // §1 danger: #F54848 («Выход» in profile)
  static final _dangerButtonStyle = FilledButton.styleFrom(
    backgroundColor: const Color(0xFFF54848),
    foregroundColor: AppColors.surface,
    minimumSize: const Size(double.infinity, 48),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadii.button)),
    ),
    textStyle: AppTextStyles.buttonLabel,
  );

  @override
  void initState() {
    super.initState();
    _refreshBiometricSaved();
  }

  Future<void> _refreshBiometricSaved() async {
    final saved = await hasSavedBiometricSession(login: widget.adminLogin);
    if (!mounted) return;
    setState(() => _biometricSaved = saved);
  }

  Future<void> _saveForBiometric() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await saveCurrentSessionForBiometricLogin();
    if (!mounted) return;
    setState(() => _busy = false);
    await _refreshBiometricSaved();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Current admin session is saved for Face ID / Fingerprint login.'
                : 'Could not save biometric session. Please sign in online and try again.',
          ),
        ),
      );
  }

  Future<void> _logout() async {
    if (_busy) return;
    setState(() => _busy = true);
    final preserveBiometric = _biometricSaved;
    await logoutAdmin(clearSavedSession: !preserveBiometric);
    if (!mounted) return;
    setState(() => _busy = false);
    final s = S.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s.logoutButton)));
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<bool>(
          valueListenable: adminLoggedInNotifier,
          builder: (context, isAdmin, _) => Text(
            isAdmin ? s.adminPanelTitle : s.tabProfile,
            style: _titleStyle,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
            vertical: AppSpacing.xl,
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: adminLoggedInNotifier,
            builder: (context, isAdmin, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isAdmin) ...[
                    FilledButton.icon(
                      style: _primaryButtonStyle,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AdminUsersPage(
                              adminLogin: widget.adminLogin,
                              adminPassword: widget.adminPassword,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.people_alt_outlined),
                      label: Text(s.adminEditUsersList),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      style: _primaryButtonStyle,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AdminAddedRecipesPage(
                              adminLogin: widget.adminLogin,
                              adminPassword: widget.adminPassword,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.library_books_outlined),
                      label: const Text('Recipes added'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _saveForBiometric,
                    icon: Icon(
                      _biometricSaved
                          ? Icons.verified_user
                          : Icons.fingerprint,
                    ),
                    label: Text(
                      _biometricSaved
                          ? 'Face ID / Fingerprint is saved for admin login'
                          : 'Save admin login for Face ID / Fingerprint',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    style: _primaryButtonStyle,
                    onPressed: () {
                      // Return to the food cards list (root route with recipe feed).
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.restaurant_menu),
                    label: Text(s.adminEditCards),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    style: _dangerButtonStyle,
                    onPressed: _busy ? null : _logout,
                    icon: const Icon(Icons.logout),
                    label: Text(s.logoutButton),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
