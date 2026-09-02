// =============================================================================
// FILE: lib/features/tasks/data/tasks_repository.dart
// PURPOSE: Talks to backend/api/tasks.php. Access is role-scoped server-side
// per method (not admin-exclusive) — field team (MT) always gets their own
// tasks back from GET regardless of filters sent; supervisory roles
// (SDO/XEN/SE/ADMIN) get the full, filterable list and may assign/reassign/
// cancel. See API.md "Task Assignment".
// =============================================================================

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../models/task_models.dart';

class TaskPage {
  final List<TaskAssignment> items;
  final int total;
  const TaskPage({required this.items, required this.total});
}

abstract class TasksRepository {
  /// Lists tasks. For non-supervisory roles the backend ignores [assignedTo]
  /// and always scopes to the caller's own tasks.
  Future<TaskPage> listTasks({
    String? status,
    int? assignedTo,
    String? division,
    String? subDivision,
    int page = 1,
    int perPage = 20,
  });

  Future<TaskAssignment> getTask(int id);

  /// Assigns a new task. Either [consumerId] or [scheduleId] must be given.
  /// Supervisory roles only (enforced server-side).
  Future<void> assignTask({
    int? consumerId,
    int? scheduleId,
    required int assignedToUserId,
    String? dueDate,
    String? notes,
  });

  /// The assignee may only move their own task to IN_PROGRESS. Supervisory
  /// roles may set any status, reassign, change due date, or edit notes.
  Future<void> updateTask(
    int id, {
    String? status,
    int? assignedToUserId,
    String? dueDate,
    String? notes,
  });

  /// Soft-cancels a task (status -> CANCELLED). Supervisory roles only.
  Future<void> cancelTask(int id);
}

// =============================================================================
// REAL IMPLEMENTATION
// =============================================================================
class ApiTasksRepository implements TasksRepository {
  final ApiClient _client;
  final String token;

  ApiTasksRepository({required this.token, ApiClient? client}) : _client = client ?? ApiClient();

  Uri _uri([Map<String, String>? params]) =>
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tasks}').replace(queryParameters: params);

  @override
  Future<TaskPage> listTasks({
    String? status,
    int? assignedTo,
    String? division,
    String? subDivision,
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _client.get(
      _uri({
        'page': '$page',
        'per_page': '$perPage',
        if (status != null && status.isNotEmpty) 'status': status,
        if (assignedTo != null && assignedTo > 0) 'assigned_to': '$assignedTo',
        if (division != null && division.isNotEmpty) 'division': division,
        if (subDivision != null && subDivision.isNotEmpty) 'sub_division': subDivision,
      }),
      token: token,
    );
    final items = (response['data'] as List)
        .map((e) => TaskAssignment.fromJson(e as Map<String, dynamic>))
        .toList();
    return TaskPage(items: items, total: (response['total'] as num?)?.toInt() ?? items.length);
  }

  @override
  Future<TaskAssignment> getTask(int id) async {
    final response = await _client.get(_uri({'id': '$id'}), token: token);
    return TaskAssignment.fromJson(response['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> assignTask({
    int? consumerId,
    int? scheduleId,
    required int assignedToUserId,
    String? dueDate,
    String? notes,
  }) {
    return _client.post(
      _uri(),
      token: token,
      body: {
        if (scheduleId != null && scheduleId > 0) 'schedule_id': scheduleId,
        if (consumerId != null && consumerId > 0) 'consumer_id': consumerId,
        'assigned_to_user_id': assignedToUserId,
        if (dueDate != null && dueDate.isNotEmpty) 'due_date': dueDate,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  @override
  Future<void> updateTask(
    int id, {
    String? status,
    int? assignedToUserId,
    String? dueDate,
    String? notes,
  }) {
    return _client.put(
      _uri({'id': '$id'}),
      token: token,
      body: {
        if (status != null) 'status': status,
        if (assignedToUserId != null) 'assigned_to_user_id': assignedToUserId,
        if (dueDate != null) 'due_date': dueDate,
        if (notes != null) 'notes': notes,
      },
    );
  }

  @override
  Future<void> cancelTask(int id) {
    return _client.delete(_uri({'id': '$id'}), token: token);
  }
}
