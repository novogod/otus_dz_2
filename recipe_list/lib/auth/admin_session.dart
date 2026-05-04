import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../data/api/recipe_api_config.dart';
import '../i18n.dart';

/// Admin-сессия с онлайн-аутентификацией в mahallem и офлайн-фолбэком.
///
/// Успешный онлайн-логин зеркалится в локальную БД (`auth_credentials`),
/// поэтому при отсутствии сети пользователь может войти теми же
/// credentials офлайн.
final ValueNotifier<bool> adminLoggedInNotifier = ValueNotifier<bool>(false);
final ValueNotifier<bool> userLoggedInNotifier = ValueNotifier<bool>(false);
final ValueNotifier<String?> currentUserLoginNotifier = ValueNotifier<String?>(
  null,
);
final ValueNotifier<String?> currentUserTokenNotifier = ValueNotifier<String?>(
  null,
);
final ValueNotifier<String?> currentRecipeAdminTokenNotifier =
    ValueNotifier<String?>(null);

String? _sessionAdminPassword;

String? get currentSessionAdminPassword => _sessionAdminPassword;

Database? _db;

const String _kAuthBase = String.fromEnvironment(
  'MAHALLEM_AUTH_BASE',
  defaultValue: 'https://mahallem.ist',
);
const String _kAuthLoginPath = String.fromEnvironment(
  'MAHALLEM_AUTH_LOGIN_PATH',
  defaultValue: '/users/login',
);
const String _kAuthSignUpPath = String.fromEnvironment(
  'MAHALLEM_AUTH_SIGNUP_PATH',
  defaultValue: '/users',
);
const String _kSenderPath = String.fromEnvironment(
  'MAHALLEM_SENDER_PATH',
  defaultValue: '/sender/send',
);
const String _kAuthForgotPasswordPath = String.fromEnvironment(
  'MAHALLEM_AUTH_FORGOT_PASSWORD_PATH',
  defaultValue: '/forgot-password',
);
const String _kAuthResetPasswordPath = String.fromEnvironment(
  'MAHALLEM_AUTH_RESET_PASSWORD_PATH',
  defaultValue: '/reset-password',
);
const String _legacyAdminLogin = 'admin';
const String _legacyAdminPassword = 'admin';

enum SignUpResult {
  success,
  invalidEmail,
  duplicate,
  networkError,
  senderError,
  serverError,
}

enum PasswordRecoveryStartResult {
  success,
  invalidEmail,
  networkError,
  serverError,
}

class PasswordRecoveryStartResponse {
  const PasswordRecoveryStartResponse({
    required this.result,
    this.sessionCookie,
  });

  final PasswordRecoveryStartResult result;
  final String? sessionCookie;
}

enum PasswordResetResult {
  success,
  invalidCode,
  passwordTooShort,
  sessionExpired,
  networkError,
  serverError,
}

class AdminRecipeUser {
  const AdminRecipeUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.status,
    required this.preferredLanguage,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
  });

  final String id;
  final String email;
  final String fullName;
  final String status;
  final String preferredLanguage;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  bool get isActive => status == 'active';

  static AdminRecipeUser fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v is! String || v.isEmpty) return null;
      return DateTime.tryParse(v);
    }

    return AdminRecipeUser(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: (json['fullName'] ?? '').toString(),
      status: (json['status'] ?? 'active').toString(),
      preferredLanguage: (json['preferredLanguage'] ?? 'en').toString(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      lastLoginAt: parseDate(json['lastLoginAt']),
    );
  }
}

