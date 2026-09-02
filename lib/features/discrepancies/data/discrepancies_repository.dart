// =============================================================================
// FILE: lib/features/discrepancies/data/discrepancies_repository.dart
// PURPOSE: Talks to backend/api/discrepancies.php. Any authenticated user can
// report a discrepancy; field team (MT) only ever sees their own reports;
// supervisory roles (SDO/XEN/SE/ADMIN) see reports within their assigned
// division/sub-division scope — SDO must never see another sub-division's
// discrepancies (workflow spec). See API.md "Discrepancy Reporting".
// =============================================================================

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../models/discrepancy_models.dart';

class DiscrepancyPage {
  final List<DiscrepancyReport> items;
  final int total;
  const DiscrepancyPage({required this.items, required this.total});
}

abstract class DiscrepanciesRepository {
  /// [division]/[subDivision] should come from ScopeDefaults.forUser() for
  /// SDO/XEN — never left to the caller to pick freely — same pattern as
  /// SchedulingRepository.listSchedules().
  Future<DiscrepancyPage> listDiscrepancies({
    String? status,
    String? type,
    String? severity,
    String? division,
    String? subDivision,
    int? assignedTo,
    int? inspectionId,
    int page = 1,
    int perPage = 20,
  });

  Future<DiscrepancyReport> getDiscrepancy(int id);

  /// Reports a new discrepancy. Either [referenceNumber] or [consumerId]
  /// identifies the consumer (both optional but recommended).
  Future<void> reportDiscrepancy({
    String? referenceNumber,
    int? consumerId,
    int? inspectionId,
    required String type,
    required String description,
    required String severity,
    String? photoEvidenceBase64,
  });

  /// Triage a report and/or assign an M&T worker to investigate it.
  /// Supervisory roles only (enforced server-side); [assignedToUserId] must
  /// be an active MT user, and an SDO may only assign within their own
  /// sub-division (same rule as task assignment).
  Future<void> triageDiscrepancy(
    int id, {
    String? status,
    String? resolutionNotes,
    int? assignedToUserId,
  });
}

// =============================================================================
// REAL IMPLEMENTATION
// =============================================================================
class ApiDiscrepanciesRepository implements DiscrepanciesRepository {
  final ApiClient _client;
  final String token;

  ApiDiscrepanciesRepository({required this.token, ApiClient? client}) : _client = client ?? ApiClient();

  Uri _uri([Map<String, String>? params]) =>
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.discrepancies}').replace(queryParameters: params);

  @override
  Future<DiscrepancyPage> listDiscrepancies({
    String? status,
    String? type,
    String? severity,
    String? division,
    String? subDivision,
    int? assignedTo,
    int? inspectionId,
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _client.get(
      _uri({
        'page': '$page',
        'per_page': '$perPage',
        if (status != null && status.isNotEmpty) 'status': status,
        if (type != null && type.isNotEmpty) 'type': type,
        if (severity != null && severity.isNotEmpty) 'severity': severity,
        if (division != null && division.isNotEmpty) 'division': division,
        if (subDivision != null && subDivision.isNotEmpty) 'sub_division': subDivision,
        if (assignedTo != null && assignedTo > 0) 'assigned_to': '$assignedTo',
        if (inspectionId != null && inspectionId > 0) 'inspection_id': '$inspectionId',
      }),
      token: token,
    );
    final items = (response['data'] as List)
        .map((e) => DiscrepancyReport.fromJson(e as Map<String, dynamic>))
        .toList();
    return DiscrepancyPage(items: items, total: (response['total'] as num?)?.toInt() ?? items.length);
  }

  @override
  Future<DiscrepancyReport> getDiscrepancy(int id) async {
    final response = await _client.get(_uri({'id': '$id'}), token: token);
    return DiscrepancyReport.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> reportDiscrepancy({
    String? referenceNumber,
    int? consumerId,
    int? inspectionId,
    required String type,
    required String description,
    required String severity,
    String? photoEvidenceBase64,
  }) {
    return _client.post(
      _uri(),
      token: token,
      body: {
        if (referenceNumber != null && referenceNumber.isNotEmpty) 'reference_number': referenceNumber,
        if (consumerId != null && consumerId > 0) 'consumer_id': consumerId,
        if (inspectionId != null && inspectionId > 0) 'inspection_id': inspectionId,
        'type': type,
        'description': description,
        'severity': severity,
        if (photoEvidenceBase64 != null && photoEvidenceBase64.isNotEmpty)
          'photo_evidence_base64': photoEvidenceBase64,
      },
    );
  }

  @override
  Future<void> triageDiscrepancy(
    int id, {
    String? status,
    String? resolutionNotes,
    int? assignedToUserId,
  }) {
    return _client.put(
      _uri({'id': '$id'}),
      token: token,
      body: {
        if (status != null) 'status': status,
        if (resolutionNotes != null) 'resolution_notes': resolutionNotes,
        if (assignedToUserId != null) 'assigned_to_user_id': assignedToUserId,
      },
    );
  }
}
