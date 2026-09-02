// =============================================================================
// FILE: lib/features/tasks/widgets/task_widgets.dart
// PURPOSE: Shared UI pieces for the Task Assignment feature.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/overdue_badge.dart';
import '../models/task_models.dart';

/// Small colored pill showing a task's current status.
class TaskStatusBadge extends StatelessWidget {
  final TaskStatus status;
  const TaskStatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case TaskStatus.pending:     return AppColors.textHint;
      case TaskStatus.inProgress:  return AppColors.accentGold;
      case TaskStatus.completed:   return AppColors.successGreen;
      case TaskStatus.cancelled:   return AppColors.errorRed;
      case TaskStatus.unknown:     return AppColors.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Text(
        status.displayLabel,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _color),
      ),
    );
  }
}

/// Small colored pill showing the Approval Workflow outcome of a task's
/// linked inspection (spec 3.10) — separate from TaskStatusBadge, since a
/// REJECTED inspection reopens the task to PENDING server-side, so the task
/// status alone can't distinguish "never started" from "rejected, redo it".
class InspectionOutcomeBadge extends StatelessWidget {
  final String status; // PENDING_APPROVAL | APPROVED | REJECTED
  const InspectionOutcomeBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case 'APPROVED':         return AppColors.successGreen;
      case 'REJECTED':         return AppColors.errorRed;
      case 'PENDING_APPROVAL': return AppColors.accentGold;
      default:                 return AppColors.textHint;
    }
  }

  String get _label {
    switch (status) {
      case 'APPROVED':         return 'Approved';
      case 'REJECTED':         return 'Rejected';
      case 'PENDING_APPROVAL': return 'Pending Approval';
      default:                 return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Text(_label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _color)),
    );
  }
}

/// A single task row card, used on the Tasks list screen.
class TaskTile extends StatelessWidget {
  final TaskAssignment task;
  final bool isSupervisor;
  final VoidCallback? onTap;

  const TaskTile({
    super.key,
    required this.task,
    required this.isSupervisor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.consumerName,
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (task.isOverdue) ...[
                    const OverdueBadge(),
                    const SizedBox(width: 6),
                  ],
                  TaskStatusBadge(status: task.status),
                ],
              ),
              const SizedBox(height: 2),
              Text('${task.referenceNumber} · ${task.meterId}', style: AppTextStyles.bodySmall),
              if (task.inspectionOverallStatus != null) ...[
                const SizedBox(height: 6),
                InspectionOutcomeBadge(status: task.inspectionOverallStatus!),
              ],
              if (task.autoReassignedAt != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.sync_alt_rounded, size: 13, color: AppColors.warningAmber),
                    const SizedBox(width: 4),
                    Text('Auto-reassigned', style: AppTextStyles.bodySmall.copyWith(color: AppColors.warningAmber, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      isSupervisor ? 'Assigned to ${task.assignedToName}' : 'Assigned by ${task.assignedByName}',
                      style: AppTextStyles.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (task.dueDate != null) ...[
                    const Icon(Icons.event_outlined, size: 14, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(task.dueDate!, style: AppTextStyles.bodySmall),
                  ],
                ],
              ),
              if (task.notes != null && task.notes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(task.notes!, style: AppTextStyles.bodySmall.copyWith(fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Row of filter chips for task status.
class TaskStatusFilterBar extends StatelessWidget {
  final String? selected; // null = All
  final ValueChanged<String?> onChanged;

  const TaskStatusFilterBar({super.key, required this.selected, required this.onChanged});

  static const _options = <String?, String>{
    null: 'All',
    'PENDING': 'Pending',
    'IN_PROGRESS': 'In Progress',
    'COMPLETED': 'Completed',
    'CANCELLED': 'Cancelled',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _options.entries.map((entry) {
          final isSelected = selected == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (_) => onChanged(entry.key),
              selectedColor: AppColors.primaryGreenSurface,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
              ),
              backgroundColor: AppColors.surfaceCard,
              side: BorderSide(color: isSelected ? AppColors.primaryGreen : AppColors.borderSubtle),
            ),
          );
        }).toList(),
      ),
    );
  }
}
