// =============================================================================
// FILE: lib/features/dashboard/screens/dashboard_screen.dart
// PURPOSE: Dashboard & Analytics (GET /api/dashboard.php). Supervisory roles
// only (SDO/XEN/SE/ADMIN) — reachable from the home shell for accessLevel
// >= 1. Shows quarter summary totals, the Approval Workflow pipeline,
// discrepancy trends, and field-team performance, filterable by quarter and
// consumer category.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/scope_defaults.dart';
import '../../../core/widgets/logout_action.dart';
import '../../admin/widgets/admin_widgets.dart';
import '../../scheduling/models/schedule_models.dart' show kConsumerCategories;
import '../data/dashboard_repository.dart';
import '../models/dashboard_models.dart';
import '../widgets/dashboard_widgets.dart';

class DashboardScreen extends StatefulWidget {
  final UserModel currentUser;
  const DashboardScreen({super.key, required this.currentUser});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardRepository _repo = ApiDashboardRepository(token: widget.currentUser.token);

  DashboardData? _data;
  bool _isLoading = true;
  String? _error;
  late String _quarter = _currentQuarter();
  String? _categoryFilter;

  // SDO/XEN are always scoped to their own sub-division/division (see
  // scope_defaults.dart) — this is not user-editable, per the workflow spec.
  late final ScopeDefaults _scope = ScopeDefaults.forUser(widget.currentUser);

  static String _currentQuarter() {
    final now = DateTime.now();
    final q = ((now.month - 1) ~/ 3) + 1;
    return '${now.year}-Q$q';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _repo.getDashboard(
        quarter: _quarter,
        category: _categoryFilter,
        division: _scope.division,
        subDivision: _scope.subDivision,
      );
      setState(() {
        _data = data;
        _quarter = data.quarter; // normalize in case the server adjusted it
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('ApiException(null, null): ', '');
        _isLoading = false;
      });
    }
  }

  void _onQuarterChanged(String q) {
    setState(() => _quarter = q);
    _load();
  }

  void _onCategoryChanged(String? category) {
    setState(() => _categoryFilter = category);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(title: const Text(AppStrings.dashboardTitle), actions: const [LogoutAction()]),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              QuarterSelector(quarter: _quarter, onChanged: _onQuarterChanged),
              if (_scope.division != null || _scope.subDivision != null) ...[
                const SizedBox(height: 2),
                Center(
                  child: Text(
                    'Showing data for ${_scope.subDivision ?? _scope.division}',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _CategoryFilterBar(selected: _categoryFilter, onChanged: _onCategoryChanged),
              const SizedBox(height: AppSpacing.md),
              AdminListState(
                isLoading: _isLoading,
                errorMessage: _error,
                isEmpty: false,
                onRetry: () => _load(),
              ),
              if (!_isLoading && _error == null && _data != null) ..._buildContent(_data!),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContent(DashboardData data) {
    final summary = data.summary;
    return [
      Text(AppStrings.dashboardSummaryTitle, style: AppTextStyles.headingMedium.copyWith(fontSize: 16)),
      const SizedBox(height: AppSpacing.sm),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.5,
        children: [
          StatCard(
            label: 'Meters Tested',
            value: '${summary.totalMetersTested}',
            icon: Icons.speed_outlined,
            color: AppColors.primaryGreen,
          ),
          StatCard(
            label: 'Pending Inspections',
            value: '${summary.pendingInspections}',
            icon: Icons.pending_actions_outlined,
            color: AppColors.accentGold,
          ),
          StatCard(
            label: 'Total Scheduled',
            value: '${summary.totalScheduled}',
            icon: Icons.event_note_outlined,
            color: AppColors.primaryGreenLight,
          ),
          StatCard(
            label: 'Completion Rate',
            value: summary.completionRatePct != null ? '${summary.completionRatePct!.toStringAsFixed(0)}%' : '—',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.successGreen,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      DashboardSectionCard(
        title: AppStrings.dashboardPipelineTitle,
        child: ApprovalPipelineBar(pipeline: data.approvalPipeline),
      ),
      const SizedBox(height: AppSpacing.lg),
      DashboardSectionCard(
        title: AppStrings.dashboardTrendsTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('By Type', style: AppTextStyles.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            BarRowList(
              entries: data.discrepancyTrends.byType,
              emptyMessage: AppStrings.dashboardEmptyTrends,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('By Severity', style: AppTextStyles.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            BarRowList(
              entries: data.discrepancyTrends.bySeverity,
              emptyMessage: AppStrings.dashboardEmptyTrends,
              color: AppColors.errorRed,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('By Month', style: AppTextStyles.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            BarRowList(
              entries: data.discrepancyTrends.byMonth,
              emptyMessage: AppStrings.dashboardEmptyTrends,
              color: AppColors.accentGold,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('${data.discrepancyTrends.totalOpen} still open', style: AppTextStyles.bodySmall),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      DashboardSectionCard(
        title: AppStrings.dashboardTeamTitle,
        child: data.teamPerformance.isEmpty
            ? Text(AppStrings.dashboardEmptyTeam, style: AppTextStyles.bodySmall)
            : Column(
                children: [
                  for (final entry in data.teamPerformance) ...[
                    TeamPerformanceTile(entry: entry),
                    if (entry != data.teamPerformance.last) const Divider(height: 1, color: AppColors.borderSubtle),
                  ],
                ],
              ),
      ),
    ];
  }
}

class _CategoryFilterBar extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;
  const _CategoryFilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: const Text('All Categories'),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
              selectedColor: AppColors.primaryGreenSurface,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected == null ? AppColors.primaryGreen : AppColors.textSecondary,
              ),
              backgroundColor: AppColors.surfaceCard,
              side: BorderSide(color: selected == null ? AppColors.primaryGreen : AppColors.borderSubtle),
            ),
          ),
          ...kConsumerCategories.map((cat) {
            final isSelected = selected == cat;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                onSelected: (_) => onChanged(isSelected ? null : cat),
                selectedColor: AppColors.accentGoldLight,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.accentGold : AppColors.textSecondary,
                ),
                backgroundColor: AppColors.surfaceCard,
                side: BorderSide(color: isSelected ? AppColors.accentGold : AppColors.borderSubtle),
              ),
            );
          }),
        ],
      ),
    );
  }
}
