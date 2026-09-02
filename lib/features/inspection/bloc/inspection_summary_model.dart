// =============================================================================
// FILE: lib/features/inspection/bloc/inspection_summary_model.dart
// PURPOSE: Read-model for a previously submitted inspection, as returned by
// GET /api/data.php?action=inspections-list. Kept separate from
// inspection_models.dart (which models the in-progress form state) since
// this is a display-only summary of already-synced records.
// =============================================================================

class InspectionSummary {
  final int id;
  final String referenceNumber;
  final String meterId;
  final String consumerAccount;
  final String inspectionDatetime;
  final double? kwh;
  final double? kvarh;
  final double? mdi;
  final String? loadDetails;
  final double? touPeak;
  final double? touOffPeak;
  final double? touDay;
  final double? touNight;
  final String? sealConditionCode;
  final String? ctptBoxStatusCode;
  final int? taskId;
  final String? overallStatus;       // PENDING_APPROVAL | APPROVED | REJECTED
  final int? currentApprovalLevel;
  final String? consumerName;
  final String? division;
  final String? subDivision;
  final String? category;
  final int imageCount;
  final String submittedBy;
  final String? createdAt;

  const InspectionSummary({
    required this.id,
    required this.referenceNumber,
    required this.meterId,
    required this.consumerAccount,
    required this.inspectionDatetime,
    this.kwh,
    this.kvarh,
    this.mdi,
    this.loadDetails,
    this.touPeak,
    this.touOffPeak,
    this.touDay,
    this.touNight,
    this.sealConditionCode,
    this.ctptBoxStatusCode,
    this.taskId,
    this.overallStatus,
    this.currentApprovalLevel,
    this.consumerName,
    this.division,
    this.subDivision,
    this.category,
    this.imageCount = 0,
    required this.submittedBy,
    this.createdAt,
  });

  factory InspectionSummary.fromJson(Map<String, dynamic> json) => InspectionSummary(
        id:                    (json['id'] as num).toInt(),
        referenceNumber:       json['reference_number'] as String? ?? '',
        meterId:               json['meter_id'] as String? ?? '',
        consumerAccount:       json['consumer_account'] as String? ?? '',
        inspectionDatetime:    json['inspection_datetime'] as String? ?? '',
        kwh:                   _asDouble(json['kwh']),
        kvarh:                 _asDouble(json['kvarh']),
        mdi:                   _asDouble(json['mdi']),
        loadDetails:           json['load_details'] as String?,
        touPeak:               _asDouble(json['tou_peak']),
        touOffPeak:            _asDouble(json['tou_off_peak']),
        touDay:                _asDouble(json['tou_day']),
        touNight:              _asDouble(json['tou_night']),
        sealConditionCode:     json['seal_condition_code'] as String?,
        ctptBoxStatusCode:     json['ctpt_box_status_code'] as String?,
        taskId:                (json['task_id'] as num?)?.toInt(),
        overallStatus:         json['overall_status'] as String?,
        currentApprovalLevel:  (json['current_approval_level'] as num?)?.toInt(),
        consumerName:          json['consumer_name'] as String?,
        division:              json['division'] as String?,
        subDivision:           json['sub_division'] as String?,
        category:              json['category'] as String?,
        imageCount:            (json['image_count'] as num?)?.toInt() ?? 0,
        submittedBy:           json['submitted_by'] as String? ?? '',
        createdAt:             json['created_at'] as String?,
      );
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
