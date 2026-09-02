// =============================================================================
// FILE: lib/features/dashboard/widgets/dashboard_widgets.dart
// PURPOSE: Shared UI pieces for the Dashboard & Analytics feature. No chart
// package is in pubspec.yaml, so trends/pipeline are rendered as simple
// proportional bar rows built from core widgets — lightweight and consistent
// with the rest of the app's design tokens.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../models/dashboard_models.dart';

/// A single big-number stat tile, used in the summary grid.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primaryGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: AppTextStyles.headingMedium.copyWith(color: color, fontSize: 22)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// A titled card wrapper used for each dashboard section.
class DashboardSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const DashboardSectionCard({super.key, required this.title, required this.child});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.headingMedium.copyWith(fontSize: 16)),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// One row of a proportional bar chart: label, count, and a bar sized
/// relative to [maxCount].
class BarRow extends StatelessWidget {
  final String label;
  final int count;
  final int maxCount;
  final Color color;

  const BarRow({
    super.key,
    required this.label,
    required this.count,
    required this.maxCount,
    this.color = AppColors.primaryGreen,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxCount > 0 ? (count / maxCount).clamp(0.02, 1.0) : 0.02;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Container(height: 14, color: AppColors.surfaceMuted),
                    Container(
                      height: 14,
                      width: constraints.maxWidth * fraction,
                      color: color,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 28,
            child: Text('$count', style: AppTextStyles.labelLarge.copyWith(fontSize: 12), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

/// Renders a list of [LabeledCount] as bar rows, sized relative to the
/// largest count in the list. Shows [emptyMessage] when the list is empty.
class BarRowList extends StatelessWidget {
  final List<LabeledCount> entries;
  final Color color;
  final String emptyMessage;

  const BarRowList({
    super.key,
    required this.entries,
    required this.emptyMessage,
    this.color = AppColors.primaryGreen,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(emptyMessage, style: AppTextStyles.bodySmall),
      );
    }
    final maxCount = entries.map((e) => e.count).fold(0, (a, b) => a > b ? a : b);
    return Column(
      children: entries.map((e) => BarRow(label: e.label, count: e.count, maxCount: maxCount, color: color)).toList(),
    );
  }
}

/// Segmented horizontal bar for the approval pipeline (pending at each
/// level, approved, rejected) plus a small legend underneath.
class ApprovalPipelineBar extends StatelessWidget {
  final ApprovalPipelineCounts pipeline;
  const ApprovalPipelineBar({super.key, required this.pipeline});

  static const _segments = <String, Color>{
    'SDO': AppColors.accentGold,
    'XEN': AppColors.primaryGreenLight,
    'SE': AppColors.primaryGreen,
    'Approved': AppColors.successGreen,
    'Rejected': AppColors.errorRed,
  };

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{
      'SDO': pipeline.pendingSdo,
      'XEN': pipeline.pendingXen,
      'SE': pipeline.pendingSe,
      'Approved': pipeline.approved,
      'Rejected': pipeline.rejected,
    };
    final total = counts.values.fold(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total == 0)
          const Text('No inspections in the approval pipeline yet.', style: AppTextStyles.bodySmall)
        else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 20,
              child: Row(
                children: counts.entries
                    .where((e) => e.value > 0)
                    .map((e) => Expanded(
                          flex: e.value,
                          child: Container(color: _segments[e.key]),
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: counts.entries.map((e) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: _segments[e.key], shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('${e.key}: ${e.value}', style: AppTextStyles.bodySmall),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// One row in the team performance list.
class TeamPerformanceTile extends StatelessWidget {
  final TeamPerformanceEntry entry;
  const TeamPerformanceTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.fullName, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary, fontSize: 14)),
                if (entry.scopeName != null && entry.scopeName!.isNotEmpty)
                  Text(entry.scopeName!, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.completedCount}/${entry.assignedCount} done',
                style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
              ),
              if (entry.avgCompletionHours != null)
                Text(
                  '~${entry.avgCompletionHours!.toStringAsFixed(1)}h avg',
                  style: AppTextStyles.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Prev/Next quarter navigator shown at the top of the dashboard.
class QuarterSelector extends StatelessWidget {
  final String quarter;
  final ValueChanged<String> onChanged;

  const QuarterSelector({super.key, required this.quarter, required this.onChanged});

  /// Parses "YYYY-Qn" and shifts by [delta] quarters (can cross year boundaries).
  static String shift(String quarter, int delta) {
    final match = RegExp(r'^(\d{4})-Q([1-4])$').firstMatch(quarter);
    if (match == null) return quarter;
    var year = int.parse(match.group(1)!);
    var q = int.parse(match.group(2)!) + delta;
    while (q > 4) {
      q -= 4;
      year += 1;
    }
    while (q < 1) {
      q += 4;
      year -= 1;
    }
    return '$year-Q$q';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => onChanged(shift(quarter, -1)),
        ),
        Text(quarter, style: AppTextStyles.headingMedium.copyWith(fontSize: 16)),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () => onChanged(shift(quarter, 1)),
        ),
      ],
    );
  }
}
