// =============================================================================
// FILE: lib/features/dashboard/models/dashboard_models.dart
// PURPOSE: Data models for the Dashboard & Analytics feature. Mirrors the
// JSON shape returned by backend/api/dashboard.php (see API.md "Dashboard &
// Analytics").
// =============================================================================

class DashboardSummary {
  final int totalScheduled;
  final int totalMetersTested;
  final int pendingInspections;
  final int completedSchedules;
  final double? completionRatePct;

  const DashboardSummary({
    required this.totalScheduled,
    required this.totalMetersTested,
    required this.pendingInspections,
    required this.completedSchedules,
    this.completionRatePct,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
        totalScheduled:     (json['total_scheduled'] as num?)?.toInt() ?? 0,
        totalMetersTested:  (json['total_meters_tested'] as num?)?.toInt() ?? 0,
        pendingInspections: (json['pending_inspections'] as num?)?.toInt() ?? 0,
        completedSchedules: (json['completed_schedules'] as num?)?.toInt() ?? 0,
        completionRatePct:  (json['completion_rate_pct'] as num?)?.toDouble(),
      );
}

class ApprovalPipelineCounts {
  final int pendingSdo;
  final int pendingXen;
  final int pendingSe;
  final int approved;
  final int rejected;

  const ApprovalPipelineCounts({
    required this.pendingSdo,
    required this.pendingXen,
    required this.pendingSe,
    required this.approved,
    required this.rejected,
  });

  int get totalPending => pendingSdo + pendingXen + pendingSe;

  factory ApprovalPipelineCounts.fromJson(Map<String, dynamic> json) => ApprovalPipelineCounts(
        pendingSdo: (json['pending_sdo'] as num?)?.toInt() ?? 0,
        pendingXen: (json['pending_xen'] as num?)?.toInt() ?? 0,
        pendingSe:  (json['pending_se'] as num?)?.toInt() ?? 0,
        approved:   (json['approved'] as num?)?.toInt() ?? 0,
        rejected:   (json['rejected'] as num?)?.toInt() ?? 0,
      );
}

/// A single labeled count, used for the "by type" / "by severity" / "by
/// month" discrepancy breakdowns — each entry's key column name varies
/// (type/severity/month) so this is intentionally generic.
class LabeledCount {
  final String label;
  final int count;
  const LabeledCount({required this.label, required this.count});

