import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

Future<void> _systemShare() async {
  // SharePlus picks the right transport per platform:
  //  - iOS / Android: native UIActivityViewController / ACTION_SEND
  //    (lists every installed app: Instagram, WhatsApp, Messages…)
  //  - Web (Safari/Chrome/Edge with navigator.share): system share sheet
  await SharePlus.instance.share(
    ShareParams(
      title: _kShareTitle,
      text: '$_kShareText ${_shareUrl()}',
      uri: Uri.parse(_shareUrl()),
      subject: _kShareTitle,
    ),
  );
}

Future<void> _open(Uri u) async {
  await launchUrl(u, mode: LaunchMode.externalApplication);
}

/// Fixed list of network share-via-URL intents, in display order.
/// All entries open in a new tab and pull the page's og:image / title
/// from `web/index.html` to render the preview card on the recipient
/// side (just like WhatsApp link previews).
List<_ShareTarget> _socialTargets(BuildContext context) {
  final s = S.of(context);
  final url = _shareUrl();
  final urlEnc = Uri.encodeComponent(url);
  final title = Uri.encodeComponent(_kShareTitle);
  final text = Uri.encodeComponent(_kShareText);
  final textWithUrl = Uri.encodeComponent('$_kShareText $url');
  return [
    _ShareTarget(
      label: 'WhatsApp',
      bg: const Color(0xFF25D366),
      icon: const Icon(Icons.chat_bubble, size: 18, color: Colors.white),
      uri: Uri.parse('https://wa.me/?text=$textWithUrl'),
    ),
    _ShareTarget(
      label: 'Telegram',
      bg: const Color(0xFF0088CC),
      icon: const Icon(Icons.send, size: 18, color: Colors.white),
      uri: Uri.parse('https://t.me/share/url?url=$urlEnc&text=$text'),
    ),
    _ShareTarget(
      label: 'Facebook',
      bg: const Color(0xFF1877F2),
      icon: const _GlyphText('f', fontSize: 22, weight: FontWeight.w900),
      uri: Uri.parse('https://www.facebook.com/sharer/sharer.php?u=$urlEnc'),
    ),
    _ShareTarget(
      label: 'X',
      bg: Colors.black,
      icon: const _GlyphText('𝕏', fontSize: 18, weight: FontWeight.w900),
      uri: Uri.parse('https://twitter.com/intent/tweet?url=$urlEnc&text=$text'),
    ),
    _ShareTarget(
      label: 'Reddit',
      bg: const Color(0xFFFF4500),
      icon: const _GlyphText('R', fontSize: 18, weight: FontWeight.w900),
      uri: Uri.parse('https://www.reddit.com/submit?url=$urlEnc&title=$title'),
    ),
    _ShareTarget(
      label: 'LinkedIn',
      bg: const Color(0xFF0A66C2),
      icon: const _GlyphText('in', fontSize: 13, weight: FontWeight.w900),
      uri: Uri.parse(
        'https://www.linkedin.com/sharing/share-offsite/?url=$urlEnc',
      ),
    ),
    _ShareTarget(
      label: 'VK',
      bg: const Color(0xFF0077FF),
      icon: const _GlyphText('VK', fontSize: 13, weight: FontWeight.w900),
      uri: Uri.parse(
        'https://vk.com/share.php?url=$urlEnc&title=$title&description=$text',
      ),
    ),
    _ShareTarget(
      label: 'Pinterest',
      bg: const Color(0xFFE60023),
      icon: const _GlyphText('P', fontSize: 18, weight: FontWeight.w900),
      uri: Uri.parse(
        'https://pinterest.com/pin/create/button/?url=$urlEnc&description=$text',
      ),
    ),
    _ShareTarget(
      label: s.shareEmail,
      bg: AppColors.primaryDark,
      icon: const Icon(Icons.email, size: 18, color: Colors.white),
      uri: Uri.parse('mailto:?subject=$title&body=$textWithUrl'),
    ),
    _ShareTarget(
      label: s.shareCopyLink,
      bg: AppColors.surfaceMuted,
      iconColor: AppColors.primaryDark,
      icon: const Icon(Icons.link, size: 20, color: AppColors.primaryDark),
      copyToClipboard: true,
    ),
  ];
}

class _ShareTarget {
  final String label;
  final Color bg;
  final Color iconColor;
  final Widget icon;
  final Uri? uri;
  final bool copyToClipboard;

  const _ShareTarget({
    required this.label,
    required this.bg,
    required this.icon,
    this.iconColor = Colors.white,
    this.uri,
    this.copyToClipboard = false,
  });
}

Future<void> _onShareTap(BuildContext context) async {
  // 1) On iOS/Android and on web browsers that expose navigator.share
  //    (Android Chrome, iOS Safari, modern Edge, Win10+/macOS13+ Chrome)
  //    let the OS render its native share sheet — that's what surfaces
  //    every installed app (Instagram, WhatsApp, Messages, …).
  if (!kIsWeb || canWebShareWeb()) {
    await _systemShare();
    return;
  }
  // 2) Otherwise (Linux Chrome, Firefox desktop, older Edge, …) the
  //    Web Share API isn't available, so share_plus would silently
  //    fall back to clipboard. Show our own dropdown of social-network
  //    URL intents instead — each opens the corresponding network in
  //    a new tab, pre-filled with the page link; previews render on
  //    the recipient side from the og:image / og:title / og:description
  //    meta tags in web/index.html.
  await _showShareMenu(context);
}

Future<void> _showShareMenu(BuildContext context) async {
  final box = context.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null) return;
  final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
  final position = RelativeRect.fromLTRB(
    origin.dx,
    origin.dy + box.size.height + 4,
    overlay.size.width - origin.dx - box.size.width,
    0,
  );
  final s = S.of(context);
  final targets = _socialTargets(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  await showMenu<int>(
    context: context,
    position: position,
    items: [
      for (var i = 0; i < targets.length; i++)
        PopupMenuItem<int>(
          value: i,
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: targets[i].bg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: targets[i].icon,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(targets[i].label),
            ],
          ),
        ),
    ],
  ).then((idx) async {
    if (idx == null) return;
    final t = targets[idx];
    if (t.copyToClipboard) {
      await Clipboard.setData(ClipboardData(text: _shareUrl()));
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(s.shareLinkCopied),
            duration: const Duration(seconds: 3),
          ),
        );
      return;
    }
    if (t.uri != null) {
      await _open(t.uri!);
    }
  });
}

/// Single share button rendered next to the language / reload buttons
/// in the recipes AppBar. Visible on every platform — taps open the
/// OS-native share sheet so the user can pick whichever app they like
/// (Instagram, WhatsApp, Messages, Mail, Telegram, …). On browsers
/// without the Web Share API, falls back to a popup menu of social
/// network URL intents.
class WebActionButtons extends StatelessWidget {
  const WebActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PwaInstallButton(),
        const SizedBox(width: AppSpacing.sm),
        Builder(
          builder: (innerContext) => _CircleButton(
            tooltip: s.shareTooltip,
            background: AppColors.surfaceMuted,
            border: const BorderSide(width: 1, color: Colors.black),
            onTap: () => _onShareTap(innerContext),
            child: const Icon(
              Icons.share,
              size: 22,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
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
        letterSpacing: -0.5,
      ),
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
