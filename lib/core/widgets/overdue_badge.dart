// =============================================================================
// FILE: lib/core/widgets/overdue_badge.dart
// PURPOSE: Small red pill flagging a schedule entry or task as overdue —
// still open, but past its scheduled/due date. Shared by the Task Assignment
// and Meter Scheduling features (see TaskAssignment.isOverdue and
// ScheduleEntry.isOverdue), which both implement the workflow spec's
// "Delayed inspections" / "Alerts when inspections are overdue" requirement
// as a pure client-side date check.
// =============================================================================

import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class OverdueBadge extends StatelessWidget {
  const OverdueBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.errorRed.withOpacity(0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.errorRed),
          SizedBox(width: 3),
          Text('Overdue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.errorRed)),
        ],
      ),
    );
  }
}
