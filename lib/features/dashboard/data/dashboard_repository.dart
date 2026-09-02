// =============================================================================
// FILE: lib/features/dashboard/data/dashboard_repository.dart
// PURPOSE: Talks to backend/api/dashboard.php. Supervisory roles only
// (SDO/XEN/SE/ADMIN) — enforced server-side. See API.md "Dashboard &
// Analytics".
// =============================================================================

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../models/dashboard_models.dart';

abstract class DashboardRepository {
  /// All filters optional; [quarter] defaults server-side to the current one.
  Future<DashboardData> getDashboard({
    String? quarter,
    String? division,
    String? subDivision,
    String? category,
  });
}

// =============================================================================
// REAL IMPLEMENTATION
// =============================================================================
class ApiDashboardRepository implements DashboardRepository {
  final ApiClient _client;
  final String token;

  ApiDashboardRepository({required this.token, ApiClient? client}) : _client = client ?? ApiClient();

  @override
  Future<DashboardData> getDashboard({
    String? quarter,
    String? division,
    String? subDivision,
    String? category,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.dashboard}').replace(queryParameters: {
      if (quarter != null && quarter.isNotEmpty) 'quarter': quarter,
      if (division != null && division.isNotEmpty) 'division': division,
      if (subDivision != null && subDivision.isNotEmpty) 'sub_division': subDivision,
      if (category != null && category.isNotEmpty) 'category': category,
    });
    final response = await _client.get(uri, token: token);
    return DashboardData.fromJson(response);
  }
}