Future<void> bootstrapAdminSession({required Database db}) async {
  _db = db;
  _sessionAdminPassword = null;
  final rows = await db.query(
    'auth_credentials',
    columns: ['login', 'token', 'preferred_language', 'is_admin'],
    where: 'active = 1',
    limit: 1,
  );
  if (rows.isEmpty) {
    _setSessionState(login: null, token: null, isAdmin: false);
    return;
  }
  final login = rows.first['login'] as String?;
  final token = rows.first['token'] as String?;
  final storedLang = rows.first['preferred_language'] as String?;
  final storedIsAdmin = (rows.first['is_admin'] as int? ?? 0) == 1;
  if (storedLang != null) {
    final lang = AppLang.values.where((l) => l.name == storedLang).firstOrNull;
    if (lang != null) cycleAppLangTo(lang);
  }
  // Legacy admin fallback is allowed only for truly legacy sessions without
  // token. If a token exists, trust persisted is_admin instead of login alias.
  final hasToken = token != null && token.isNotEmpty;
  final isLegacyAdminSession = login == _legacyAdminLogin && !hasToken;
  final isAdmin = storedIsAdmin || isLegacyAdminSession;
  _setSessionState(
    login: login,
    token: isAdmin ? null : token,
    isAdmin: isAdmin,
  );
  if (isAdmin && hasToken) {
    currentRecipeAdminTokenNotifier.value = token;
  }
  // Restore in-memory session password for the legacy admin so that
  // openProfilePage can reopen the admin panel after an app restart.
  if (isLegacyAdminSession) {
    _sessionAdminPassword = _legacyAdminPassword;
  }
  // Online admins: _sessionAdminPassword remains null; token restore keeps
  // session alive across splash/restart until explicit logout.
}

Future<bool> loginAsAdmin({
  required String login,
  required String password,
}) async {
  final db = _db;
  if (db == null) return false;

  final normalizedLogin = login.trim();
  if (normalizedLogin.isEmpty || password.isEmpty) return false;

  final recipeAdminToken = await _loginRecipeAdminOnline(
    normalizedLogin,
    password,
  );
  if (recipeAdminToken != null) {
    await _saveMirroredCredentials(
      db: db,
      login: normalizedLogin,
      passwordHash: _passwordHash(password),
      token: recipeAdminToken,
      isAdmin: true,
    );
    _setSessionState(login: normalizedLogin, token: null, isAdmin: true);
    currentRecipeAdminTokenNotifier.value = recipeAdminToken;
    _sessionAdminPassword = password;
    return true;
  }

  final online = await _loginOnline(normalizedLogin, password);
  if (online != null) {
    if (online.preferredLang != null) {
      final lang = AppLang.values
          .where((l) => l.name == online.preferredLang)
          .firstOrNull;
      if (lang != null) cycleAppLangTo(lang);
    }
    await _saveMirroredCredentials(
      db: db,
      login: normalizedLogin,
      passwordHash: _passwordHash(password),
      token: online.token,
      preferredLang: online.preferredLang,
      isAdmin: online.isAdmin,
    );
    _setSessionState(
      login: normalizedLogin,
      token: online.token,
      isAdmin: online.isAdmin,
    );
    _sessionAdminPassword = online.isAdmin ? password : null;
    return true;
  }

  final offline = await _loginOffline(
    db: db,
    login: normalizedLogin,
    passwordHash: _passwordHash(password),
  );
  final legacyOk =
      normalizedLogin == _legacyAdminLogin && password == _legacyAdminPassword;
  if (legacyOk) {
    await _saveMirroredCredentials(
      db: db,
      login: normalizedLogin,
      passwordHash: _passwordHash(password),
      token: null,
      isAdmin: true,
    );
  }
  final ok = offline != null || legacyOk;
  if (!ok) {
    _setSessionState(login: null, token: null, isAdmin: false);
    return false;
  }
  _setSessionState(
    login: normalizedLogin,
    token: (offline?.isAdmin ?? false) ? null : offline?.token,
    isAdmin:
        offline?.isAdmin == true ||
        legacyOk ||
        normalizedLogin == _legacyAdminLogin,
  );
  if (offline?.isAdmin == true && offline?.token != null) {
    currentRecipeAdminTokenNotifier.value = offline!.token;
  }
  _sessionAdminPassword = (legacyOk || normalizedLogin == _legacyAdminLogin)
      ? password
      : null;
  return ok;
}

Future<void> logoutAdmin() async {
  final db = _db;
  if (db != null) {
    await db.update('auth_credentials', {'active': 0});
  }
  _setSessionState(login: null, token: null, isAdmin: false);
  currentRecipeAdminTokenNotifier.value = null;
  _sessionAdminPassword = null;
}

bool get canSyncFavoritesRemotely =>
    RecipeApiConfig.backend == RecipeBackend.mahallem &&
    userLoggedInNotifier.value &&
    currentUserTokenNotifier.value != null;

