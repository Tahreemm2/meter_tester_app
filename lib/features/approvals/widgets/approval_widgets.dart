// =============================================================================
// FILE: lib/features/approvals/widgets/approval_widgets.dart
// PURPOSE: Shared UI pieces for the Approval Workflow feature.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../models/approval_models.dart';

/// Small colored pill showing an inspection's overall approval status.
class ApprovalStatusBadge extends StatelessWidget {
  final ApprovalOverallStatus status;
  const ApprovalStatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case ApprovalOverallStatus.pendingApproval: return AppColors.accentGold;
      case ApprovalOverallStatus.approved:         return AppColors.successGreen;
      case ApprovalOverallStatus.rejected:         return AppColors.errorRed;
      case ApprovalOverallStatus.unknown:          return AppColors.textHint;
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

/// Small pill showing which role (SDO/XEN/SE) an inspection is currently
/// waiting on. Hidden once the inspection is finalized (level 0).
class PendingLevelBadge extends StatelessWidget {
  final int level;
  const PendingLevelBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final role = roleForApprovalLevel(level);
    if (role == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryGreenSurface,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.4)),
      ),
      child: Text(
        'Awaiting $role',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryGreen),
      ),
    );
  }
}

/// A single inspection row card, used on the Approvals list screen.
class ApprovalTile extends StatelessWidget {
  final InspectionApproval approval;
  final VoidCallback? onTap;

  const ApprovalTile({super.key, required this.approval, this.onTap});

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
                      approval.consumerName?.isNotEmpty == true ? approval.consumerName! : approval.referenceNumber,
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (approval.overallStatus == ApprovalOverallStatus.pendingApproval)
                    PendingLevelBadge(level: approval.currentApprovalLevel)
                  else
                    ApprovalStatusBadge(status: approval.overallStatus),
                ],
              ),
              const SizedBox(height: 2),
              Text('${approval.referenceNumber} · ${approval.meterId}', style: AppTextStyles.bodySmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Submitted by ${approval.submittedByName}',
                      style: AppTextStyles.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (approval.category != null) ...[
                    const Icon(Icons.category_outlined, size: 14, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(approval.category!, style: AppTextStyles.bodySmall),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row of filter chips for approval status (Pending / Approved / Rejected).
class ApprovalStatusFilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const ApprovalStatusFilterBar({super.key, required this.selected, required this.onChanged});

  static const _options = <String, String>{
    'PENDING': 'Pending',
    'APPROVED': 'Approved',
    'REJECTED': 'Rejected',
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

/// One row in the decision-history timeline shown on the detail screen.
class ApprovalHistoryTile extends StatelessWidget {
  final ApprovalHistoryEntry entry;
  const ApprovalHistoryTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final isApproved = entry.action == 'APPROVED';
    final color = isApproved ? AppColors.successGreen : AppColors.errorRed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isApproved ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
            size: 20,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.roleCode} · ${entry.action == 'APPROVED' ? 'Approved' : 'Rejected'}',
                  style: AppTextStyles.labelLarge.copyWith(color: color, fontSize: 13),
                ),
                Text(entry.approverName, style: AppTextStyles.bodySmall),
                if (entry.remarks != null && entry.remarks!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      entry.remarks!,
                      style: AppTextStyles.bodySmall.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          if (entry.createdAt != null)
            Text(entry.createdAt!.split(' ').first, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
