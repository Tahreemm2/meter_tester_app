// =============================================================================
// FILE: lib/features/approvals/data/approvals_repository.dart
// PURPOSE: Talks to backend/api/approvals.php. Supervisory roles only
// (SDO/XEN/SE/ADMIN) — enforced server-side. status=PENDING (default) is the
// caller's own review queue for SDO/XEN/SE; ADMIN sees the global pool.
// See API.md "Approval Workflow".
// =============================================================================

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../models/approval_models.dart';

class ApprovalPage {
  final List<InspectionApproval> items;
  final int total;
  const ApprovalPage({required this.items, required this.total});
}

abstract class ApprovalsRepository {
  /// [status] is one of PENDING (default), APPROVED, REJECTED.
  Future<ApprovalPage> listApprovals({
    String status = 'PENDING',
    String? division,
    String? subDivision,
    String? category,
    int page = 1,
    int perPage = 20,
  });

  Future<InspectionApproval> getApproval(int inspectionId);

  /// Records a decision at the inspection's current approval level.
  /// [decision] is "APPROVE" or "REJECT".
  Future<void> decide(int inspectionId, {required String decision, String? remarks});
}

// =============================================================================
// REAL IMPLEMENTATION
// =============================================================================
class ApiApprovalsRepository implements ApprovalsRepository {
  final ApiClient _client;
  final String token;

  ApiApprovalsRepository({required this.token, ApiClient? client}) : _client = client ?? ApiClient();

  Uri _uri([Map<String, String>? params]) =>
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.approvals}').replace(queryParameters: params);

  @override
  Future<ApprovalPage> listApprovals({
    String status = 'PENDING',
    String? division,
    String? subDivision,
    String? category,
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _client.get(
      _uri({
        'status': status,
        'page': '$page',
        'per_page': '$perPage',
        if (division != null && division.isNotEmpty) 'division': division,
        if (subDivision != null && subDivision.isNotEmpty) 'sub_division': subDivision,
        if (category != null && category.isNotEmpty) 'category': category,
      }),
      token: token,
    );
    final items = (response['data'] as List)
        .map((e) => InspectionApproval.fromJson(e as Map<String, dynamic>))
        .toList();
    return ApprovalPage(items: items, total: (response['total'] as num?)?.toInt() ?? items.length);
  }

  @override
  Future<InspectionApproval> getApproval(int inspectionId) async {
    final response = await _client.get(_uri({'id': '$inspectionId'}), token: token);
    return InspectionApproval.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> decide(int inspectionId, {required String decision, String? remarks}) {
    return _client.post(
      _uri({'action': 'decide'}),
      token: token,
      body: {
        'inspection_id': inspectionId,
        'decision': decision,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      },
    );
  }
}
