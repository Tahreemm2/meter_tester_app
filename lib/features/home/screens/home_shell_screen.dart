// =============================================================================
// FILE: lib/features/home/screens/home_shell_screen.dart
// PURPOSE: Screen 3 — Home Shell / Dashboard
//
// This is the landing screen after successful authentication.
// It demonstrates:
//   1. Role-based greeting and scope display
//   2. Placeholder module tiles (future feature screens)
//   3. Logout with confirmation dialog
//
// All module tiles are role-filtered placeholders. Replace the module grid
// with actual navigation as features are built.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/logout_action.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/widgets/auth_widgets.dart';
import '../../inspection/screens/inspection_form_screen.dart';
import '../../inspection/screens/recent_inspections_screen.dart';
import '../../admin/screens/admin_home_screen.dart';
import '../../tasks/screens/tasks_list_screen.dart';
import '../../discrepancies/screens/discrepancies_list_screen.dart';
import '../../scheduling/screens/schedules_list_screen.dart';
import '../../approvals/screens/approvals_list_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../sdo/screens/sdo_alerts_screen.dart';
import '../../alerts/screens/inspection_notifications_screen.dart';
import '../../sdo/screens/sdo_home_screen.dart';
import '../../profile/screens/profile_screen.dart';

class HomeShellScreen extends StatelessWidget {
  const HomeShellScreen({super.key});

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // On logout, navigate back to root (login screen)
        if (state is AuthUnauthenticated) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          // Guard: ensure we have an authenticated user
          if (state is! AuthAuthenticated) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = state.user;

          return Scaffold(
            backgroundColor: AppColors.backgroundPage,
            appBar: _buildAppBar(context, user),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Role Proof Banner ──────────────────────────────
                    _RoleProofBanner(user: user),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Welcome Header ─────────────────────────────────
                    _WelcomeHeader(user: user),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Session Details Card ───────────────────────────
                    _SessionDetailsCard(user: user),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Module Grid ────────────────────────────────────
                    Text(
                      'Available Modules',
                      style: AppTextStyles.headingMedium.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ModuleGrid(user: user),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  AppBar _buildAppBar(BuildContext context, UserModel user) {
    return AppBar(
      title: const Text(AppStrings.homeTitle),
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.person_outline_rounded, size: 20),
          tooltip: 'Profile',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProfileScreen(currentUser: user)),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, size: 20),
          tooltip: AppStrings.homeLogoutButton,
          onPressed: () => confirmLogout(context),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

}

// =============================================================================
// WIDGET: Role Proof Banner
// Proves the UI successfully captured the role and geographic scope.
// This is the primary deliverable of the role-based routing requirement.
// =============================================================================
class _RoleProofBanner extends StatelessWidget {
  final UserModel user;

  const _RoleProofBanner({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryGreenSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.primaryGreen.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Proof header
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: AppColors.primaryGreen,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Session Active',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.primaryGreen,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // ────────────────────────────────────────────────────────────
          // PRIMARY PROOF TEXT — This is the required placeholder output
          // ────────────────────────────────────────────────────────────
          RichText(
            text: TextSpan(
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primaryGreen,
                height: 1.7,
              ),
              children: [
                TextSpan(
                  text: '${AppStrings.homeLoggedInAs} ',
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),
                TextSpan(
                  text: user.role.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const TextSpan(text: '  |  '),
                TextSpan(
                  text: '${AppStrings.homeRegionLabel} ',
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),
                TextSpan(
                  text: user.scopeName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WIDGET: Welcome Header
// =============================================================================
class _WelcomeHeader extends StatelessWidget {
  final UserModel user;

  const _WelcomeHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppStrings.homeWelcome} ${user.fullName}',
                style: AppTextStyles.headingMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                user.employeeId,
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        RoleChip(label: user.role.code),
      ],
    );
  }
}

// =============================================================================
// WIDGET: Session Details Card
// Displays full breakdown of role, scope, and access level.
// =============================================================================
class _SessionDetailsCard extends StatelessWidget {
  final UserModel user;

  const _SessionDetailsCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.person_outline_rounded,
            label: AppStrings.homeRoleLabel,
            value: user.role.displayName,
          ),
          const SectionDivider(),
          _DetailRow(
            icon: Icons.map_outlined,
            label: AppStrings.homeScopeLabel,
            value: '${user.scope.displayLabel} — ${user.scopeName}',
          ),
          const SectionDivider(),
          _DetailRow(
            icon: Icons.security_outlined,
            label: 'Access Level:',
            value: 'Level ${user.role.accessLevel} / 4',
            valueStyle: AppTextStyles.bodyMedium.copyWith(
              color: _accessLevelColor(user.role.accessLevel),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SectionDivider(),
          _DetailRow(
            icon: Icons.badge_outlined,
            label: 'Employee ID:',
            value: user.employeeId,
          ),
        ],
      ),
    );
  }

