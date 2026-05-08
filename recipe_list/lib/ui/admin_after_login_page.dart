import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/admin_session.dart';
import '../i18n.dart';
import '../router/routes.dart';
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
  final TextEditingController _newPasswordController = TextEditingController();
  bool _newPasswordObscured = true;
  bool _changingPassword = false;

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

  @override
  void dispose() {
    _newPasswordController.dispose();
    super.dispose();
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

  Future<void> _submitNewPassword() async {
    if (_changingPassword) return;
    final newPassword = _newPasswordController.text;
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Password must be at least 6 characters.'),
          ),
        );
      return;
    }
    setState(() => _changingPassword = true);
    final result = await changeUserPassword(newPassword);
    if (!mounted) return;
    setState(() => _changingPassword = false);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    switch (result) {
      case ChangePasswordResult.success:
        _newPasswordController.clear();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Password changed. A reminder has been emailed to you.',
            ),
          ),
        );
        break;
      case ChangePasswordResult.passwordTooShort:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Password must be at least 6 characters.'),
          ),
        );
        break;
      case ChangePasswordResult.notLoggedIn:
      case ChangePasswordResult.unauthorized:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please sign in again.'),
          ),
        );
        break;
      case ChangePasswordResult.networkError:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Network error. Please check your connection.'),
          ),
        );
        break;
      case ChangePasswordResult.serverError:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not change password. Please try again.'),
          ),
        );
        break;
    }
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
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
                      _biometricSaved ? Icons.verified_user : Icons.fingerprint,
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
                      // Open the recipes list (go_router root).
                      context.go(Routes.recipes);
                    },
                    icon: const Icon(Icons.restaurant_menu),
                    label: Text(s.adminEditCards),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (!isAdmin) ...[
                    const Divider(height: AppSpacing.xl * 2),
                    const Text(
                      'Change password',
                      style: TextStyle(
                        fontFamily: AppTextStyles.fontFamily,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: _newPasswordObscured,
                      enabled: !_changingPassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submitNewPassword(),
                      decoration: InputDecoration(
                        labelText: 'New password',
                        helperText:
                            'Min 6 characters. We will email it to you as a reminder.',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _newPasswordObscured
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () => setState(
                            () => _newPasswordObscured = !_newPasswordObscured,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      style: _primaryButtonStyle,
                      onPressed: _changingPassword ? null : _submitNewPassword,
                      icon: _changingPassword
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.surface,
                              ),
                            )
                          : const Icon(Icons.lock_reset),
                      label: const Text('Change password'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
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
        ),
      ),
    );
  }
}
