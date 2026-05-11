// ignore_for_file: deprecated_member_use, library_private_types_in_public_api

import 'dart:async';

import 'package:country_flags/country_flags.dart';
import 'package:country_picker/country_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/admin_session.dart';
import '../auth/passkey_api.dart' as passkey_api;
import '../data/api/recipe_api.dart';
import '../data/app_services.dart';
import '../i18n.dart';
import '../router/routes.dart';
import '../utils/imgproxy.dart';
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
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  /// ISO 3166-1 alpha-2 country code currently selected by the
  /// user. Stored separately from [_countryController] (which is
  /// kept in sync with the picker for legacy reasons) so we can
  /// render the localized country name in the picker tile.
  String? _countryCode;

  /// Focus node for the city autocomplete field — required by
  /// [RawAutocomplete] so we can pass the same controller as
  /// [_cityController].
  final FocusNode _cityFocus = FocusNode();

  /// Most recent city query the user typed. Used to discard stale
  /// Nominatim responses when the user keeps typing past a request
  /// that's still in flight (debounce + race-guard).
  String _latestCityQuery = '';
  late bool _editing;
  AppLang _selectedLang = appLang.value;
  bool _busy = false;
  bool _passkeyBusy = false;
  bool _newPasswordObscured = true;
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
      if (!_editing) {
        _cityController.text = snap.city ?? '';
        _countryController.text = snap.country ?? '';
        _countryCode = (snap.country ?? '').trim().isEmpty
            ? null
            : snap.country!.trim().toUpperCase();
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
    _newPasswordController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _cityFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_busy) return;
    final newPassword = _newPasswordController.text;
    final wantsPasswordChange = newPassword.isNotEmpty;
    if (wantsPasswordChange && newPassword.length < 6) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Password must be at least 6 characters.'),
          ),
        );
      return;
    }
    setState(() => _busy = true);
    // Persist language change globally — this is wired to slang
    // and updates all visible UI (`AppLangScope` listens).
    if (_selectedLang != appLang.value) {
      cycleAppLangTo(_selectedLang);
      // Keep local mirrored session language in sync with explicit
      // profile language choice so trusted-session startup restores it.
      await persistActiveSessionPreferredLanguage(_selectedLang);
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
          city: _cityController.text.trim(),
          country: _countryCode ?? '',
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
              city: updated.city,
              country: updated.country,
              recipesAdded: _profile?.recipesAdded ?? 0,
              memberSince: updated.memberSince ?? _profile?.memberSince,
            ),
          );
        }
      } catch (e) {
        errorMessage = e.toString();
      }
    }
    // Password change rides along with the rest of the Save
    // action: a non-empty New password field triggers the
    // backend POST /recipes/account/password call, with its own
    // toast on failure so the name/language outcome stays clear.
    String? passwordMessage;
    if (wantsPasswordChange) {
      final result = await changeUserPassword(newPassword);
      if (!mounted) return;
      switch (result) {
        case ChangePasswordResult.success:
          _newPasswordController.clear();
          passwordMessage =
              'Password changed. A reminder has been emailed to you.';
          break;
        case ChangePasswordResult.passwordTooShort:
          passwordMessage = 'Password must be at least 6 characters.';
          break;
        case ChangePasswordResult.notLoggedIn:
        case ChangePasswordResult.unauthorized:
          passwordMessage = 'Session expired. Please sign in again.';
          break;
        case ChangePasswordResult.networkError:
          passwordMessage = 'Network error. Please check your connection.';
          break;
        case ChangePasswordResult.serverError:
          passwordMessage = 'Could not change password. Please try again.';
          break;
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _editing = false;
    });
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final profileMessage = errorMessage == null
        ? S.of(context).profileSavedToast
        : 'Save failed: $errorMessage';
    final combined = passwordMessage == null
        ? profileMessage
        : '$profileMessage $passwordMessage';
    messenger.showSnackBar(SnackBar(content: Text(combined)));
    if (widget.isPostSignup) {
      context.go(Routes.recipes);
    }
  }

  Future<void> _addPasskey() async {
    if (_busy || _passkeyBusy) return;
    final s = S.of(context);
    if (kIsWeb) {
      final token = currentUserTokenNotifier.value;
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(s.profilePasskeySignInFirst)));
        return;
      }
      if (!passkey_api.isPasskeySupported) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(s.profilePasskeyNotSupported)));
        return;
      }
      setState(() => _passkeyBusy = true);
      try {
        await passkey_api.registerPasskey(token: token);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(s.profilePasskeyAdded)));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(s.profilePasskeyAddFailed(error: e))),
          );
      } finally {
        if (mounted) setState(() => _passkeyBusy = false);
      }
      return;
    }
    // Native (iOS / Android): save current session for biometric login.
    setState(() => _passkeyBusy = true);
    bool ok = false;
    try {
      ok = await saveCurrentSessionForBiometricLogin();
    } catch (e) {
      // Keep the profile screen stable even if local credential-store
      // persistence fails unexpectedly.
      debugPrint(
        '[UserCardPage] saveCurrentSessionForBiometricLogin failed: $e',
      );
      ok = false;
    }
    if (!mounted) return;
    setState(() => _passkeyBusy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok ? s.profileBiometricSaved : s.profileBiometricSaveFailed,
          ),
        ),
      );
  }

  Future<void> _handleLogout() async {
    if (_busy) return;
    setState(() => _busy = true);
    final preserveBiometric = await hasSavedBiometricSession();
    await logoutAdmin(
      clearSavedSession: !preserveBiometric,
      lossEvent: AdminSessionLossEvent(
        reason: 'User tapped Logout in profile (UserCardPage)',
      ),
    );
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
              city: p.city,
              country: p.country,
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
            city: p.city,
            country: p.country,
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
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
                  const SizedBox(height: AppSpacing.md),
                  _buildCityField(s),
                  const SizedBox(height: AppSpacing.md),
                  _buildCountryField(s),
                  if (_editing && !widget.isPostSignup) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildNewPasswordField(),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _buildStats(s, theme),
                  const SizedBox(height: AppSpacing.xl),
                  _buildPrimaryRow(s),
                  const SizedBox(height: AppSpacing.md),
                  if (!widget.isPostSignup) _buildPasskeyButton(),
                  if (!widget.isPostSignup) _buildLogoutButton(s),
                ],
              ),
            ),
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

  Widget _buildCityField(S s) {
    return RawAutocomplete<String>(
      textEditingController: _cityController,
      focusNode: _cityFocus,
      optionsBuilder: _cityOptionsBuilder,
      onSelected: (value) {
        _cityController.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, _) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: _editing,
          maxLength: 80,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'City',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the suggestion list for the city autocomplete field.
  ///
  /// Debounces user input (350ms) and queries OSM Nominatim with
  /// the current UI language and the user-selected country code
  /// so the user sees city names localized to their app language
  /// and scoped to their country (when one is set). A race-guard
  /// via [_latestCityQuery] discards stale responses when the
  /// user keeps typing past an in-flight request.
  Future<Iterable<String>> _cityOptionsBuilder(TextEditingValue tev) async {
    final query = tev.text.trim();
    _latestCityQuery = query;
    if (query.length < 2) return const <String>[];
    // Debounce: wait briefly and bail out if the user has typed
    // more characters since this call started.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (_latestCityQuery != query) return const <String>[];
    final results = await _fetchCitySuggestions(query);
    if (_latestCityQuery != query) return const <String>[];
    return results;
  }

  /// Fetches city suggestions from OSM Nominatim. Returns an
  /// empty list on any network/parse error — the field then
  /// degrades to plain free-text input. Uses a fresh [Dio]
  /// instance to avoid leaking app auth headers to a 3rd-party
  /// service.
  Future<List<String>> _fetchCitySuggestions(String query) async {
    try {
      final lang = Localizations.localeOf(context).languageCode;
      final cc = _countryCode?.toLowerCase();
      final dio = Dio(
        BaseOptions(
          headers: {
            // Nominatim usage policy requires an identifying UA.
            'User-Agent': 'mahallem-recipes/1.0 (https://mahallem.com)',
          },
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final resp = await dio.get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: <String, dynamic>{
          'q': query,
          'format': 'jsonv2',
          'addressdetails': 1,
          'limit': 8,
          'accept-language': lang,
          if (cc != null && cc.isNotEmpty) 'countrycodes': cc,
        },
      );
      final data = resp.data ?? const <dynamic>[];
      final out = <String>[];
      final seen = <String>{};
      for (final raw in data) {
        if (raw is! Map) continue;
        final addr = raw['address'];
        String? name;
        if (addr is Map) {
          name =
              (addr['city'] ??
                      addr['town'] ??
                      addr['village'] ??
                      addr['municipality'] ??
                      addr['hamlet'])
                  as String?;
        }
        name ??= raw['name'] as String?;
        if (name == null || name.isEmpty) continue;
        if (!seen.add(name.toLowerCase())) continue;
        out.add(name);
      }
      return out;
    } catch (_) {
      return const <String>[];
    }
  }

  Widget _buildCountryField(S s) {
    final code = _countryCode;
    final loc = CountryLocalizations.of(context);
    final name = (code != null && loc != null)
        ? (loc.countryName(countryCode: code) ?? code)
        : null;
    final placeholder = TextStyle(
      color: AppColors.textPrimary.withValues(alpha: _editing ? 0.55 : 0.4),
    );
    return InkWell(
      onTap: _editing ? _openCountryPicker : null,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Country',
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            if (code != null) ...[
              CountryFlag.fromCountryCode(
                code,
                theme: const ImageTheme(width: 28, height: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                code,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                name ?? (_editing ? 'Select country' : '—'),
                style: name != null
                    ? const TextStyle(color: AppColors.textPrimary)
                    : placeholder,
              ),
            ),
            if (_editing && _countryCode != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _countryCode = null;
                    _countryController.text = '';
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: AppSpacing.sm),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            if (_editing)
              const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _openCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      useSafeArea: true,
      // Override the default emoji-flag with an SVG so it renders
      // identically across all platforms. Web (Chromium) has no
      // built-in flag glyphs and otherwise shows '?' boxes.
      customFlagBuilder: (country) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: CountryFlag.fromCountryCode(
          country.countryCode,
          theme: const ImageTheme(width: 28, height: 20),
        ),
      ),
      onSelect: (country) {
        setState(() {
          _countryCode = country.countryCode;
          _countryController.text = country.countryCode;
        });
      },
    );
  }

  /// Converts an ISO 3166-1 alpha-2 [code] to its regional indicator
  /// flag emoji ("TR" → "🇹🇷"). Pure offset arithmetic, no
  /// network or asset lookup. Currently unused now that flags
  /// render as SVG via [CountryFlag] — kept commented as a
  /// reference for future Cupertino-style chip experiments.
  // ignore: unused_element
  String? _flagEmoji(String code) {
    if (code.length != 2) return null;
    final base = 0x1F1E6 - 0x41;
    final upper = code.toUpperCase();
    final c0 = upper.codeUnitAt(0);
    final c1 = upper.codeUnitAt(1);
    if (c0 < 0x41 || c0 > 0x5A || c1 < 0x41 || c1 > 0x5A) return null;
    return String.fromCharCodes([base + c0, base + c1]);
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

  /// Inline password-change field, rendered alongside the other
  /// editable profile fields. Only visible in edit mode; the value
  /// is submitted by the same Save button that persists name and
  /// language (see [_handleSave]).
  Widget _buildNewPasswordField() {
    return TextField(
      controller: _newPasswordController,
      obscureText: _newPasswordObscured,
      enabled: !_busy,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.done,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: 'New password',
        helperText: 'Change password',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(
            _newPasswordObscured ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: _busy
              ? null
              : () => setState(
                  () => _newPasswordObscured = !_newPasswordObscured,
                ),
        ),
      ),
    );
  }

  Widget _buildPasskeyButton() {
    if (!userLoggedInNotifier.value) return const SizedBox.shrink();
    final s = S.of(context);
    final label = kIsWeb
        ? s.profileAddPasskeyButton
        : s.profileSaveBiometricButton;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryDark,
            side: const BorderSide(color: AppColors.primaryDark),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            textStyle: const TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          icon: _passkeyBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.fingerprint),
          onPressed: (_busy || _passkeyBusy) ? null : _addPasskey,
          label: Text(label),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
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
    String? fallbackUrl;
    if (hasAvatar) {
      String sourceForProxy;
      if (url.startsWith('http')) {
        final uri = Uri.tryParse(url);
        // Storage lives on the parent host `mahallem.ist`. Historical
        // image rows may carry `recipies.mahallem.ist`; new rows
        // shouldn't, but `snackhack.app` is matched defensively in case
        // a future writer paths through the new SPA origin.
        if (uri != null &&
            (uri.host == 'recipies.mahallem.ist' ||
                uri.host == 'snackhack.app') &&
            uri.path.startsWith('/storage/')) {
          final canonical = uri.replace(host: 'mahallem.ist').toString();
          sourceForProxy = canonical;
          fallbackUrl = canonical;
        } else {
          sourceForProxy = url;
          fallbackUrl = url;
        }
      } else {
        final normalized = url.startsWith('/') ? url : '/$url';
        sourceForProxy = normalized;
        fallbackUrl = 'https://mahallem.ist$normalized';
      }
      // 240 dp slot @ ~3x DPR ≈ 720 px — keep imgproxy resize at 480
      // (it serves WebP, browser/iOS scales final 120-dp slot).
      fullUrl = imgproxyUrl(sourceForProxy, 480, 480);
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
                    errorBuilder: (_, __, ___) =>
                        (fallbackUrl != null && fallbackUrl != fullUrl)
                        ? Image.network(
                            fallbackUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : const Icon(
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
