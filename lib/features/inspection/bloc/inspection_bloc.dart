// =============================================================================
// FILE: lib/features/inspection/bloc/inspection_bloc.dart
// PURPOSE: BLoC for the Smart Inspection Form module.
//
// EVENTS → BLOC → STATES flow:
//
//   ReferenceNumberChanged    → updates ref number in form data
//   FetchConsumerRequested     → calls the real auto-fetch API, populates fields
//   FieldValueChanged          → updates any text field value
//   DropdownChanged            → updates any dropdown selection
//   FormSubmitRequested        → validates + submits to the real API
//   FormClearRequested         → resets form to initial empty state
//
// BACKEND INTEGRATION:
//   Talks to the real MEPCO PHP/MySQL API via InspectionRepository (see
//   lib/features/inspection/data/inspection_repository.dart). The bearer
//   token is read from SessionManager on every call, so this bloc never
//   needs the token passed in explicitly.
//
// DEPENDENCY: flutter_bloc: ^8.x.x
// =============================================================================

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'inspection_models.dart';
import '../config/inspection_config.dart';
import '../data/inspection_repository.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/session_manager.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/media_capture_service.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

// =============================================================================
// EVENTS
// =============================================================================
abstract class InspectionEvent {
  const InspectionEvent();
}

/// User typed in the Reference Number field.
class ReferenceNumberChanged extends InspectionEvent {
  final String value;
  const ReferenceNumberChanged(this.value);
}

/// User tapped "Auto-Fetch Data".
class FetchConsumerRequested extends InspectionEvent {
  const FetchConsumerRequested();
}

/// Generic event for any text field value change.
/// [field] identifies which field (use InspectionField enum below).
class FieldValueChanged extends InspectionEvent {
  final InspectionField field;
  final String value;
  const FieldValueChanged(this.field, this.value);
}

/// User selected an option from a dropdown.
class DropdownChanged extends InspectionEvent {
  final InspectionDropdown dropdown;
  final String? code; // null means "cleared"
  const DropdownChanged(this.dropdown, this.code);
}

/// User tapped "Submit Inspection".
class FormSubmitRequested extends InspectionEvent {
  const FormSubmitRequested();
}

/// User tapped "Clear Form".
class FormClearRequested extends InspectionEvent {
  const FormClearRequested();
}

/// Fired on form load and whenever the user taps "Retry" on the GPS card.
class GpsCaptureRequested extends InspectionEvent {
  const GpsCaptureRequested();
}

/// User tapped a photo-type button (camera or gallery) to attach evidence.
class ImageCaptureRequested extends InspectionEvent {
  final String imageType; // METER, SEAL, INSTALLATION, LOAD
  final bool fromCamera;  // false = pick from gallery
  const ImageCaptureRequested(this.imageType, {this.fromCamera = true});
}

/// User removed a previously attached photo.
class ImageRemoved extends InspectionEvent {
  final int index;
  const ImageRemoved(this.index);
}

/// Internal event fired once the backend's dropdown options have loaded,
/// so the UI rebuilds with live (admin-editable) options instead of the
/// bundled defaults.
class _FormOptionsLoaded extends InspectionEvent {
  final FormOptionsConfig config;
  const _FormOptionsLoaded(this.config);
}

// Field identifiers — avoids a separate event class per text field
enum InspectionField {
  kwh,
  kvarh,
  mdi,
  loadDetails,
  touPeak,
  touOffPeak,
  touDay,
  touNight,
}

// Dropdown identifiers
enum InspectionDropdown { sealCondition, ctPtBox }

// =============================================================================
// STATE
// =============================================================================
class InspectionState {
  final InspectionFormData formData;
  final Map<String, String?> validationErrors; // field key → error message
  final bool showValidationErrors; // true after first submit attempt

  const InspectionState({
    required this.formData,
    this.validationErrors = const {},
    this.showValidationErrors = false,
  });

