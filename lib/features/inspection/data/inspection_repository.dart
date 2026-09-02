// =============================================================================
// FILE: lib/features/inspection/data/inspection_repository.dart
// PURPOSE: Abstraction over the inspection-related backend calls, so
// InspectionBloc never talks to http/ApiClient directly. Production code
// uses ApiInspectionRepository (talks to backend/api/data.php). Tests can
// inject a fake implementation instead of hitting the network.
// =============================================================================

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../config/inspection_config.dart';
import '../bloc/inspection_models.dart';
import '../bloc/inspection_summary_model.dart';
import '../bloc/inspection_detail_model.dart';

class InspectionPage {
  final List<InspectionSummary> items;
  final int total;
  const InspectionPage({required this.items, required this.total});
}

abstract class InspectionRepository {
  /// Returns null if no consumer record exists for [referenceNumber]
  /// (mirrors the backend's 404 CONSUMER_NOT_FOUND response). Any other
  /// failure (network, server error) is rethrown as an ApiException.
  Future<ConsumerFetchResult?> fetchConsumer(String referenceNumber, String token);

  /// Loads the current Seal Condition / CT-PT Box dropdown options from the
  /// backend, so an admin can edit them without an app release.
  Future<FormOptionsConfig> fetchFormOptions(String token);

  /// Submits a completed inspection. Throws ApiException (with
  /// [ApiException.fieldErrors] populated on HTTP 422) on failure.
  Future<void> submitInspection(InspectionSubmissionPayload payload, String token);

  /// Returns the most recently submitted inspections (newest first), for a
  /// simple activity/history view. [limit] is capped at 100 server-side.
  Future<List<InspectionSummary>> fetchRecentInspections(String token, {int limit = 20});

  /// Full filtered/paged inspection listing — mirrors GET /api/data.php
  /// ?action=inspections-list. MT is always scoped server-side to their own
  /// submissions; SDO/XEN are always scoped server-side to their own
  /// division/sub-division(s) regardless of the [division]/[subDivision]
  /// params below (those may only narrow further within that scope).
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
  });

  /// Full single-inspection record — every reading, GPS coordinate,
  /// equipment-condition code, and uploaded image. Mirrors GET
  /// /api/data.php?action=inspection-detail&id=. Supervisory roles may
  /// fetch any inspection within their enforced scope (server-side
  /// checked); the field team member who submitted it may also fetch it.
  Future<InspectionDetail> getInspectionDetail(String token, int id);
}

// =============================================================================
// REAL IMPLEMENTATION — talks to backend/api/data.php
// =============================================================================
class ApiInspectionRepository implements InspectionRepository {
  final ApiClient _client;

  ApiInspectionRepository({ApiClient? client}) : _client = client ?? ApiClient();

  @override
  Future<ConsumerFetchResult?> fetchConsumer(String referenceNumber, String token) async {
    try {
      final response = await _client.get(
        ApiConfig.dataUri(ApiConfig.consumerFetchAction, {'ref': referenceNumber}),
        token: token,
      );
      return ConsumerFetchResult.fromJson(response);
    } on ApiException catch (e) {
      if (e.errorCode == 'CONSUMER_NOT_FOUND') return null;
      rethrow;
    }
  }

  @override
  Future<FormOptionsConfig> fetchFormOptions(String token) async {
    final response = await _client.get(
      ApiConfig.dataUri(ApiConfig.formOptionsAction),
      token: token,
    );
    return FormOptionsConfig.fromJson(response);
  }

  @override
  Future<void> submitInspection(InspectionSubmissionPayload payload, String token) async {
    await _client.post(
      ApiConfig.dataUri(ApiConfig.inspectionSubmitAction),
      body: payload.toJson(),
      token: token,
    );
  }

  @override
  Future<List<InspectionSummary>> fetchRecentInspections(String token, {int limit = 20}) async {
    final response = await _client.get(
      ApiConfig.dataUri(ApiConfig.inspectionsListAction, {'limit': '$limit'}),
      token: token,
    );
    return (response['data'] as List)
        .map((e) => InspectionSummary.fromJson(e as Map<String, dynamic>))
        .toList();
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
    final params = <String, String>{
      'page':     '$page',
      'per_page': '$perPage',
      if (search != null && search.isNotEmpty)           'search': search,
      if (status != null && status.isNotEmpty)            'status': status,
      if (division != null && division.isNotEmpty)        'division': division,
      if (subDivision != null && subDivision.isNotEmpty)  'sub_division': subDivision,
      if (category != null && category.isNotEmpty)        'category': category,
      if (dateFrom != null && dateFrom.isNotEmpty)         'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty)             'date_to': dateTo,
    };
    final response = await _client.get(
      ApiConfig.dataUri(ApiConfig.inspectionsListAction, params),
      token: token,
    );
    final items = (response['data'] as List)
        .map((e) => InspectionSummary.fromJson(e as Map<String, dynamic>))
        .toList();
    final total = (response['total'] as num?)?.toInt() ?? items.length;
    return InspectionPage(items: items, total: total);
  }

  @override
  Future<InspectionDetail> getInspectionDetail(String token, int id) async {
    final response = await _client.get(
      ApiConfig.dataUri(ApiConfig.inspectionDetailAction, {'id': '$id'}),
      token: token,
    );
    return InspectionDetail.fromJson(response['data'] as Map<String, dynamic>);
  }
}
