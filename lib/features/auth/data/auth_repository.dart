// =============================================================================
// FILE: lib/features/auth/data/auth_repository.dart
// PURPOSE: Abstraction over "however we authenticate" so AuthBloc never talks
// to http/ApiClient directly. Production code uses ApiAuthRepository (talks
// to backend/api/login.php, logout.php, me.php). Tests can inject a fake
// implementation instead of hitting the network.
// =============================================================================

import '../../../core/config/api_config.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_client.dart';

/// Result of a login attempt. Exactly one of [user] or [pendingUser] is set:
///   - requiresOtp == false → [user] is populated with a real bearer token.
///   - requiresOtp == true  → [pendingUser] holds the display info (name,
///     masked contact, etc.) and [tempToken] must be used for verify/resend.
class AuthLoginResult {
  final bool requiresOtp;
  final UserModel? user;
  final UserModel? pendingUser;
  final String? tempToken;
  final int cooldownSeconds;

  const AuthLoginResult.authenticated(this.user)
      : requiresOtp = false,
        pendingUser = null,
        tempToken = null,
        cooldownSeconds = 0;

  const AuthLoginResult.otpRequired({
    required this.pendingUser,
    required this.tempToken,
    required this.cooldownSeconds,
  })  : requiresOtp = true,
        user = null;
}

abstract class AuthRepository {
  Future<AuthLoginResult> login({required String username, required String password});

  Future<UserModel> verifyOtp({required String tempToken, required String otpCode});

  /// Returns the new cooldown duration in seconds.
  Future<int> resendOtp({required String tempToken});

  /// Best-effort server-side token revocation. Callers should clear local
  /// session state regardless of whether this succeeds.
  Future<void> logout(String token);

  /// Validates a stored token and returns the current profile, or throws
  /// ApiException if the token is invalid/expired.
  Future<UserModel> fetchCurrentUser(String token);

  /// Changes the current user's own password. Throws ApiException with
  /// errorCode 'INVALID_CURRENT_PASSWORD' (401) if [currentPassword] doesn't
  /// match, or with [ApiException.fieldErrors] populated (422) for
  /// validation failures (too short, same as current).
  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  });
}

// =============================================================================
// REAL IMPLEMENTATION — talks to backend/api/login.php, logout.php, me.php
// =============================================================================
class ApiAuthRepository implements AuthRepository {
  final ApiClient _client;

  ApiAuthRepository({ApiClient? client}) : _client = client ?? ApiClient();

  @override
  Future<AuthLoginResult> login({required String username, required String password}) async {
    final response = await _client.post(
      ApiConfig.uri(ApiConfig.login),
      body: {'action': 'login', 'username': username, 'password': password},
    );

    final bool requiresOtp = response['requires_otp'] == true;

    if (requiresOtp) {
      return AuthLoginResult.otpRequired(
        pendingUser: UserModel.fromJson(response),
        tempToken: response['temp_token'] as String,
        cooldownSeconds: (response['cooldown_seconds'] as num?)?.toInt() ?? 60,
      );
    }

    return AuthLoginResult.authenticated(UserModel.fromJson(response));
  }

  @override
  Future<UserModel> verifyOtp({required String tempToken, required String otpCode}) async {
    final response = await _client.post(
      ApiConfig.uri(ApiConfig.login),
      body: {'action': 'verify_otp', 'temp_token': tempToken, 'otp_code': otpCode},
    );

    return UserModel.fromJson(response);
  }

  @override
  Future<int> resendOtp({required String tempToken}) async {
    final response = await _client.post(
      ApiConfig.uri(ApiConfig.login),
      body: {'action': 'resend_otp', 'temp_token': tempToken},
    );

    return (response['cooldown_seconds'] as num?)?.toInt() ?? 60;
  }

  @override
  Future<void> logout(String token) async {
    if (token.isEmpty) return;
    try {
      await _client.post(ApiConfig.uri(ApiConfig.logout), token: token);
    } catch (_) {
      // Best-effort: if the server call fails (e.g. offline), the local
      // session is still cleared by the caller. Nothing more to do here.
    }
  }

  @override
  Future<UserModel> fetchCurrentUser(String token) async {
    final response = await _client.get(ApiConfig.uri(ApiConfig.me), token: token);

    // api/me.php returns the profile fields but no "token" key (none is
    // re-issued) — re-attach the token we already have so UserModel.fromJson
    // produces a fully-populated session object.
    return UserModel.fromJson({...response, 'token': token});
  }

  @override
  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.post(
      ApiConfig.uri(ApiConfig.changePassword),
      token: token,
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }
}
