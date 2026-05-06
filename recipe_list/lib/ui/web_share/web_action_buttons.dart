import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../i18n.dart';
import '../../models/recipe.dart';
import '../app_theme.dart';
import 'pwa_install.dart';

/// Public-facing share URL. We always share the production landing
/// page, even when the app is opened on `localhost` for dev — sending
/// a localhost link to a friend is useless.
const String _kShareBaseUrl = 'https://recipies.mahallem.ist/';
const String _kShareOrigin = 'https://recipies.mahallem.ist';

const String _kShareTitle = 'Otus Food';
const String _kShareText =
    'Check out Otus Food — recipes from around the world!';

/// Bag of overrides that lets a single share entry-point deliver
/// either the app-level landing page (used by the AppBar share
/// button) or a per-recipe deep-link (used by the share badge on
/// each recipe card). All three fields are optional; absent fields
/// fall back to the app-level defaults.
class _ShareContent {
  const _ShareContent({this.url, this.title, this.text});
  final String? url;
  final String? title;
  final String? text;
}

String _shareUrl([_ShareContent? c]) {
  if (c?.url != null && c!.url!.isNotEmpty) return c.url!;
  final base = Uri.base;
  final host = base.host;
  if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
    return _kShareBaseUrl;
  }
  return '${base.origin}/';
}

String _shareTitle([_ShareContent? c]) =>
    (c?.title?.isNotEmpty ?? false) ? c!.title! : _kShareTitle;

String _shareText([_ShareContent? c]) =>
    (c?.text?.isNotEmpty ?? false) ? c!.text! : _kShareText;

/// Build a per-recipe share URL on the public production origin.
/// Always uses `https://recipies.mahallem.ist` (never localhost),
/// and includes the current app language so the receiver lands on
/// the same translation the sender saw.
String _recipeShareUrl(int id, String langCode) =>
    '$_kShareOrigin/$langCode/recipes/$id';

Future<void> _systemShare({
  Rect? sharePositionOrigin,
  _ShareContent? content,
}) async {
  // SharePlus picks the right transport per platform:
  //  - iOS / Android: native UIActivityViewController / ACTION_SEND
  //    (lists every installed app: Instagram, WhatsApp, Messages…)
  //  - Web (Safari/Chrome/Edge with navigator.share): system share sheet
  //
  // On iPad UIActivityViewController is presented as a popover and
  // iPadOS *requires* an anchor `CGRect` — without
  // `sharePositionOrigin` the system call silently no-ops (or in
  // some iPadOS versions throws an exception caught by share_plus).
  // We pass the share button's global rect so the popover hangs
  // off it; harmless on iPhone/Android (ignored).
  final url = _shareUrl(content);
  final title = _shareTitle(content);
  final text = _shareText(content);
  await SharePlus.instance.share(
    ShareParams(
      title: title,
      text: '$text $url',
      uri: Uri.parse(url),
      subject: title,
      sharePositionOrigin: sharePositionOrigin,
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
List<_ShareTarget> _socialTargets(
  BuildContext context, {
  _ShareContent? content,
}) {
  final s = S.of(context);
  final url = _shareUrl(content);
  final urlEnc = Uri.encodeComponent(url);
  final title = Uri.encodeComponent(_shareTitle(content));
  final text = Uri.encodeComponent(_shareText(content));
  final textWithUrl = Uri.encodeComponent('${_shareText(content)} $url');
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

Future<void> _onShareTap(BuildContext context, {_ShareContent? content}) async {
  // On native iOS/Android the system share sheet is reliable and
  // surfaces every installed app, so we keep it there.
  if (!kIsWeb) {
    // Compute the global rect of the tapped share button — used as
    // anchor for the iPad popover. On iPhone/Android the value is
    // ignored.
    final box = context.findRenderObject() as RenderBox?;
    Rect? origin;
    if (box != null && box.hasSize) {
      final topLeft = box.localToGlobal(Offset.zero);
      origin = topLeft & box.size;
    }
    await _systemShare(sharePositionOrigin: origin, content: content);
    return;
  }
  // On web we ALWAYS show our own dropdown of social-network URL
  // intents. Reasons:
  //  1. navigator.share is missing on Linux Chrome, Firefox desktop,
  //     older Edge and any non-https origin.
  //  2. Even where it exists (Safari, Chrome on Win/macOS), the call
  //     must run synchronously inside the original click event to
  //     keep "transient user activation". Going through share_plus's
  //     async chain can drop that activation, in which case Safari
  //     and Chrome silently no-op and the user sees nothing happen.
  // The dropdown entries are plain https deep-links, so they open
  // the corresponding native app on mobile (WhatsApp/Telegram/…)
  // and the network's web composer on desktop. Preview cards on the
  // recipient side render from the og:image / og:title /
  // og:description meta tags in web/index.html.
  await _showShareMenu(context, content: content);
}

Future<void> _showShareMenu(
  BuildContext context, {
  _ShareContent? content,
}) async {
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
  final targets = _socialTargets(context, content: content);
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
      await Clipboard.setData(ClipboardData(text: _shareUrl(content)));
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
      // 1px primary-green border around the whole modal, matching
      // the rest of the app's accent colour. Default AlertDialog
      // corner radius is 28.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: AppColors.primary, width: 1),
      ),
      title: Text(
        s.pwaInstallTitle,
        style: const TextStyle(color: AppColors.textPrimary),
      ),
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
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '•  ',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                Expanded(
                  child: Text(
                    step,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
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

/// Public entry-point: share a specific [recipe]. Used by the
/// share badge anchored to the top-left of every recipe card.
/// Mirrors the behaviour of the AppBar share button (system share
/// sheet on iOS/Android, social-network dropdown on web), but the
/// payload is a deep-link to the recipe's details page on the
/// public production origin (`https://recipies.mahallem.ist`) in
/// the current app language.
Future<void> shareRecipe(BuildContext context, Recipe recipe) {
  final langCode = appLang.value.name;
  final url = _recipeShareUrl(recipe.id, langCode);
  final name = recipe.name;
  final title = name.isNotEmpty ? '$name — $_kShareTitle' : _kShareTitle;
  final text = name.isNotEmpty ? 'Check out "$name" on Otus Food' : _kShareText;
  return _onShareTap(
    context,
    content: _ShareContent(url: url, title: title, text: text),
  );
}