Future<Set<int>> fetchRemoteFavorites(AppLang lang) async {
  if (!canSyncFavoritesRemotely) return const <int>{};
  final token = currentUserTokenNotifier.value;
  if (token == null || token.isEmpty) return const <int>{};
  final dio = Dio(
    BaseOptions(
      baseUrl: RecipeApiConfig.activeBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      headers: {'x-recipes-user-token': token},
    ),
  );
  final res = await dio.get<Map<String, dynamic>>(
    '/favorites',
    queryParameters: {'lang': lang.name},
  );
  final idsRaw = res.data?['ids'];
  if (idsRaw is! List) return const <int>{};
  return idsRaw.whereType<num>().map((n) => n.toInt()).toSet();
}

Future<void> setRemoteFavorite({
  required int recipeId,
  required AppLang lang,
  required bool favorite,
}) async {
  if (!canSyncFavoritesRemotely) return;
  final token = currentUserTokenNotifier.value;
  if (token == null || token.isEmpty) return;
  final dio = Dio(
    BaseOptions(
      baseUrl: RecipeApiConfig.activeBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      headers: {'x-recipes-user-token': token},
    ),
  );
  await dio.post<Object>(
    '/favorites',
    data: {'recipeId': recipeId, 'lang': lang.name, 'favorite': favorite},
  );
}

class _OnlineLoginResult {
  const _OnlineLoginResult({
    required this.token,
    required this.isAdmin,
    this.preferredLang,
  });

  final String? token;
  final bool isAdmin;
  final String? preferredLang;
}

class _OfflineLoginResult {
  const _OfflineLoginResult({required this.token, required this.isAdmin});

  final String? token;
  final bool isAdmin;
}

void _setSessionState({
  required String? login,
  required String? token,
  required bool isAdmin,
}) {
  currentUserLoginNotifier.value = login;
  currentUserTokenNotifier.value = token;
  userLoggedInNotifier.value = login != null && login.isNotEmpty;
  adminLoggedInNotifier.value = userLoggedInNotifier.value && isAdmin;
  if (!adminLoggedInNotifier.value) {
    _sessionAdminPassword = null;
    currentRecipeAdminTokenNotifier.value = null;
  }
}

Future<SignUpResult> signUpUser({
  required String name,
  required String email,
  required String password,
  AppLang? preferredLang,
}) async {
  final normalizedName = name.trim();
  final normalizedEmail = email.trim().toLowerCase();
  if (!_isValidEmail(normalizedEmail)) {
    return SignUpResult.invalidEmail;
  }
  if (normalizedName.isEmpty || password.isEmpty) {
    return SignUpResult.serverError;
  }
  if (RecipeApiConfig.backend != RecipeBackend.mahallem) {
    return SignUpResult.serverError;
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: _kAuthBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
    ),
  );

  final signUpOk = await _createUser(
    dio: dio,
    name: normalizedName,
    email: normalizedEmail,
    password: password,
    language: (preferredLang ?? appLang.value).name,
  );
  if (signUpOk == SignUpResult.success) {
    final senderOk = await _sendCredentialsEmail(
      dio: dio,
      name: normalizedName,
      email: normalizedEmail,
      password: password,
    );
    if (!senderOk) return SignUpResult.senderError;
    return SignUpResult.success;
  }
  return signUpOk;
}

