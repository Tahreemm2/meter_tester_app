// =============================================================================
// FILE: lib/features/tasks/screens/task_form_screen.dart
// PURPOSE: Assign a new task (POST /api/tasks.php). Supervisory roles only
// (enforced server-side). Source consumer can come directly (consumer_id) or
// via an existing PENDING schedule entry (schedule_id), per API.md.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/id_picker_fields.dart';
import '../../auth/widgets/auth_widgets.dart';
import '../../admin/widgets/admin_widgets.dart';
import '../../scheduling/data/scheduling_repository.dart';
import '../../scheduling/models/schedule_models.dart';
import '../data/tasks_repository.dart';

enum _TaskSource { consumer, schedule }

class TaskFormScreen extends StatefulWidget {
  final UserModel currentUser;
  const TaskFormScreen({super.key, required this.currentUser});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  late final TasksRepository _tasksRepo = ApiTasksRepository(token: widget.currentUser.token);
  late final SchedulingRepository _scheduleRepo = ApiSchedulingRepository(token: widget.currentUser.token);
  final _notesCtrl = TextEditingController();

  _TaskSource _source = _TaskSource.schedule;
  int? _consumerId;
  int? _selectedScheduleId;
  int? _assignedToUserId;
  DateTime? _dueDate;

  List<ScheduleEntry> _pendingSchedules = [];
  bool _isLoadingSchedules = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPendingSchedules();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPendingSchedules() async {
    try {
      final page = await _scheduleRepo.listSchedules(status: 'PENDING', perPage: 50);
      if (!mounted) return;
      setState(() {
        _pendingSchedules = page.items;
        _isLoadingSchedules = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingSchedules = false);
    }
  }

  bool get _canSubmit {
    if (_assignedToUserId == null) return false;
    if (_source == _TaskSource.consumer) return _consumerId != null;
    return _selectedScheduleId != null;
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      setState(() => _error = 'Select a consumer/schedule and an assignee before continuing.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await _tasksRepo.assignTask(
        consumerId: _source == _TaskSource.consumer ? _consumerId : null,
        scheduleId: _source == _TaskSource.schedule ? _selectedScheduleId : null,
        assignedToUserId: _assignedToUserId!,
        dueDate: _dueDate?.toIso8601String().split('T').first,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (!mounted) return;
      showAdminSnack(context, 'Task assigned.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(title: const Text(AppStrings.tasksAssignNew)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: AppSpacing.md),
              ],
              Text('Assign From', style: AppTextStyles.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<_TaskSource>(
                segments: const [
                  ButtonSegment(value: _TaskSource.schedule, label: Text('Pending Schedule')),
                  ButtonSegment(value: _TaskSource.consumer, label: Text('Consumer')),
                ],
                selected: {_source},
                onSelectionChanged: (s) => setState(() => _source = s.first),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_source == _TaskSource.schedule) _buildScheduleSelector() else
                ConsumerIdField(
                  currentUser: widget.currentUser,
                  onChanged: (id) => setState(() => _consumerId = id),
                ),
              const SizedBox(height: AppSpacing.lg),
              UserIdField(
                currentUser: widget.currentUser,
                roleFilter: 'MT',
                onChanged: (id) => setState(() => _assignedToUserId = id),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Due Date (optional)', style: AppTextStyles.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(_dueDate == null ? 'Select date' : _dueDate!.toIso8601String().split('T').first),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked != null) setState(() => _dueDate = picked);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Notes (optional)',
                hint: 'Any instructions for the field team...',
                controller: _notesCtrl,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: AppStrings.tasksAssignNew,
                isLoading: _isSaving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleSelector() {
    if (_isLoadingSchedules) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_pendingSchedules.isEmpty) {
      return Text(
        'No PENDING schedule entries found. Generate a quarter from the Scheduling module, or switch to "Consumer" above.',
        style: AppTextStyles.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pending Schedule Entry', style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<int>(
          initialValue: _selectedScheduleId,
          isExpanded: true,
          hint: const Text('Select a schedule entry'),
          items: _pendingSchedules
              .map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      '${s.referenceNumber} — ${s.consumerName} (${s.scheduledDate})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (id) => setState(() => _selectedScheduleId = id),
        ),
      ],
    );
  }
}
