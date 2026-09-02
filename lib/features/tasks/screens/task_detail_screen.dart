// =============================================================================
// FILE: lib/features/tasks/screens/task_detail_screen.dart
// PURPOSE: View + act on a single task. The assignee can start their own
// PENDING task; supervisory roles can reassign, change status, edit notes/
// due date, or cancel. Mirrors the PUT/DELETE rules in backend/api/tasks.php.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_exception.dart';
import '../../admin/widgets/admin_widgets.dart';
import '../../auth/widgets/auth_widgets.dart';
import '../../inspection/screens/inspection_detail_screen.dart';
import '../../inspection/screens/inspection_form_screen.dart';
import '../data/tasks_repository.dart';
import '../models/task_models.dart';
import '../widgets/task_widgets.dart';

class TaskDetailScreen extends StatefulWidget {
  final UserModel currentUser;
  final TaskAssignment task;

  const TaskDetailScreen({super.key, required this.currentUser, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late final TasksRepository _repo = ApiTasksRepository(token: widget.currentUser.token);
  late TaskAssignment _task = widget.task;
  late final bool _isSupervisor = widget.currentUser.role.accessLevel >= 1;
  bool _isBusy = false;
  String? _error;
  bool _changed = false;

  Future<void> _setStatus(String status) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await _repo.updateTask(_task.id, status: status);
      setState(() {
        _task = _task.copyWith(status: TaskStatusX.fromCode(status));
        _changed = true;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Opens the inspection form pre-filled with this task's reference number
  /// and linked via taskId, so submitting the inspection auto-completes this
  /// task (and its schedule) server-side — see
  /// POST /api/data.php?action=inspection-submit.
  Future<void> _startInspection() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InspectionFormScreen(
          initialReferenceNumber: _task.referenceNumber,
          taskId: _task.id,
        ),
      ),
    );
    if (!mounted) return;

    // The inspection submission (if completed) updates this task server-side
    // — refresh our local copy so the status badge reflects it immediately.
    try {
      final refreshed = await _repo.getTask(_task.id);
      setState(() {
        _task = refreshed;
        _changed = true;
      });
    } catch (_) {
      // Best-effort refresh — if it fails, the task list still re-fetches
      // when this screen is popped, so nothing is permanently stale.
    }
  }

  Future<void> _viewInspection() async {
    final inspectionId = _task.inspectionId;
    if (inspectionId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InspectionDetailScreen(
          token: widget.currentUser.token,
          inspectionId: inspectionId,
          currentUser: widget.currentUser,
        ),
      ),
    );
    if (!mounted) return;
    try {
      final refreshed = await _repo.getTask(_task.id);
      setState(() {
        _task = refreshed;
        _changed = true;
      });
    } catch (_) {
      // Best-effort — see _startInspection's identical comment.
    }
  }

  Future<void> _cancelTask() async {
    final confirmed = await confirmDestructiveAction(
      context,
      message: AppStrings.tasksConfirmCancel,
      confirmLabel: AppStrings.tasksCancelTask,
    );
    if (!confirmed) return;

    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await _repo.cancelTask(_task.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _editNotesAndDueDate() async {
    final notesCtrl = TextEditingController(text: _task.notes ?? '');
    DateTime? dueDate = _task.dueDate != null ? DateTime.tryParse(_task.dueDate!) : null;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
          ),
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit Task', style: AppTextStyles.headingMedium),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Notes',
                  hint: 'Instructions for the field team...',
                  controller: notesCtrl,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Due Date', style: AppTextStyles.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(dueDate == null ? 'Select date' : dueDate!.toIso8601String().split('T').first),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: dueDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) setSheetState(() => dueDate = picked);
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: AppStrings.adminSave,
                  onPressed: () => Navigator.of(sheetContext).pop({
                    'notes': notesCtrl.text.trim(),
                    'due_date': dueDate?.toIso8601String().split('T').first,
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await _repo.updateTask(
        _task.id,
        notes: result['notes'] as String?,
        dueDate: result['due_date'] as String?,
      );
      setState(() => _changed = true);
      if (!mounted) return;
      showAdminSnack(context, 'Task updated.');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundPage,
        appBar: AppBar(
          title: const Text('Task Detail'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
        ),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(_task.consumerName, style: AppTextStyles.headingMedium),
                    ),
                    TaskStatusBadge(status: _task.status),
                  ],
                ),
                if (_task.inspectionOverallStatus != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  InspectionOutcomeBadge(status: _task.inspectionOverallStatus!),
                ],
                const SizedBox(height: AppSpacing.lg),
                _InfoCard(task: _task, onViewInspection: _task.inspectionId != null ? _viewInspection : null),
                const SizedBox(height: AppSpacing.xl),
                if (!_isSupervisor && _task.status == TaskStatus.pending)
                  PrimaryButton(
                    label: AppStrings.tasksStartTask,
                    isLoading: _isBusy,
                    onPressed: () => _setStatus('IN_PROGRESS'),
                  ),
                if (!_isSupervisor &&
                    (_task.status == TaskStatus.pending || _task.status == TaskStatus.inProgress)) ...[
                  const SizedBox(height: AppSpacing.sm),
                  PrimaryButton(
                    label: _task.isRejectedInspection ? 'Inspect Again' : 'Start Inspection',
                    isLoading: _isBusy,
                    onPressed: _startInspection,
                  ),
                ],
                if (_isSupervisor) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Notes / Due Date'),
                    onPressed: _isBusy ? null : _editNotesAndDueDate,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_task.status != TaskStatus.cancelled && _task.status != TaskStatus.completed) ...[
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final s in ['PENDING', 'IN_PROGRESS', 'COMPLETED'])
                          if (s != _task.status.code)
                            OutlinedButton(
                              onPressed: _isBusy ? null : () => _setStatus(s),
                              child: Text('Mark ${TaskStatusX.fromCode(s).displayLabel}'),
                            ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.errorRed),
                        label: const Text(AppStrings.tasksCancelTask, style: TextStyle(color: AppColors.errorRed)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.errorRed)),
                        onPressed: _isBusy ? null : _cancelTask,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final TaskAssignment task;
  final VoidCallback? onViewInspection;
  const _InfoCard({required this.task, this.onViewInspection});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          _row('Reference #', task.referenceNumber),
          const SectionDivider(),
          _row('Meter ID', task.meterId),
          const SectionDivider(),
          _row('Assigned To', task.assignedToName),
          const SectionDivider(),
          _row('Assigned By', task.assignedByName),
          if (task.autoReassignedAt != null) ...[
            const SectionDivider(),
            _row('Auto-Reassigned', 'from ${task.autoReassignedFromName ?? 'previous assignee'} — did not complete in time'),
          ],
          const SectionDivider(),
          _row('Due Date', task.dueDate ?? '—'),
          if (task.notes != null && task.notes!.isNotEmpty) ...[
            const SectionDivider(),
            _row('Notes', task.notes!),
          ],
          if (task.inspectionId != null) ...[
            const SectionDivider(),
            InkWell(
              onTap: onViewInspection,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 120, child: Text('Linked Inspection', style: AppTextStyles.labelLarge)),
                    Expanded(
                      child: Text('#${task.inspectionId}', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGreen)),
                    ),
                    if (onViewInspection != null)
                      const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text(label, style: AppTextStyles.labelLarge)),
            Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
          ],
        ),
      );
}
