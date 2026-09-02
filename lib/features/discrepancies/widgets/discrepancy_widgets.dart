// =============================================================================
// FILE: lib/features/discrepancies/widgets/discrepancy_widgets.dart
// PURPOSE: Shared UI pieces for the Discrepancy Reporting feature.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../models/discrepancy_models.dart';

class DiscrepancyStatusBadge extends StatelessWidget {
  final DiscrepancyStatus status;
  const DiscrepancyStatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case DiscrepancyStatus.open:         return AppColors.errorRed;
      case DiscrepancyStatus.underReview:  return AppColors.accentGold;
      case DiscrepancyStatus.resolved:     return AppColors.successGreen;
      case DiscrepancyStatus.dismissed:    return AppColors.textHint;
      case DiscrepancyStatus.unknown:      return AppColors.textHint;
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

class SeverityBadge extends StatelessWidget {
  final String severity;
  const SeverityBadge({super.key, required this.severity});

  Color get _color {
    switch (severity.toUpperCase()) {
      case 'CRITICAL': return AppColors.errorRed;
      case 'HIGH':      return const Color(0xFFD9822B);
      case 'MEDIUM':    return AppColors.accentGold;
      case 'LOW':       return AppColors.textHint;
      default:          return AppColors.textHint;
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
        severity.isEmpty ? '—' : '${severity[0]}${severity.substring(1).toLowerCase()}',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _color),
      ),
    );
  }
}

class DiscrepancyTile extends StatelessWidget {
  final DiscrepancyReport report;
  final VoidCallback? onTap;

  const DiscrepancyTile({super.key, required this.report, this.onTap});

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
                      report.type.discrepancyTypeLabel,
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary, fontSize: 15),
                    ),
                  ),
                  SeverityBadge(severity: report.severity),
                  const SizedBox(width: 6),
                  DiscrepancyStatusBadge(status: report.status),
                ],
              ),
              const SizedBox(height: 4),
              if (report.consumerName != null)
                Text('${report.referenceNumber ?? ''} · ${report.consumerName}', style: AppTextStyles.bodySmall),
              const SizedBox(height: 6),
              Text(
                report.description,
                style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text('Reported by ${report.reportedByName}', style: AppTextStyles.bodySmall),
                ],
              ),
              if (report.assignedToName != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.engineering_outlined, size: 14, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text('Assigned to ${report.assignedToName}', style: AppTextStyles.bodySmall),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DiscrepancyFilterBar extends StatelessWidget {
  final String? selectedStatus;
  final ValueChanged<String?> onChanged;

  const DiscrepancyFilterBar({super.key, required this.selectedStatus, required this.onChanged});

  static const _options = <String?, String>{
    null: 'All',
    'OPEN': 'Open',
    'UNDER_REVIEW': 'Under Review',
    'RESOLVED': 'Resolved',
    'DISMISSED': 'Dismissed',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _options.entries.map((entry) {
          final isSelected = selectedStatus == entry.key;
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
