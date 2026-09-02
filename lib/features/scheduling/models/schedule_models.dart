// =============================================================================
// FILE: lib/features/scheduling/models/schedule_models.dart
// PURPOSE: Data models for the Meter Scheduling System. Mirrors the JSON
// shape returned by backend/api/admin/schedules.php (see API.md "Meter
// Scheduling System"). Despite the admin/ path, access is restricted to
// supervisory roles (SDO/XEN/SE/ADMIN), not ADMIN-exclusive.
// =============================================================================

/// Category used by both Scheduling and Consumer records — B1 through B4.
const List<String> kConsumerCategories = ['B1', 'B2', 'B3', 'B4'];

enum ScheduleStatus { pending, assigned, completed, cancelled, unknown }

extension ScheduleStatusX on ScheduleStatus {
  static ScheduleStatus fromCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'PENDING':   return ScheduleStatus.pending;
      case 'ASSIGNED':  return ScheduleStatus.assigned;
      case 'COMPLETED': return ScheduleStatus.completed;
      case 'CANCELLED': return ScheduleStatus.cancelled;
      default:          return ScheduleStatus.unknown;
    }
  }

  String get code {
    switch (this) {
      case ScheduleStatus.pending:   return 'PENDING';
      case ScheduleStatus.assigned:  return 'ASSIGNED';
      case ScheduleStatus.completed: return 'COMPLETED';
      case ScheduleStatus.cancelled: return 'CANCELLED';
      case ScheduleStatus.unknown:   return 'UNKNOWN';
    }
  }

  String get displayLabel {
    switch (this) {
      case ScheduleStatus.pending:   return 'Pending';
      case ScheduleStatus.assigned:  return 'Assigned';
      case ScheduleStatus.completed: return 'Completed';
      case ScheduleStatus.cancelled: return 'Cancelled';
      case ScheduleStatus.unknown:   return 'Unknown';
    }
  }
}

class ScheduleEntry {
  final int id;
  final int consumerId;
  final String quarter;
  final String? division;
  final String? subDivision;
  final String? category;
  final String scheduledDate;
  final ScheduleStatus status;
  final bool isManualOverride;
  final String? overrideReason;
  final int? generatedByUserId;

  // Joined consumer fields
  final String referenceNumber;
  final String consumerName;
  final String meterId;

  // Automatic reassignment tracking (SRS Schedule section: "Automatically
  // reassigned inspections") — correlated from the linked task_assignments
  // row; both null if never auto-reassigned. See
  // run_auto_reassignment_sweep() in config/helpers.php.
  final String? autoReassignedAt;
  final String? autoReassignedFromName;

  const ScheduleEntry({
    required this.id,
    required this.consumerId,
    required this.quarter,
    this.division,
    this.subDivision,
    this.category,
    required this.scheduledDate,
    required this.status,
    required this.isManualOverride,
    this.overrideReason,
    this.generatedByUserId,
    required this.referenceNumber,
    required this.consumerName,
    required this.meterId,
    this.autoReassignedAt,
    this.autoReassignedFromName,
  });

  /// True when this entry is still open (not completed/cancelled) and its
  /// scheduled date has already passed — a simple "is this late at all"
  /// flag for operational triage. Distinct from the formal SDO->XEN->SE
  /// escalation chain (which only fires at 30/60/90 days overdue — see
  /// GET /api/alerts.php) and from automatic reassignment (which fires once
  /// at 15 days overdue — see autoReassignedAt above); this is just "past
  /// its date," useful the moment a schedule is missed, well before either
  /// of those thresholds.
  bool get isOverdue {
    if (status != ScheduleStatus.pending && status != ScheduleStatus.assigned) return false;
    final date = DateTime.tryParse(scheduledDate);
    if (date == null) return false;
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    return date.isBefore(todayDateOnly);
  }

  /// Whole days since the scheduled date — null if not overdue or unparseable.
  int? get daysOverdue {
    if (!isOverdue) return null;
    final date = DateTime.tryParse(scheduledDate);
    if (date == null) return null;
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    return todayDateOnly.difference(DateTime(date.year, date.month, date.day)).inDays;
  }

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) => ScheduleEntry(
        id:                 (json['id'] as num).toInt(),
        consumerId:         (json['consumer_id'] as num).toInt(),
        quarter:            json['quarter'] as String? ?? '',
        division:           json['division'] as String?,
        subDivision:        json['sub_division'] as String?,
        category:           json['category'] as String?,
        scheduledDate:      json['scheduled_date'] as String? ?? '',
        status:             ScheduleStatusX.fromCode(json['status'] as String?),
        isManualOverride:   _asBool(json['is_manual_override']),
        overrideReason:     json['override_reason'] as String?,
        generatedByUserId:  (json['generated_by_user_id'] as num?)?.toInt(),
        referenceNumber:    json['reference_number'] as String? ?? '',
        consumerName:       json['consumer_name'] as String? ?? '',
        meterId:            json['meter_id'] as String? ?? '',
        autoReassignedAt:       json['auto_reassigned_at'] as String?,
        autoReassignedFromName: json['auto_reassigned_from_name'] as String?,
      );
}

bool _asBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value == '1' || value.toLowerCase() == 'true';
  return false;
}

/// Computes the current + next quarter strings ("YYYY-Qn") for quick-pick UI.
List<String> upcomingQuarters({int count = 4}) {
  final now = DateTime.now();
  final quarters = <String>[];
  var year = now.year;
  var q = ((now.month - 1) ~/ 3) + 1;
  for (var i = 0; i < count; i++) {
    quarters.add('$year-Q$q');
    q += 1;
    if (q > 4) {
      q = 1;
      year += 1;
    }
  }
  return quarters;
}
