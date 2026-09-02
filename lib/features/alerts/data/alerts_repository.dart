// =============================================================================
// FILE: lib/features/alerts/data/alerts_repository.dart
// PURPOSE: Talks to backend/api/alerts.php.
// - Supervisory roles (SDO/XEN/SE/ADMIN): ESCALATION rows are level-gated
//   (SDO=1, XEN=2, SE=3); DISCREPANCY rows are visible to every supervisory
//   role in scope, any level. ADMIN sees everything unfiltered.
// - M&T: always gets back their own INSPECTION_DECISION rows — an
//   SDO/XEN/SE approve/forward/reject on an inspection they submitted —
//   regardless of the type filter passed here (there's nothing else for
//   them to see on this endpoint).
// All scoping/gating is enforced server-side.
// See API.md "Notifications: Escalation Alerts & New-Discrepancy Alerts".
// =============================================================================

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../models/alert_models.dart';

abstract class AlertsRepository {
  Future<List<AppAlert>> fetchAlerts({bool unreadOnly = false, AlertType? type});
  Future<void> markRead(int id);
}

// =============================================================================
// REAL IMPLEMENTATION
// =============================================================================
class ApiAlertsRepository implements AlertsRepository {
  final ApiClient _client;
  final String token;

  ApiAlertsRepository({required this.token, ApiClient? client}) : _client = client ?? ApiClient();

  @override
  Future<List<AppAlert>> fetchAlerts({bool unreadOnly = false, AlertType? type}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.alerts}').replace(
      queryParameters: {
        if (unreadOnly) 'unread_only': '1',
        if (type != null) 'type': switch (type) {
          AlertType.discrepancy => 'DISCREPANCY',
          AlertType.inspectionDecision => 'INSPECTION_DECISION',
          AlertType.escalation => 'ESCALATION',
        },
      },
    );
    final response = await _client.get(uri, token: token);
    return (response['data'] as List)
        .map((e) => AppAlert.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markRead(int id) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.alerts}').replace(
      queryParameters: {'action': 'mark-read'},
    );
    await _client.post(uri, token: token, body: {'id': id});
  }
}
