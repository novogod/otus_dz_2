import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../auth/admin_session.dart';
import '../i18n.dart';
import 'app_theme.dart';
import 'password_recovery_page.dart';
import 'signup_page.dart';
import 'splash_page.dart';

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
  bool _obscurePassword = true;
  bool _authBusy = false;
  ui.Image? _logoImage;

  @override
  void initState() {
    super.initState();
    final initialLogin = widget.initialLogin;
    if (initialLogin != null && initialLogin.trim().isNotEmpty) {
      _loginController.text = initialLogin.trim();
    }
    _loadImage();
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
    super.dispose();
  }

  Future<void> _submit() async {
    final s = S.of(context);
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.loginInvalidCredentials)));
      return;
    }
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
    Navigator.of(context).pop(true);
  }

  Future<void> _logout() async {
    if (_authBusy) return;
    setState(() => _authBusy = true);
    await logoutAdmin();
    if (!mounted) return;
    setState(() => _authBusy = false);
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
        await openPasswordRecoveryPage(
          context,
          email: email,
          recoverySessionCookie: result.sessionCookie ?? '',
        );
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
      builder: (context, loggedIn, _) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: kSplashGradient),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        SizedBox(
                          width: 260,
                          child: SplashMaskedLogo(image: _logoImage),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _loginController,
                                enabled: !loggedIn,
                                style: TextStyle(
                                  color: loggedIn
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                ),
                                textInputAction: TextInputAction.next,
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
                                controller: _passwordController,
                                enabled: !loggedIn,
                                style: TextStyle(
                                  color: loggedIn
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                ),
                                obscureText: _obscurePassword,
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
                                    backgroundColor: AppColors.primaryDark,
                                  ),
                                  onPressed: _authBusy
                                      ? null
                                      : (loggedIn ? _logout : _submit),
                                  child: Text(
                                    loggedIn ? s.logoutButton : s.loginButton,
                                  ),
                                ),
                              ),
                              if (!loggedIn) ...[
                                const SizedBox(height: AppSpacing.sm),
                                TextButton(
                                  onPressed: _authBusy ? null : _forgotPassword,
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
  }
}
