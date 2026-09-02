// =============================================================================
// FILE: lib/features/sdo/screens/sdo_home_screen.dart
// PURPOSE: SDO spec item 1 — "Dashboard Overview": meters scheduled, meters
// inspected, pending/overdue inspections, discrepancies, completion %, and
// recent alerts — plus quick navigation into every other SDO spec item
// (Inspection Management, Discrepancies, Worker Monitoring, Schedule,
// Alerts, Reports, Profile). This is what the home shell's "Dashboard" tile
// opens for an SDO specifically (XEN/SE/ADMIN keep the general
// DashboardScreen) — see home_shell_screen.dart's role-conditional route.
//
// Approval Workflow (3.10): when an M&T field worker submits an inspection
// (POST /api/data.php?action=inspection-submit), it lands directly in this
// SDO's own review queue at approval level 1 — GET /api/dashboard.php
// already returns that count as approval_pipeline.pending_sdo, so it's
// surfaced here as a stat card, and the "Approvals" quick-access tile below
// opens ApprovalsListScreen (GET/POST /api/approvals.php) where the SDO can
// actually Approve or Reject it.
//
// Every number here is pulled through ScopeDefaults (sub-division-only, not
// user-editable) — see scope_defaults.dart for why and how "the SDO
// supervises one or more sub-divisions" is handled.
//
// "Total meters in the sub-division" isn't something any current endpoint
// exposes to a non-admin (only /api/admin/consumers.php has the full
// consumer roster, and that's ADMIN-only) — so this shows "meters scheduled
// this quarter" instead, which is the closest honest proxy available today.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/scope_defaults.dart';
import '../../../core/widgets/logout_action.dart';
import '../../admin/widgets/admin_widgets.dart';
import '../../approvals/screens/approvals_list_screen.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../dashboard/widgets/dashboard_widgets.dart';
import '../../discrepancies/data/discrepancies_repository.dart';
import '../../discrepancies/models/discrepancy_models.dart';
import '../../discrepancies/screens/discrepancies_list_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../scheduling/data/scheduling_repository.dart';
import '../../scheduling/models/schedule_models.dart';
import '../../scheduling/screens/schedules_list_screen.dart';
import 'sdo_alerts_screen.dart';
import 'sdo_inspections_screen.dart';
import 'sdo_reports_screen.dart';
import 'worker_monitoring_screen.dart';

class SdoHomeScreen extends StatefulWidget {
  final UserModel currentUser;
  const SdoHomeScreen({super.key, required this.currentUser});

  @override
  State<SdoHomeScreen> createState() => _SdoHomeScreenState();
}

class _SdoHomeScreenState extends State<SdoHomeScreen> {
  late final DashboardRepository _dashboardRepo = ApiDashboardRepository(token: widget.currentUser.token);
  late final SchedulingRepository _scheduleRepo = ApiSchedulingRepository(token: widget.currentUser.token);
  late final DiscrepanciesRepository _discrepancyRepo = ApiDiscrepanciesRepository(token: widget.currentUser.token);
  late final ScopeDefaults _scope = ScopeDefaults.forUser(widget.currentUser);

  DashboardData? _dashboard;
  int _overdueCount = 0;
  int _openDiscrepancyCount = 0;
  bool _isLoading = true;
  String? _error;

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
      final dashboardFuture = _scope.isMultiSubDivision
          ? Future.wait(_scope.subDivisions.map((sd) => _dashboardRepo.getDashboard(subDivision: sd)))
              .then(DashboardData.merge)
          : _dashboardRepo.getDashboard(division: _scope.division, subDivision: _scope.subDivision);

      final scheduleMerge = mergeAcrossSubDivisions<ScheduleEntry>(
        _scope,
        fetchOne: (sd) async {
          final page = await _scheduleRepo.listSchedules(subDivision: sd, page: 1, perPage: 300);
          return page.items;
        },
      );
      final schedulesFuture = scheduleMerge ??
          _scheduleRepo
              .listSchedules(division: _scope.division, subDivision: _scope.subDivision, page: 1, perPage: 300)
              .then((p) => p.items);

      final discrepancyMerged = mergeAcrossSubDivisions<DiscrepancyReport>(
        _scope,
        fetchOne: (sd) async {
          final page = await _discrepancyRepo.listDiscrepancies(status: 'OPEN', subDivision: sd, page: 1, perPage: 300);
          return page.items;
        },
      );
      final discrepancyFuture = discrepancyMerged != null
          ? discrepancyMerged.then((items) => items.length)
          : _discrepancyRepo
              .listDiscrepancies(
                status: 'OPEN',
                division: _scope.division,
                subDivision: _scope.subDivision,
                page: 1,
                perPage: 1,
              )
              .then((page) => page.total);

      final results = await Future.wait([dashboardFuture, schedulesFuture, discrepancyFuture]);
      final dashboard = results[0] as DashboardData;
      final schedules = results[1] as List<ScheduleEntry>;
      final openDiscrepancyCount = results[2] as int;

