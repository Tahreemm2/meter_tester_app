// =============================================================================
// FILE: lib/features/approvals/models/approval_models.dart
// PURPOSE: Data models for the Approval Workflow feature. Mirrors the JSON
// shape returned by backend/api/approvals.php (see API.md "Approval
// Workflow"). An inspection moves through a sequential chain of reviews:
// SDO -> XEN -> SE, with the exact chain depending on the consumer's
// category (configured server-side via api/admin/approval_rules.php).
// =============================================================================

/// Overall approval outcome — must match backend ENUM on `inspections.overall_status`.
enum ApprovalOverallStatus { pendingApproval, approved, rejected, unknown }

extension ApprovalOverallStatusX on ApprovalOverallStatus {
  static ApprovalOverallStatus fromCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'PENDING_APPROVAL': return ApprovalOverallStatus.pendingApproval;
      case 'APPROVED':         return ApprovalOverallStatus.approved;
      case 'REJECTED':         return ApprovalOverallStatus.rejected;
      default:                 return ApprovalOverallStatus.unknown;
    }
  }

  String get code {
    switch (this) {
      case ApprovalOverallStatus.pendingApproval: return 'PENDING_APPROVAL';
      case ApprovalOverallStatus.approved:         return 'APPROVED';
      case ApprovalOverallStatus.rejected:         return 'REJECTED';
      case ApprovalOverallStatus.unknown:          return 'UNKNOWN';
    }
  }

  String get displayLabel {
    switch (this) {
      case ApprovalOverallStatus.pendingApproval: return 'Pending Approval';
      case ApprovalOverallStatus.approved:         return 'Approved';
      case ApprovalOverallStatus.rejected:         return 'Rejected';
      case ApprovalOverallStatus.unknown:          return 'Unknown';
    }
  }
}

/// Which supervisory role a given approval level (1/2/3) maps to — must match
/// APPROVAL_LEVEL_ROLES in backend/config/helpers.php.
String? roleForApprovalLevel(int level) {
  switch (level) {
    case 1: return 'SDO';
    case 2: return 'XEN';
    case 3: return 'SE';
    default: return null;
  }
}

// -----------------------------------------------------------------------------
// APPROVAL HISTORY ENTRY (one row per level decided)
// -----------------------------------------------------------------------------
class ApprovalHistoryEntry {
  final int level;
  final String roleCode;
  final String action; // APPROVED | REJECTED
  final String? remarks;
  final String approverName;
  final String? createdAt;

  const ApprovalHistoryEntry({
    required this.level,
    required this.roleCode,
    required this.action,
    this.remarks,
    required this.approverName,
    this.createdAt,
  });

  factory ApprovalHistoryEntry.fromJson(Map<String, dynamic> json) => ApprovalHistoryEntry(
        level:        (json['level'] as num).toInt(),
        roleCode:     json['role_code'] as String? ?? '',
        action:       json['action'] as String? ?? '',
        remarks:      json['remarks'] as String?,
        approverName: json['approver_name'] as String? ?? '',
        createdAt:    json['created_at'] as String?,
      );
}

// -----------------------------------------------------------------------------
// INSPECTION APPROVAL  (backend/api/approvals.php — INSPECTION_SELECT_SQL)
// -----------------------------------------------------------------------------
class InspectionApproval {
  final int id;
  final String referenceNumber;
  final String meterId;
  final String consumerAccount;
  final String inspectionDatetime;
  final double kwh;
  final double kvarh;
  final double mdi;
  final ApprovalOverallStatus overallStatus;
  final int currentApprovalLevel;
  final String? consumerName;
  final String? division;
  final String? subDivision;
  final String? category;
  final String submittedByName;
  final String? createdAt;

  // Only populated on the single-inspection GET (?id=), not the list.
  final List<ApprovalHistoryEntry> history;

  const InspectionApproval({
    required this.id,
    required this.referenceNumber,
    required this.meterId,
    required this.consumerAccount,
    required this.inspectionDatetime,
    required this.kwh,
    required this.kvarh,
    required this.mdi,
    required this.overallStatus,
    required this.currentApprovalLevel,
    this.consumerName,
    this.division,
    this.subDivision,
    this.category,
    required this.submittedByName,
    this.createdAt,
    this.history = const [],
  });

  /// Which role must decide this inspection right now, or null if it's
  /// already finalized (APPROVED/REJECTED).
  String? get pendingRole => roleForApprovalLevel(currentApprovalLevel);

  factory InspectionApproval.fromJson(Map<String, dynamic> json) => InspectionApproval(
        id:                   (json['id'] as num).toInt(),
        referenceNumber:      json['reference_number'] as String? ?? '',
        meterId:              json['meter_id'] as String? ?? '',
        consumerAccount:      json['consumer_account'] as String? ?? '',
        inspectionDatetime:   json['inspection_datetime'] as String? ?? '',
        kwh:                  _asDouble(json['kwh']) ?? 0,
        kvarh:                _asDouble(json['kvarh']) ?? 0,
        mdi:                  _asDouble(json['mdi']) ?? 0,
        overallStatus:        ApprovalOverallStatusX.fromCode(json['overall_status'] as String?),
        currentApprovalLevel: (json['current_approval_level'] as num?)?.toInt() ?? 0,
        consumerName:         json['consumer_name'] as String?,
        division:             json['division'] as String?,
        subDivision:          json['sub_division'] as String?,
        category:             json['category'] as String?,
        submittedByName:      json['submitted_by_name'] as String? ?? '',
        createdAt:            json['created_at'] as String?,
        history: (json['history'] as List?)
                ?.map((e) => ApprovalHistoryEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// Backend DECIMAL columns (kwh/kvarh/mdi, GPS, TOU) can arrive as either a
/// JSON number or a numeric string, depending on the DB driver's handling of
/// DECIMAL types — see cast_decimal_fields() in backend/config/helpers.php.
/// Accepting both here matches the same defensive parsing already used by
/// InspectionSummary and InspectionDetail (features/inspection/bloc/).
double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
