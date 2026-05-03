import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../auth/admin_session.dart';
import '../i18n.dart';
import 'app_theme.dart';
import 'splash_page.dart';

Future<String?> openPasswordRecoveryPage(
  BuildContext context, {
  required String email,
  required String recoverySessionCookie,
}) {
  return Navigator.of(context).push<String>(
    PageRouteBuilder<String>(
      transitionDuration: AppDurations.splashTransition,
      reverseTransitionDuration: AppDurations.splashTransition,
      pageBuilder: (context, animation, secondaryAnimation) =>
          PasswordRecoveryPage(
            email: email,
            recoverySessionCookie: recoverySessionCookie,
          ),
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
    ),
  );
}

class PasswordRecoveryPage extends StatefulWidget {
  final String email;
  final String recoverySessionCookie;

  const PasswordRecoveryPage({
    super.key,
    required this.email,
    required this.recoverySessionCookie,
  });

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _busy = false;
  ui.Image? _logoImage;

  @override
  void initState() {
    super.initState();
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
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = S.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_busy) return;

    setState(() => _busy = true);
    final result = await resetPasswordWithCode(
      code: _codeController.text,
      newPassword: _newPasswordController.text,
      recoverySessionCookie: widget.recoverySessionCookie,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case PasswordResetResult.success:
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(s.passwordRecoverySaved)));
        Navigator.of(context).pop<String>(widget.email);
      case PasswordResetResult.invalidCode:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(s.passwordRecoveryInvalidCode)),
          );
      case PasswordResetResult.passwordTooShort:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(s.passwordRecoveryPasswordTooShort)),
          );
      case PasswordResetResult.sessionExpired:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(s.passwordRecoverySessionExpired)),
          );
      case PasswordResetResult.networkError:
      case PasswordResetResult.serverError:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(s.passwordRecoverySaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
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
      floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
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
                    SizedBox(
                      width: 260,
                      child: SplashMaskedLogo(image: _logoImage),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      s.passwordRecoveryTitle,
                      style: AppTextStyles.recipeTitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      s.passwordRecoveryInstruction,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.inputHint,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.secondaryLink,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: s.passwordRecoveryCodeLabel,
                              hintText: s.passwordRecoveryCodeHint,
                              fillColor: AppColors.surface,
                              counterText: '',
                            ),
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                                return s.passwordRecoveryInvalidCode;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: s.passwordRecoveryNewPassword,
                              fillColor: AppColors.surface,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if ((v ?? '').length < 6) {
                                return s.passwordRecoveryPasswordTooShort;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryDark,
                              ),
                              onPressed: _busy ? null : _submit,
                              child: Text(s.passwordRecoverySubmit),
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
  }
}