Future<PasswordRecoveryStartResponse> requestPasswordRecovery({
  required String email,
}) async {
  final normalizedEmail = email.trim().toLowerCase();
  if (!_isValidEmail(normalizedEmail)) {
    return const PasswordRecoveryStartResponse(
      result: PasswordRecoveryStartResult.invalidEmail,
    );
  }
  if (RecipeApiConfig.backend != RecipeBackend.mahallem) {
    return const PasswordRecoveryStartResponse(
      result: PasswordRecoveryStartResult.serverError,
    );
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: _kAuthBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      validateStatus: (_) => true,
    ),
  );

  final langCode = appLang.value.name; // 'en', 'ru', 'tr', etc.

  try {
    final res = await dio.post<Map<String, dynamic>>(
      _normalizePath(_kAuthForgotPasswordPath),
      data: {'email': normalizedEmail, 'app_name': 'Otus Food'},
      options: Options(headers: {'Accept-Language': langCode}),
    );

    final status = res.statusCode ?? 0;
    final body = res.data;
    final ok = status >= 200 && status < 300 && body?['success'] == true;
    if (!ok) {
      return const PasswordRecoveryStartResponse(
        result: PasswordRecoveryStartResult.serverError,
      );
    }

    final setCookieHeader = res.headers['set-cookie'];
    final sessionCookie =
        (setCookieHeader != null && setCookieHeader.isNotEmpty)
        ? setCookieHeader.first.split(';').first
        : null;

    return PasswordRecoveryStartResponse(
      result: PasswordRecoveryStartResult.success,
      sessionCookie: sessionCookie,
    );
  } on DioException catch (e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const PasswordRecoveryStartResponse(
        result: PasswordRecoveryStartResult.networkError,
      );
    }
    return const PasswordRecoveryStartResponse(
      result: PasswordRecoveryStartResult.serverError,
    );
  }
}

Future<PasswordResetResult> resetPasswordWithCode({
  required String code,
  required String newPassword,
  required String recoverySessionCookie,
}) async {
  final normalizedCode = code.trim();
  if (!RegExp(r'^\d{4}$').hasMatch(normalizedCode)) {
    return PasswordResetResult.invalidCode;
  }
  if (newPassword.length < 6) {
    return PasswordResetResult.passwordTooShort;
  }
  if (RecipeApiConfig.backend != RecipeBackend.mahallem) {
    return PasswordResetResult.serverError;
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: _kAuthBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      validateStatus: (_) => true,
      headers: {'Cookie': recoverySessionCookie},
    ),
  );

  try {
    final res = await dio.post<Map<String, dynamic>>(
      _normalizePath(_kAuthResetPasswordPath),
      data: {'code': normalizedCode, 'newPassword': newPassword},
    );
    final status = res.statusCode ?? 0;
    final body = res.data;
    if (status >= 200 && status < 300 && body?['success'] == true) {
      return PasswordResetResult.success;
    }

    final message = '${body?['message'] ?? ''} ${body?['details'] ?? ''}'
        .toLowerCase();
    if (message.contains('session')) {
      return PasswordResetResult.sessionExpired;
    }
    if (message.contains('code')) {
      return PasswordResetResult.invalidCode;
    }
    if ((message.contains('password') && message.contains('short')) ||
        message.contains('min chars')) {
      return PasswordResetResult.passwordTooShort;
    }

    return PasswordResetResult.serverError;
  } on DioException catch (e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return PasswordResetResult.networkError;
    }
    return PasswordResetResult.serverError;
  }
}

Future<List<AdminRecipeUser>> fetchRecipeAdminUsers({
  required String adminLogin,
  required String adminPassword,
}) async {
  if (RecipeApiConfig.backend != RecipeBackend.mahallem) return const [];
  final token = await _ensureRecipeAdminToken(
    adminLogin: adminLogin,
    adminPassword: adminPassword,
  );
  if (token == null || token.isEmpty) {
    throw StateError('admin_login_failed');
  }
  final dio = Dio(
    BaseOptions(
      baseUrl: _kAuthBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      validateStatus: (_) => true,
      headers: {'Authorization': 'Bearer $token'},
    ),
  );
  final res = await dio.get<Map<String, dynamic>>('/api/recipe-admin/users');
  final status = res.statusCode ?? 0;
  if (status == 401 || status == 403) {
    currentRecipeAdminTokenNotifier.value = null;
    throw StateError('admin_list_unauthorized');
  }
  if (status < 200 || status >= 300) {
    throw StateError('admin_list_failed');
  }
  final decoded = res.data;
  if (decoded is! Map<String, dynamic>) {
    throw StateError('admin_list_invalid_response');
  }
  final usersRaw = decoded['users'];
  if (usersRaw is! List) return const [];
  return usersRaw
      .whereType<Map<String, dynamic>>()
      .map(AdminRecipeUser.fromJson)
      .toList(growable: false);
}

