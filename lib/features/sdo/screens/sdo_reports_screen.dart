// =============================================================================
// FILE: lib/features/sdo/screens/sdo_reports_screen.dart
// PURPOSE: SDO spec item 7 — "View/download capabilities (if permitted) for
// inspection reports, pending reports, discrepancy reports, and monthly
// progress reports." Per the workflow doc itself, "the exact report format
// is still pending from the client" and no PDF-generation endpoint exists on
// the backend — so this is a VIEW-only hub into the already-scoped data
// views, honestly labeled as such, rather than a fake "Download PDF" button
// that doesn't actually produce anything.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/logout_action.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../discrepancies/screens/discrepancies_list_screen.dart';
import 'sdo_inspections_screen.dart';

class SdoReportsScreen extends StatelessWidget {
  final UserModel currentUser;
  const SdoReportsScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(title: const Text('Reports'), actions: const [LogoutAction()]),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(color: AppColors.accentGoldLight, borderRadius: BorderRadius.circular(AppRadius.chip)),
              child: Text(
                'View-only for now — PDF export isn\'t available until the report format is finalized and a backend export endpoint is built.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.accentGold),
              ),
            ),
            _ReportCard(
              icon: Icons.fact_check_outlined,
              title: 'Inspection Reports',
              subtitle: 'All inspections in your sub-division',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SdoInspectionsScreen(currentUser: currentUser)),
              ),
            ),
            _ReportCard(
              icon: Icons.pending_actions_outlined,
              title: 'Pending Reports',
              subtitle: 'Inspections not yet completed',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SdoInspectionsScreen(currentUser: currentUser)),
              ),
            ),
            _ReportCard(
              icon: Icons.report_problem_outlined,
              title: 'Discrepancy Reports',
              subtitle: 'Theft, tampering, damage & other findings',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DiscrepanciesListScreen(currentUser: currentUser)),
              ),
            ),
            _ReportCard(
              icon: Icons.insights_outlined,
              title: 'Monthly Progress Report',
              subtitle: 'Completion rate, pipeline & trends',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DashboardScreen(currentUser: currentUser)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ReportCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

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
              Icon(icon, color: AppColors.primaryGreen, size: 24),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary, fontSize: 15)),
                    Text(subtitle, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
