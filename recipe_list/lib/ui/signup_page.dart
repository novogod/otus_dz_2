import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../auth/admin_session.dart';
import '../i18n.dart';
import 'app_theme.dart';
import 'splash_page.dart';

Future<bool> openSignUpPage(BuildContext context) async {
  final created = await Navigator.of(context).push<bool>(_signUpRoute());
  return created ?? false;
}

Route<bool> _signUpRoute() {
  return PageRouteBuilder<bool>(
    transitionDuration: AppDurations.splashTransition,
    reverseTransitionDuration: AppDurations.splashTransition,
    pageBuilder: (context, animation, secondaryAnimation) => const SignUpPage(),
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

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = S.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_busy) return;
    setState(() => _busy = true);
    final result = await signUpUser(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();

    switch (result) {
      case SignUpResult.success:
        messenger.showSnackBar(SnackBar(content: Text(s.signUpSuccess)));
        Navigator.of(context).pop(true);
        return;
      case SignUpResult.invalidEmail:
        messenger.showSnackBar(SnackBar(content: Text(s.signUpInvalidEmail)));
      case SignUpResult.duplicate:
        messenger.showSnackBar(SnackBar(content: Text(s.signUpDuplicateUser)));
      case SignUpResult.senderError:
        messenger.showSnackBar(SnackBar(content: Text(s.signUpSenderError)));
      case SignUpResult.networkError:
      case SignUpResult.serverError:
        messenger.showSnackBar(SnackBar(content: Text(s.signUpError)));
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
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: s.signUpName,
                              fillColor: AppColors.surface,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? s.addRecipeRequired
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _emailController,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: s.signUpEmail,
                              fillColor: AppColors.surface,
                            ),
                            validator: (v) {
                              final email = (v ?? '').trim();
                              if (email.isEmpty) {
                                return s.addRecipeRequired;
                              }
                              if (!email.contains('@')) {
                                return s.signUpInvalidEmail;
                              }
                              final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                              if (!re.hasMatch(email)) {
                                return s.signUpInvalidEmail;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: s.signUpPassword,
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
                              if (v == null || v.isEmpty) {
                                return s.addRecipeRequired;
                              }
                              if (v.length < 4) return s.signUpPasswordTooShort;
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
                              child: Text(s.signUpButton),
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
