import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../auth/admin_session.dart';
import '../i18n.dart';
import 'admin_after_login_page.dart';
import 'app_theme.dart';
import 'password_recovery_page.dart';
import 'signup_page.dart';
import 'splash_page.dart';

Future<void> openProfilePage(
  BuildContext context, {
  String? prefillLogin,
}) async {
  final login = currentUserLoginNotifier.value?.trim();
  final password = currentSessionAdminPassword;
  final recipeAdminToken = currentRecipeAdminTokenNotifier.value;
  final hasRecipeAdminToken =
      recipeAdminToken != null && recipeAdminToken.isNotEmpty;

  final hasLogin = login != null && login.isNotEmpty;
  final canOpenWithPassword =
      password != null && password.isNotEmpty && hasLogin;
  final canOpenWithToken = hasRecipeAdminToken && hasLogin;
  final canOpenWithAdminFlag = adminLoggedInNotifier.value && hasLogin;
  final shouldOpenAdmin =
      adminLoggedInNotifier.value || canOpenWithToken || canOpenWithPassword;

  if (shouldOpenAdmin &&
      (canOpenWithToken || canOpenWithPassword || canOpenWithAdminFlag)) {
    await openAdminAfterLoginPage(
      context,
      adminLogin: login,
      // If token is already present, password can be empty. Network calls in
      // admin_session.dart reuse currentRecipeAdminTokenNotifier first.
      adminPassword: password ?? '',
      replaceCurrent: false,
    );
    return;
  }
  if (!context.mounted) return;
  await openLoginPage(
    context,
    prefillLogin: (prefillLogin != null && prefillLogin.trim().isNotEmpty)
        ? prefillLogin
        : login,
  );
  if (!context.mounted) return;

  // After LoginPage closes, check if user is now authenticated as admin.
  // If so, open the admin panel. This handles the post-login flow.
  final loginAfter = currentUserLoginNotifier.value?.trim();
  final passwordAfter = currentSessionAdminPassword;
  final tokenAfter = currentRecipeAdminTokenNotifier.value;
  final hasTokenAfter = tokenAfter != null && tokenAfter.isNotEmpty;
  final hasLoginAfter = loginAfter != null && loginAfter.isNotEmpty;
  final isAdminAfter = adminLoggedInNotifier.value && hasLoginAfter;

  if ((isAdminAfter || (hasTokenAfter && hasLoginAfter)) && context.mounted) {
    await openAdminAfterLoginPage(
      context,
      adminLogin: loginAfter,
      adminPassword: passwordAfter ?? '',
      replaceCurrent: false,
    );
  }
}

Future<void> openLoginPage(BuildContext context, {String? prefillLogin}) async {
  await Navigator.of(
    context,
  ).push<bool>(buildLoginRoute(prefillLogin: prefillLogin));
}

Route<bool> buildLoginRoute({String? prefillLogin}) {
  return PageRouteBuilder<bool>(
    transitionDuration: AppDurations.splashTransition,
    reverseTransitionDuration: AppDurations.splashTransition,
    pageBuilder: (context, animation, secondaryAnimation) =>
        LoginPage(initialLogin: prefillLogin),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curved);
      return SlideTransition(position: slide, child: child);
    },
  );
}

class LoginPage extends StatefulWidget {
  final String? initialLogin;

