// =============================================================================
// FILE: lib/features/scheduling/widgets/scheduling_widgets.dart
// PURPOSE: Shared UI pieces for the Meter Scheduling feature.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/overdue_badge.dart';
import '../models/schedule_models.dart';

class ScheduleStatusBadge extends StatelessWidget {
  final ScheduleStatus status;
  const ScheduleStatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case ScheduleStatus.pending:   return AppColors.textHint;
      case ScheduleStatus.assigned:  return AppColors.accentGold;
      case ScheduleStatus.completed: return AppColors.successGreen;
      case ScheduleStatus.cancelled: return AppColors.errorRed;
      case ScheduleStatus.unknown:   return AppColors.textHint;
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

class ScheduleTile extends StatelessWidget {
  final ScheduleEntry schedule;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ScheduleTile({super.key, required this.schedule, this.onTap, this.onDelete});

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
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            schedule.consumerName,
                            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (schedule.isOverdue) ...[
                          const OverdueBadge(),
                          const SizedBox(width: 6),
                        ],
                        ScheduleStatusBadge(status: schedule.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${schedule.referenceNumber} · ${schedule.meterId}', style: AppTextStyles.bodySmall),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.event_outlined, size: 14, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(
                          schedule.scheduledDate,
                          style: schedule.isOverdue
                              ? AppTextStyles.bodySmall.copyWith(color: AppColors.errorRed, fontWeight: FontWeight.w600)
                              : AppTextStyles.bodySmall,
                        ),
                        if (schedule.daysOverdue != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${schedule.daysOverdue} day${schedule.daysOverdue == 1 ? '' : 's'} overdue)',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.errorRed),
                          ),
                        ],
                        const SizedBox(width: 10),
                        if (schedule.category != null) ...[
                          const Icon(Icons.category_outlined, size: 14, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(schedule.category!, style: AppTextStyles.bodySmall),
                        ],
                        if (schedule.isManualOverride) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.edit_note_rounded, size: 14, color: AppColors.accentGold),
                          const SizedBox(width: 2),
                          Text('override', style: AppTextStyles.bodySmall.copyWith(color: AppColors.accentGold)),
                        ],
                      ],
                    ),
                    if (schedule.autoReassignedAt != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.sync_alt_rounded, size: 14, color: AppColors.warningAmber),
                          const SizedBox(width: 4),
                          Text(
                            'Auto-reassigned from ${schedule.autoReassignedFromName ?? 'previous worker'}',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.warningAmber, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.textHint),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
