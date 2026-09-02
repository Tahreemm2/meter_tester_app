// =============================================================================
// FILE: lib/features/discrepancies/models/discrepancy_models.dart
// PURPOSE: Data models for the Discrepancy Reporting feature. Mirrors the
// JSON shape returned by backend/api/discrepancies.php (see API.md
// "Discrepancy Reporting").
// =============================================================================

const List<String> kDiscrepancyTypes = ['THEFT', 'SLOWNESS', 'DAMAGE', 'TAMPERING', 'ABNORMAL_READING'];
const List<String> kDiscrepancySeverities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];

enum DiscrepancyStatus { open, underReview, resolved, dismissed, unknown }

extension DiscrepancyStatusX on DiscrepancyStatus {
  static DiscrepancyStatus fromCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'OPEN':          return DiscrepancyStatus.open;
      case 'UNDER_REVIEW':  return DiscrepancyStatus.underReview;
      case 'RESOLVED':      return DiscrepancyStatus.resolved;
      case 'DISMISSED':     return DiscrepancyStatus.dismissed;
      default:              return DiscrepancyStatus.unknown;
    }
  }

  String get code {
    switch (this) {
      case DiscrepancyStatus.open:         return 'OPEN';
      case DiscrepancyStatus.underReview:  return 'UNDER_REVIEW';
      case DiscrepancyStatus.resolved:     return 'RESOLVED';
      case DiscrepancyStatus.dismissed:    return 'DISMISSED';
      case DiscrepancyStatus.unknown:      return 'UNKNOWN';
    }
  }

  String get displayLabel {
    switch (this) {
      case DiscrepancyStatus.open:         return 'Open';
      case DiscrepancyStatus.underReview:  return 'Under Review';
      case DiscrepancyStatus.resolved:     return 'Resolved';
      case DiscrepancyStatus.dismissed:    return 'Dismissed';
      case DiscrepancyStatus.unknown:      return 'Unknown';
    }
  }
}

extension DiscrepancyTypeLabel on String {
  String get discrepancyTypeLabel {
    switch (toUpperCase()) {
      case 'THEFT':             return 'Theft';
      case 'SLOWNESS':          return 'Slowness';
      case 'DAMAGE':            return 'Damage';
      case 'TAMPERING':         return 'Tampering';
      case 'ABNORMAL_READING':  return 'Abnormal Reading';
      default:                  return this;
    }
  }
}

class DiscrepancyReport {
  final int id;
  final int? inspectionId;
  final int? consumerId;
  final String type;
  final String description;
  final String severity;
  final String? photoEvidenceUrl;
  final DiscrepancyStatus status;
  final String? resolutionNotes;
  final String? createdAt;
  final String? updatedAt;

  // Joined fields
  final String? referenceNumber;
  final String? consumerName;
  final String reportedByName;
  final int? assignedToUserId;
  final String? assignedToName; // "Assigned M&T worker" per SRS — distinct from reportedByName/resolvedByName
  final String? resolvedByName;

  const DiscrepancyReport({
    required this.id,
    this.inspectionId,
    this.consumerId,
    required this.type,
    required this.description,
    required this.severity,
    this.photoEvidenceUrl,
    required this.status,
    this.resolutionNotes,
    this.createdAt,
    this.updatedAt,
    this.referenceNumber,
    this.consumerName,
    required this.reportedByName,
    this.assignedToUserId,
    this.assignedToName,
    this.resolvedByName,
  });

  factory DiscrepancyReport.fromJson(Map<String, dynamic> json) => DiscrepancyReport(
        id:                (json['id'] as num).toInt(),
        inspectionId:      (json['inspection_id'] as num?)?.toInt(),
        consumerId:        (json['consumer_id'] as num?)?.toInt(),
        type:              json['type'] as String? ?? '',
        description:       json['description'] as String? ?? '',
        severity:          json['severity'] as String? ?? '',
        photoEvidenceUrl:  json['photo_evidence_url'] as String?,
        status:            DiscrepancyStatusX.fromCode(json['status'] as String?),
        resolutionNotes:   json['resolution_notes'] as String?,
        createdAt:         json['created_at'] as String?,
        updatedAt:         json['updated_at'] as String?,
        referenceNumber:   json['reference_number'] as String?,
        consumerName:      json['consumer_name'] as String?,
        reportedByName:    json['reported_by_name'] as String? ?? '',
        assignedToUserId:  (json['assigned_to_user_id'] as num?)?.toInt(),
        assignedToName:    json['assigned_to_name'] as String?,
        resolvedByName:    json['resolved_by_name'] as String?,
      );
}
