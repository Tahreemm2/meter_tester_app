// =============================================================================
// FILE: lib/features/admin/screens/admin_home_screen.dart
// PURPOSE: Landing screen for the Admin Panel module (visible only to ADMIN
// role users — see home_shell_screen.dart's module grid).
//
// ADMIN no longer sees the operational modules (Tasks, Discrepancies,
// Inventory, Reports, Scheduling, Approvals, Analytics, Alerts) as separate
// top-level tiles on the Home screen — home_shell_screen.dart hides those
// for the ADMIN role specifically, and they live here instead, alongside
// the three admin-only management areas that mirror the backend's
// admin/*.php endpoints (Users, Consumer/Meter records, Form Options).
// This mirrors the pattern already used for SDO — see sdo_home_screen.dart's
// "Quick Access" grid.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/logout_action.dart';
import '../widgets/admin_widgets.dart';
import 'users_list_screen.dart';
import 'consumers_list_screen.dart';
import 'form_options_screen.dart';
import '../../tasks/screens/tasks_list_screen.dart';
import '../../discrepancies/screens/discrepancies_list_screen.dart';
import '../../inspection/screens/recent_inspections_screen.dart';
import '../../scheduling/screens/schedules_list_screen.dart';
import '../../approvals/screens/approvals_list_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../sdo/screens/sdo_alerts_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  final UserModel currentUser;

  const AdminHomeScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(title: const Text(AppStrings.adminPanelTitle), actions: const [LogoutAction()]),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // ── Operational modules ──────────────────────────────────────
            Text(
              'Modules',
              style: AppTextStyles.headingMedium.copyWith(fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ModulesQuickAccessGrid(currentUser: currentUser),
            const SizedBox(height: AppSpacing.xl),

            // ── Administration ───────────────────────────────────────────
            Text(
              'Administration',
              style: AppTextStyles.headingMedium.copyWith(fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.sm),
            AdminSectionCard(
              icon: Icons.people_outline_rounded,
              title: AppStrings.adminUsersTitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UsersListScreen(token: currentUser.token, currentUsername: currentUser.username),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AdminSectionCard(
              icon: Icons.electric_meter_outlined,
              title: AppStrings.adminConsumersTitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ConsumersListScreen(token: currentUser.token)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AdminSectionCard(
              icon: Icons.tune_rounded,
              title: AppStrings.adminFormOptionsTitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => FormOptionsScreen(token: currentUser.token)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// WIDGET: Modules quick-access grid
// Same tile pattern as SdoHomeScreen's "Quick Access" grid, so both
// supervisory roles feel consistent.
// =============================================================================
class _ModuleQuickAccessItem {
  final IconData icon;
  final String label;
  final WidgetBuilder? builder; // null = coming soon
  const _ModuleQuickAccessItem({required this.icon, required this.label, this.builder});
}

class _ModulesQuickAccessGrid extends StatelessWidget {
  final UserModel currentUser;
  const _ModulesQuickAccessGrid({required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final items = <_ModuleQuickAccessItem>[
      _ModuleQuickAccessItem(
        icon: Icons.assignment_turned_in_outlined,
        label: AppStrings.moduleTasks,
        builder: (_) => TasksListScreen(currentUser: currentUser),
      ),
      _ModuleQuickAccessItem(
        icon: Icons.report_problem_outlined,
        label: AppStrings.moduleDiscrepancies,
        builder: (_) => DiscrepanciesListScreen(currentUser: currentUser),
      ),
      _ModuleQuickAccessItem(
        icon: Icons.bar_chart_outlined,
        label: AppStrings.moduleReports,
        builder: (_) => RecentInspectionsScreen(currentUser: currentUser),
      ),
      _ModuleQuickAccessItem(
        icon: Icons.event_note_outlined,
        label: AppStrings.moduleScheduling,
        builder: (_) => SchedulesListScreen(currentUser: currentUser),
      ),
      _ModuleQuickAccessItem(
        icon: Icons.task_alt_outlined,
        label: AppStrings.moduleApprovals,
        builder: (_) => ApprovalsListScreen(currentUser: currentUser),
      ),
      _ModuleQuickAccessItem(
        icon: Icons.insights_outlined,
        label: AppStrings.moduleDashboard,
        builder: (_) => DashboardScreen(currentUser: currentUser),
      ),
      _ModuleQuickAccessItem(
        icon: Icons.notifications_active_outlined,
        label: AppStrings.moduleAlerts,
        builder: (_) => SdoAlertsScreen(currentUser: currentUser),
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
        final isActive = item.builder != null;
        return Material(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: isActive
                ? () => Navigator.of(context).push(MaterialPageRoute(builder: item.builder!))
                : () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${item.label}: ${AppStrings.moduleComingSoon}',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.white),
                        ),
                        backgroundColor: AppColors.primaryGreen,
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                      ),
                    ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: isActive ? null : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, size: 28, color: isActive ? AppColors.primaryGreen : AppColors.textHint),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.label,
                    style: AppTextStyles.labelLarge.copyWith(
                      fontSize: 12,
                      color: isActive ? AppColors.textPrimary : AppColors.textHint,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
