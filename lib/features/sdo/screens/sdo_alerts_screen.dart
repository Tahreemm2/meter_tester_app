// =============================================================================
// FILE: lib/features/sdo/screens/sdo_alerts_screen.dart
// PURPOSE: SDO spec item 6 — "Alerts for inspections delayed beyond the
// allowed period, new discrepancy notifications, and relevant system
// alerts."
//
// Backed by GET /api/alerts.php, which merges two notification types into
// one feed:
//   - ESCALATION: "if an inspection is not completed within one month, an
//     alert/report is sent to the SDO. If it remains unresolved, it is
//     escalated to the XEN and then the SE." Level-gated server-side (an
//     SDO only ever receives level-1 rows).
//   - DISCREPANCY: fired the moment a new discrepancy is reported, visible
//     to every supervisory role in scope (not level-gated).
// Both are also scoped server-side by division/sub-division, so no
// client-side filtering is needed here — whatever comes back IS this
// user's notification feed. Tapping one marks it read via
// POST /api/alerts.php?action=mark-read.
//
// The "Open Discrepancies" section below is a separate, complementary
// source — a standing list of everything still unresolved (from
// GET /api/discrepancies.php), vs. the dismissible "something just
// happened" notifications above.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/scope_defaults.dart';
import '../../../core/widgets/logout_action.dart';
import '../../admin/widgets/admin_widgets.dart';
import '../../alerts/data/alerts_repository.dart';
import '../../alerts/models/alert_models.dart';
import '../../discrepancies/data/discrepancies_repository.dart';
import '../../discrepancies/models/discrepancy_models.dart';

class SdoAlertsScreen extends StatefulWidget {
  final UserModel currentUser;
  const SdoAlertsScreen({super.key, required this.currentUser});

  @override
  State<SdoAlertsScreen> createState() => _SdoAlertsScreenState();
}

class _SdoAlertsScreenState extends State<SdoAlertsScreen> {
  late final AlertsRepository _alertsRepo = ApiAlertsRepository(token: widget.currentUser.token);
  late final DiscrepanciesRepository _discrepancyRepo = ApiDiscrepanciesRepository(token: widget.currentUser.token);
  late final ScopeDefaults _scope = ScopeDefaults.forUser(widget.currentUser);

  List<AppAlert> _alerts = [];
  List<DiscrepancyReport> _openDiscrepancies = [];
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
      // alerts.php is already fully scoped server-side (role -> escalation
      // level, division/sub-division) — a single call is all this needs.
      final alerts = await _alertsRepo.fetchAlerts();

      final discrepancyMerged = mergeAcrossSubDivisions<DiscrepancyReport>(
        _scope,
        fetchOne: (sd) async {
          final page = await _discrepancyRepo.listDiscrepancies(status: 'OPEN', subDivision: sd, page: 1, perPage: 50);
          return page.items;
        },
      );
      final openDiscrepancies = discrepancyMerged != null
          ? await discrepancyMerged
          : (await _discrepancyRepo.listDiscrepancies(
              status: 'OPEN',
              division: _scope.division,
              subDivision: _scope.subDivision,
              page: 1,
              perPage: 50,
            ))
              .items;

      setState(() {
        _alerts = alerts;
        _openDiscrepancies = openDiscrepancies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('ApiException(null, null): ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _markRead(AppAlert alert) async {
    // Optimistic — flip locally first so the tap feels instant.
    setState(() {
      _alerts = _alerts.map((a) => a.id == alert.id ? a.copyWith(isRead: true) : a).toList();
    });
    try {
      await _alertsRepo.markRead(alert.id);
    } catch (_) {
      // Best-effort — a stale is_read flag isn't worth interrupting the
      // user; the next full _load() reconciles it either way.
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _alerts.where((a) => !a.isRead).length;
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(
        title: Text(unreadCount > 0 ? 'Alerts ($unreadCount new)' : 'Alerts'),
        actions: const [LogoutAction()],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              AdminListState(isLoading: _isLoading, errorMessage: _error, isEmpty: false, onRetry: () => _load()),
              if (!_isLoading && _error == null) ...[
                _SectionHeader(
                  icon: Icons.notifications_active_outlined,
                  color: AppColors.errorRed,
                  title: 'Notifications',
                  count: _alerts.length,
                ),
                if (_alerts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text('Nothing new right now.', style: AppTextStyles.bodySmall),
                  )
                else
                  ..._alerts.map((a) {
                    final isDiscrepancy = a.type == AlertType.discrepancy;
                    return _AlertTile(
                      title: a.consumerName,
                      subtitle: '${a.referenceNumber} · ${a.meterId} · ${a.message}',
                      trailing: isDiscrepancy ? a.levelLabel : '${a.daysOverdue} day${a.daysOverdue == 1 ? '' : 's'}',
                      color: isDiscrepancy ? AppColors.accentGold : AppColors.errorRed,
                      isRead: a.isRead,
                      onTap: a.isRead ? null : () => _markRead(a),
                    );
                  }),
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(
                  icon: Icons.report_problem_outlined,
                  color: AppColors.accentGold,
                  title: 'Open Discrepancies',
                  count: _openDiscrepancies.length,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_openDiscrepancies.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text('No open discrepancies.', style: AppTextStyles.bodySmall),
                  )
                else
                  ..._openDiscrepancies.map((d) => _AlertTile(
                        title: d.consumerName ?? d.referenceNumber ?? 'Unknown consumer',
                        subtitle: d.type.discrepancyTypeLabel,
                        trailing: d.severity,
                        color: AppColors.accentGold,
                        isRead: true,
                        onTap: null,
                      )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final int count;
  const _SectionHeader({required this.icon, required this.color, required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(title, style: AppTextStyles.headingMedium.copyWith(fontSize: 15)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(AppRadius.chip)),
            child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

/// [isRead] dims the tile and [onTap] (null when already read/not
/// applicable) marks it read on tap — matches a standard notification-list
/// affordance.
class _AlertTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  final Color color;
  final bool isRead;
  final VoidCallback? onTap;
  const _AlertTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.color,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isRead ? AppColors.surfaceCard.withOpacity(0.6) : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: color.withOpacity(isRead ? 0.15 : 0.3)),
          ),
          child: Row(
            children: [
              if (!isRead) ...[
                Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: isRead ? AppColors.textSecondary : AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    Text(subtitle, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              Text(trailing, style: AppTextStyles.bodySmall.copyWith(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