  factory LabeledCount.fromJson(Map<String, dynamic> json, String labelKey) => LabeledCount(
        label: json[labelKey] as String? ?? '—',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

class DiscrepancyTrends {
  final List<LabeledCount> byType;
  final List<LabeledCount> bySeverity;
  final List<LabeledCount> byMonth;
  final int totalOpen;

  const DiscrepancyTrends({
    required this.byType,
    required this.bySeverity,
    required this.byMonth,
    required this.totalOpen,
  });

  factory DiscrepancyTrends.fromJson(Map<String, dynamic> json) => DiscrepancyTrends(
        byType: (json['by_type'] as List? ?? [])
            .map((e) => LabeledCount.fromJson(e as Map<String, dynamic>, 'type'))
            .toList(),
        bySeverity: (json['by_severity'] as List? ?? [])
            .map((e) => LabeledCount.fromJson(e as Map<String, dynamic>, 'severity'))
            .toList(),
        byMonth: (json['by_month'] as List? ?? [])
            .map((e) => LabeledCount.fromJson(e as Map<String, dynamic>, 'month'))
            .toList(),
        totalOpen: (json['total_open'] as num?)?.toInt() ?? 0,
      );
}

class TeamPerformanceEntry {
  final int userId;
  final String fullName;
  final String? scopeName;
  final int assignedCount;
  final int completedCount;
  final double? completionRatePct;
  final double? avgCompletionHours;

  const TeamPerformanceEntry({
    required this.userId,
    required this.fullName,
    this.scopeName,
    required this.assignedCount,
    required this.completedCount,
    this.completionRatePct,
    this.avgCompletionHours,
  });

  factory TeamPerformanceEntry.fromJson(Map<String, dynamic> json) => TeamPerformanceEntry(
        userId:             (json['user_id'] as num).toInt(),
        fullName:           json['full_name'] as String? ?? '',
        scopeName:          json['scope_name'] as String?,
        assignedCount:      (json['assigned_count'] as num?)?.toInt() ?? 0,
        completedCount:     (json['completed_count'] as num?)?.toInt() ?? 0,
        completionRatePct:  (json['completion_rate_pct'] as num?)?.toDouble(),
        avgCompletionHours: (json['avg_completion_hours'] as num?)?.toDouble(),
      );
}

class DashboardData {
  final String quarter;
  final String? division;
  final String? subDivision;
  final String? category;
  final DashboardSummary summary;
  final ApprovalPipelineCounts approvalPipeline;
  final DiscrepancyTrends discrepancyTrends;
  final List<TeamPerformanceEntry> teamPerformance;

  const DashboardData({
    required this.quarter,
    this.division,
    this.subDivision,
    this.category,
    required this.summary,
    required this.approvalPipeline,
    required this.discrepancyTrends,
    required this.teamPerformance,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final filters = json['filters'] as Map<String, dynamic>? ?? {};
    return DashboardData(
      quarter:     json['quarter'] as String? ?? '',
      division:    filters['division'] as String?,
      subDivision: filters['sub_division'] as String?,
      category:    filters['category'] as String?,
      summary:            DashboardSummary.fromJson(json['summary'] as Map<String, dynamic>? ?? {}),
      approvalPipeline:   ApprovalPipelineCounts.fromJson(json['approval_pipeline'] as Map<String, dynamic>? ?? {}),
      discrepancyTrends:  DiscrepancyTrends.fromJson(json['discrepancy_trends'] as Map<String, dynamic>? ?? {}),
      teamPerformance: (json['team_performance'] as List? ?? [])
          .map((e) => TeamPerformanceEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Combines one DashboardData per sub-division (from a multi-sub-division
  /// SDO's Future.wait fetch — see mergeAcrossSubDivisions in
  /// scope_defaults.dart) into a single view: counts summed, rate fields
  /// averaged, discrepancy breakdowns summed by matching label, team
  /// performance lists concatenated (each sub-division's workers are
  /// distinct people, so no de-duplication needed).
  factory DashboardData.merge(List<DashboardData> parts) {
    if (parts.isEmpty) {
      return const DashboardData(
        quarter: '',
        summary: DashboardSummary(totalScheduled: 0, totalMetersTested: 0, pendingInspections: 0, completedSchedules: 0),
        approvalPipeline: ApprovalPipelineCounts(pendingSdo: 0, pendingXen: 0, pendingSe: 0, approved: 0, rejected: 0),
        discrepancyTrends: DiscrepancyTrends(byType: [], bySeverity: [], byMonth: [], totalOpen: 0),
        teamPerformance: [],
      );
    }
    if (parts.length == 1) return parts.first;

    int sumInt(int Function(DashboardData) select) => parts.fold(0, (acc, p) => acc + select(p));

    double? averagePct(double? Function(DashboardData) select) {
      final values = parts.map(select).whereType<double>().toList();
      if (values.isEmpty) return null;
      return values.reduce((a, b) => a + b) / values.length;
    }

    List<LabeledCount> mergeLabeledCounts(List<List<LabeledCount>> lists) {
      final totals = <String, int>{};
      final order = <String>[];
      for (final list in lists) {
        for (final entry in list) {
          if (!totals.containsKey(entry.label)) order.add(entry.label);
          totals[entry.label] = (totals[entry.label] ?? 0) + entry.count;
        }
      }
      return order.map((label) => LabeledCount(label: label, count: totals[label]!)).toList();
    }

    return DashboardData(
      quarter: parts.first.quarter,
      division: parts.first.division,
      subDivision: null, // spans multiple sub-divisions — no single value applies
      category: parts.first.category,
      summary: DashboardSummary(
        totalScheduled: sumInt((p) => p.summary.totalScheduled),
        totalMetersTested: sumInt((p) => p.summary.totalMetersTested),
        pendingInspections: sumInt((p) => p.summary.pendingInspections),
        completedSchedules: sumInt((p) => p.summary.completedSchedules),
        completionRatePct: averagePct((p) => p.summary.completionRatePct),
      ),
      approvalPipeline: ApprovalPipelineCounts(
        pendingSdo: sumInt((p) => p.approvalPipeline.pendingSdo),
        pendingXen: sumInt((p) => p.approvalPipeline.pendingXen),
        pendingSe: sumInt((p) => p.approvalPipeline.pendingSe),
        approved: sumInt((p) => p.approvalPipeline.approved),
        rejected: sumInt((p) => p.approvalPipeline.rejected),
      ),
      discrepancyTrends: DiscrepancyTrends(
        byType: mergeLabeledCounts(parts.map((p) => p.discrepancyTrends.byType).toList()),
        bySeverity: mergeLabeledCounts(parts.map((p) => p.discrepancyTrends.bySeverity).toList()),
        byMonth: mergeLabeledCounts(parts.map((p) => p.discrepancyTrends.byMonth).toList()),
        totalOpen: sumInt((p) => p.discrepancyTrends.totalOpen),
      ),
      teamPerformance: parts.expand((p) => p.teamPerformance).toList(),
    );
  }
}
