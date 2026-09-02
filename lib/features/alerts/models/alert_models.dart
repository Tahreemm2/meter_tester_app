// =============================================================================
// FILE: lib/features/alerts/models/alert_models.dart
// PURPOSE: Maps GET /api/alerts.php rows. Three notification types share one
// feed:
//   - ESCALATION: the overdue-inspection chain (SDO alert -> XEN escalation
//     -> SE escalation). Supervisory roles only.
//   - DISCREPANCY: a newly-reported discrepancy, visible to every
//     supervisory role in scope (not level-gated like escalation).
//   - INSPECTION_DECISION: an SDO/XEN/SE approve/forward/reject decision on
//     an inspection this M&T submitted — the feedback half of the Approval
//     Workflow (3.10). M&T only; a given M&T only ever sees their own.
// See API.md "Notifications: Escalation Alerts & New-Discrepancy Alerts".
// =============================================================================

enum AlertType { escalation, discrepancy, inspectionDecision }

class AppAlert {
  final int id;
  final AlertType type;

  // ESCALATION-only fields (null for other types).
  final int? scheduleId;
  final int? escalationLevel; // 1 = SDO alert, 2 = XEN escalation, 3 = SE escalation
  final int? daysOverdue;
  final String? scheduledDate;
  final String? scheduleStatus;

  // DISCREPANCY-only fields (null for other types).
  final int? discrepancyId;
  final String? discrepancyType;
  final String? discrepancySeverity;
  final String? discrepancyStatus;

  // INSPECTION_DECISION-only fields (null for other types).
  final int? inspectionId;
  final String? inspectionOverallStatus; // PENDING_APPROVAL / APPROVED / REJECTED, as of now (not at decision time)

  // Shared across all types.
  final String? division;
  final String? subDivision;
  final String message;
  final bool isRead;
  final String createdAt;
  final String referenceNumber;
  final String meterId;
  final String consumerName;

  const AppAlert({
    required this.id,
    required this.type,
    this.scheduleId,
    this.escalationLevel,
    this.daysOverdue,
    this.scheduledDate,
    this.scheduleStatus,
    this.discrepancyId,
    this.discrepancyType,
    this.discrepancySeverity,
    this.discrepancyStatus,
    this.inspectionId,
    this.inspectionOverallStatus,
    this.division,
    this.subDivision,
    required this.message,
    required this.isRead,
    required this.createdAt,
    required this.referenceNumber,
    required this.meterId,
    required this.consumerName,
  });

  /// "SDO Alert" / "XEN Escalation" / "SE Escalation" for an escalation row,
  /// "New Discrepancy" for a discrepancy row, "Approved" / "Rejected" /
  /// "Forwarded" for an inspection-decision row.
  String get levelLabel {
    if (type == AlertType.discrepancy) return 'New Discrepancy';
    if (type == AlertType.inspectionDecision) {
      return switch (inspectionOverallStatus) {
        'APPROVED' => 'Approved',
        'REJECTED' => 'Rejected',
        _ => 'Forwarded',
      };
    }
    return switch (escalationLevel) {
      1 => 'SDO Alert',
      2 => 'XEN Escalation',
      3 => 'SE Escalation',
      _ => 'Alert',
    };
  }

  static AlertType _typeFromJson(String? raw) => switch (raw) {
        'DISCREPANCY' => AlertType.discrepancy,
        'INSPECTION_DECISION' => AlertType.inspectionDecision,
        _ => AlertType.escalation,
      };

  factory AppAlert.fromJson(Map<String, dynamic> json) => AppAlert(
        id:                   (json['id'] as num).toInt(),
        type:                 _typeFromJson(json['type'] as String?),
        scheduleId:           (json['schedule_id'] as num?)?.toInt(),
        escalationLevel:      (json['escalation_level'] as num?)?.toInt(),
        daysOverdue:          (json['days_overdue'] as num?)?.toInt(),
        scheduledDate:        json['scheduled_date'] as String?,
        scheduleStatus:       json['schedule_status'] as String?,
        discrepancyId:        (json['discrepancy_id'] as num?)?.toInt(),
        discrepancyType:      json['discrepancy_type'] as String?,
        discrepancySeverity:  json['discrepancy_severity'] as String?,
        discrepancyStatus:    json['discrepancy_status'] as String?,
        inspectionId:         (json['inspection_id'] as num?)?.toInt(),
        inspectionOverallStatus: json['inspection_overall_status'] as String?,
        division:             json['division'] as String?,
        subDivision:          json['sub_division'] as String?,
        message:              json['message'] as String? ?? '',
        isRead:               json['is_read'] == 1 || json['is_read'] == true,
        createdAt:            json['created_at'] as String? ?? '',
        referenceNumber:      json['reference_number'] as String? ?? '',
        meterId:              json['meter_id'] as String? ?? '',
        consumerName:         json['consumer_name'] as String? ?? '',
      );

  AppAlert copyWith({bool? isRead}) => AppAlert(
        id: id,
        type: type,
        scheduleId: scheduleId,
        escalationLevel: escalationLevel,
        daysOverdue: daysOverdue,
        scheduledDate: scheduledDate,
        scheduleStatus: scheduleStatus,
        discrepancyId: discrepancyId,
        discrepancyType: discrepancyType,
        discrepancySeverity: discrepancySeverity,
        discrepancyStatus: discrepancyStatus,
        inspectionId: inspectionId,
        inspectionOverallStatus: inspectionOverallStatus,
        division: division,
        subDivision: subDivision,
        message: message,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        referenceNumber: referenceNumber,
        meterId: meterId,
        consumerName: consumerName,
      );
}
