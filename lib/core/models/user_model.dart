// =============================================================================
// FILE: lib/core/models/user_model.dart
// PURPOSE: Data models for the authenticated user session.
//
// API CONTRACT (live):
//   Deserializes the JSON returned by the real backend
//   (POST /api/login.php, GET /api/me.php) via `UserModel.fromJson(...)`.
//   See lib/features/auth/data/auth_repository.dart for the calling code.
// =============================================================================

// -----------------------------------------------------------------------------
// ENUMS — UserRole & GeographicScope
// -----------------------------------------------------------------------------

/// Roles defined for the Meter Testing System.
/// Values must match the string codes sent by the PHP API.
enum UserRole {
  mt,     // Meter Tester — field worker, lowest access
  sdo,    // Sub-Divisional Officer
  xen,    // Executive Engineer
  se,     // Superintending Engineer
  admin,  // System Administrator — full access
  unknown,
}

/// Extension to convert API string → enum and display label → string.
extension UserRoleExtension on UserRole {
  /// Maps API string code to enum value.
  static UserRole fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'MT':    return UserRole.mt;
      case 'SDO':   return UserRole.sdo;
      case 'XEN':   return UserRole.xen;
      case 'SE':    return UserRole.se;
      case 'ADMIN': return UserRole.admin;
      default:      return UserRole.unknown;
    }
  }

  /// Returns the API-compatible string code for this role.
  String get code {
    switch (this) {
      case UserRole.mt:      return 'MT';
      case UserRole.sdo:     return 'SDO';
      case UserRole.xen:     return 'XEN';
      case UserRole.se:      return 'SE';
      case UserRole.admin:   return 'ADMIN';
      case UserRole.unknown: return 'UNKNOWN';
    }
  }

  /// Human-readable display name for UI rendering.
  String get displayName {
    switch (this) {
      case UserRole.mt:      return 'Meter Tester (M&T)';
      case UserRole.sdo:     return 'Sub-Divisional Officer';
      case UserRole.xen:     return 'Executive Engineer';
      case UserRole.se:      return 'Superintending Engineer';
      case UserRole.admin:   return 'System Administrator';
      case UserRole.unknown: return 'Unknown Role';
    }
  }

  /// Access level (0 = lowest, 4 = highest). Used for permission gates.
  int get accessLevel {
    switch (this) {
      case UserRole.mt:      return 0;
      case UserRole.sdo:     return 1;
      case UserRole.xen:     return 2;
      case UserRole.se:      return 3;
      case UserRole.admin:   return 4;
      case UserRole.unknown: return -1;
    }
  }
}

// -----------------------------------------------------------------------------

/// Geographic scope of the user's operational authority.
enum GeographicScope {
  subDivision, // M&T, SDO level
  division,    // XEN level
  circle,      // SE level
  region,      // Regional oversight
  national,    // Admin / national view
  unassigned,
}

extension GeographicScopeExtension on GeographicScope {
  static GeographicScope fromCode(String code) {
    switch (code.toUpperCase()) {
      case 'SUB_DIVISION': return GeographicScope.subDivision;
      case 'DIVISION':     return GeographicScope.division;
      case 'CIRCLE':       return GeographicScope.circle;
      case 'REGION':       return GeographicScope.region;
      case 'NATIONAL':     return GeographicScope.national;
      default:             return GeographicScope.unassigned;
    }
  }

  String get code {
    switch (this) {
      case GeographicScope.subDivision: return 'SUB_DIVISION';
      case GeographicScope.division:    return 'DIVISION';
      case GeographicScope.circle:      return 'CIRCLE';
      case GeographicScope.region:      return 'REGION';
      case GeographicScope.national:    return 'NATIONAL';
      case GeographicScope.unassigned:  return 'UNASSIGNED';
    }
  }

