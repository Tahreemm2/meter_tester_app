// =============================================================================
// FILE: lib/features/scheduling/data/scheduling_repository.dart
// PURPOSE: Talks to backend/api/admin/schedules.php. Restricted to
// supervisory roles (SDO/XEN/SE/ADMIN) server-side — see API.md "Meter
// Scheduling System".
// =============================================================================

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../models/schedule_models.dart';

class SchedulePage {
  final List<ScheduleEntry> items;
  final int total;
  const SchedulePage({required this.items, required this.total});
}

class GenerateResult {
  final String message;
  final String quarter;
  final int created;
  final int skippedExisting;
  const GenerateResult({
    required this.message,
    required this.quarter,
    required this.created,
    required this.skippedExisting,
  });
}

abstract class SchedulingRepository {
  Future<SchedulePage> listSchedules({
    String? division,
    String? subDivision,
    String? category,
    String? quarter,
    String? status,
    int page = 1,
    int perPage = 20,
  });

  Future<GenerateResult> generateQuarter({
    String? quarter,
    String? division,
    String? subDivision,
    String? category,
  });

  Future<void> createSchedule({
    required int consumerId,
    required String quarter,
    required String scheduledDate,
    String? category,
  });

  Future<void> updateSchedule(
    int id, {
    String? scheduledDate,
    String? status,
    String? overrideReason,
    String? category,
  });

  Future<void> deleteSchedule(int id);
}

// =============================================================================
// REAL IMPLEMENTATION
// =============================================================================
class ApiSchedulingRepository implements SchedulingRepository {
  final ApiClient _client;
  final String token;

  ApiSchedulingRepository({required this.token, ApiClient? client}) : _client = client ?? ApiClient();

  Uri _uri([Map<String, String>? params]) =>
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.adminSchedules}').replace(queryParameters: params);

  @override
  Future<SchedulePage> listSchedules({
    String? division,
    String? subDivision,
    String? category,
    String? quarter,
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _client.get(
      _uri({
        'page': '$page',
        'per_page': '$perPage',
        if (division != null && division.isNotEmpty) 'division': division,
        if (subDivision != null && subDivision.isNotEmpty) 'sub_division': subDivision,
        if (category != null && category.isNotEmpty) 'category': category,
        if (quarter != null && quarter.isNotEmpty) 'quarter': quarter,
        if (status != null && status.isNotEmpty) 'status': status,
      }),
      token: token,
    );
    final items = (response['data'] as List)
        .map((e) => ScheduleEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return SchedulePage(items: items, total: (response['total'] as num?)?.toInt() ?? items.length);
  }

  @override
  Future<GenerateResult> generateQuarter({
    String? quarter,
    String? division,
    String? subDivision,
    String? category,
  }) async {
    final response = await _client.post(
      _uri({'action': 'generate'}),
      token: token,
      body: {
        if (quarter != null && quarter.isNotEmpty) 'quarter': quarter,
        if (division != null && division.isNotEmpty) 'division': division,
        if (subDivision != null && subDivision.isNotEmpty) 'sub_division': subDivision,
        if (category != null && category.isNotEmpty) 'category': category,
      },
    );
    return GenerateResult(
      message: response['message'] as String? ?? 'Generated.',
      quarter: response['quarter'] as String? ?? (quarter ?? ''),
      created: (response['created'] as num?)?.toInt() ?? 0,
      skippedExisting: (response['skipped_existing'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> createSchedule({
    required int consumerId,
    required String quarter,
    required String scheduledDate,
    String? category,
  }) {
    return _client.post(
      _uri(),
      token: token,
      body: {
        'consumer_id': consumerId,
        'quarter': quarter,
        'scheduled_date': scheduledDate,
        if (category != null && category.isNotEmpty) 'category': category,
      },
    );
  }

  @override
  Future<void> updateSchedule(
    int id, {
    String? scheduledDate,
    String? status,
    String? overrideReason,
    String? category,
  }) {
    return _client.put(
      _uri({'id': '$id'}),
      token: token,
      body: {
        if (scheduledDate != null) 'scheduled_date': scheduledDate,
        if (status != null) 'status': status,
        if (overrideReason != null) 'override_reason': overrideReason,
        if (category != null) 'category': category,
      },
    );
  }

  @override
  Future<void> deleteSchedule(int id) {
    return _client.delete(_uri({'id': '$id'}), token: token);
  }
}
