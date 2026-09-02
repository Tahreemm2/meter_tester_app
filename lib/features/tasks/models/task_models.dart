// =============================================================================
// FILE: lib/features/tasks/models/task_models.dart
// PURPOSE: Data models for the Task Assignment feature. Mirrors the JSON
// shape returned by backend/api/tasks.php (see API.md "Task Assignment").
// =============================================================================

/// Task lifecycle states — must match VALID_TASK_STATUSES in tasks.php.
enum TaskStatus { pending, inProgress, completed, cancelled, unknown }

extension TaskStatusX on TaskStatus {
  static TaskStatus fromCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'PENDING':     return TaskStatus.pending;
      case 'IN_PROGRESS': return TaskStatus.inProgress;
      case 'COMPLETED':   return TaskStatus.completed;
      case 'CANCELLED':   return TaskStatus.cancelled;
      default:            return TaskStatus.unknown;
    }
  }

  String get code {
    switch (this) {
      case TaskStatus.pending:     return 'PENDING';
      case TaskStatus.inProgress:  return 'IN_PROGRESS';
      case TaskStatus.completed:   return 'COMPLETED';
      case TaskStatus.cancelled:   return 'CANCELLED';
      case TaskStatus.unknown:     return 'UNKNOWN';
    }
  }

  String get displayLabel {
    switch (this) {
      case TaskStatus.pending:     return 'Pending';
      case TaskStatus.inProgress:  return 'In Progress';
      case TaskStatus.completed:   return 'Completed';
      case TaskStatus.cancelled:   return 'Cancelled';
      case TaskStatus.unknown:     return 'Unknown';
    }
  }
}

// -----------------------------------------------------------------------------
// TASK  (backend/api/tasks.php — TASK_SELECT_SQL)
// -----------------------------------------------------------------------------
class TaskAssignment {
  final int id;
  final int? scheduleId;
  final int consumerId;
  final int assignedToUserId;
  final int assignedByUserId;
  final TaskStatus status;
  final String? dueDate;
  final String? notes;
  final int? inspectionId;
  final String? createdAt;
  final String? updatedAt;

  // Joined consumer fields
  final String referenceNumber;
  final String consumerName;
  final String meterId;
  final String? division;
  final String? subDivision;

  // Joined user fields
  final String assignedToName;
  final String assignedByName;

  // Automatic reassignment tracking (SRS Schedule section: "Automatically
  // reassigned inspections") — both null if this task has never been
  // auto-reassigned by the system. Distinct from a supervisor manually
  // changing assignedToUserId via PUT.
  final String? autoReassignedAt;
  final String? autoReassignedFromName;

  // Approval Workflow outcome (spec 3.10) of the linked inspection —
  // PENDING_APPROVAL | APPROVED | REJECTED, or null when inspectionId is
  // null (no inspection submitted against this task yet). Lets the task
  // list/detail screens show the tester the outcome without a separate
  // fetch, and tell a fresh "Start Inspection" apart from a post-rejection
  // "Inspect Again".
  final String? inspectionOverallStatus;

  const TaskAssignment({
    required this.id,
    this.scheduleId,
    required this.consumerId,
    required this.assignedToUserId,
    required this.assignedByUserId,
    required this.status,
    this.dueDate,
    this.notes,
    this.inspectionId,
    this.createdAt,
    this.updatedAt,
    required this.referenceNumber,
    required this.consumerName,
    required this.meterId,
    this.division,
    this.subDivision,
    required this.assignedToName,
    required this.assignedByName,
    this.autoReassignedAt,
    this.autoReassignedFromName,
    this.inspectionOverallStatus,
  });

  /// True when this task is still open (not completed/cancelled) and its
  /// due date has already passed — see ScheduleEntry.isOverdue for why this
  /// is a safe pure-client computation ahead of a real backend alerting
  /// feature.
  bool get isOverdue {
    if (status != TaskStatus.pending && status != TaskStatus.inProgress) return false;
    if (dueDate == null) return false;
    final date = DateTime.tryParse(dueDate!);
    if (date == null) return false;
    final today = DateTime.now();
    return date.isBefore(DateTime(today.year, today.month, today.day));
  }

  /// True when this task's linked inspection was rejected by a reviewer —
  /// the task itself is reopened to PENDING server-side when that happens
  /// (see approvals.php), so the tester can inspect again.
  bool get isRejectedInspection => inspectionOverallStatus == 'REJECTED';

  factory TaskAssignment.fromJson(Map<String, dynamic> json) => TaskAssignment(
        id:               (json['id'] as num).toInt(),
        scheduleId:       (json['schedule_id'] as num?)?.toInt(),
        consumerId:       (json['consumer_id'] as num).toInt(),
        assignedToUserId: (json['assigned_to_user_id'] as num).toInt(),
        assignedByUserId: (json['assigned_by_user_id'] as num).toInt(),
        status:           TaskStatusX.fromCode(json['status'] as String?),
        dueDate:          json['due_date'] as String?,
        notes:            json['notes'] as String?,
        inspectionId:     (json['inspection_id'] as num?)?.toInt(),
        createdAt:        json['created_at'] as String?,
        updatedAt:        json['updated_at'] as String?,
        referenceNumber:  json['reference_number'] as String? ?? '',
        consumerName:     json['consumer_name'] as String? ?? '',
        meterId:          json['meter_id'] as String? ?? '',
        division:         json['division'] as String?,
        subDivision:      json['sub_division'] as String?,
        assignedToName:   json['assigned_to_name'] as String? ?? '',
        assignedByName:   json['assigned_by_name'] as String? ?? '',
        autoReassignedAt:       json['auto_reassigned_at'] as String?,
        autoReassignedFromName: json['auto_reassigned_from_name'] as String?,
        inspectionOverallStatus: json['inspection_overall_status'] as String?,
      );

  TaskAssignment copyWith({TaskStatus? status}) => TaskAssignment(
        id: id,
        scheduleId: scheduleId,
        consumerId: consumerId,
        assignedToUserId: assignedToUserId,
        assignedByUserId: assignedByUserId,
        status: status ?? this.status,
        dueDate: dueDate,
        notes: notes,
        inspectionId: inspectionId,
        createdAt: createdAt,
        updatedAt: updatedAt,
        referenceNumber: referenceNumber,
        consumerName: consumerName,
        meterId: meterId,
        division: division,
        subDivision: subDivision,
        assignedToName: assignedToName,
        assignedByName: assignedByName,
        autoReassignedAt: autoReassignedAt,
        autoReassignedFromName: autoReassignedFromName,
        inspectionOverallStatus: inspectionOverallStatus,
      );
}
