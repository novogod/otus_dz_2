// ignore_for_file: deprecated_member_use, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/admin_session.dart';
import '../i18n.dart';
import '../router/routes.dart';
import 'app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: currentUserLoginNotifier.value ?? '',
    );
    _editing = widget.initialEditMode || widget.isPostSignup;
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
    // and updates all visible UI (`AppLangScope` listens). Display
    // name editing is not yet persisted server-side; the local
    // `user_profile` table lands when /recipes/users/me ships.
    if (_selectedLang != appLang.value) {
      cycleAppLangTo(_selectedLang);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _editing = false;
    });
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(S.of(context).profileSavedToast)),
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
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Avatar upload coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
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

  Widget _buildStats(S s, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          s.profileRecipesAdded(n: 0),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          s.profileMemberSince(date: '—'),
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildPrimaryRow(S s) {
    if (widget.isPostSignup) {
      return Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : () => context.go(Routes.recipes),
              child: Text(s.profileSkip),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: ElevatedButton(
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
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFF54848),
        ),
        onPressed: _busy ? null : _handleLogout,
        child: Text(s.profileLogout),
      ),
    );
  }
}

class _AvatarSlot extends StatelessWidget {
  const _AvatarSlot({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 3),
          ),
          child: const Icon(
            Icons.person,
            size: 64,
            color: AppColors.textSecondary,
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