  Color _accessLevelColor(int level) {
    switch (level) {
      case 0: return AppColors.textSecondary;
      case 1: return AppColors.primaryGreenLight;
      case 2: return AppColors.primaryGreen;
      case 3: return AppColors.primaryGreen;
      case 4: return AppColors.accentGold;
      default: return AppColors.textHint;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textHint),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 110,
          child: Text(label, style: AppTextStyles.labelLarge),
        ),
        Expanded(
          child: Text(
            value,
            style: valueStyle ?? AppTextStyles.bodyMedium,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// WIDGET: Module Grid
// Placeholder tiles for future feature modules.
// Role-filtered: only modules relevant to the user's access level are shown.
// =============================================================================

/// Module descriptor — expand this list as features are built.
class _ModuleDescriptor {
  final String title;
  final IconData icon;
  final int minAccessLevel; // Minimum role level required to see this module
  final bool isActive;      // false = coming soon
  final Widget Function(BuildContext, UserModel)? routeBuilder; // null = coming soon
  final Set<String> excludeRoleCodes; // role codes that already reach this elsewhere, so hide the duplicate tile

  const _ModuleDescriptor({
    required this.title,
    required this.icon,
    required this.minAccessLevel,
    this.isActive = false,
    this.routeBuilder,
    this.excludeRoleCodes = const {},
  });
}

const List<_ModuleDescriptor> _allModules = [
  _ModuleDescriptor(
    title: AppStrings.moduleTests,
    icon: Icons.speed_outlined,
    minAccessLevel: 0,
    isActive: true,
    routeBuilder: _inspectionRoute,
    // Field inspection is M&T's job per the SRS — SDO/XEN/SE/ADMIN monitor,
    // assign, and approve inspections but don't perform them themselves.
    // (Enforced server-side too — see the role check on
    // action=inspection-submit in api/data.php.)
    excludeRoleCodes: {'SDO', 'XEN', 'SE', 'ADMIN'},
  ),
  _ModuleDescriptor(
    title: AppStrings.moduleTasks,
    icon: Icons.assignment_turned_in_outlined,
    minAccessLevel: 0, // All roles — field team see their own tasks, supervisors see + assign all
    isActive: true,
    routeBuilder: _tasksRoute,
    // ADMIN gets this inside the consolidated Admin Panel instead (see
    // admin_home_screen.dart's "Modules" grid) — no duplicate top-level tile.
    excludeRoleCodes: {'ADMIN'},
  ),
  _ModuleDescriptor(
    title: AppStrings.moduleDiscrepancies,
    icon: Icons.report_problem_outlined,
    minAccessLevel: 0, // All roles — anyone can report, supervisors triage
    isActive: true,
    routeBuilder: _discrepanciesRoute,
    // ADMIN: consolidated into Admin Panel. SDO: already in SdoHomeScreen's
    // own Quick Access grid (opened via the Analytics tile below).
    excludeRoleCodes: {'ADMIN', 'SDO'},
  ),
  _ModuleDescriptor(
    title: AppStrings.moduleInventory,
    icon: Icons.inventory_2_outlined,
    minAccessLevel: 0,
    isActive: false,
    // ADMIN: consolidated into Admin Panel (still "Coming Soon" there too).
    // SDO: not part of their dashboard either — hidden until it's built.
    excludeRoleCodes: {'ADMIN', 'SDO'},
  ),
  _ModuleDescriptor(
    title: AppStrings.moduleReports,
    icon: Icons.bar_chart_outlined,
    minAccessLevel: 1,
    isActive: true,
    routeBuilder: _reportsRoute,
    excludeRoleCodes: {'ADMIN', 'SDO'},
  ),
  _ModuleDescriptor(
    title: AppStrings.moduleScheduling,
    icon: Icons.event_note_outlined,
    minAccessLevel: 1, // Supervisory roles only (SDO/XEN/SE/ADMIN)
    isActive: true,
    routeBuilder: _schedulingRoute,
    excludeRoleCodes: {'ADMIN', 'SDO'},
  ),
  _ModuleDescriptor(
    title: AppStrings.moduleApprovals,
    icon: Icons.task_alt_outlined,
    minAccessLevel: 1, // Supervisory roles only (SDO/XEN/SE/ADMIN) — SDO->XEN->SE review chain
    isActive: true,
    routeBuilder: _approvalsRoute,
    excludeRoleCodes: {'ADMIN', 'SDO'},
  ),
  _ModuleDescriptor(
    title: AppStrings.moduleDashboard,
    icon: Icons.insights_outlined,
    minAccessLevel: 1, // Supervisory roles only
    isActive: true,
    routeBuilder: _dashboardRoute,
    // ADMIN: consolidated into Admin Panel. SDO keeps this one — it's their
    // entry point into SdoHomeScreen itself, not a duplicate.
    excludeRoleCodes: {'ADMIN'},
  ),
  _ModuleDescriptor(
    title: AppStrings.moduleAlerts,
    icon: Icons.notifications_active_outlined,
    // Supervisory roles: the SDO/XEN/SE escalation chain (spec 3.9), routed
    // to SdoAlertsScreen — despite the name its data source
    // (GET /api/alerts.php) is already scoped server-side per role (SDO
    // sees level-1 alerts, XEN level-2, SE level-3), so the same screen is
    // correct for every supervisory role, not just SDO.
    // M&T: the Approval Workflow feedback loop (spec 3.10) — routed instead
    // to InspectionNotificationsScreen, since alerts.php scopes an M&T
    // caller to their own INSPECTION_DECISION rows (an SDO/XEN/SE
    // approve/forward/reject on something they submitted), not the
    // escalation/discrepancy feed the other roles get.
    minAccessLevel: 0,
    isActive: true,
    routeBuilder: _alertsRoute,
    // SDO already has this nested under their Dashboard tile's own tab bar
    // (see sdo_home_screen.dart), and ADMIN gets it inside the consolidated
    // Admin Panel — don't show a second, redundant entry point for either.
    excludeRoleCodes: {'SDO', 'ADMIN'},
  ),
  _ModuleDescriptor(
    title: AppStrings.adminPanelTitle,
    icon: Icons.admin_panel_settings_outlined,
    minAccessLevel: 4, // ADMIN role only
    isActive: true,
    routeBuilder: _adminRoute,
  ),
];

// Route builder functions (top-level so they can be const)
Widget _inspectionRoute(BuildContext _, UserModel __) => const InspectionFormScreen();
Widget _reportsRoute(BuildContext _, UserModel user) => RecentInspectionsScreen(currentUser: user);
Widget _adminRoute(BuildContext _, UserModel user) => AdminHomeScreen(currentUser: user);
Widget _tasksRoute(BuildContext _, UserModel user) => TasksListScreen(currentUser: user);
Widget _discrepanciesRoute(BuildContext _, UserModel user) => DiscrepanciesListScreen(currentUser: user);
Widget _schedulingRoute(BuildContext _, UserModel user) => SchedulesListScreen(currentUser: user);
Widget _approvalsRoute(BuildContext _, UserModel user) => ApprovalsListScreen(currentUser: user);
Widget _dashboardRoute(BuildContext _, UserModel user) =>
    user.role.code == 'SDO' ? SdoHomeScreen(currentUser: user) : DashboardScreen(currentUser: user);
Widget _alertsRoute(BuildContext _, UserModel user) =>
    user.role.code == 'MT' ? InspectionNotificationsScreen(currentUser: user) : SdoAlertsScreen(currentUser: user);

class _ModuleGrid extends StatelessWidget {
  final UserModel user;

  const _ModuleGrid({required this.user});

  @override
  Widget build(BuildContext context) {
    // Filter modules by the user's access level
    final visibleModules = _allModules
        .where((m) => user.role.accessLevel >= m.minAccessLevel && !m.excludeRoleCodes.contains(user.role.code))
        .toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.2,
      ),
      itemCount: visibleModules.length,
      itemBuilder: (context, index) {
        return _ModuleTile(module: visibleModules[index], user: user);
      },
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final _ModuleDescriptor module;
  final UserModel user;

  const _ModuleTile({required this.module, required this.user});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: module.isActive && module.routeBuilder != null
        ? () => Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => module.routeBuilder!(ctx, user)))
        : () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${module.title}: ${AppStrings.moduleComingSoon}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.white),
                ),
                backgroundColor: AppColors.primaryGreen,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
              ),
            );
          },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: module.isActive ? AppColors.surfaceCard : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.borderSubtle, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              module.icon,
              size: 32,
              color: module.isActive
                ? AppColors.primaryGreen
                : AppColors.textHint,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              module.title,
              style: AppTextStyles.labelLarge.copyWith(
                color: module.isActive ? AppColors.textPrimary : AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
            if (!module.isActive) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Coming Soon',
                style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
