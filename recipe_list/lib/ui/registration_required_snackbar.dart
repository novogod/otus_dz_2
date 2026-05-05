import 'dart:async';

import 'package:flutter/material.dart';

import '../i18n.dart';
import 'login_page.dart' show openLoginPage;
import 'signup_page.dart' show openSignUpPage;

/// Длительность авто-дисмисса snackbar-а «Registration required».
const Duration kRegistrationRequiredSnackBarDuration = Duration(seconds: 4);

/// Показать snackbar «Registration required for this feature, please tap
/// Sign Up button» с гарантированным авто-закрытием через 4 с.
///
/// Почему не используем родной таймер `ScaffoldMessenger`-а:
/// после переезда на `StatefulShellRoute.indexedStack` в дереве
/// одновременно зарегистрированы 2–3 `Scaffold`-а
/// (`AppShell` + текущая ветка + при наличии `LoginPage`,
/// который пушится на root-навигатор). Каждый раз, когда меняется
/// топ-приоритетный `Scaffold` (например, пользователь нажал
/// «Sign Up» и поверх открылся signup), `ScaffoldMessenger`
/// перетаскивает snackbar на новый host и **сбрасывает**
/// slide-in-анимацию. Auto-dismiss-таймер мессенджера запускается
/// только при `AnimationStatus.completed`; если анимация
/// постоянно сбрасывается, таймер никогда не стартует и
/// snackbar «висит вечно». Чтобы это обойти, держим собственный
/// `Timer` на 4 с, который форсирует
/// `ScaffoldFeatureController.close()`.
void showRegistrationRequiredSnackBar(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  final s = S.of(context);
  // На всякий случай убираем уже висящий snackbar, если есть.
  messenger.removeCurrentSnackBar();

  late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
  controller;
  // Лимитный таймер: закроет snackbar даже если внутренняя
  // анимация ScaffoldMessenger-а никогда не доехала до
  // `completed` (см. doc-comment выше).
  late final Timer dismissTimer;

  controller = messenger.showSnackBar(
    SnackBar(
      // Длительность тоже задаём — на случай, если мессенджер
      // всё-таки доедет до `completed` раньше нашего таймера,
      // он закроет сам в эту же секунду.
      duration: kRegistrationRequiredSnackBarDuration,
      content: Text(s.favoritesRegistrationRequired(button: s.signUp)),
      action: SnackBarAction(
        label: s.signUp,
        onPressed: () async {
          dismissTimer.cancel();
          messenger.removeCurrentSnackBar();
          final created = await openSignUpPage(context);
          if (!context.mounted || !created) return;
          await openLoginPage(context);
        },
      ),
    ),
  );
  dismissTimer = Timer(kRegistrationRequiredSnackBarDuration, () {
    // `close()` форсирует закрытие независимо от текущего
    // состояния анимации.
    controller.close();
  });
  // Если snackbar закрылся «своим ходом» (тап по action / другой
  // показ) — отменяем наш страховочный таймер, чтобы он не
  // дёргал closed-ноль раз.
  controller.closed.whenComplete(dismissTimer.cancel);
}
