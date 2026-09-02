// =============================================================================
// FILE: lib/features/tasks/screens/tasks_list_screen.dart
// PURPOSE: Lists task assignments (GET /api/tasks.php). Field team (MT) sees
// only their own tasks and can start them; supervisory roles (SDO/XEN/SE/
// ADMIN) see the full list, can filter by status, and assign new tasks.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/scope_defaults.dart';
import '../../../core/widgets/logout_action.dart';
import '../../admin/widgets/admin_widgets.dart';
import '../data/tasks_repository.dart';
import '../models/task_models.dart';
import '../widgets/task_widgets.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';

class TasksListScreen extends StatefulWidget {
  final UserModel currentUser;

  const TasksListScreen({super.key, required this.currentUser});

  @override
  State<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends State<TasksListScreen> {
  late final TasksRepository _repo = ApiTasksRepository(token: widget.currentUser.token);
  late final bool _isSupervisor = widget.currentUser.role.accessLevel >= 1;
  // MT's own-tasks scoping is already enforced server-side; for SDO/XEN this
  // is the actual sub-division/division restriction from the workflow spec —
  // not user-editable (no "All" toggle), matching "SDO cannot see data
  // belonging to another sub-division."
  late final ScopeDefaults _scope = ScopeDefaults.forUser(widget.currentUser);

  final List<TaskAssignment> _tasks = [];
  int _total = 0;
  int _page = 1;
  static const _perPage = 20;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  String? _statusFilter;
  bool _overdueOnly = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      if (reset) {
        _isLoading = true;
        _error = null;
        _page = 1;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final result = await _repo.listTasks(
        status: _statusFilter,
        division: _scope.division,
        subDivision: _scope.subDivision,
        page: _page,
        perPage: _perPage,
      );
      setState(() {
        if (reset) _tasks.clear();
        _tasks.addAll(result.items);
        _total = result.total;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('ApiException(null, null): ', '');
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_tasks.length >= _total) return;
    _page += 1;
    await _load();
  }

  void _onStatusFilterChanged(String? status) {
    setState(() => _statusFilter = status);
    _load(reset: true);
  }

  /// Overdue is a derived client-side property (see TaskAssignment.isOverdue),
  /// not a server-side status, so this filters the already-loaded page rather
  /// than requesting a new one — see the "Delayed inspections" note in
  /// scope_defaults.dart for the rest of the escalation-visibility work.
  List<TaskAssignment> get _visibleTasks =>
      _overdueOnly ? _tasks.where((t) => t.isOverdue).toList() : _tasks;

  Future<void> _openAssign() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskFormScreen(currentUser: widget.currentUser)),
    );
    if (created == true) _load(reset: true);
  }

  Future<void> _openDetail(TaskAssignment task) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(currentUser: widget.currentUser, task: task),
      ),
    );
    if (changed == true) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(title: const Text(AppStrings.tasksTitle), actions: const [LogoutAction()]),
      floatingActionButton: _isSupervisor
          ? FloatingActionButton.extended(
              onPressed: _openAssign,
              backgroundColor: AppColors.primaryGreen,
              icon: const Icon(Icons.add_task_rounded, color: AppColors.white),
              label: const Text(AppStrings.tasksAssignNew, style: TextStyle(color: AppColors.white)),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: () => _load(reset: true),
          child: ListView(
            padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, _isSupervisor ? 96 : AppSpacing.md),
            children: [
              Row(
                children: [
                  Expanded(child: TaskStatusFilterBar(selected: _statusFilter, onChanged: _onStatusFilterChanged)),
                  const SizedBox(width: AppSpacing.sm),
                  FilterChip(
                    label: const Text('Overdue'),
                    avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.errorRed),
                    selected: _overdueOnly,
                    onSelected: (v) => setState(() => _overdueOnly = v),
                    selectedColor: AppColors.errorRed.withOpacity(0.12),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _overdueOnly ? AppColors.errorRed : AppColors.textSecondary,
                    ),
                    backgroundColor: AppColors.surfaceCard,
                    side: BorderSide(color: _overdueOnly ? AppColors.errorRed : AppColors.borderSubtle),
                  ),
                ],
              ),
              if (_isSupervisor && (_scope.division != null || _scope.subDivision != null))
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Showing ${_scope.subDivision ?? _scope.division} only',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              AdminListState(
                isLoading: _isLoading,
                errorMessage: _error,
                isEmpty: _visibleTasks.isEmpty,
                onRetry: () => _load(reset: true),
              ),
              if (!_isLoading && _error == null && _visibleTasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Center(
                    child: Text(
                      _overdueOnly
                          ? 'Nothing overdue right now.'
                          : (_isSupervisor ? AppStrings.tasksEmptyAll : AppStrings.tasksEmptyMine),
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ),
              ..._visibleTasks.map((t) => TaskTile(
                    task: t,
                    isSupervisor: _isSupervisor,
                    onTap: () => _openDetail(t),
                  )),
              if (!_isLoading && !_overdueOnly && _tasks.length < _total)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(
                    child: _isLoadingMore
                        ? const CircularProgressIndicator(color: AppColors.primaryGreen)
                        : TextButton(onPressed: _loadMore, child: const Text(AppStrings.adminLoadMore)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
