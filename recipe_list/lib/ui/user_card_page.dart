// ignore_for_file: deprecated_member_use, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/admin_session.dart';
import '../data/api/recipe_api.dart';
import '../data/api/recipe_api_config.dart';
import '../data/app_services.dart';
import '../utils/imgproxy.dart';
import '../i18n.dart';
import '../router/routes.dart';
import 'app_theme.dart';
import 'photo_picker_sheet.dart';

/// User Card page (chunk D of docs/user-card-and-social-signals.md).
///
/// Renders the currently logged-in user's profile: avatar slot,
/// display name (= login email until backend `/recipes/users/me`
/// lands), preferred language picker, recipes-added count
/// (placeholder until backend exposes it), and a danger-styled
/// Logout button. Has two presentation modes:
///
///  * default: AppBar title `s.profileLabel`, Edit/Save toggles
///    bottom row.
///  * post-signup (`isPostSignup: true`): AppBar title
///    `s.profileFinishSetup`, Add/Skip buttons (Skip → recipes,
///    Add → save and go recipes). Used as the redirect target
///    after the signup-page success result.
///
/// Avatar upload is stubbed: tapping the camera FAB shows a
/// TODO snackbar — the matching backend endpoint and S3 bucket
/// (`food-avatars`) are tracked in §2 of the doc.
class UserCardPage extends StatefulWidget {
  const UserCardPage({
    super.key,
    this.initialEditMode = false,
    this.isPostSignup = false,
  });

  /// When true the page enters edit mode immediately so post-signup
  /// users see editable fields without an extra tap.
  final bool initialEditMode;

  /// When true the AppBar shows `s.profileFinishSetup` and the
  /// bottom row shows Skip/Add instead of Edit/Save.
  final bool isPostSignup;

  @override
  State<UserCardPage> createState() => _UserCardPageState();
}

