// =============================================================================
// FILE: lib/features/inspection/config/inspection_config.dart
// PURPOSE: Centralized configuration for all form dropdown options and
//          field definitions in the Smart Inspection Form.
//
// ADMIN GUIDE:
//   FormOptionsConfig.defaults below is the fallback used only until the
//   live options load. InspectionBloc fetches the real, admin-editable
//   list from GET /api/data.php?action=form-options on startup (see
//   lib/features/inspection/data/inspection_repository.dart) and swaps it
//   in via FormOptionsConfig.fromJson. Admins manage these options through
//   backend/api/admin/form_options.php — no app release required.
//
// LOCALIZATION:
//   All user-visible strings are keyed through InspectionStrings below.
//   To support Urdu, create InspectionStringsUr with the same keys.
// =============================================================================

// =============================================================================
// SECTION 1: UI STRINGS — all user-visible text for this module
// =============================================================================
class InspectionStrings {
  InspectionStrings._();

  // Page / AppBar
  static const String pageTitle         = 'Meter Inspection';
  static const String pageSubtitle      = 'Smart Field Data Collection';

  // Section headers
  static const String sectionFetch      = 'Reference Lookup';
  static const String sectionAutoData   = 'Consumer & Meter Details';
  static const String sectionReadings   = 'Technical Readings';
  static const String sectionTou        = 'Time of Use (TOU) Data';
  static const String sectionInfra      = 'Infrastructure Status';
  static const String sectionGps        = 'Location Verification';
  static const String sectionImages     = 'Photo Evidence';
  static const String sectionSubmit     = 'Submit Inspection';

  // Reference fetch
  static const String refNumberLabel    = 'Reference Number / Key';
  static const String refNumberHint     = 'e.g. REF-2025-00142';
  static const String fetchButton       = 'Auto-Fetch Data';
  static const String fetchingLabel     = 'Fetching...';
  static const String fetchSuccess      = 'Consumer data loaded successfully.';
  static const String fetchNotFound     = 'No record found for this reference number.';
  static const String fetchError        = 'Network error. Please try again.';

  // Auto-populated fields
  static const String meterIdLabel      = 'Meter ID';
  static const String meterIdHint       = 'Auto-populated after fetch';
  static const String consumerLabel     = 'Consumer Details';
  static const String consumerHint      = 'Auto-populated after fetch';
  static const String dateTimeLabel     = 'Inspection Date & Time';

  // Readings
  static const String kwhLabel          = 'KWH Reading';
  static const String kwhHint           = '0.00';
  static const String kvarhLabel        = 'KVARH Reading';
  static const String kvarhHint         = '0.00';
  static const String mdiLabel          = 'MDI Reading';
  static const String mdiHint           = '0.00';
  static const String loadDetailsLabel  = 'Load Details / Observations';
  static const String loadDetailsHint   = 'Describe connected load, any anomalies...';

  // TOU fields
  static const String touPeakLabel      = 'TOU — Peak (kWh)';
  static const String touOffPeakLabel   = 'TOU — Off-Peak (kWh)';
  static const String touDayLabel       = 'TOU — Day (kWh)';
  static const String touNightLabel     = 'TOU — Night (kWh)';

  // Dropdowns
  static const String sealConditionLabel  = 'Seal Condition';
  static const String sealConditionHint   = 'Select seal status';
  static const String ctPtBoxLabel        = 'CT/PT/BT Box Status';
  static const String ctPtBoxHint         = 'Select box status';

  // Validation messages
  static const String validRefRequired    = 'Reference number is required before submitting.';
  static const String validFetchRequired  = 'Please fetch consumer data before submitting.';
  static const String validKwhEmpty       = 'KWH reading is required.';
  static const String validKvarhEmpty     = 'KVARH reading is required.';
  static const String validMdiEmpty       = 'MDI reading is required.';
  static const String validNumberFormat   = 'Enter a valid decimal number (e.g. 1234.56).';
  static const String validSealRequired   = 'Seal condition must be selected.';
  static const String validCtPtRequired   = 'CT/PT/BT Box status must be selected.';
  static const String validTouPeak        = 'TOU Peak reading is required.';
  static const String validTouOffPeak     = 'TOU Off-Peak reading is required.';
  static const String validGpsRequired    = 'A valid GPS location is required. Tap "Retry" in the Location Verification section.';
  static const String validImagesRequired = 'At least 2 photos are required (Photo Evidence section).';
  static const String validImagesMinimum  = 'At least 2 photos are required; you have fewer than that.';

  // GPS / Location
  static const String gpsCapturing        = 'Capturing your location...';
  static const String gpsCapturedLabel    = 'Location captured';
  static const String gpsRetryButton      = 'Retry';
  static const String gpsRequiredNote     = 'Required — every inspection must be geo-tagged.';

  // Photo evidence
  static const String imagesCountNote     = 'Attach 2-12 photos (Meter, Seal, Installation, or Load).';
  static const String imagesCameraButton  = 'Camera';
  static const String imagesGalleryButton = 'Gallery';
  static const String imagesEmptyState    = 'No photos attached yet.';

