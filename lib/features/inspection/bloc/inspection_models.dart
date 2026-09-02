// =============================================================================
// FILE: lib/features/inspection/bloc/inspection_models.dart
// PURPOSE: Data models for the inspection form state and submission payload.
//
// API CONTRACT:
//   InspectionSubmissionPayload.toJson() produces the exact JSON body
//   for: POST /api/inspection/submit
// =============================================================================

import '../config/inspection_config.dart';

// =============================================================================
// FETCH STATE — tracks the auto-fetch lifecycle
// =============================================================================
enum FetchStatus { idle, loading, success, notFound, error }

// =============================================================================
// GPS STATE — tracks the mandatory location-capture lifecycle
// =============================================================================
enum GpsStatus { idle, loading, success, error }

// =============================================================================
// CAPTURED IMAGE — a single geo-tagged inspection photo
// Mirrors one entry of backend/api/data.php's "images" array exactly:
// {"type","data_base64","latitude","longitude","captured_at"}
// =============================================================================
class CapturedImage {
  /// One of: METER, SEAL, INSTALLATION, LOAD (VALID_IMAGE_TYPES server-side).
  final String type;
  final String base64Data;
  final double latitude;
  final double longitude;
  final DateTime capturedAt;

  const CapturedImage({
    required this.type,
    required this.base64Data,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
  });

  Map<String, dynamic> toJson() => {
    'type':         type,
    'data_base64':  base64Data,
    'latitude':     latitude,
    'longitude':    longitude,
    'captured_at':  capturedAt.toIso8601String(),
  };
}

const List<String> kInspectionImageTypes = ['METER', 'SEAL', 'INSTALLATION', 'LOAD'];

String inspectionImageTypeLabel(String code) {
  switch (code) {
    case 'METER':         return 'Meter';
    case 'SEAL':           return 'Seal';
    case 'INSTALLATION':   return 'Installation';
    case 'LOAD':            return 'Load / Wiring';
    default:                return code;
  }
}

// =============================================================================
// INSPECTION FORM DATA MODEL
// Holds all mutable field values. Immutable — use copyWith to update.
// =============================================================================
class InspectionFormData {
  // Task linkage — set when this form was opened from a task ("Start
  // Inspection" on TaskDetailScreen) rather than a standalone reference
  // lookup. Threaded through to InspectionSubmissionPayload so the backend
  // can mark the originating task_assignments row (and its schedule)
  // COMPLETED on submit — see POST /api/data.php?action=inspection-submit.
  final int? taskId;

  // Reference lookup
  final String referenceNumber;
  final FetchStatus fetchStatus;
  final ConsumerFetchResult? fetchedConsumer; // null until fetch succeeds
  final String? fetchMessage;

  // Auto-populated (read-only after fetch)
  final String meterId;
  final String consumerDetails;
  final DateTime inspectionDateTime;

  // Technical readings
  final String kwh;
  final String kvarh;
  final String mdi;
  final String loadDetails;

  // TOU readings
  final String touPeak;
  final String touOffPeak;
  final String touDay;
  final String touNight;

  // Infrastructure dropdowns
  final String? sealConditionCode;   // null = not selected
  final String? ctPtBoxStatusCode;   // null = not selected

  // GPS — mandatory server-side (see backend/api/data.php). Auto-captured
  // once on form load and re-triggerable via a "Retry" button.
  final GpsStatus gpsStatus;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final double? gpsAccuracy;
  final String? gpsPlaceName; // display-only, best-effort reverse geocode
  final String? gpsError;

  // Photo evidence — 2 to 12 geo-tagged images required server-side.
  final List<CapturedImage> images;

  // Form state
  final bool isSubmitting;
  final bool isSubmitted;
  final String? submitError;

  const InspectionFormData({
    this.taskId,
    this.referenceNumber    = '',
    this.fetchStatus        = FetchStatus.idle,
    this.fetchedConsumer,
    this.fetchMessage,
    this.meterId            = '',
    this.consumerDetails    = '',
    required this.inspectionDateTime,
    this.kwh                = '',
    this.kvarh              = '',
    this.mdi                = '',
    this.loadDetails        = '',
    this.touPeak            = '',
    this.touOffPeak         = '',
    this.touDay             = '',
    this.touNight           = '',
    this.sealConditionCode,
    this.ctPtBoxStatusCode,
    this.gpsStatus           = GpsStatus.idle,
    this.gpsLatitude,
    this.gpsLongitude,
    this.gpsAccuracy,
    this.gpsPlaceName,
    this.gpsError,
    this.images              = const [],
    this.isSubmitting       = false,
    this.isSubmitted        = false,
    this.submitError,
  });

