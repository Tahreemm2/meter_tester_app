// =============================================================================
// FILE: test/inspection_bloc_test.dart
// PURPOSE: Unit tests for InspectionBloc — validates all state transitions.
//
// RUN: flutter test test/inspection_bloc_test.dart
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mnt_module2/features/inspection/bloc/inspection_bloc.dart';
import 'package:mnt_module2/features/inspection/bloc/inspection_models.dart';
import 'package:mnt_module2/features/inspection/bloc/inspection_summary_model.dart';
import 'package:mnt_module2/features/inspection/bloc/inspection_detail_model.dart';
import 'package:mnt_module2/features/inspection/config/inspection_config.dart';
import 'package:mnt_module2/features/inspection/data/inspection_repository.dart';

/// In-memory fake standing in for the real HTTP-backed
/// ApiInspectionRepository, so these tests run instantly and without any
/// network/backend dependency. Mirrors the old kMockConsumerDatabase.
class FakeInspectionRepository implements InspectionRepository {
  static const _mockDatabase = {
    'REF-2025-00142': ConsumerFetchResult(
      meterId: 'MTR-LHR-2024-00987',
      consumerName: 'Haji Textile Mills (Pvt) Ltd.',
      consumerAddress: 'Plot 14-B, SITE Area, Lahore',
      consumerAccount: 'LHR-04-2200-1429',
      tariffCategory: 'Industrial B-2',
      sanctionedLoad: '250 kW',
    ),
  };

  bool submitCalled = false;

  @override
  Future<ConsumerFetchResult?> fetchConsumer(String referenceNumber, String token) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _mockDatabase[referenceNumber.toUpperCase().trim()];
  }

  @override
  Future<FormOptionsConfig> fetchFormOptions(String token) async {
    return FormOptionsConfig.defaults;
  }

  @override
  Future<void> submitInspection(InspectionSubmissionPayload payload, String token) async {
    await Future.delayed(const Duration(milliseconds: 50));
    submitCalled = true;
  }

  @override
  Future<List<InspectionSummary>> fetchRecentInspections(String token, {int limit = 20}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return const [
      InspectionSummary(
        id: 1,
        referenceNumber: 'REF-2025-00142',
        meterId: 'MTR-LHR-2024-00987',
        consumerAccount: 'LHR-04-2200-1429',
        inspectionDatetime: '2025-01-01T09:00:00Z',
        submittedBy: 'Test Inspector',
      ),
    ];
  }

  @override
  Future<InspectionPage> listInspections(
    String token, {
    String? search,
    String? status,
    String? division,
    String? subDivision,
    String? category,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  }) async {
    final items = await fetchRecentInspections(token, limit: perPage);
    return InspectionPage(items: items, total: items.length);
  }

  @override
  Future<InspectionDetail> getInspectionDetail(String token, int id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return const InspectionDetail(
      id: 1,
      referenceNumber: 'REF-2025-00142',
      meterId: 'MTR-LHR-2024-00987',
      consumerAccount: 'LHR-04-2200-1429',
      inspectionDatetime: '2025-01-01T09:00:00Z',
      submittedBy: 'Test Inspector',
    );
  }
}