class _UserCardPageState extends State<UserCardPage> {
  late final TextEditingController _nameController;
  late bool _editing;
  AppLang _selectedLang = appLang.value;
  bool _busy = false;
  UserProfileSnapshot? _profile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: currentUserLoginNotifier.value ?? '',
    );
    _editing = widget.initialEditMode || widget.isPostSignup;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final api = appServicesNotifier.value?.api;
    if (api == null) return;
    final snap = await api.fetchMyProfile();
    if (!mounted || snap == null) return;
    setState(() {
      _profile = snap;
      // Display name from server takes precedence over the login
      // pre-fill, but only when the user hasn't started editing.
      if (!_editing && (snap.displayName ?? '').isNotEmpty) {
        _nameController.text = snap.displayName!;
      }
      final fromServer = AppLang.values
          .where((l) => l.name == (snap.language ?? ''))
          .firstOrNull;
      if (fromServer != null) _selectedLang = fromServer;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Persist language change globally — this is wired to slang
    // and updates all visible UI (`AppLangScope` listens).
    if (_selectedLang != appLang.value) {
      cycleAppLangTo(_selectedLang);
    }
    // Push display name + language to the server. Failures are
    // surfaced as a snackbar but don't block the local change —
    // the next bootstrap will reconcile.
    final api = appServicesNotifier.value?.api;
    String? errorMessage;
    if (api != null) {
      try {
        final updated = await api.updateMyProfile(
          displayName: _nameController.text.trim(),
          language: _selectedLang.name,
        );
        if (mounted) {
          setState(
            () => _profile = UserProfileSnapshot(
              id: updated.id,
              email: updated.email,
              displayName: updated.displayName,
              language: updated.language,
              avatarPath: updated.avatarPath,
              avatarUrl: updated.avatarUrl,
              recipesAdded: _profile?.recipesAdded ?? 0,
              memberSince: updated.memberSince ?? _profile?.memberSince,
            ),
          );
        }
      } catch (e) {
        errorMessage = e.toString();
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _editing = false;
    });
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          errorMessage == null
              ? S.of(context).profileSavedToast
              : 'Save failed: $errorMessage',
        ),
      ),
    );
    if (widget.isPostSignup) {
      context.go(Routes.recipes);
    }
  }

  Future<void> _handleLogout() async {
    if (_busy) return;
    setState(() => _busy = true);
    await logoutAdmin(clearSavedSession: true);
    if (!mounted) return;
    context.go(Routes.recipes);
  }

  void _showAvatarPickerStub() {
    _pickAndUploadAvatar();
  }

  Future<void> _pickAndUploadAvatar() async {
    final api = appServicesNotifier.value?.api;
    if (api == null) return;
    final s = S.of(context);
    final action = await showPhotoPickerSheet(
      context,
      title: s.addRecipePhotoSourceTitle,
      cameraLabel: s.profilePhotoFromCamera,
      galleryLabel: s.profilePhotoFromGallery,
      removeLabel: (_profile?.avatarUrl ?? '').isNotEmpty
          ? s.profilePhotoRemove
          : null,
    );
    if (!mounted || action == null) return;
    final messenger = ScaffoldMessenger.of(context);
    if (action == PhotoPickerAction.remove) {
      try {
        await api.deleteAvatar();
        if (!mounted) return;
        setState(() {
          final p = _profile;
          if (p != null) {
            _profile = UserProfileSnapshot(
              id: p.id,
              email: p.email,
              displayName: p.displayName,
              language: p.language,
              avatarPath: null,
              avatarUrl: null,
              recipesAdded: p.recipesAdded,
              memberSince: p.memberSince,
            );
          }
        });
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Remove failed: $e')));
      }
      return;
    }
    final source = action == PhotoPickerAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    final picked = await pickAndCompressPhoto(
      source: source,
      onError: (err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo pick failed: ${err.name}')),
        );
      },
    );
    if (!mounted || picked == null) return;
    setState(() => _busy = true);
    try {
      final url = await api.uploadAvatar(
        bytes: picked.bytes,
        filename: picked.filename,
      );
      if (!mounted) return;
      setState(() {
        final p = _profile;
        if (p != null) {
          _profile = UserProfileSnapshot(
            id: p.id,
            email: p.email,
            displayName: p.displayName,
            language: p.language,
            avatarPath: url,
            avatarUrl: url,
            recipesAdded: p.recipesAdded,
            memberSince: p.memberSince,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final title = widget.isPostSignup ? s.profileFinishSetup : s.tabProfile;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: _AvatarSlot(
                  avatarUrl: _profile?.avatarUrl,
                  onTap: _editing ? _showAvatarPickerStub : null,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildDisplayNameField(s),
              const SizedBox(height: AppSpacing.md),
              _buildLanguagePicker(s),
              const SizedBox(height: AppSpacing.lg),
              _buildStats(s, theme),
              const SizedBox(height: AppSpacing.xl),
              _buildPrimaryRow(s),
              const SizedBox(height: AppSpacing.md),
              if (!widget.isPostSignup) _buildLogoutButton(s),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisplayNameField(S s) {
    return TextField(
      controller: _nameController,
      enabled: _editing,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: s.profileDisplayName,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildLanguagePicker(S s) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: s.profileLanguage,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 4,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLang>(
          isExpanded: true,
          value: _selectedLang,
          onChanged: _editing
              ? (lang) {
                  if (lang == null) return;
                  setState(() => _selectedLang = lang);
                }
              : null,
          items: AppLang.values
              .map(
                (lang) => DropdownMenuItem<AppLang>(
                  value: lang,
                  child: Text('${lang.flag}  ${lang.label}'),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildStats(S s, ThemeData /* unused */ _) {
    final memberSince = _profile?.memberSince;
    final memberSinceLabel = memberSince != null
        ? '${memberSince.year}-${memberSince.month.toString().padLeft(2, '0')}-${memberSince.day.toString().padLeft(2, '0')}'
        : '—';
    // Profile scaffold uses `surfaceMuted` (#ECECEC) — render stats
    // in `textPrimary` so the lines stay readable per
    // docs/design_system.md (no grey-on-grey).
    const statsStyle = TextStyle(
      fontFamily: AppTextStyles.fontFamily,
      fontWeight: FontWeight.w400,
      fontSize: 14,
      height: 23 / 14,
      color: AppColors.textPrimary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          s.profileRecipesAdded(n: _profile?.recipesAdded ?? 0),
          style: statsStyle,
        ),
        const SizedBox(height: 4),
        Text(s.profileMemberSince(date: memberSinceLabel), style: statsStyle),
      ],
    );
  }

  Widget _buildPrimaryRow(S s) {
    // Per docs/design_system.md §9g (and the user-card spec
    // §2.4) the primary CTA on the User Card is filled with
    // `primaryDark` (#165932) on white text, radius 25, h 48 —
    // not the pale-on-pale Material-3 ElevatedButton default
    // which collapses to surface-fill + primary-text on the
    // muted scaffold and fails contrast.
    final primaryStyle = ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryDark,
      foregroundColor: AppColors.surface,
      disabledBackgroundColor: AppColors.primaryDark.withValues(alpha: 0.6),
      disabledForegroundColor: AppColors.surface,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      textStyle: const TextStyle(
        fontFamily: AppTextStyles.fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
    );
    final outlineStyle = OutlinedButton.styleFrom(
      foregroundColor: AppColors.primaryDark,
      side: const BorderSide(color: AppColors.primaryDark, width: 1),
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      textStyle: const TextStyle(
        fontFamily: AppTextStyles.fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
    );
    if (widget.isPostSignup) {
      return Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton(
              style: outlineStyle,
              onPressed: _busy ? null : () => context.go(Routes.recipes),
              child: Text(s.profileSkip),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: ElevatedButton(
              style: primaryStyle,
              onPressed: _busy ? null : _handleSave,
              child: Text(s.profileAdd),
            ),
          ),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: primaryStyle,
        onPressed: _busy
            ? null
            : () {
                if (_editing) {
                  _handleSave();
                } else {
                  setState(() => _editing = true);
                }
              },
        child: Text(_editing ? s.profileSave : s.profileEdit),
      ),
    );
  }

  Widget _buildLogoutButton(S s) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        style: TextButton.styleFrom(foregroundColor: const Color(0xFFF54848)),
        onPressed: _busy ? null : _handleLogout,
        child: Text(s.profileLogout),
      ),
    );
  }
}

class _AvatarSlot extends StatelessWidget {
  const _AvatarSlot({this.onTap, this.avatarUrl});
  final VoidCallback? onTap;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    final hasAvatar = url != null && url.isNotEmpty;
    // Server returns a path like `/storage/v1/object/public/avatars/...`.
    // Resolve it against the recipes API origin AND route it through
    // imgproxy so the slot loads ~15-30 KB WebP instead of the
    // 300-700 KB JPEG written to the bucket. Recipe-card author chip
    // does the same via [imgproxyUrl] (see recipe_card.dart:851).
    String? fullUrl;
    if (hasAvatar) {
      String absolute;
      if (url.startsWith('http')) {
        absolute = url;
      } else {
        final base = RecipeApiConfig.mahallemBaseUrl;
        final origin = Uri.tryParse(base);
        if (origin != null) {
          absolute =
              '${origin.scheme}://${origin.host}'
              '${origin.hasPort ? ":${origin.port}" : ""}'
              '${url.startsWith('/') ? url : '/$url'}';
        } else {
          absolute = url;
        }
      }
      // 240 dp slot @ ~3x DPR ≈ 720 px — keep imgproxy resize at 480
      // (it serves WebP, browser/iOS scales final 120-dp slot).
      fullUrl = imgproxyUrl(absolute, 480, 480);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
          width: 120,
          height: 120,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 3),
          ),
          child: hasAvatar && fullUrl != null
              ? Image.network(
                  fullUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.person,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                )
              : (onTap != null
                    ? const SizedBox.shrink()
                    : const Icon(
                        Icons.person,
                        size: 64,
                        color: AppColors.textSecondary,
                      )),
        ),
        ),
        if (onTap != null)
          Positioned(
            right: -4,
            bottom: -4,
            child: Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.photo_camera,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
