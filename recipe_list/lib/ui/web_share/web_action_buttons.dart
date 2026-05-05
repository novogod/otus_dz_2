import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
  if (!kIsWeb) return _kShareBaseUrl;
  final base = Uri.base;
  final host = base.host;
  if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
    return _kShareBaseUrl;
  }
  return '${base.origin}/';
}

Future<void> _open(Uri u) async {
  await launchUrl(u, mode: LaunchMode.externalApplication);
}

Future<void> _shareFacebook() async {
  final url = Uri.encodeComponent(_shareUrl());
  await _open(Uri.parse('https://www.facebook.com/sharer/sharer.php?u=$url'));
}

Future<void> _shareVk() async {
  final url = Uri.encodeComponent(_shareUrl());
  final title = Uri.encodeComponent(_kShareTitle);
  final desc = Uri.encodeComponent(_kShareText);
  await _open(
    Uri.parse(
      'https://vk.com/share.php?url=$url&title=$title&description=$desc',
    ),
  );
}

Future<void> _shareWhatsApp() async {
  final text = Uri.encodeComponent('$_kShareText ${_shareUrl()}');
  await _open(Uri.parse('https://api.whatsapp.com/send?text=$text'));
}

Future<void> _shareInstagram(BuildContext context) async {
  // Instagram has no web share-by-URL endpoint. Best-effort: copy
  // the link to clipboard and open instagram.com so the user can
  // paste into a story/DM.
  await Clipboard.setData(ClipboardData(text: _shareUrl()));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Link copied. Open Instagram → New post / Story → paste.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
  }
  await _open(Uri.parse('https://www.instagram.com/'));
}

/// Round-button row rendered next to the language / reload buttons
/// in the recipes AppBar. Web-only — on iOS/Android the platform
/// already exposes Share / Add-to-Home-Screen via the system UI,
/// so the row collapses to nothing.
class WebActionButtons extends StatelessWidget {
  const WebActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    // Hide on phone-sized viewports (both narrow web layouts and
    // phone-sized PWA installs). Tablets and desktops keep the row.
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    if (shortestSide < 600) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PwaInstallButton(),
        const SizedBox(width: AppSpacing.sm),
        _CircleButton(
          tooltip: 'Share on Facebook',
          background: const Color(0xFF1877F2),
          onTap: _shareFacebook,
          child: const _GlyphText('f', fontSize: 22, weight: FontWeight.w900),
        ),
        const SizedBox(width: AppSpacing.sm),
        _CircleButton(
          tooltip: 'Copy link & open Instagram',
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF58529), Color(0xFFDD2A7B), Color(0xFF8134AF)],
          ),
          onTap: () => _shareInstagram(context),
          child: const Icon(
            Icons.camera_alt_outlined,
            size: 22,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _CircleButton(
          tooltip: 'Share on VK',
          background: const Color(0xFF0077FF),
          onTap: _shareVk,
          child: const _GlyphText('VK', fontSize: 13, weight: FontWeight.w900),
        ),
        const SizedBox(width: AppSpacing.sm),
        _CircleButton(
          tooltip: 'Share on WhatsApp',
          background: const Color(0xFF25D366),
          onTap: _shareWhatsApp,
          child: const Icon(Icons.chat_bubble, size: 18, color: Colors.white),
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
    return ValueListenableBuilder<bool>(
      valueListenable: pwaInstallAvailable,
      builder: (context, available, _) {
        if (!available) return const SizedBox.shrink();
        return _CircleButton(
          tooltip: 'Install as app',
          background: AppColors.surfaceMuted,
          border: const BorderSide(width: 1, color: Colors.black),
          onTap: () => triggerPwaInstall(),
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

class _CircleButton extends StatelessWidget {
  final String tooltip;
  final Color? background;
  final Gradient? gradient;
  final BorderSide border;
  final VoidCallback onTap;
  final Widget child;

  const _CircleButton({
    required this.tooltip,
    this.background,
    this.gradient,
    this.border = BorderSide.none,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final core = Material(
      color: gradient == null
          ? (background ?? AppColors.surfaceMuted)
          : Colors.transparent,
      shape: CircleBorder(side: border),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: gradient != null
            ? BoxDecoration(shape: BoxShape.circle, gradient: gradient)
            : null,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Center(child: child)),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(message: tooltip, child: core),
    );
  }
}

class _GlyphText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight weight;
  const _GlyphText(this.text, {required this.fontSize, required this.weight});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: weight,
        height: 1,
        fontFamily: 'Roboto',
        // Tighten so 'VK' fits on a 40-circle without baseline drift.
        letterSpacing: -0.5,
      ),
    );
  }
}