Future<AdminRecipeUser?> updateRecipeAdminUser({
  required String adminLogin,
  required String adminPassword,
  required String id,
  required String fullName,
  required String preferredLanguage,
  required String status,
}) async {
  if (RecipeApiConfig.backend != RecipeBackend.mahallem) return null;
  final token = await _ensureRecipeAdminToken(
    adminLogin: adminLogin,
    adminPassword: adminPassword,
  );
  if (token == null || token.isEmpty) {
    throw StateError('admin_update_unauthorized');
  }
  final dio = Dio(
    BaseOptions(
      baseUrl: _kAuthBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      validateStatus: (_) => true,
      headers: {'Authorization': 'Bearer $token'},
    ),
  );
  final res = await dio.patch<Map<String, dynamic>>(
    '/api/recipe-admin/users/$id',
    data: {
      'fullName': fullName,
      'preferredLanguage': preferredLanguage,
      'status': status,
    },
  );
  final statusCode = res.statusCode ?? 0;
  if (statusCode == 401 || statusCode == 403) {
    currentRecipeAdminTokenNotifier.value = null;
    throw StateError('admin_update_unauthorized');
  }
  if (statusCode == 404) throw StateError('admin_update_not_found');
  if (statusCode < 200 || statusCode >= 300) {
    throw StateError('admin_update_failed');
  }
  final userRaw = res.data?['user'];
  if (userRaw is! Map<String, dynamic>) return null;
  return AdminRecipeUser.fromJson(userRaw);
}

Future<bool> deleteRecipeAdminUser({
  required String adminLogin,
  required String adminPassword,
  required String id,
}) async {
  if (RecipeApiConfig.backend != RecipeBackend.mahallem) return false;
  final token = await _ensureRecipeAdminToken(
    adminLogin: adminLogin,
    adminPassword: adminPassword,
  );
  if (token == null || token.isEmpty) {
    throw StateError('admin_delete_unauthorized');
  }
  final dio = Dio(
    BaseOptions(
      baseUrl: _kAuthBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      validateStatus: (_) => true,
      headers: {'Authorization': 'Bearer $token'},
    ),
  );
  final res = await dio.delete<Map<String, dynamic>>(
    '/api/recipe-admin/users/$id',
  );
  final statusCode = res.statusCode ?? 0;
  if (statusCode == 401 || statusCode == 403) {
    currentRecipeAdminTokenNotifier.value = null;
    throw StateError('admin_delete_unauthorized');
  }
  if (statusCode == 404) throw StateError('admin_delete_not_found');
  if (statusCode < 200 || statusCode >= 300) {
    throw StateError('admin_delete_failed');
  }
  return res.data?['success'] == true;
}

Future<int> bulkDeleteRecipeAdminUsers({
  required String adminLogin,
  required String adminPassword,
  required List<String> ids,
}) async {
  if (RecipeApiConfig.backend != RecipeBackend.mahallem) return 0;
  if (ids.isEmpty) return 0;
  final token = await _ensureRecipeAdminToken(
    adminLogin: adminLogin,
    adminPassword: adminPassword,
  );
  if (token == null || token.isEmpty) {
    throw StateError('admin_bulk_delete_unauthorized');
  }
  final dio = Dio(
    BaseOptions(
      baseUrl: _kAuthBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      validateStatus: (_) => true,
      headers: {'Authorization': 'Bearer $token'},
    ),
  );
  final res = await dio.post<Map<String, dynamic>>(
    '/api/recipe-admin/users/bulk-delete',
    data: {'ids': ids},
  );
  final statusCode = res.statusCode ?? 0;
  if (statusCode == 401 || statusCode == 403) {
    currentRecipeAdminTokenNotifier.value = null;
    throw StateError('admin_bulk_delete_unauthorized');
  }
  if (statusCode < 200 || statusCode >= 300) {
    throw StateError('admin_bulk_delete_failed');
  }
  final deletedCount = res.data?['deletedCount'];
  if (deletedCount is int) return deletedCount;
  if (deletedCount is num) return deletedCount.toInt();
  return 0;
}

