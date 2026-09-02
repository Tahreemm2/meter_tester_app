// =============================================================================
// FILE: lib/features/alerts/screens/inspection_notifications_screen.dart
// PURPOSE: The M&T side of the Approval Workflow feedback loop (spec 3.10).
// A meter tester's Recent Inspections / Inspection Detail screens already
// show a live status badge (Pending Approval / Approved / Rejected) whenever
// they reopen the app, but they had no way to be TOLD the moment an
// SDO/XEN/SE actually decided — this screen is that: a feed of
// GET /api/alerts.php rows (type=INSPECTION_DECISION, always scoped
// server-side to this user's own recipient_user_id — see api/alerts.php),
// one row per decision, newest/unread first. Tapping a row marks it read
// (POST /api/alerts.php?action=mark-read) and opens the inspection itself,
// where a rejected one shows the "Inspect Again" button.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/logout_action.dart';
import '../../admin/widgets/admin_widgets.dart';
import '../data/alerts_repository.dart';
import '../models/alert_models.dart';
import '../../inspection/screens/inspection_detail_screen.dart';

class InspectionNotificationsScreen extends StatefulWidget {
  final UserModel currentUser;
  const InspectionNotificationsScreen({super.key, required this.currentUser});

  @override
  State<InspectionNotificationsScreen> createState() => _InspectionNotificationsScreenState();
}

class _InspectionNotificationsScreenState extends State<InspectionNotificationsScreen> {
  late final AlertsRepository _repo = ApiAlertsRepository(token: widget.currentUser.token);

  List<AppAlert> _notifications = [];
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
      // alerts.php already scopes an M&T caller to their own
      // INSPECTION_DECISION rows only — no client-side filtering needed.
      final notifications = await _repo.fetchAlerts();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('ApiException(null, null): ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _openNotification(AppAlert alert) async {
    if (!alert.isRead) {
      // Optimistic — flip locally first so the tap feels instant; a failure
      // here just means it stays unread until the next _load(), not worth
      // interrupting navigation for.
      setState(() {
        _notifications = _notifications.map((n) => n.id == alert.id ? n.copyWith(isRead: true) : n).toList();
      });
      _repo.markRead(alert.id).catchError((_) {});
    }

    final inspectionId = alert.inspectionId;
    if (inspectionId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InspectionDetailScreen(
          token: widget.currentUser.token,
          inspectionId: inspectionId,
          currentUser: widget.currentUser,
        ),
      ),
    );
    // The inspection may have just been re-submitted via "Inspect Again" —
    // refresh so a stale row doesn't linger at the top of the feed.
    if (mounted) _load();
  }

  Color _colorFor(AppAlert alert) {
    switch (alert.inspectionOverallStatus) {
      case 'APPROVED':
        return AppColors.successGreen;
      case 'REJECTED':
        return AppColors.errorRed;
      default:
        return AppColors.accentGold; // forwarded to the next level, still pending
    }
  }

  IconData _iconFor(AppAlert alert) {
    switch (alert.inspectionOverallStatus) {
      case 'APPROVED':
        return Icons.check_circle_outline_rounded;
      case 'REJECTED':
        return Icons.cancel_outlined;
      default:
        return Icons.forward_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(
        title: Text(unreadCount > 0 ? 'Notifications ($unreadCount new)' : 'Notifications'),
        actions: const [LogoutAction()],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              AdminListState(isLoading: _isLoading, errorMessage: _error, isEmpty: false, onRetry: _load),
              if (!_isLoading && _error == null)
                if (_notifications.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xl),
                    child: Center(
                      child: Text(
                        'No decisions on your submitted inspections yet.',
                        style: AppTextStyles.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ..._notifications.map((n) => _NotificationTile(
                        alert: n,
                        color: _colorFor(n),
                        icon: _iconFor(n),
                        onTap: () => _openNotification(n),
                      )),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppAlert alert;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _NotificationTile({required this.alert, required this.color, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRead = alert.isRead;
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
            border: Border.all(color: color.withOpacity(isRead ? 0.15 : 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!isRead) ...[
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          alert.levelLabel,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (alert.referenceNumber.isNotEmpty || alert.consumerName.isNotEmpty)
                      Text(
                        [alert.referenceNumber, alert.consumerName].where((s) => s.isNotEmpty).join(' · '),
                        style: AppTextStyles.labelLarge.copyWith(
                          color: isRead ? AppColors.textSecondary : AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(alert.message, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
