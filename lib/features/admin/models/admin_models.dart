// =============================================================================
// FILE: lib/features/admin/models/admin_models.dart
// PURPOSE: Data models for the Admin management feature — employee accounts,
// consumer/meter records, and inspection-form dropdown options. Mirrors the
// JSON shapes returned by backend/api/admin/*.php (see API.md).
// =============================================================================

// -----------------------------------------------------------------------------
// MANAGED USER  (backend/api/admin/users.php)
// -----------------------------------------------------------------------------
class ManagedUser {
  final int id;
  final String employeeId;
  final String fullName;
  final String username;
  final String roleCode;
  final String scopeCode;
  final String scopeName;
  final String? contactNumber;
  final bool isFirstLogin;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  const ManagedUser({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.username,
    required this.roleCode,
    required this.scopeCode,
    required this.scopeName,
    this.contactNumber,
    required this.isFirstLogin,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory ManagedUser.fromJson(Map<String, dynamic> json) => ManagedUser(
        id:            (json['id'] as num).toInt(),
        employeeId:    json['employee_id'] as String? ?? '',
        fullName:      json['full_name'] as String? ?? '',
        username:      json['username'] as String? ?? '',
        roleCode:      json['role_code'] as String? ?? '',
        scopeCode:     json['scope_code'] as String? ?? '',
        scopeName:     json['scope_name'] as String? ?? '',
        contactNumber: json['contact_number'] as String?,
        // MySQL TINYINT(1) can come back as bool, int, or numeric string
        // depending on driver — normalize defensively.
        isFirstLogin:  _asBool(json['is_first_login']),
        isActive:      _asBool(json['is_active'], defaultValue: true),
        createdAt:     json['created_at'] as String?,
        updatedAt:     json['updated_at'] as String?,
      );

  ManagedUser copyWith({bool? isActive}) => ManagedUser(
        id: id,
        employeeId: employeeId,
        fullName: fullName,
        username: username,
        roleCode: roleCode,
        scopeCode: scopeCode,
        scopeName: scopeName,
        contactNumber: contactNumber,
        isFirstLogin: isFirstLogin,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

// -----------------------------------------------------------------------------
// MANAGED CONSUMER  (backend/api/admin/consumers.php)
// -----------------------------------------------------------------------------
class ManagedConsumer {
  final int id;
  final String referenceNumber;
  final String meterId;
  final String consumerName;
  final String consumerAddress;
  final String consumerAccount;
  final String tariffCategory;
  final String sanctionedLoad;
  final String? createdAt;

  const ManagedConsumer({
    required this.id,
    required this.referenceNumber,
    required this.meterId,
    required this.consumerName,
    required this.consumerAddress,
    required this.consumerAccount,
    required this.tariffCategory,
    required this.sanctionedLoad,
    this.createdAt,
  });

  factory ManagedConsumer.fromJson(Map<String, dynamic> json) => ManagedConsumer(
        id:              (json['id'] as num).toInt(),
        referenceNumber: json['reference_number'] as String? ?? '',
        meterId:         json['meter_id'] as String? ?? '',
        consumerName:    json['consumer_name'] as String? ?? '',
        consumerAddress: json['consumer_address'] as String? ?? '',
        consumerAccount: json['consumer_account'] as String? ?? '',
        tariffCategory:  json['tariff_category'] as String? ?? '',
        sanctionedLoad:  json['sanctioned_load'] as String? ?? '',
        createdAt:       json['created_at'] as String?,
      );
}

// -----------------------------------------------------------------------------
// MANAGED FORM OPTION  (backend/api/admin/form_options.php)
// -----------------------------------------------------------------------------
class ManagedFormOption {
  final int id;
  final String dropdownKey; // 'SEAL_CONDITION' | 'CTPT_BOX'
  final String code;
  final String label;
  final String? description;
  final int sortOrder;
  final bool isActive;

  const ManagedFormOption({
    required this.id,
    required this.dropdownKey,
    required this.code,
    required this.label,
    this.description,
    required this.sortOrder,
    required this.isActive,
  });

  factory ManagedFormOption.fromJson(Map<String, dynamic> json) => ManagedFormOption(
        id:          (json['id'] as num).toInt(),
        dropdownKey: json['dropdown_key'] as String? ?? '',
        code:        json['code'] as String? ?? '',
        label:       json['label'] as String? ?? '',
        description: json['description'] as String?,
        sortOrder:   (json['sort_order'] as num?)?.toInt() ?? 0,
        isActive:    _asBool(json['is_active'], defaultValue: true),
      );
}

/// Normalizes a value that might be bool, int (0/1), or numeric string into
/// a Dart bool. PHP/MySQL JSON encoding of TINYINT(1) columns is inconsistent
/// across drivers, so this is defensive rather than assuming one shape.
bool _asBool(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value == '1' || value.toLowerCase() == 'true';
  return defaultValue;
}
