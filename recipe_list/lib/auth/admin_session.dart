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

Future<void> bootstrapAdminSession({required Database db}) async {
  _db = db;
  final rows = await db.query(
    'auth_credentials',
    columns: ['login', 'token'],
    where: 'active = 1',
    limit: 1,
  );
  if (rows.isEmpty) {
    _setSessionState(login: null, token: null, isAdmin: false);
    return;
  }
  final login = rows.first['login'] as String?;
  final token = rows.first['token'] as String?;
  _setSessionState(
    login: login,
    token: token,
    // Legacy admin mode is explicitly `admin` account only.
    isAdmin: login == _legacyAdminLogin,
  );
}

Future<bool> loginAsAdmin({
  required String login,
  required String password,
}) async {
  final db = _db;
  if (db == null) return false;

  final normalizedLogin = login.trim();
  if (normalizedLogin.isEmpty || password.isEmpty) return false;

  final online = await _loginOnline(normalizedLogin, password);
  if (online != null) {
    await _saveMirroredCredentials(
      db: db,
      login: normalizedLogin,
      passwordHash: _passwordHash(password),
      token: online.token,
    );
    _setSessionState(
      login: normalizedLogin,
      token: online.token,
      isAdmin: online.isAdmin,
    );
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
    );
  }
  final ok = offline != null || legacyOk;
  if (!ok) {
    _setSessionState(login: null, token: null, isAdmin: false);
    return false;
  }
  _setSessionState(
    login: normalizedLogin,
    token: offline?.token,
    isAdmin: legacyOk || normalizedLogin == _legacyAdminLogin,
  );
  return ok;
}

Future<void> logoutAdmin() async {
  final db = _db;
  if (db != null) {
    await db.update('auth_credentials', {'active': 0});
  }
  _setSessionState(login: null, token: null, isAdmin: false);
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
  const _OnlineLoginResult({required this.token, required this.isAdmin});

  final String? token;
  final bool isAdmin;
}

class _OfflineLoginResult {
  const _OfflineLoginResult({required this.token});

  final String? token;
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
}

Future<SignUpResult> signUpUser({
  required String name,
  required String email,
  required String password,
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

  try {
    final res = await dio.post<Map<String, dynamic>>(
      _normalizePath(_kAuthForgotPasswordPath),
      data: {'email': normalizedEmail},
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

Future<SignUpResult> _createUser({
  required Dio dio,
  required String name,
  required String email,
  required String password,
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
    {'name': name, 'email': email, 'password': password},
    {'login': email, 'password': password, 'avatar': ''},
    {'login': email, 'password': password, 'name': name, 'avatar': ''},
    {'login': email, 'password': password, 'name': name},
    {'username': email, 'password': password, 'name': name},
    {'user': email, 'password': password, 'name': name},
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
            return _OnlineLoginResult(token: token, isAdmin: isAdmin);
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
    columns: ['login', 'password_hash', 'token'],
    where: 'login = ? AND password_hash = ?',
    whereArgs: [login, passwordHash],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  await _setActiveLogin(db, login);
  return _OfflineLoginResult(token: rows.first['token'] as String?);
}

Future<void> _saveMirroredCredentials({
  required Database db,
  required String login,
  required String passwordHash,
  required String? token,
}) async {
  final ts = DateTime.now().millisecondsSinceEpoch;
  await db.insert('auth_credentials', {
    'login': login,
    'password_hash': passwordHash,
    'token': token,
    'active': 1,
    'updated_at': ts,
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
