// =============================================================================
// FILE: lib/core/network/api_exception.dart
// PURPOSE: Typed exception thrown by ApiClient on any non-2xx response or
// network failure. Carries the backend's machine-readable `error_code`
// (see backend/API.md) so BLoCs can branch on it instead of parsing
// human-readable message strings.
// =============================================================================

class ApiException implements Exception {
  final String message;
  final String? errorCode;
  final int? statusCode;

  /// Field-level validation errors, if the backend returned a
  /// { "errors": { "field": "message" } } map (HTTP 422 responses).
  final Map<String, dynamic>? fieldErrors;

  const ApiException({
    required this.message,
    this.errorCode,
    this.statusCode,
    this.fieldErrors,
  });

  /// True when this represents a connectivity problem (no response at all)
  /// rather than a well-formed error response from the server.
  bool get isNetworkError => statusCode == null;

  bool get isAuthError =>
      statusCode == 401 ||
      errorCode == 'AUTH_MISSING_TOKEN' ||
      errorCode == 'AUTH_INVALID_TOKEN' ||
      errorCode == 'AUTH_TOKEN_EXPIRED';

  @override
  String toString() => 'ApiException($statusCode, $errorCode): $message';
}