  // Submit
  static const String submitButton        = 'Submit Inspection';
  static const String submittingLabel     = 'Submitting...';
  static const String submitSuccess       = 'Inspection submitted successfully.';
  static const String submitError         = 'Submission failed. Please try again.';
  static const String mandatoryNote       = '* Required fields';

  // Misc
  static const String clearFormButton     = 'Clear Form';
  static const String clearFormConfirm    = 'Clear all entered data?';
  static const String clearFormCancel     = 'Cancel';
  static const String clearFormOk         = 'Clear';
  static const String readOnlyBadge       = 'Auto-filled';
  static const String autoFetchFirst      = 'Fetch consumer data first';
}

// =============================================================================
// SECTION 2: DROPDOWN OPTIONS — admin-configurable form option lists
// =============================================================================

/// A single selectable option in a dropdown field.
/// [code] is sent to the API; [label] is shown in the UI.
class FormOption {
  final String code;
  final String label;
  final String? description; // Optional tooltip or sub-text

  const FormOption({
    required this.code,
    required this.label,
    this.description,
  });

  Map<String, dynamic> toJson() => {'code': code, 'label': label};
}

/// Central configuration class for all dynamic form option lists.
/// Replace static lists with an API call in production:
///   factory FormOptionsConfig.fromJson(Map<String, dynamic> json)
class FormOptionsConfig {
  final List<FormOption> sealConditions;
  final List<FormOption> ctPtBoxStatuses;

  const FormOptionsConfig({
    required this.sealConditions,
    required this.ctPtBoxStatuses,
  });

  // ---------------------------------------------------------------------------
  // DEFAULT / STATIC CONFIG (used until API provides live config)
  // ---------------------------------------------------------------------------
  static const FormOptionsConfig defaults = FormOptionsConfig(
    sealConditions: [
      FormOption(
        code: 'INTACT',
        label: 'Intact',
        description: 'All seals are present and undamaged.',
      ),
      FormOption(
        code: 'BROKEN',
        label: 'Broken',
        description: 'One or more seals are physically broken.',
      ),
      FormOption(
        code: 'TAMPERED',
        label: 'Tampered',
        description: 'Evidence of tampering or unauthorized access.',
      ),
      FormOption(
        code: 'MISSING',
        label: 'Missing',
        description: 'Seals are absent entirely.',
      ),
    ],
    ctPtBoxStatuses: [
      FormOption(
        code: 'SECURED',
        label: 'Secured',
        description: 'Box is properly locked and undamaged.',
      ),
      FormOption(
        code: 'ACCESSIBLE',
        label: 'Accessible',
        description: 'Box is unlocked but otherwise intact.',
      ),
      FormOption(
        code: 'TAMPERED',
        label: 'Tampered',
        description: 'Box shows signs of forced or unauthorized access.',
      ),
      FormOption(
        code: 'DAMAGED',
        label: 'Damaged',
        description: 'Box is physically damaged or broken.',
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // JSON deserialization (for future PHP API integration)
  // ---------------------------------------------------------------------------
  factory FormOptionsConfig.fromJson(Map<String, dynamic> json) {
    List<FormOption> parseOptions(List<dynamic> raw) =>
        raw.map((e) => FormOption(code: e['code'], label: e['label'])).toList();

    return FormOptionsConfig(
      sealConditions:  parseOptions(json['seal_conditions']   as List? ?? []),
      ctPtBoxStatuses: parseOptions(json['ctpt_box_statuses'] as List? ?? []),
    );
  }
}

// =============================================================================
// SECTION 3: Consumer auto-fetch response model
// =============================================================================

/// Represents the consumer/meter data returned by the auto-fetch API call.
class ConsumerFetchResult {
  final String meterId;
  final String consumerName;
  final String consumerAddress;
  final String consumerAccount;
  final String tariffCategory;
  final String sanctionedLoad;

  const ConsumerFetchResult({
    required this.meterId,
    required this.consumerName,
    required this.consumerAddress,
    required this.consumerAccount,
    required this.tariffCategory,
    required this.sanctionedLoad,
  });

  /// Human-readable consumer details string for the read-only field.
  String get formattedDetails =>
    '$consumerName | $consumerAccount | $tariffCategory | Load: $sanctionedLoad';

  /// Deserializes the response from GET /api/data.php?action=consumer-fetch
  factory ConsumerFetchResult.fromJson(Map<String, dynamic> json) {
    return ConsumerFetchResult(
      meterId:         json['meter_id']         as String? ?? '',
      consumerName:    json['consumer_name']    as String? ?? '',
      consumerAddress: json['consumer_address'] as String? ?? '',
      consumerAccount: json['consumer_account'] as String? ?? '',
      tariffCategory:  json['tariff_category']  as String? ?? '',
      sanctionedLoad:  json['sanctioned_load']  as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'meter_id':         meterId,
    'consumer_name':    consumerName,
    'consumer_address': consumerAddress,
    'consumer_account': consumerAccount,
    'tariff_category':  tariffCategory,
    'sanctioned_load':  sanctionedLoad,
  };
}