Future<String?> _ensureRecipeAdminToken({
  required String adminLogin,
  required String adminPassword,
}) async {
  final existing = currentRecipeAdminTokenNotifier.value;
  if (existing != null && existing.isNotEmpty) return existing;
  final token = await _loginRecipeAdminOnline(adminLogin.trim(), adminPassword);
  if (token == null || token.isEmpty) return null;
  currentRecipeAdminTokenNotifier.value = token;
  await _persistRecipeAdminToken(login: adminLogin.trim(), token: token);
  return token;
}

Future<void> _persistRecipeAdminToken({
  required String login,
  required String token,
}) async {
  final db = _db;
  if (db == null) return;
  await db.update(
    'auth_credentials',
    {'token': token, 'updated_at': DateTime.now().millisecondsSinceEpoch},
    where: 'login = ? AND active = 1',
    whereArgs: [login],
  );
}

Future<String?> _loginRecipeAdminOnline(String login, String password) async {
  if (RecipeApiConfig.backend != RecipeBackend.mahallem) return null;
  if (login.isEmpty || password.isEmpty) return null;

  final dio = Dio(
    BaseOptions(
      baseUrl: _kAuthBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      validateStatus: (_) => true,
    ),
  );
  final res = await dio.post<Map<String, dynamic>>(
    '/api/recipe-admin/login',
    data: {'email': login, 'password': password},
  );
  final status = res.statusCode ?? 0;
  if (status == 401 || status == 403) return null;
  if (status < 200 || status >= 300) return null;
  final token = res.data?['token'];
  if (token is String && token.isNotEmpty) return token;
  return null;
}

Future<SignUpResult> _createUser({
  required Dio dio,
  required String name,
  required String email,
  required String password,
  String language = 'en',
}) async {
  final paths = <String>{
    _normalizePath(_kAuthSignUpPath),
    '/user',
    '/users',
    '/users/register',
    '/users/signup',
    '/auth/register',
    '/register',
  };

  final payloads = <Map<String, String>>[
    {'name': name, 'email': email, 'password': password, 'language': language},
    {'login': email, 'password': password, 'avatar': ''},
    {'login': email, 'password': password, 'name': name, 'avatar': ''},
    {'login': email, 'password': password, 'name': name, 'language': language},
    {
      'username': email,
      'password': password,
      'name': name,
      'language': language,
    },
    {'user': email, 'password': password, 'name': name, 'language': language},
  ];

  final methods = <String>{'POST', 'PUT'};

  var sawNetworkError = false;
  for (final path in paths) {
    for (final method in methods) {
      var pathMissing = false;
      for (final payload in payloads) {
        try {
          final res = await dio.request<Object>(
            path,
            data: payload,
            options: Options(method: method),
          );
          final status = res.statusCode ?? 0;
          if (status >= 200 && status < 300) return SignUpResult.success;
        } on DioException catch (e) {
          final code = e.response?.statusCode;
          if (code == 404) {
            // endpoint absent, switch to next path
            pathMissing = true;
            break;
          }
          if (code == 409) return SignUpResult.duplicate;
          if (code == 400 ||
              code == 401 ||
              code == 403 ||
              code == 405 ||
              code == 422) {
            continue;
          }
          sawNetworkError = true;
        }
      }
      if (pathMissing) {
        break;
      }
    }
  }
  return sawNetworkError ? SignUpResult.networkError : SignUpResult.serverError;
}

Future<bool> _sendCredentialsEmail({
  required Dio dio,
  required String name,
  required String email,
  required String password,
}) async {
  final paths = <String>{
    _normalizePath(_kSenderPath),
    '/sender/send',
    '/sender',
    '/send-email',
    '/mailer/send',
  };

  final subject = 'Otus Food credentials';
  final text =
      'Hello $name!\n\n'
      'Your Otus Food account is ready.\n'
      'Login: $email\n'
      'Password: $password\n\n'
      'You can sign in in the app Profile section.';

  final payloads = <Map<String, String>>[
    {'to': email, 'subject': subject, 'text': text},
    {'email': email, 'subject': subject, 'message': text},
    {'recipient': email, 'subject': subject, 'body': text},
  ];

  for (final path in paths) {
    for (final payload in payloads) {
      try {
        final res = await dio.post<Object>(path, data: payload);
        final status = res.statusCode ?? 0;
        if (status >= 200 && status < 300) return true;
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) break;
        // try next payload / next path
      }
    }
  }
  return false;
}

