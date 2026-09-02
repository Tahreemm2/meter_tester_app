// =============================================================================
// FILE: lib/core/services/session_manager.dart
// PURPOSE: Singleton responsible for persisting the current session (bearer
// token + user profile) to encrypted on-device storage, so the app can
// restore a logged-in session on relaunch instead of always showing
// LoginScreen (see AuthBloc's AppStarted event).
// =============================================================================

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class SessionManager {
  SessionManager._internal();
  static final SessionManager instance = SessionManager._internal();

  static const _tokenKey = 'mepco_auth_token';
  static const _userKey = 'mepco_user_profile';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Persists the token + full user profile after a successful login/OTP verify.
  Future<void> saveSession(UserModel user) async {
    await _storage.write(key: _tokenKey, value: user.token);
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  /// Returns the stored bearer token, or null if there is no saved session.
  Future<String?> getToken() => _storage.read(key: _tokenKey);

  /// Returns the stored user profile (without re-validating the token against
  /// the server — callers should still call ApiAuthRepository.me() to confirm
  /// the token is still valid before trusting this).
  Future<UserModel?> getCachedUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;

    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Clears the session — call on logout or when the token is found to be
  /// invalid/expired during a session-restore check.
  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}
