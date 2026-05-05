import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../i18n.dart';
import '../app_theme.dart';
import 'pwa_install.dart';

/// Public-facing share URL. We always share the production landing
/// page, even when the app is opened on `localhost` for dev — sending
/// a localhost link to a friend is useless.
const String _kShareBaseUrl = 'https://recipies.mahallem.ist/';

const String _kShareTitle = 'Otus Food';
const String _kShareText =
    'Check out Otus Food — recipes from around the world!';

String _shareUrl() {
  final base = Uri.base;
  final host = base.host;
  if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
    return _kShareBaseUrl;
  }
  return '${base.origin}/';
}

Future<void> _share() async {
  // SharePlus picks the right transport per platform:
  //  - iOS / Android: native UIActivityViewController / ACTION_SEND
  //    (lists every installed app: Instagram, WhatsApp, Messages…)
  //  - Web (Safari/Chrome/Edge with navigator.share): system share sheet
  //  - Desktop / unsupported web: writes to clipboard via the plugin.
  await SharePlus.instance.share(
    ShareParams(
      title: _kShareTitle,
      text: '$_kShareText ${_shareUrl()}',
      uri: Uri.parse(_shareUrl()),
      subject: _kShareTitle,
    ),
  );
}

/// Single share button rendered next to the language / reload buttons
/// in the recipes AppBar. Visible on every platform — taps open the
/// OS-native share sheet so the user can pick whichever app they like
/// (Instagram, WhatsApp, Messages, Mail, Telegram, …).
class WebActionButtons extends StatelessWidget {
  const WebActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PwaInstallButton(),
        const SizedBox(width: AppSpacing.sm),
        _CircleButton(
          tooltip: 'Share',
          background: AppColors.surfaceMuted,
          border: const BorderSide(width: 1, color: Colors.black),
          onTap: _share,
          child: const Icon(
            Icons.share,
            size: 22,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }
}

class _PwaInstallButton extends StatelessWidget {
  const _PwaInstallButton();

  @override
  Widget build(BuildContext context) {
    // Hide entirely off-web (iOS/Android apps are already installed)
    // and when the page is already running as an installed PWA.
    if (!kIsWeb) return const SizedBox.shrink();
    if (isPwaStandaloneWeb()) return const SizedBox.shrink();

    final s = S.of(context);
    final isIos = isIosBrowserWeb();
    return ValueListenableBuilder<bool>(
      valueListenable: pwaInstallAvailable,
      builder: (context, available, _) {
        // Show the button when the browser captured the prompt
        // (Android Chrome / Edge / Desktop Chrome) OR when running
        // on iOS Safari/Chrome where the prompt API is unavailable
        // and we fall back to manual instructions.
        if (!available && !isIos) return const SizedBox.shrink();
        return _CircleButton(
          tooltip: s.pwaInstallTooltip,
          background: AppColors.surfaceMuted,
          border: const BorderSide(width: 1, color: Colors.black),
          onTap: () {
            if (available) {
              triggerPwaInstall();
            } else {
              _showIosInstallInstructions(context);
            }
          },
          child: const Icon(
            Icons.install_desktop,
            size: 22,
            color: AppColors.primaryDark,
          ),
        );
      },
    );
  }
}

/// Modal shown on iOS Safari/Chrome where `beforeinstallprompt` is
/// unavailable. Walks the user through the manual Add-to-Home-Screen
/// flow for both browsers. Body is fully translated via slang.
Future<void> _showIosInstallInstructions(BuildContext context) {
  final s = S.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.pwaInstallTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _InstructionsBlock(
              heading: s.pwaInstallSafariTitle,
              steps: [
                s.pwaInstallSafariStep1,
                s.pwaInstallSafariStep2,
                s.pwaInstallSafariStep3,
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _InstructionsBlock(
              heading: s.pwaInstallChromeTitle,
              steps: [
                s.pwaInstallChromeStep1,
                s.pwaInstallChromeStep2,
                s.pwaInstallChromeStep3,
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(s.pwaInstallGotIt),
        ),
      ],
    ),
  );
}

class _InstructionsBlock extends StatelessWidget {
  final String heading;
  final List<String> steps;

  const _InstructionsBlock({required this.heading, required this.steps});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(step, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final String tooltip;
  final Color? background;
  final BorderSide border;
  final VoidCallback onTap;
  final Widget child;

  const _CircleButton({
    required this.tooltip,
    this.background,
    this.border = BorderSide.none,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final core = Material(
      color: background ?? AppColors.surfaceMuted,
      shape: CircleBorder(side: border),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Center(child: child)),
      ),
    );
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(message: tooltip, child: core),
    );
  }
}