  /// Factory for a fresh, empty form — call when screen initialises.
  /// [initialReferenceNumber] and [taskId] are set when the form was opened
  /// from TaskDetailScreen's "Start Inspection" action rather than a
  /// standalone reference lookup.
  factory InspectionFormData.empty({String? initialReferenceNumber, int? taskId}) =>
      InspectionFormData(
        inspectionDateTime: DateTime.now(),
        referenceNumber: initialReferenceNumber ?? '',
        taskId: taskId,
      );

  bool get isFetched    => fetchStatus == FetchStatus.success;
  bool get isFetching   => fetchStatus == FetchStatus.loading;
  bool get isGpsCaptured => gpsStatus == GpsStatus.success && gpsLatitude != null && gpsLongitude != null;
  bool get isGpsCapturing => gpsStatus == GpsStatus.loading;
  bool get hasEnoughImages => images.length >= 2 && images.length <= 12;

  // ---------------------------------------------------------------------------
  InspectionFormData copyWith({
    int? taskId,
    String? referenceNumber,
    FetchStatus? fetchStatus,
    ConsumerFetchResult? fetchedConsumer,
    String? fetchMessage,
    bool clearFetchedConsumer = false,
    String? meterId,
    String? consumerDetails,
    DateTime? inspectionDateTime,
    String? kwh,
    String? kvarh,
    String? mdi,
    String? loadDetails,
    String? touPeak,
    String? touOffPeak,
    String? touDay,
    String? touNight,
    String? sealConditionCode,
    bool clearSeal = false,
    String? ctPtBoxStatusCode,
    bool clearCtPt = false,
    GpsStatus? gpsStatus,
    double? gpsLatitude,
    double? gpsLongitude,
    double? gpsAccuracy,
    String? gpsPlaceName,
    bool clearGpsPlaceName = false,
    String? gpsError,
    bool clearGpsError = false,
    List<CapturedImage>? images,
    bool? isSubmitting,
    bool? isSubmitted,
    String? submitError,
    bool clearSubmitError = false,
  }) {
    return InspectionFormData(
      taskId:            taskId            ?? this.taskId,
      referenceNumber:   referenceNumber   ?? this.referenceNumber,
      fetchStatus:       fetchStatus       ?? this.fetchStatus,
      fetchedConsumer:   clearFetchedConsumer ? null : (fetchedConsumer ?? this.fetchedConsumer),
      fetchMessage:      fetchMessage      ?? this.fetchMessage,
      meterId:           meterId           ?? this.meterId,
      consumerDetails:   consumerDetails   ?? this.consumerDetails,
      inspectionDateTime: inspectionDateTime ?? this.inspectionDateTime,
      kwh:               kwh               ?? this.kwh,
      kvarh:             kvarh             ?? this.kvarh,
      mdi:               mdi               ?? this.mdi,
      loadDetails:       loadDetails       ?? this.loadDetails,
      touPeak:           touPeak           ?? this.touPeak,
      touOffPeak:        touOffPeak        ?? this.touOffPeak,
      touDay:            touDay            ?? this.touDay,
      touNight:          touNight          ?? this.touNight,
      sealConditionCode: clearSeal ? null : (sealConditionCode ?? this.sealConditionCode),
      ctPtBoxStatusCode: clearCtPt ? null : (ctPtBoxStatusCode ?? this.ctPtBoxStatusCode),
      gpsStatus:         gpsStatus         ?? this.gpsStatus,
      gpsLatitude:       gpsLatitude       ?? this.gpsLatitude,
      gpsLongitude:      gpsLongitude      ?? this.gpsLongitude,
      gpsAccuracy:       gpsAccuracy       ?? this.gpsAccuracy,
      gpsPlaceName:      clearGpsPlaceName ? null : (gpsPlaceName ?? this.gpsPlaceName),
      gpsError:          clearGpsError ? null : (gpsError ?? this.gpsError),
      images:            images            ?? this.images,
      isSubmitting:      isSubmitting      ?? this.isSubmitting,
      isSubmitted:       isSubmitted       ?? this.isSubmitted,
      submitError:       clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }
}

// =============================================================================
// SUBMISSION PAYLOAD — the final JSON object sent to the PHP API
// =============================================================================
class InspectionSubmissionPayload {
  // Set when this inspection fulfills an assigned task, so the backend
  // marks task_assignments (and its schedule) COMPLETED on submit.
  final int? taskId;
  final String referenceNumber;
  final String meterId;
  final String consumerAccount;
  final String inspectionDateTime;   // ISO 8601

  // Readings
  final double kwh;
  final double kvarh;
  final double mdi;
  final String loadDetails;

  // TOU
  final double? touPeak;
  final double? touOffPeak;
  final double? touDay;
  final double? touNight;