  factory InspectionState.initial() =>
      InspectionState(formData: InspectionFormData.empty());

  bool get hasErrors => validationErrors.isNotEmpty;

  InspectionState copyWith({
    InspectionFormData? formData,
    Map<String, String?>? validationErrors,
    bool? showValidationErrors,
  }) {
    return InspectionState(
      formData: formData ?? this.formData,
      validationErrors: validationErrors ?? this.validationErrors,
      showValidationErrors: showValidationErrors ?? this.showValidationErrors,
    );
  }
}

// =============================================================================
// BLOC
// =============================================================================
class InspectionBloc extends Bloc<InspectionEvent, InspectionState> {
  final InspectionRepository _repository;

  // Active form options config. Starts with the bundled defaults so the UI
  // has something to render immediately, then gets replaced with the
  // backend's live (admin-editable) options once they load.
  FormOptionsConfig _optionsConfig = FormOptionsConfig.defaults;

  /// [initialReferenceNumber]/[initialTaskId] are set when this bloc is
  /// created for TaskDetailScreen's "Start Inspection" action rather than a
  /// standalone reference lookup — seeds the form and immediately triggers
  /// the auto-fetch, and carries taskId through to submission so the backend
  /// marks the originating task (and its schedule) COMPLETED.
  InspectionBloc({
    InspectionRepository? repository,
    String? initialReferenceNumber,
    int? initialTaskId,
  })  : _repository = repository ?? ApiInspectionRepository(),
        super(
          InspectionState(
            formData: InspectionFormData.empty(
              initialReferenceNumber: initialReferenceNumber,
              taskId: initialTaskId,
            ),
          ),
        ) {
    on<ReferenceNumberChanged>(_onRefChanged);
    on<FetchConsumerRequested>(_onFetchConsumer);
    on<FieldValueChanged>(_onFieldChanged);
    on<DropdownChanged>(_onDropdownChanged);
    on<FormSubmitRequested>(_onSubmitRequested);
    on<FormClearRequested>(_onClearRequested);
    on<_FormOptionsLoaded>(_onFormOptionsLoaded);
    on<GpsCaptureRequested>(_onGpsCaptureRequested);
    on<ImageCaptureRequested>(_onImageCaptureRequested);
    on<ImageRemoved>(_onImageRemoved);

    _loadFormOptions();

    if (initialReferenceNumber != null && initialReferenceNumber.isNotEmpty) {
      add(const FetchConsumerRequested());
    }
  }

  // Expose options for the UI dropdowns
  FormOptionsConfig get optionsConfig => _optionsConfig;

  // ---------------------------------------------------------------------------
  // HANDLERS
  // ---------------------------------------------------------------------------

  void _onRefChanged(
    ReferenceNumberChanged event,
    Emitter<InspectionState> emit,
  ) {
    emit(
      state.copyWith(
        formData: state.formData.copyWith(
          referenceNumber: event.value,
          fetchStatus: FetchStatus.idle,
          fetchMessage: '',
          clearFetchedConsumer: true,
          meterId: '',
          consumerDetails: '',
        ),
      ),
    );
  }