  String get displayLabel {
    switch (this) {
      case GeographicScope.subDivision: return 'Sub-Division';
      case GeographicScope.division:    return 'Division';
      case GeographicScope.circle:      return 'Circle';
      case GeographicScope.region:      return 'Region';
      case GeographicScope.national:    return 'National (All)';
      case GeographicScope.unassigned:  return 'Unassigned';
    }
  }
}

// -----------------------------------------------------------------------------
// USER MODEL
// -----------------------------------------------------------------------------

/// Represents the authenticated user session payload.
/// Directly mirrors the expected PHP API JSON response.
class UserModel {
  final String employeeId;       // Unique employee identifier
  final String fullName;         // Display name
  final String username;         // Login username / email
  final UserRole role;           // Parsed role enum
  final GeographicScope scope;   // Parsed geographic scope enum
  final String scopeName;        // Named area (e.g., "Multan North Sub-Division")
  final String token;            // Bearer token for subsequent API calls
  final bool isFirstTimeLogin;   // Triggers OTP screen if true
  final String? contactMasked;   // Masked contact for OTP display (e.g., "***-***-7890")

  const UserModel({
    required this.employeeId,
    required this.fullName,
    required this.username,
    required this.role,
    required this.scope,
    required this.scopeName,
    required this.token,
    required this.isFirstTimeLogin,
    this.contactMasked,
  });

  // ---------------------------------------------------------------------------
  // JSON DESERIALIZATION (ready for PHP REST API)
  // ---------------------------------------------------------------------------
  /// Constructs a UserModel from the API JSON response.
  /// Expected JSON shape:
  /// {
  ///   "employee_id": "EMP001",
  ///   "full_name": "Muhammad Ali Khan",
  ///   "username": "ali.khan",
  ///   "role_code": "SDO",
  ///   "scope_code": "SUB_DIVISION",
  ///   "scope_name": "Multan North Sub-Division",
  ///   "token": "eyJ...",
  ///   "is_first_login": true,
  ///   "contact_masked": "***-***-7890"
  /// }
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      employeeId:       json['employee_id']    as String? ?? '',
      fullName:         json['full_name']       as String? ?? '',
      username:         json['username']        as String? ?? '',
      role:             UserRoleExtension.fromCode(json['role_code'] as String? ?? ''),
      scope:            GeographicScopeExtension.fromCode(json['scope_code'] as String? ?? ''),
      scopeName:        json['scope_name']      as String? ?? '',
      token:            json['token']           as String? ?? '',
      isFirstTimeLogin: json['is_first_login']  as bool?   ?? false,
      contactMasked:    json['contact_masked']  as String?,
    );
  }

  /// Serializes model back to JSON (useful for local session caching).
  Map<String, dynamic> toJson() => {
    'employee_id':    employeeId,
    'full_name':      fullName,
    'username':       username,
    'role_code':      role.code,
    'scope_code':     scope.code,
    'scope_name':     scopeName,
    'token':          token,
    'is_first_login': isFirstTimeLogin,
    'contact_masked': contactMasked,
  };

  // ---------------------------------------------------------------------------
  // COPYWIDTH (immutable update pattern)
  // ---------------------------------------------------------------------------
  UserModel copyWith({
    String? employeeId,
    String? fullName,
    String? username,
    UserRole? role,
    GeographicScope? scope,
    String? scopeName,
    String? token,
    bool? isFirstTimeLogin,
    String? contactMasked,
  }) {
    return UserModel(
      employeeId:       employeeId       ?? this.employeeId,
      fullName:         fullName         ?? this.fullName,
      username:         username         ?? this.username,
      role:             role             ?? this.role,
      scope:            scope            ?? this.scope,
      scopeName:        scopeName        ?? this.scopeName,
      token:            token            ?? this.token,
      isFirstTimeLogin: isFirstTimeLogin ?? this.isFirstTimeLogin,
      contactMasked:    contactMasked    ?? this.contactMasked,
    );
  }

  @override
  String toString() =>
    'UserModel(id: $employeeId, name: $fullName, role: ${role.code}, scope: ${scope.code})';
}
