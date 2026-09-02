// =============================================================================
// FILE: lib/features/inspection/bloc/inspection_detail_model.dart
// PURPOSE: Read-model for a single inspection's full record, as returned by
// GET /api/data.php?action=inspection-detail&id=42 — every reading, GPS
// coordinate, equipment-condition code, and uploaded image for one
// inspection. Distinct from InspectionSummary (the list-row shape, which
// omits images and the consumer's address/tariff/sanctioned-load) — see
// inspection_summary_model.dart.
//
// Supervisory roles (SDO/XEN/SE/ADMIN) may fetch any inspection within their
// enforced scope; this is what backs the "Consumer Info / Meter Info / GPS /
// Equipment Condition / Images" detail view used by the Approval Workflow
// and the SDO's read-only Inspection Management screen.
// =============================================================================

class InspectionImage {
  final String type; // METER | SEAL | INSTALLATION | LOAD
  final String url;
  final double? latitude;
  final double? longitude;
  final String? capturedAt;

  const InspectionImage({
    required this.type,
    required this.url,
    this.latitude,
    this.longitude,
    this.capturedAt,
  });

  factory InspectionImage.fromJson(Map<String, dynamic> json) => InspectionImage(
        type:       json['image_type'] as String? ?? '',
        url:        json['image_url'] as String? ?? '',
        latitude:   _asDouble(json['gps_latitude']),
        longitude:  _asDouble(json['gps_longitude']),
        capturedAt: json['captured_at'] as String?,
      );

  String get typeLabel {
    switch (type.toUpperCase()) {
      case 'METER':        return 'Meter';
      case 'SEAL':         return 'Seal';
      case 'INSTALLATION': return 'Installation';
      case 'LOAD':         return 'Load';
      default:             return type;
    }
  }
}

/// The most recent REJECT decision on an inspection — present on
/// [InspectionDetail.rejection] only when `overall_status == REJECTED`. This
/// is the one piece of Approval Workflow history exposed to the submitting
/// M&T directly on the record itself (GET ?action=inspection-detail), since
/// GET /api/approvals.php?id= is supervisory-role-only and 403s for them.
class InspectionRejection {
  final String? roleCode; // SDO | XEN | SE — which level rejected it
  final String? remarks;
  final String? createdAt;
  final String? approverName;

  const InspectionRejection({this.roleCode, this.remarks, this.createdAt, this.approverName});

  factory InspectionRejection.fromJson(Map<String, dynamic> json) => InspectionRejection(
        roleCode:     json['role_code'] as String?,
        remarks:      json['remarks'] as String?,
        createdAt:    json['created_at'] as String?,
        approverName: json['approver_name'] as String?,
      );
}

class InspectionDetail {
  final int id;
  final String referenceNumber;
  final String meterId;
  final String consumerAccount;
  final String inspectionDatetime;

  // SECTION A — Consumer info
  final String? consumerName;
  final String? consumerAddress;
  final String? division;
  final String? subDivision;
  final String? category;
  final String? tariffCategory;
  final String? sanctionedLoad;

  // SECTION B — Meter / readings
  final double? kwh;
  final double? kvarh;
  final double? mdi;
  final String? loadDetails;
  final double? touPeak;
  final double? touOffPeak;
  final double? touDay;
  final double? touNight;

  // SECTION C — GPS / location
  final double? gpsLatitude;
  final double? gpsLongitude;
  final double? gpsAccuracyMeters;

  // SECTION D — Equipment condition
  final String? sealConditionCode;
  final String? ctptBoxStatusCode;

  final int? taskId;
  final String? overallStatus;
  final int? currentApprovalLevel;
  final String submittedBy;
  final String? createdAt;

  // Set only when overallStatus == 'REJECTED' — see InspectionRejection.
  final InspectionRejection? rejection;

  // SECTION E — Images
  final List<InspectionImage> images;

  const InspectionDetail({
    required this.id,
    required this.referenceNumber,
    required this.meterId,
    required this.consumerAccount,
    required this.inspectionDatetime,
    this.consumerName,
    this.consumerAddress,
    this.division,
    this.subDivision,
    this.category,
    this.tariffCategory,
    this.sanctionedLoad,
    this.kwh,
    this.kvarh,
    this.mdi,
    this.loadDetails,
    this.touPeak,
    this.touOffPeak,
    this.touDay,
    this.touNight,
    this.gpsLatitude,
    this.gpsLongitude,
    this.gpsAccuracyMeters,
    this.sealConditionCode,
    this.ctptBoxStatusCode,
    this.taskId,
    this.overallStatus,
    this.currentApprovalLevel,
    required this.submittedBy,
    this.createdAt,
    this.rejection,
    this.images = const [],
  });

  bool get hasGps => gpsLatitude != null && gpsLongitude != null;

  factory InspectionDetail.fromJson(Map<String, dynamic> json) => InspectionDetail(
        id:                    (json['id'] as num).toInt(),
        referenceNumber:       json['reference_number'] as String? ?? '',
        meterId:               json['meter_id'] as String? ?? '',
        consumerAccount:       json['consumer_account'] as String? ?? '',
        inspectionDatetime:    json['inspection_datetime'] as String? ?? '',
        consumerName:          json['consumer_name'] as String?,
        consumerAddress:       json['consumer_address'] as String?,
        division:              json['division'] as String?,
        subDivision:           json['sub_division'] as String?,
        category:              json['category'] as String?,
        tariffCategory:        json['tariff_category'] as String?,
        sanctionedLoad:        json['sanctioned_load'] as String?,
        kwh:                   _asDouble(json['kwh']),
        kvarh:                 _asDouble(json['kvarh']),
        mdi:                   _asDouble(json['mdi']),
        loadDetails:           json['load_details'] as String?,
        touPeak:               _asDouble(json['tou_peak']),
        touOffPeak:            _asDouble(json['tou_off_peak']),
        touDay:                _asDouble(json['tou_day']),
        touNight:              _asDouble(json['tou_night']),
        gpsLatitude:           _asDouble(json['gps_latitude']),
        gpsLongitude:          _asDouble(json['gps_longitude']),
        gpsAccuracyMeters:     _asDouble(json['gps_accuracy_meters']),
        sealConditionCode:     json['seal_condition_code'] as String?,
        ctptBoxStatusCode:     json['ctpt_box_status_code'] as String?,
        taskId:                (json['task_id'] as num?)?.toInt(),
        overallStatus:         json['overall_status'] as String?,
        currentApprovalLevel:  (json['current_approval_level'] as num?)?.toInt(),
        submittedBy:           json['submitted_by'] as String? ?? '',
        createdAt:             json['created_at'] as String?,
        rejection: json['rejection'] != null
            ? InspectionRejection.fromJson(json['rejection'] as Map<String, dynamic>)
            : null,
        images: (json['images'] as List?)
                ?.map((e) => InspectionImage.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