Future<_OnlineLoginResult?> _loginOnline(String login, String password) async {
  if (RecipeApiConfig.backend != RecipeBackend.mahallem) {
    return null;
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: _kAuthBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
    ),
  );

  final paths = <String>{
    _normalizePath(_kAuthLoginPath),
    '/users/login',
    '/auth/login',
    '/login',
  };

  for (final path in paths) {
    final payloads = <Map<String, String>>[
      {'login': login, 'password': password},
      {'username': login, 'password': password},
      {'email': login, 'password': password},
      {'user': login, 'password': password},
    ];
    try {
      for (final payload in payloads) {
        try {
          final res = await dio.post<Object>(path, data: payload);
          final status = res.statusCode ?? 0;
          if (status >= 200 && status < 300) {
            final body = res.data;
            final token = body is Map<String, dynamic>
                ? body['token'] as String?
                : null;
            final isAdmin = body is Map<String, dynamic>
                ? (body['isAdmin'] == true ||
                      body['is_admin'] == true ||
                      body['role'] == 'admin')
                : false;
            final preferredLang = body is Map<String, dynamic>
                ? body['preferredLanguage'] as String?
                : null;
            return _OnlineLoginResult(
              token: token,
              isAdmin: isAdmin,
              preferredLang: preferredLang,
            );
          }
        } on DioException catch (e) {
          final code = e.response?.statusCode;
          if (code == 404) {
            // this path doesn't exist; switch to next path
            break;
          }
          // Wrong payload shape / unauthorized. Try next payload variant.
          if (code == 400 || code == 401 || code == 403 || code == 422) {
            continue;
          }
          // Network/server failure — stop online flow and fallback offline.
          return null;
        }
      }
    } on DioException catch (e) {
      // Если endpoint не найден — пробуем следующий известный путь.
      if (e.response?.statusCode == 404) continue;
      // На любых сетевых/авторизационных ошибках онлайн-сценарий
      // считаем неуспешным и позволяем офлайн-фолбэк.
      return null;
    }
  }
  return null;
}

Future<_OfflineLoginResult?> _loginOffline({
  required Database db,
  required String login,
  required String passwordHash,
}) async {
  final rows = await db.query(
    'auth_credentials',
    columns: ['login', 'password_hash', 'token', 'is_admin'],
    where: 'login = ? AND password_hash = ?',
    whereArgs: [login, passwordHash],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  await _setActiveLogin(db, login);
  return _OfflineLoginResult(
    token: rows.first['token'] as String?,
    isAdmin: (rows.first['is_admin'] as int? ?? 0) == 1,
  );
}

Future<void> _saveMirroredCredentials({
  required Database db,
  required String login,
  required String passwordHash,
  required String? token,
  String? preferredLang,
  bool isAdmin = false,
}) async {
  final ts = DateTime.now().millisecondsSinceEpoch;
  await db.insert('auth_credentials', {
    'login': login,
    'password_hash': passwordHash,
    'token': token,
    'active': 1,
    'updated_at': ts,
    'is_admin': isAdmin ? 1 : 0,
    if (preferredLang != null) 'preferred_language': preferredLang,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
  await db.update(
    'auth_credentials',
    {'active': 0},
    where: 'login <> ?',
    whereArgs: [login],
  );
}

Future<void> _setActiveLogin(Database db, String login) async {
  await db.transaction((txn) async {
    await txn.update('auth_credentials', {'active': 0});
    await txn.update(
      'auth_credentials',
      {'active': 1},
      where: 'login = ?',
      whereArgs: [login],
    );
  });
}

String _normalizePath(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '/users/login';
  return trimmed.startsWith('/') ? trimmed : '/$trimmed';
}

bool _isValidEmail(String raw) {
  if (!raw.contains('@')) return false;
  final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  return re.hasMatch(raw);
}

String _passwordHash(String raw) {
  // Lightweight deterministic hash (FNV-1a 32-bit) for offline
  // credential mirror. Not a cryptographic KDF, but stable across
  // app restarts and avoids plaintext storage.
  var hash = 0x811C9DC5;
  for (final c in raw.codeUnits) {
    hash ^= c;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