      setState(() {
        _dashboard = dashboard;
        _overdueCount = schedules.where((s) => s.isOverdue).length;
        _openDiscrepancyCount = openDiscrepancyCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('ApiException(null, null): ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(
        title: const Text('Sub-Division Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProfileScreen(currentUser: widget.currentUser)),
            ),
          ),
          const LogoutAction(),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(_scope.label ?? widget.currentUser.scopeName, style: AppTextStyles.bodySmall),
              const SizedBox(height: AppSpacing.md),
              AdminListState(isLoading: _isLoading, errorMessage: _error, isEmpty: false, onRetry: () => _load()),
              if (!_isLoading && _error == null && _dashboard != null) ..._buildOverview(_dashboard!),
              const SizedBox(height: AppSpacing.lg),
              Text('Quick Access', style: AppTextStyles.headingMedium.copyWith(fontSize: 16)),
              const SizedBox(height: AppSpacing.sm),
              _buildQuickAccessGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOverview(DashboardData data) {
    return [
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.5,
        children: [
          StatCard(
            label: 'Meters Scheduled (Qtr)',
            value: '${data.summary.totalScheduled}',
            icon: Icons.event_note_outlined,
            color: AppColors.primaryGreenLight,
          ),
          StatCard(
            label: 'Inspected This Quarter',
            value: '${data.summary.totalMetersTested}',
            icon: Icons.speed_outlined,
            color: AppColors.primaryGreen,
          ),
          StatCard(
            label: 'Pending Inspections',
            value: '${data.summary.pendingInspections}',
            icon: Icons.pending_actions_outlined,
            color: AppColors.accentGold,
          ),
          StatCard(
            label: 'Awaiting My Approval',
            value: '${data.approvalPipeline.pendingSdo}',
            icon: Icons.fact_check_outlined,
            color: AppColors.accentGold,
          ),
          StatCard(
            label: 'Overdue Inspections',
            value: '$_overdueCount',
            icon: Icons.warning_amber_rounded,
            color: AppColors.errorRed,
          ),
          StatCard(
            label: 'Open Discrepancies',
            value: '$_openDiscrepancyCount',
            icon: Icons.report_problem_outlined,
            color: AppColors.accentGold,
          ),
          StatCard(
            label: 'Completion Rate',
            value: data.summary.completionRatePct != null ? '${data.summary.completionRatePct!.toStringAsFixed(0)}%' : '—',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.successGreen,
          ),
        ],
      ),
    ];
  }

  Widget _buildQuickAccessGrid(BuildContext context) {
    final pendingApprovalCount = _dashboard?.approvalPipeline.pendingSdo ?? 0;
    final items = <_QuickAccessItem>[
      _QuickAccessItem(
        icon: Icons.task_alt_outlined,
        label: 'Approvals',
        builder: (_) => ApprovalsListScreen(currentUser: widget.currentUser),
        badgeCount: pendingApprovalCount,
      ),
      _QuickAccessItem(
        icon: Icons.fact_check_outlined,
        label: 'Inspections',
        builder: (_) => SdoInspectionsScreen(currentUser: widget.currentUser),
      ),
      _QuickAccessItem(
        icon: Icons.report_problem_outlined,
        label: 'Discrepancies',
        builder: (_) => DiscrepanciesListScreen(currentUser: widget.currentUser),
      ),
      _QuickAccessItem(
        icon: Icons.groups_outlined,
        label: 'Workers',
        builder: (_) => WorkerMonitoringScreen(currentUser: widget.currentUser),
      ),
      _QuickAccessItem(
        icon: Icons.event_note_outlined,
        label: 'Schedule',
        builder: (_) => SchedulesListScreen(currentUser: widget.currentUser),
      ),
      _QuickAccessItem(
        icon: Icons.notifications_active_outlined,
        label: 'Alerts',
        builder: (_) => SdoAlertsScreen(currentUser: widget.currentUser),
        badgeCount: _overdueCount + _openDiscrepancyCount,
      ),
      _QuickAccessItem(
        icon: Icons.bar_chart_outlined,
        label: 'Reports',
        builder: (_) => SdoReportsScreen(currentUser: widget.currentUser),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.95,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Material(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: item.builder)),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(item.icon, size: 28, color: AppColors.primaryGreen),
                      if (item.badgeCount != null && item.badgeCount! > 0)
                        Positioned(
                          right: -6,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.errorRed, borderRadius: BorderRadius.circular(8)),
                            child: Text('${item.badgeCount}', style: const TextStyle(fontSize: 9, color: AppColors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(item.label, style: AppTextStyles.labelLarge.copyWith(fontSize: 12), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuickAccessItem {
  final IconData icon;
  final String label;
  final Widget Function(BuildContext) builder;
  final int? badgeCount;
  const _QuickAccessItem({required this.icon, required this.label, required this.builder, this.badgeCount});
}