  Future<void> _onFetchConsumer(
    FetchConsumerRequested event,
    Emitter<InspectionState> emit,
  ) async {
    final ref = state.formData.referenceNumber.trim();
    if (ref.isEmpty) return;

    // Show loading state
    emit(
      state.copyWith(
        formData: state.formData.copyWith(
          fetchStatus: FetchStatus.loading,
          fetchMessage: '',
        ),
      ),
    );

    try {
      final token = await _getToken();
      final ConsumerFetchResult? result = await _repository.fetchConsumer(ref, token);

      if (result != null) {
        emit(
          state.copyWith(
            formData: state.formData.copyWith(
              fetchStatus: FetchStatus.success,
              fetchedConsumer: result,
              fetchMessage: InspectionStrings.fetchSuccess,
              meterId: result.meterId,
              consumerDetails: result.formattedDetails,
              // Refresh the captured timestamp on successful fetch
              inspectionDateTime: DateTime.now(),
            ),
          ),
        );
      } else {
        emit(
          state.copyWith(
            formData: state.formData.copyWith(
              fetchStatus: FetchStatus.notFound,
              fetchMessage: InspectionStrings.fetchNotFound,
              clearFetchedConsumer: true,
              meterId: '',
              consumerDetails: '',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          formData: state.formData.copyWith(
            fetchStatus: FetchStatus.error,
            fetchMessage: e.isNetworkError ? InspectionStrings.fetchError : e.message,
          ),
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          formData: state.formData.copyWith(
            fetchStatus: FetchStatus.error,
            fetchMessage: InspectionStrings.fetchError,
          ),
        ),
      );
    }
  }

  void _onFieldChanged(FieldValueChanged event, Emitter<InspectionState> emit) {
    final updated = switch (event.field) {
      InspectionField.kwh => state.formData.copyWith(kwh: event.value),
      InspectionField.kvarh => state.formData.copyWith(kvarh: event.value),
      InspectionField.mdi => state.formData.copyWith(mdi: event.value),
      InspectionField.loadDetails => state.formData.copyWith(
        loadDetails: event.value,
      ),
      InspectionField.touPeak => state.formData.copyWith(touPeak: event.value),
      InspectionField.touOffPeak => state.formData.copyWith(
        touOffPeak: event.value,
      ),
      InspectionField.touDay => state.formData.copyWith(touDay: event.value),
      InspectionField.touNight => state.formData.copyWith(
        touNight: event.value,
      ),
    };

    // Live-clear the specific field's validation error as the user types
    final newErrors = Map<String, String?>.from(state.validationErrors)
      ..remove(event.field.name);

    emit(state.copyWith(formData: updated, validationErrors: newErrors));
  }

  void _onDropdownChanged(
    DropdownChanged event,
    Emitter<InspectionState> emit,
  ) {
    final updated = switch (event.dropdown) {
      InspectionDropdown.sealCondition => state.formData.copyWith(
        sealConditionCode: event.code,
      ),
      InspectionDropdown.ctPtBox => state.formData.copyWith(
        ctPtBoxStatusCode: event.code,
      ),
    };

    final newErrors = Map<String, String?>.from(state.validationErrors)
      ..remove(event.dropdown.name);

    emit(state.copyWith(formData: updated, validationErrors: newErrors));
  }

  Future<void> _onSubmitRequested(
    FormSubmitRequested event,
    Emitter<InspectionState> emit,
  ) async {
    // First: run validation
    final errors = _validate(state.formData);

    if (errors.isNotEmpty) {
      emit(
        state.copyWith(validationErrors: errors, showValidationErrors: true),
      );
      return;
    }

    // Validation passed — submit
    emit(
      state.copyWith(
        formData: state.formData.copyWith(
          isSubmitting: true,
          clearSubmitError: true,
        ),
        showValidationErrors: false,
      ),
    );

    final payload = InspectionSubmissionPayload.fromFormData(state.formData);

    try {
      final token = await _getToken();
      await _repository.submitInspection(payload, token);

      // ✅ Log the full payload to console
      developer.log(payload.toString(), name: 'InspectionBloc.Submit');

      emit(
        state.copyWith(
          formData: state.formData.copyWith(
            isSubmitting: false,
            isSubmitted: true,
          ),
        ),
      );
    } on ApiException catch (e) {
      // Surface field-level validation errors from the server (HTTP 422),
      // merged with any local ones, so the user sees exactly what to fix.
      if (e.fieldErrors != null) {
        emit(
          state.copyWith(
            formData: state.formData.copyWith(
              isSubmitting: false,
              submitError: e.message,
            ),
            showValidationErrors: true,
          ),
        );
      } else {
        emit(
          state.copyWith(
            formData: state.formData.copyWith(
              isSubmitting: false,
              submitError: e.isNetworkError ? InspectionStrings.submitError : e.message,
            ),
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          formData: state.formData.copyWith(
            isSubmitting: false,
            submitError: '${InspectionStrings.submitError}\n$e',
          ),
        ),
      );
    }
  }

  void _onClearRequested(
    FormClearRequested event,
    Emitter<InspectionState> emit,
  ) {
    emit(InspectionState.initial());
    // A cleared form is effectively "starting a new inspection" — capture a
    // fresh GPS reading immediately rather than leaving the GPS card idle
    // until the user notices and taps "Capture Location" themselves.
    add(const GpsCaptureRequested());
  }

  void _onFormOptionsLoaded(
    _FormOptionsLoaded event,
    Emitter<InspectionState> emit,
  ) {
    _optionsConfig = event.config;
    // Re-emit the current state unchanged, purely to trigger a UI rebuild
    // so BlocBuilder re-reads the (now updated) optionsConfig getter.
    emit(state.copyWith());
  }

  // ---------------------------------------------------------------------------
  // GPS CAPTURE
  // Mandatory field server-side — auto-triggered on bloc creation, and
  // re-triggerable from the UI's "Retry" button if it fails or the user
  // wants a fresher reading right before submitting.
  // ---------------------------------------------------------------------------
  Future<void> _onGpsCaptureRequested(
    GpsCaptureRequested event,
    Emitter<InspectionState> emit,
  ) async {
    emit(
      state.copyWith(
        formData: state.formData.copyWith(
          gpsStatus: GpsStatus.loading,
          clearGpsError: true,
          clearGpsPlaceName: true,
        ),
      ),
    );

    final result = await LocationService.instance.getCurrentLocation();

    if (result.isSuccess) {
      emit(
        state.copyWith(
          formData: state.formData.copyWith(
            gpsStatus: GpsStatus.success,
            gpsLatitude: result.latitude,
            gpsLongitude: result.longitude,
            gpsAccuracy: result.accuracyMeters,
            gpsPlaceName: result.placeName,
            clearGpsPlaceName: result.placeName == null,
            clearGpsError: true,
          ),
          validationErrors: Map<String, String?>.from(state.validationErrors)..remove('gps'),
        ),
      );
    } else {
      emit(
        state.copyWith(
          formData: state.formData.copyWith(
            gpsStatus: GpsStatus.error,
            gpsError: result.errorMessage,
            clearGpsPlaceName: true,
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // IMAGE CAPTURE / REMOVAL
  // Every image is geo-tagged with the form's current GPS reading — GPS must
  // already be captured before a photo can be attached (the UI disables the
  // capture buttons until then; this is a defensive second check).
  // ---------------------------------------------------------------------------
  Future<void> _onImageCaptureRequested(
    ImageCaptureRequested event,
    Emitter<InspectionState> emit,
  ) async {
    if (!state.formData.isGpsCaptured) {
      emit(
        state.copyWith(
          formData: state.formData.copyWith(
            gpsError: 'Capture your GPS location before attaching photos.',
          ),
        ),
      );
      return;
    }

    if (state.formData.images.length >= 12) {
      return; // Server caps at 12 — silently ignore further taps.
    }

    try {
      final photo = await MediaCaptureService.instance.pickImage(
        event.fromCamera ? ImageSource.camera : ImageSource.gallery,
      );
      if (photo == null) return; // user cancelled

      final newImage = CapturedImage(
        type: event.imageType,
        base64Data: photo.base64Data,
        latitude: state.formData.gpsLatitude!,
        longitude: state.formData.gpsLongitude!,
        capturedAt: DateTime.now(),
      );

      final updatedImages = [...state.formData.images, newImage];
      final newErrors = Map<String, String?>.from(state.validationErrors)..remove('images');

      emit(
        state.copyWith(
          formData: state.formData.copyWith(images: updatedImages),
          validationErrors: newErrors,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          formData: state.formData.copyWith(submitError: e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  void _onImageRemoved(ImageRemoved event, Emitter<InspectionState> emit) {
    final updated = [...state.formData.images]..removeAt(event.index);
    emit(state.copyWith(formData: state.formData.copyWith(images: updated)));
  }

  // ---------------------------------------------------------------------------
  // VALIDATION
  // Returns a map of field key → error string. Empty map = valid.
  // ---------------------------------------------------------------------------
  Map<String, String?> _validate(InspectionFormData data) {
    final errors = <String, String?>{};

    // Must have successfully fetched before submitting
    if (!data.isFetched) {
      errors['fetch'] = InspectionStrings.validFetchRequired;
    }

    // KWH
    if (data.kwh.trim().isEmpty) {
      errors[InspectionField.kwh.name] = InspectionStrings.validKwhEmpty;
    } else if (double.tryParse(data.kwh) == null) {
      errors[InspectionField.kwh.name] = InspectionStrings.validNumberFormat;
    }

    // KVARH
    if (data.kvarh.trim().isEmpty) {
      errors[InspectionField.kvarh.name] = InspectionStrings.validKvarhEmpty;
    } else if (double.tryParse(data.kvarh) == null) {
      errors[InspectionField.kvarh.name] = InspectionStrings.validNumberFormat;
    }

    // MDI
    if (data.mdi.trim().isEmpty) {
      errors[InspectionField.mdi.name] = InspectionStrings.validMdiEmpty;
    } else if (double.tryParse(data.mdi) == null) {
      errors[InspectionField.mdi.name] = InspectionStrings.validNumberFormat;
    }

    // TOU Peak & Off-Peak (mandatory if consumer is TOU tariff)
    if (data.touPeak.trim().isNotEmpty &&
        double.tryParse(data.touPeak) == null) {
      errors[InspectionField.touPeak.name] =
          InspectionStrings.validNumberFormat;
    }
    if (data.touOffPeak.trim().isNotEmpty &&
        double.tryParse(data.touOffPeak) == null) {
      errors[InspectionField.touOffPeak.name] =
          InspectionStrings.validNumberFormat;
    }

    // Seal Condition dropdown
    if (data.sealConditionCode == null) {
      errors[InspectionDropdown.sealCondition.name] =
          InspectionStrings.validSealRequired;
    }

    // CT/PT Box dropdown
    if (data.ctPtBoxStatusCode == null) {
      errors[InspectionDropdown.ctPtBox.name] =
          InspectionStrings.validCtPtRequired;
    }

    // GPS — mandatory server-side
    if (!data.isGpsCaptured) {
      errors['gps'] = InspectionStrings.validGpsRequired;
    }

    // Photo evidence — 2 to 12 geo-tagged images required server-side
    if (!data.hasEnoughImages) {
      errors['images'] = data.images.isEmpty
          ? InspectionStrings.validImagesRequired
          : InspectionStrings.validImagesMinimum;
    }

    return errors;
  }

  // ---------------------------------------------------------------------------
  // PRIVATE HELPERS
  // ---------------------------------------------------------------------------

  /// Reads the stored bearer token, tolerating platform/plugin failures
  /// (e.g. running in a plain unit test with no secure-storage channel)
  /// by falling back to an empty string instead of throwing.
  Future<String> _getToken() async {
    try {
      return await SessionManager.instance.getToken() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Loads the live dropdown options from the backend in the background.
  /// Silently keeps the bundled defaults if this fails (e.g. offline) —
  /// the form remains fully usable either way.
  Future<void> _loadFormOptions() async {
    try {
      final token = await _getToken();
      if (token.isEmpty) return; // Not logged in yet — nothing to fetch with.

      final config = await _repository.fetchFormOptions(token);
      if (!isClosed) {
        add(_FormOptionsLoaded(config));
      }
    } catch (_) {
      // Keep FormOptionsConfig.defaults — already set as the initial value.
    }
  }
}
