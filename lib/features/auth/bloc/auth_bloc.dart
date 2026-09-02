// =============================================================================
// FILE: lib/features/auth/bloc/auth_bloc.dart
// PURPOSE: BLoC (Business Logic Component) for User Authentication.
//
// ARCHITECTURE:
//   UI Layer (Screens) ──► Events ──► AuthBloc ──► States ──► UI rebuild
//
// This file contains:
//   1. AuthEvent   — all possible user-triggered actions
//   2. AuthState   — all possible UI states
//   3. AuthBloc    — logic that maps events → states
//
// BACKEND INTEGRATION:
//   AuthBloc talks to the real MEPCO PHP/MySQL API via AuthRepository
//   (see lib/features/auth/data/auth_repository.dart). Sessions are
//   persisted via SessionManager so a valid login survives an app restart
//   (see AppStarted below, dispatched once from main.dart).
//
// DEPENDENCY:
//   flutter_bloc: ^8.x.x  (add to pubspec.yaml)
// =============================================================================

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/session_manager.dart';
import '../data/auth_repository.dart';

// =============================================================================
// SECTION 1: AUTH EVENTS
// =============================================================================

/// Base class for all authentication events.
abstract class AuthEvent {
  const AuthEvent();
}

/// Dispatched once from main.dart on app launch. Checks for a previously
/// saved session and validates it against the server before deciding
/// whether to show LoginScreen or restore straight into the dashboard.
class AppStarted extends AuthEvent {
  const AppStarted();
}

/// User tapped "Login" with filled credentials.
class LoginSubmitted extends AuthEvent {
  final String username;
  final String password;

  const LoginSubmitted({required this.username, required this.password});
}

/// User submitted the OTP code on the OTP verification screen.
class OtpSubmitted extends AuthEvent {
  final String otpCode;

  const OtpSubmitted({required this.otpCode});
}

/// User tapped "Resend OTP" link.
class OtpResendRequested extends AuthEvent {
  const OtpResendRequested();
}

/// Internal event fired every second to tick down the resend cooldown timer.
class OtpCooldownTicked extends AuthEvent {
  final int remainingSeconds;

  const OtpCooldownTicked({required this.remainingSeconds});
}

/// User tapped "Logout" and confirmed.
class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

// =============================================================================
// SECTION 2: AUTH STATES
// =============================================================================

/// Base class for all authentication states.
abstract class AuthState {
  const AuthState();
}

/// Initial state — also shown while AppStarted is validating a stored
/// session, so the UI can display a splash/loading screen instead of
/// flashing the login form.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Login request is in-flight (API call in progress).
class AuthLoginLoading extends AuthState {
  const AuthLoginLoading();
}

/// Login credentials validated; user requires OTP verification.
/// Carries partial user data (before OTP confirmation).
class AuthOtpRequired extends AuthState {
  final UserModel pendingUser;
  final int cooldownSeconds;
  final bool isLoading;
  final String? errorMessage;

  const AuthOtpRequired({
    required this.pendingUser,
    this.cooldownSeconds = 60,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthOtpRequired copyWith({
    UserModel? pendingUser,
    int? cooldownSeconds,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthOtpRequired(
      pendingUser:     pendingUser     ?? this.pendingUser,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      isLoading:       isLoading       ?? this.isLoading,
      errorMessage:    errorMessage,      // Allow null to clear error
    );
  }
}

/// Authentication fully successful — user is verified and session is active.
class AuthAuthenticated extends AuthState {
  final UserModel user;

  const AuthAuthenticated({required this.user});
}

/// Authentication failed — carries an error message for UI display.
class AuthFailure extends AuthState {
  final String message;
  final AuthFailureType type;

  const AuthFailure({
    required this.message,
    this.type = AuthFailureType.credentials,
  });
}

/// User has been logged out — return to login screen.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Categorizes failure type so the UI can style errors appropriately.
enum AuthFailureType {
  credentials, // Wrong username/password
  otpInvalid,  // Wrong OTP
  otpExpired,  // OTP timed out
  network,     // No connectivity
  server,      // Server-side error
}

// =============================================================================
// SECTION 3: AUTH BLOC
// =============================================================================

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repository;

  // ---------------------------------------------------------------------------
  // OTP Resend Cooldown Timer
  // ---------------------------------------------------------------------------
  Timer? _cooldownTimer;
  static const int _otpCooldownDuration = 60; // seconds

  // Holds the short-lived temp_token issued by api/login.php while the user
  // is on the OTP screen. Never exposed to the UI — verify_otp/resend_otp
  // need it, but the screens only ever read AuthOtpRequired.pendingUser.
  String? _pendingTempToken;

  // ---------------------------------------------------------------------------
  AuthBloc({AuthRepository? repository})
      : _repository = repository ?? ApiAuthRepository(),
        super(const AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<OtpSubmitted>(_onOtpSubmitted);
    on<OtpResendRequested>(_onOtpResendRequested);
    on<OtpCooldownTicked>(_onOtpCooldownTicked);
    on<LogoutRequested>(_onLogoutRequested);
  }

  // ---------------------------------------------------------------------------
  // EVENT HANDLERS
  // ---------------------------------------------------------------------------

  /// Restores a previously saved session, if any, by validating the stored
  /// token against GET /api/me.php. Falls back to AuthUnauthenticated
  /// (showing LoginScreen) if there's no session or the token has expired.
  Future<void> _onAppStarted(
    AppStarted event,
    Emitter<AuthState> emit,
  ) async {
    String? token;
    try {
      token = await SessionManager.instance.getToken();
    } catch (_) {
      // Secure storage unavailable (e.g. platform channel not ready, or
      // running in a plain test environment) — treat as "no session".
      token = null;
    }

    if (token == null || token.isEmpty) {
      emit(const AuthUnauthenticated());
      return;
    }

    try {
      final user = await _repository.fetchCurrentUser(token);
      await SessionManager.instance.saveSession(user);
      emit(AuthAuthenticated(user: user));
    } catch (_) {
      // Token invalid/expired/server unreachable — don't trap the user on a
      // splash screen. Clear the stale session and let them log in again.
      try {
        await SessionManager.instance.clearSession();
      } catch (_) {
        // Ignore — nothing more we can do if storage itself is unavailable.
      }
      emit(const AuthUnauthenticated());
    }
  }

  /// Handles login form submission.
  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoginLoading());

    try {
      final result = await _repository.login(
        username: event.username,
        password: event.password,
      );

      if (result.requiresOtp) {
        _pendingTempToken = result.tempToken;
        final cooldown = result.cooldownSeconds;

        emit(AuthOtpRequired(
          pendingUser: result.pendingUser!,
          cooldownSeconds: cooldown,
        ));
        _startCooldownTimer(initialSeconds: cooldown);
      } else {
        final user = result.user!;
        await SessionManager.instance.saveSession(user);
        emit(AuthAuthenticated(user: user));
      }
    } on ApiException catch (e) {
      emit(AuthFailure(message: e.message, type: _mapErrorType(e)));
    } catch (e) {
      emit(const AuthFailure(
        message: 'An unexpected error occurred. Please try again.',
        type: AuthFailureType.server,
      ));
    }
  }

