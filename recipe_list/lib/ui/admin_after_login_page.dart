import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../auth/admin_session.dart';
import '../auth/passkey_api.dart' as passkey_api;
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
    // This page assumes an admin session. If the admin context
    // disappears while we are mounted (e.g. a 401 on a write
    // action triggered logoutAdmin), pop ourselves so the user
    // does not see a non-admin variant of an admin-only page.
    // The dead `if (!isAdmin)` rejected-design password block
    // that used to render here was removed in commit
    // <pending>; this guard makes sure no other future
    // non-admin branch can leak through.
    adminLoggedInNotifier.addListener(_handleAdminLoggedInChanged);
  }

  void _handleAdminLoggedInChanged() {
    if (!mounted) return;
    if (!adminLoggedInNotifier.value) {
      // Capture any diagnostic record published by the caller
      // (rating pill 401, restoreAdminSession failure, manual
      // logout, ...) before popping ourselves. Surface the full
      // dump as a long-duration snackbar with a Copy action so
      // we can collect it from the field next time.
      final loss = adminSessionLossNotifier.value;
      _showSessionLossSnackBar(loss);
      // This page can be rendered both by go_router (`/profile` branch)
      // and by legacy imperative Navigator pushes. `popUntil(isFirst)`
      // is a no-op for the routed branch root, leaving a dead non-admin
      // surface behind. Prefer canonical go_router relocation and keep
      // Navigator fallback for legacy callers.
      if (GoRouter.maybeOf(context) != null) {
        context.go(Routes.profile);
      } else {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    }
  }

  void _showSessionLossSnackBar(AdminSessionLossEvent? loss) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final headline = loss == null
        ? 'Admin session ended'
        : 'Admin session ended: ${loss.toShortString()}';
    final fullDump = loss?.toDiagnosticString();
    if (fullDump != null) {
      developer.log(fullDump, name: 'admin_after_login_page', level: 900);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(headline),
          duration: const Duration(seconds: 12),
          action: fullDump == null
              ? null
              : SnackBarAction(
                  label: 'Copy details',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: fullDump));
                    if (!mounted) return;
                    final m = ScaffoldMessenger.maybeOf(context);
                    m?.showSnackBar(
                      const SnackBar(
                        content: Text('Diagnostic copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
        ),
      );
  }

  @override
  void dispose() {
    adminLoggedInNotifier.removeListener(_handleAdminLoggedInChanged);
    super.dispose();
  }

  Future<void> _refreshBiometricSaved() async {
    try {
      final saved = await hasSavedBiometricSession(login: widget.adminLogin);
      if (!mounted) return;
      setState(() => _biometricSaved = saved);
    } catch (e) {
      // Best-effort check only — never crash the admin page because of
      // local credential-store read issues.
      debugPrint('[AdminAfterLoginPage] _refreshBiometricSaved failed: $e');
      if (!mounted) return;
      setState(() => _biometricSaved = false);
    }
  }

  Future<void> _saveForBiometric() async {
    if (_busy) return;
    setState(() => _busy = true);

    if (kIsWeb) {
      // Web: register a WebAuthn passkey for the admin token so that
      // the browser's platform authenticator can sign subsequent logins.
      // Same mechanism as user_card_page._addPasskey().
      final token = currentRecipeAdminTokenNotifier.value;
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Could not save passkey: no admin token available.',
              ),
            ),
          );
        return;
      }
      if (!passkey_api.isPasskeySupported) {
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Passkeys are not supported in this browser.'),
            ),
          );
        return;
      }
      try {
        await passkey_api.registerPasskey(token: token);
        if (!mounted) return;
        setState(() {
          _busy = false;
          _biometricSaved = true;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Passkey registered. Sign in with Face ID / Fingerprint next time.',
              ),
            ),
          );
      } catch (e) {
        debugPrint('[AdminAfterLoginPage] registerPasskey failed: $e');
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Could not register passkey: $e')),
          );
      }
      return;
    }

    // Native (iOS / Android): persist token to local SQLite credential store.
    bool ok = false;
    try {
      ok = await saveCurrentSessionForBiometricLogin();
    } catch (e) {
      debugPrint('[AdminAfterLoginPage] _saveForBiometric failed: $e');
      ok = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    try {
      await _refreshBiometricSaved();
    } catch (_) {
      // _refreshBiometricSaved is already guarded; keep flow resilient.
    }
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
    await logoutAdmin(
      clearSavedSession: !preserveBiometric,
      lossEvent: AdminSessionLossEvent(
        reason: 'User tapped Logout in AdminAfterLoginPage',
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    final s = S.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s.logoutButton)));
    if (!mounted) return;
    if (GoRouter.maybeOf(context) != null) {
      context.go(Routes.recipes);
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
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
                  if (!isAdmin) {
                    // Non-admin rendering of this page is unsupported.
                    // `_handleAdminLoggedInChanged` schedules navigation
                    // away; keep the intermediate frame inert.
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                          // Open the recipes list (go_router root).
                          context.go(Routes.recipes);
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
        ),
      ),
    );
  }
}