  // Infrastructure
  final String sealConditionCode;
  final String ctPtBoxStatusCode;

  // GPS — mandatory server-side
  final double gpsLatitude;
  final double gpsLongitude;
  final double? gpsAccuracy;

  // Photo evidence — 2 to 12 geo-tagged images, mandatory server-side
  final List<CapturedImage> images;

  const InspectionSubmissionPayload({
    this.taskId,
    required this.referenceNumber,
    required this.meterId,
    required this.consumerAccount,
    required this.inspectionDateTime,
    required this.kwh,
    required this.kvarh,
    required this.mdi,
    required this.loadDetails,
    this.touPeak,
    this.touOffPeak,
    this.touDay,
    this.touNight,
    required this.sealConditionCode,
    required this.ctPtBoxStatusCode,
    required this.gpsLatitude,
    required this.gpsLongitude,
    this.gpsAccuracy,
    required this.images,
  });

  /// Builds the payload from validated form data. Callers must only call
  /// this after confirming [InspectionFormData.isGpsCaptured] and
  /// [InspectionFormData.hasEnoughImages] are both true (InspectionBloc's
  /// _validate() enforces this before submission is ever attempted).
  factory InspectionSubmissionPayload.fromFormData(InspectionFormData data) {
    return InspectionSubmissionPayload(
      taskId:           data.taskId,
      referenceNumber:  data.referenceNumber,
      meterId:          data.meterId,
      consumerAccount:  data.fetchedConsumer?.consumerAccount ?? '',
      inspectionDateTime: data.inspectionDateTime.toIso8601String(),
      kwh:              double.tryParse(data.kwh)       ?? 0.0,
      kvarh:            double.tryParse(data.kvarh)     ?? 0.0,
      mdi:              double.tryParse(data.mdi)       ?? 0.0,
      loadDetails:      data.loadDetails,
      touPeak:          double.tryParse(data.touPeak),
      touOffPeak:       double.tryParse(data.touOffPeak),
      touDay:           double.tryParse(data.touDay),
      touNight:         double.tryParse(data.touNight),
      sealConditionCode:  data.sealConditionCode!,
      ctPtBoxStatusCode:  data.ctPtBoxStatusCode!,
      gpsLatitude:      data.gpsLatitude!,
      gpsLongitude:     data.gpsLongitude!,
      gpsAccuracy:      data.gpsAccuracy,
      images:           data.images,
    );
  }

  /// Produces the final JSON body for POST /api/data.php?action=inspection-submit
  Map<String, dynamic> toJson() => {
    if (taskId != null && taskId! > 0) 'task_id': taskId,
    'reference_number':    referenceNumber,
    'meter_id':            meterId,
    'consumer_account':    consumerAccount,
    'inspection_datetime': inspectionDateTime,
    'readings': {
      'kwh':   kwh,
      'kvarh': kvarh,
      'mdi':   mdi,
    },
    'tou_readings': {
      'peak':     touPeak,
      'off_peak': touOffPeak,
      'day':      touDay,
      'night':    touNight,
    },
    'infrastructure': {
      'seal_condition':    sealConditionCode,
      'ctpt_box_status':   ctPtBoxStatusCode,
    },
    'gps': {
      'latitude':  gpsLatitude,
      'longitude': gpsLongitude,
      if (gpsAccuracy != null) 'accuracy_meters': gpsAccuracy,
    },
    'images': images.map((img) => img.toJson()).toList(),
    'load_details': loadDetails,
  };

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('╔══════════════════════════════════════════════╗');
    buffer.writeln('║       INSPECTION SUBMISSION PAYLOAD          ║');
    buffer.writeln('╠══════════════════════════════════════════════╣');
    buffer.writeln('  Reference  : $referenceNumber');
    buffer.writeln('  Meter ID   : $meterId');
    buffer.writeln('  Account    : $consumerAccount');
    buffer.writeln('  DateTime   : $inspectionDateTime');
    buffer.writeln('  KWH        : $kwh');
    buffer.writeln('  KVARH      : $kvarh');
    buffer.writeln('  MDI        : $mdi');
    buffer.writeln('  TOU Peak   : $touPeak');
    buffer.writeln('  TOU OffPk  : $touOffPeak');
    buffer.writeln('  Seal       : $sealConditionCode');
    buffer.writeln('  CT/PT Box  : $ctPtBoxStatusCode');
    buffer.writeln('  GPS        : $gpsLatitude, $gpsLongitude (±${gpsAccuracy ?? "?"}m)');
    buffer.writeln('  Images     : ${images.length} attached');
    buffer.writeln('  Load Notes : $loadDetails');
    buffer.writeln('╚══════════════════════════════════════════════╝');
    return buffer.toString();
  }
}