void main() {
  group('InspectionBloc —', () {
    late InspectionBloc bloc;

    setUp(() => bloc = InspectionBloc(repository: FakeInspectionRepository()));
    tearDown(() => bloc.close());

    // ── Initial state ────────────────────────────────────────────────────────
    test('initial state has empty form data', () {
      expect(bloc.state.formData.referenceNumber, isEmpty);
      expect(bloc.state.formData.fetchStatus, FetchStatus.idle);
      expect(bloc.state.showValidationErrors, isFalse);
    });

    // ── Reference number change ──────────────────────────────────────────────
    blocTest<InspectionBloc, InspectionState>(
      'ReferenceNumberChanged updates ref and clears fetch status',
      build: () => InspectionBloc(repository: FakeInspectionRepository()),
      act: (b) => b.add(const ReferenceNumberChanged('REF-2025-00142')),
      verify: (b) {
        expect(b.state.formData.referenceNumber, 'REF-2025-00142');
        expect(b.state.formData.fetchStatus, FetchStatus.idle);
      },
    );

    // ── Auto-fetch — success ─────────────────────────────────────────────────
    blocTest<InspectionBloc, InspectionState>(
      'FetchConsumerRequested with valid ref emits Loading then Success',
      build: () => InspectionBloc(repository: FakeInspectionRepository()),
      seed: () => InspectionState(
        formData: InspectionFormData.empty().copyWith(
          referenceNumber: 'REF-2025-00142',
        ),
      ),
      act: (b) => b.add(const FetchConsumerRequested()),
      wait: const Duration(seconds: 2),
      expect: () => [
        isA<InspectionState>().having(
          (s) => s.formData.fetchStatus,
          'loading',
          FetchStatus.loading,
        ),
        isA<InspectionState>().having(
          (s) => s.formData.fetchStatus,
          'success',
          FetchStatus.success,
        ),
      ],
    );

    blocTest<InspectionBloc, InspectionState>(
      'successful fetch populates meterId and consumerDetails',
      build: () => InspectionBloc(repository: FakeInspectionRepository()),
      seed: () => InspectionState(
        formData: InspectionFormData.empty().copyWith(
          referenceNumber: 'REF-2025-00142',
        ),
      ),
      act: (b) => b.add(const FetchConsumerRequested()),
      wait: const Duration(seconds: 2),
      verify: (b) {
        expect(b.state.formData.meterId, 'MTR-LHR-2024-00987');
        expect(b.state.formData.consumerDetails, isNotEmpty);
        expect(b.state.formData.isFetched, isTrue);
      },
    );

    // ── Auto-fetch — not found ───────────────────────────────────────────────
    blocTest<InspectionBloc, InspectionState>(
      'FetchConsumerRequested with unknown ref emits NotFound',
      build: () => InspectionBloc(repository: FakeInspectionRepository()),
      seed: () => InspectionState(
        formData: InspectionFormData.empty().copyWith(
          referenceNumber: 'REF-INVALID-9999',
        ),
      ),
      act: (b) => b.add(const FetchConsumerRequested()),
      wait: const Duration(seconds: 2),
      verify: (b) {
        expect(b.state.formData.fetchStatus, FetchStatus.notFound);
        expect(b.state.formData.meterId, isEmpty);
      },
    );

    // ── Field value changes ──────────────────────────────────────────────────
    blocTest<InspectionBloc, InspectionState>(
      'FieldValueChanged updates KWH value',
      build: () => InspectionBloc(repository: FakeInspectionRepository()),
      act: (b) => b.add(FieldValueChanged(InspectionField.kwh, '12345.67')),
      verify: (b) => expect(b.state.formData.kwh, '12345.67'),
    );

    blocTest<InspectionBloc, InspectionState>(
      'FieldValueChanged clears that field\'s validation error',
      build: () => InspectionBloc(repository: FakeInspectionRepository()),
      seed: () => InspectionState(
        formData: InspectionFormData.empty(),
        validationErrors: {InspectionField.kwh.name: 'KWH required'},
        showValidationErrors: true,
      ),
      act: (b) => b.add(FieldValueChanged(InspectionField.kwh, '100')),
      verify: (b) {
        expect(
          b.state.validationErrors.containsKey(InspectionField.kwh.name),
          isFalse,
        );
      },
    );

    // ── Dropdown changes ─────────────────────────────────────────────────────
    blocTest<InspectionBloc, InspectionState>(
      'DropdownChanged updates seal condition code',
      build: () => InspectionBloc(repository: FakeInspectionRepository()),
      act: (b) =>
          b.add(DropdownChanged(InspectionDropdown.sealCondition, 'INTACT')),
      verify: (b) => expect(b.state.formData.sealConditionCode, 'INTACT'),
    );

    // ── Submit with empty form → validation errors ───────────────────────────
    blocTest<InspectionBloc, InspectionState>(
      'FormSubmitRequested on empty form emits validation errors',
      build: () => InspectionBloc(repository: FakeInspectionRepository()),
      act: (b) => b.add(const FormSubmitRequested()),
      verify: (b) {
        expect(b.state.showValidationErrors, isTrue);
        expect(b.state.validationErrors, isNotEmpty);
        expect(b.state.formData.isSubmitted, isFalse);
      },
    );

    // ── Submit with valid data → success ─────────────────────────────────────
    blocTest<InspectionBloc, InspectionState>(
      'FormSubmitRequested with valid data emits isSubmitted=true',
      build: () => InspectionBloc(repository: FakeInspectionRepository()),
      seed: () => _validFilledState(),
      act: (b) => b.add(const FormSubmitRequested()),
      wait: const Duration(seconds: 3),
      verify: (b) {
        expect(b.state.formData.isSubmitted, isTrue);
        expect(b.state.formData.isSubmitting, isFalse);
      },
    );

    // ── Clear form ───────────────────────────────────────────────────────────
    blocTest<InspectionBloc, InspectionState>(
      'FormClearRequested resets to initial state',
      build: () => InspectionBloc(repository: FakeInspectionRepository()),
      seed: () => _validFilledState(),
      act: (b) => b.add(const FormClearRequested()),
      verify: (b) {
        expect(b.state.formData.referenceNumber, isEmpty);
        expect(b.state.formData.kwh, isEmpty);
        expect(b.state.showValidationErrors, isFalse);
      },
    );
  });
}

// Helper: produces a fully filled, valid InspectionState for submit tests
InspectionState _validFilledState() {
  final now = DateTime.now();
  return InspectionState(
    formData: InspectionFormData.empty().copyWith(
      referenceNumber: 'REF-2025-00142',
      fetchStatus: FetchStatus.success,
      meterId: 'MTR-LHR-2024-00987',
      consumerDetails:
          'Test Consumer | LHR-04-2200-1429 | Industrial B-2 | 250 kW',
      kwh: '12345.67',
      kvarh: '3456.78',
      mdi: '250.00',
      touPeak: '8000.0',
      touOffPeak: '4345.67',
      loadDetails: 'Test load observation',
      sealConditionCode: 'INTACT',
      ctPtBoxStatusCode: 'SECURED',
      gpsStatus: GpsStatus.success,
      gpsLatitude: 31.5204,
      gpsLongitude: 74.3587,
      gpsAccuracy: 8.0,
      images: [
        CapturedImage(
          type: 'METER',
          base64Data: 'dGVzdA==',
          latitude: 31.5204,
          longitude: 74.3587,
          capturedAt: now,
        ),
        CapturedImage(
          type: 'SEAL',
          base64Data: 'dGVzdA==',
          latitude: 31.5204,
          longitude: 74.3587,
          capturedAt: now,
        ),
      ],
    ),
  );
}