  /// Handles OTP code submission.
  Future<void> _onOtpSubmitted(
    OtpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    // Ensure we're in the OTP state (safety guard)
    if (state is! AuthOtpRequired) return;
    final currentState = state as AuthOtpRequired;

    emit(currentState.copyWith(isLoading: true, errorMessage: null));

    final tempToken = _pendingTempToken;
    if (tempToken == null) {
      emit(currentState.copyWith(
        isLoading: false,
        errorMessage: 'Your session expired. Please log in again.',
      ));
      return;
    }

    try {
      final user = await _repository.verifyOtp(
        tempToken: tempToken,
        otpCode: event.otpCode,
      );

      _cooldownTimer?.cancel();
      _pendingTempToken = null;
      await SessionManager.instance.saveSession(user);
      emit(AuthAuthenticated(user: user));
    } on ApiException catch (e) {
      emit(currentState.copyWith(isLoading: false, errorMessage: e.message));
    } catch (e) {
      emit(currentState.copyWith(
        isLoading: false,
        errorMessage: 'Verification failed. Please try again.',
      ));
    }
  }

  /// Handles OTP resend request — resets the cooldown timer.
  Future<void> _onOtpResendRequested(
    OtpResendRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state is! AuthOtpRequired) return;
    final currentState = state as AuthOtpRequired;

    final tempToken = _pendingTempToken;
    if (tempToken == null) return;

    try {
      final cooldown = await _repository.resendOtp(tempToken: tempToken);
      emit(currentState.copyWith(cooldownSeconds: cooldown, errorMessage: null));
      _startCooldownTimer(initialSeconds: cooldown);
    } on ApiException catch (e) {
      emit(currentState.copyWith(errorMessage: e.message));
    }
  }

  /// Ticks the cooldown timer each second.
  void _onOtpCooldownTicked(
    OtpCooldownTicked event,
    Emitter<AuthState> emit,
  ) {
    if (state is! AuthOtpRequired) return;
    final currentState = state as AuthOtpRequired;

    emit(currentState.copyWith(cooldownSeconds: event.remainingSeconds));
  }

  /// Handles logout — revokes the token server-side (best effort), clears
  /// the local session, and returns to login.
  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    _cooldownTimer?.cancel();
    _pendingTempToken = null;

    String token = '';
    try {
      token = state is AuthAuthenticated
          ? (state as AuthAuthenticated).user.token
          : await SessionManager.instance.getToken() ?? '';
    } catch (_) {
      // Storage unavailable — proceed with logout anyway using an empty
      // token; the server call below will just no-op.
    }

    try {
      await _repository.logout(token);
    } catch (_) {
      // Best-effort server-side revocation; local logout must proceed
      // regardless of network/server availability.
    }

    try {
      await SessionManager.instance.clearSession();
    } catch (_) {
      // Nothing more we can do if storage itself is unavailable — the
      // user is still logged out from the app's perspective.
    }

    emit(const AuthUnauthenticated());
  }

  // ---------------------------------------------------------------------------
  // PRIVATE HELPERS
  // ---------------------------------------------------------------------------

  /// Starts a countdown that fires OtpCooldownTicked events every second.
  void _startCooldownTimer({int initialSeconds = _otpCooldownDuration}) {
    _cooldownTimer?.cancel();
    int remaining = initialSeconds;

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      if (!isClosed) {
        add(OtpCooldownTicked(remainingSeconds: remaining));
      }
      if (remaining <= 0) {
        timer.cancel();
      }
    });
  }

  /// Maps a backend error_code to the UI-facing failure category.
  AuthFailureType _mapErrorType(ApiException e) {
    if (e.isNetworkError) return AuthFailureType.network;

    switch (e.errorCode) {
      case 'INVALID_CREDENTIALS':
        return AuthFailureType.credentials;
      case 'OTP_INVALID':
        return AuthFailureType.otpInvalid;
      case 'OTP_SESSION_EXPIRED':
      case 'OTP_SESSION_INVALID':
        return AuthFailureType.otpExpired;
      default:
        return AuthFailureType.server;
    }
  }

  // ---------------------------------------------------------------------------
  @override
  Future<void> close() {
    _cooldownTimer?.cancel();
    return super.close();
  }
}