  const LoginPage({super.key, this.initialLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  late FocusNode _passwordFocusNode;
  bool _obscurePassword = true;
  bool _authBusy = false;
  bool _biometricSaved = false;
  ui.Image? _logoImage;

  @override
  void initState() {
    super.initState();
    _passwordFocusNode = FocusNode();
    final initialLogin = widget.initialLogin;
    if (initialLogin != null && initialLogin.trim().isNotEmpty) {
      _loginController.text = initialLogin.trim();
    }
    _loadImage();
    _refreshBiometricSavedStatus();
  }

  Future<void> _refreshBiometricSavedStatus() async {
    final saved = await hasSavedBiometricSession(
      login: currentUserLoginNotifier.value?.trim(),
    );
    if (!mounted) return;
    setState(() => _biometricSaved = saved);
  }

  Future<void> _loadImage() async {
    const provider = AssetImage('assets/images/splash_food.jpg');
    final stream = provider.resolve(ImageConfiguration.empty);
    final completer = Completer<ui.Image>();
    final listener = ImageStreamListener(
      (info, _) => completer.complete(info.image),
      onError: (e, st) => completer.completeError(e, st),
    );
    stream.addListener(listener);
    try {
      final img = await completer.future;
      if (!mounted) return;
      setState(() => _logoImage = img);
    } finally {
      stream.removeListener(listener);
    }
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_authBusy) return;
    setState(() => _authBusy = true);
    final ok = await loginAsAdmin(
      login: _loginController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _authBusy = false);
    if (!ok) {
      final s = S.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.loginInvalidCredentials)));
      return;
    }
    await _refreshBiometricSavedStatus();
    if (!mounted) return;
    final s = S.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            adminLoggedInNotifier.value
                ? s.loginSuccessAdmin
                : s.loginSuccessUser,
          ),
        ),
      );
    if (!context.mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _saveCurrentSessionForBiometric() async {
    if (_authBusy) return;
    if (!userLoggedInNotifier.value) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Biometric session save is not supported in web mode.',
            ),
          ),
        );
      return;
    }

    setState(() => _authBusy = true);
    final ok = await saveCurrentSessionForBiometricLogin();
    if (!mounted) return;
    setState(() => _authBusy = false);
    await _refreshBiometricSavedStatus();
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Current session is saved for Face ID / Fingerprint login.'
                : 'Could not save biometric session. Please sign in online and try again.',
          ),
        ),
      );
  }

  Future<void> _loginWithBiometrics() async {
    if (_authBusy) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Biometric authentication is not supported in web mode.',
            ),
          ),
        );
      return;
    }

    setState(() => _authBusy = true);
    final localAuth = LocalAuthentication();
    try {
      final canCheck =
          await localAuth.canCheckBiometrics ||
          await localAuth.isDeviceSupported();
      if (!canCheck) {
        if (!mounted) return;
        setState(() => _authBusy = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Face ID / Touch ID is not available on this device.',
              ),
            ),
          );
        return;
      }

      final authenticated = await localAuth.authenticate(
        localizedReason: 'Authenticate to sign in to Recipe List',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!authenticated) {
        if (!mounted) return;
        setState(() => _authBusy = false);
        return;
      }

      final restored = await loginWithSavedTokenSession();
      if (!mounted) return;
      setState(() => _authBusy = false);

      if (!restored) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'No saved biometric session found. Please sign in with login/password once.',
              ),
            ),
          );
        return;
      }

      if (adminLoggedInNotifier.value) {
        await openAdminAfterLoginPage(
          context,
          adminLogin: currentUserLoginNotifier.value?.trim() ?? '',
          adminPassword: '',
        );
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _authBusy = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Biometric authentication failed.')),
        );
    }
  }

  Future<void> _logout() async {
    if (_authBusy) return;
    setState(() => _authBusy = true);
    // For regular users we keep an explicitly saved biometric session token,
    // so "Logout" returns to login screen but still allows Face ID/
    // fingerprint sign-in later. Admin logout remains full-clear.
    final preserveBiometric = !adminLoggedInNotifier.value && _biometricSaved;
    await logoutAdmin(clearSavedSession: !preserveBiometric);
    if (!mounted) return;
    setState(() {
      _authBusy = false;
      _biometricSaved = preserveBiometric;
    });
    Navigator.of(context).pop(false);
  }

  Future<void> _forgotPassword() async {
    final s = S.of(context);
    if (_authBusy) return;

    final email = _loginController.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.passwordRecoveryEnterEmail)));
      return;
    }

    setState(() => _authBusy = true);
    final result = await requestPasswordRecovery(email: email);
    if (!mounted) return;
    setState(() => _authBusy = false);

    switch (result.result) {
      case PasswordRecoveryStartResult.success:
        final recoveredEmail = await openPasswordRecoveryPage(
          context,
          email: email,
        );
        if (!mounted) return;
        if (recoveredEmail != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(s.passwordRecoverySaved)));
        }
      case PasswordRecoveryStartResult.invalidEmail:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(s.passwordRecoveryInvalidEmail)),
          );
      case PasswordRecoveryStartResult.networkError:
      case PasswordRecoveryStartResult.serverError:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(s.passwordRecoveryRequestFailed)),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final disabledFill = AppColors.surfaceMuted.withValues(alpha: 0.9);
    final disabledBorder = AppColors.textSecondary.withValues(alpha: 0.45);
    return ValueListenableBuilder<bool>(
      valueListenable: userLoggedInNotifier,
      builder: (context, userLoggedIn, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: adminLoggedInNotifier,
          builder: (context, adminLoggedIn, _) {
            final loggedIn = userLoggedIn && !adminLoggedIn;
            return Scaffold(
              resizeToAvoidBottomInset: true,
              floatingActionButton: FloatingActionButton(
                backgroundColor: AppColors.primaryDark,
                elevation: 12,
                focusElevation: 12,
                hoverElevation: 14,
                highlightElevation: 18,
                onPressed: () => Navigator.of(context).pop(),
                child: const Icon(Icons.chevron_left, size: 28),
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.startTop,
              body: DecoratedBox(
                decoration: const BoxDecoration(gradient: kSplashGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 260,
                              child: SplashMaskedLogo(image: _logoImage),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Form(
                              key: _formKey,
                              child: SizedBox(
                                width: 320,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: loggedIn
                                          ? null
                                          : _loginController,
                                      initialValue: loggedIn
                                          ? (currentUserLoginNotifier.value ??
                                                '')
                                          : null,
                                      enabled: !loggedIn,
                                      style: TextStyle(
                                        color: loggedIn
                                            ? AppColors.textSecondary
                                            : AppColors.textPrimary,
                                      ),
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: loggedIn
                                          ? null
                                          : (_) {
                                              _passwordFocusNode.requestFocus();
                                            },
                                      decoration: InputDecoration(
                                        labelText: s.loginUsername,
                                        fillColor: loggedIn
                                            ? disabledFill
                                            : AppColors.surface,
                                        disabledBorder: OutlineInputBorder(
                                          borderRadius: const BorderRadius.all(
                                            Radius.circular(AppRadii.input),
                                          ),
                                          borderSide: BorderSide(
                                            color: disabledBorder,
                                          ),
                                        ),
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                          ? s.addRecipeRequired
                                          : null,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    TextFormField(
                                      focusNode: loggedIn
                                          ? null
                                          : _passwordFocusNode,
                                      controller: loggedIn
                                          ? null
                                          : _passwordController,
                                      initialValue: loggedIn
                                          ? '••••••••'
                                          : null,
                                      enabled: !loggedIn,
                                      style: TextStyle(
                                        color: loggedIn
                                            ? AppColors.textSecondary
                                            : AppColors.textPrimary,
                                      ),
                                      obscureText: loggedIn
                                          ? false
                                          : _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _submit(),
                                      decoration: InputDecoration(
                                        labelText: s.loginPassword,
                                        fillColor: loggedIn
                                            ? disabledFill
                                            : AppColors.surface,
                                        disabledBorder: OutlineInputBorder(
                                          borderRadius: const BorderRadius.all(
                                            Radius.circular(AppRadii.input),
                                          ),
                                          borderSide: BorderSide(
                                            color: disabledBorder,
                                          ),
                                        ),
                                        suffixIcon: loggedIn
                                            ? null
                                            : IconButton(
                                                onPressed: () {
                                                  setState(
                                                    () => _obscurePassword =
                                                        !_obscurePassword,
                                                  );
                                                },
                                                icon: Icon(
                                                  _obscurePassword
                                                      ? Icons.visibility_off
                                                      : Icons.visibility,
                                                ),
                                              ),
                                      ),
                                      validator: (v) => (v == null || v.isEmpty)
                                          ? s.addRecipeRequired
                                          : null,
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              AppColors.primaryDark,
                                          minimumSize: const Size(
                                            double.infinity,
                                            67,
                                          ),
                                        ),
                                        onPressed: _authBusy
                                            ? null
                                            : (loggedIn ? _logout : _submit),
                                        child: Text(
                                          loggedIn
                                              ? s.logoutButton
                                              : s.loginButton,
                                        ),
                                      ),
                                    ),
                                    if (loggedIn) ...[
                                      const SizedBox(height: AppSpacing.sm),
                                      OutlinedButton.icon(
                                        onPressed: _authBusy
                                            ? null
                                            : _saveCurrentSessionForBiometric,
                                        icon: Icon(
                                          _biometricSaved
                                              ? Icons.verified_user
                                              : Icons.fingerprint,
                                          size: 72,
                                        ),
                                        label: Text(
                                          _biometricSaved
                                              ? 'Face ID / Fingerprint is saved for login'
                                              : 'Save this login for Face ID / Fingerprint',
                                        ),
                                      ),
                                    ],
                                    if (!loggedIn) ...[
                                      const SizedBox(height: AppSpacing.sm),
                                      OutlinedButton.icon(
                                        onPressed: _authBusy
                                            ? null
                                            : _loginWithBiometrics,
                                        icon: const Icon(
                                          Icons.fingerprint,
                                          size: 72,
                                        ),
                                        label: const Text(
                                          'Sign in with Face ID / Fingerprint',
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      TextButton(
                                        onPressed: _authBusy
                                            ? null
                                            : _forgotPassword,
                                        child: Text(
                                          s.forgotPassword,
                                          style: AppTextStyles.secondaryLink,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: AppSpacing.sm),
                                    if (!loggedIn)
                                      TextButton(
                                        onPressed: () async {
                                          await openSignUpPage(context);
                                        },
                                        child: Text(
                                          s.signUp,
                                          style: AppTextStyles.secondaryLink,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
