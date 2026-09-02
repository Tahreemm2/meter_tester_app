// =============================================================================
// FILE: lib/features/inspection/screens/recent_inspections_screen.dart
// PURPOSE: Read-only activity view over previously submitted inspections —
// consumes GET /api/data.php?action=inspections-list. Each row surfaces the
// Approval Workflow outcome (spec 3.10) — Pending Approval / Approved /
// Rejected — and, since a REJECTED submission's linked task is reopened
// server-side (see approvals.php), a rejected row offers "Inspect Again"
// right from the list, in addition to the same action inside the full
// InspectionDetailScreen (which also shows the reviewer's remarks).
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/logout_action.dart';
import '../data/inspection_repository.dart';
import '../bloc/inspection_summary_model.dart';
import 'inspection_detail_screen.dart';
import 'inspection_form_screen.dart';

class RecentInspectionsScreen extends StatefulWidget {
  final UserModel currentUser;

  const RecentInspectionsScreen({super.key, required this.currentUser});

  @override
  State<RecentInspectionsScreen> createState() => _RecentInspectionsScreenState();
}

class _RecentInspectionsScreenState extends State<RecentInspectionsScreen> {
  final InspectionRepository _repo = ApiInspectionRepository();

  bool _isLoading = true;
  String? _error;
  List<InspectionSummary> _items = [];

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
      final items = await _repo.fetchRecentInspections(widget.currentUser.token, limit: 50);
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('ApiException(null, null): ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _openDetail(InspectionSummary item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InspectionDetailScreen(
          token: widget.currentUser.token,
          inspectionId: item.id,
          currentUser: widget.currentUser,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _inspectAgain(InspectionSummary item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InspectionFormScreen(
          initialReferenceNumber: item.referenceNumber,
          taskId: item.taskId,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(title: const Text('Recent Inspections'), actions: const [LogoutAction()]),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: _load,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 64),
          Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 32),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.errorRed), textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 96),
          Center(child: Text('No inspections submitted yet.', style: AppTextStyles.bodySmall)),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _items.length,
      itemBuilder: (context, index) => _InspectionTile(
        item: _items[index],
        onTap: () => _openDetail(_items[index]),
        onInspectAgain: () => _inspectAgain(_items[index]),
      ),
    );
  }
}

class _InspectionTile extends StatelessWidget {
  final InspectionSummary item;
  final VoidCallback onTap;
  final VoidCallback onInspectAgain;
  const _InspectionTile({required this.item, required this.onTap, required this.onInspectAgain});

  @override
  Widget build(BuildContext context) {
    final isRejected = item.overallStatus == 'REJECTED';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(item.referenceNumber,
                        style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryGreen, fontSize: 13)),
                  ),
                  Text(_formatDate(item.inspectionDatetime), style: AppTextStyles.bodySmall),
                ],
              ),
              const SizedBox(height: 4),
              Text(item.consumerAccount, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 6),
              if (item.overallStatus != null) _StatusBadge(status: item.overallStatus!),
              const SizedBox(height: 6),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: 2,
                children: [
                  if (item.kwh != null) _Metric(label: 'kWh', value: item.kwh!),
                  if (item.kvarh != null) _Metric(label: 'kVARh', value: item.kvarh!),
                  if (item.mdi != null) _Metric(label: 'MDI', value: item.mdi!),
                ],
              ),
              const SizedBox(height: 6),
              Text('Submitted by ${item.submittedBy}', style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
              if (isRejected) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.replay_rounded, size: 16),
                    label: const Text('Inspect Again'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryGreen),
                    onPressed: onInspectAgain,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _color {
    switch (status.toUpperCase()) {
      case 'APPROVED':         return AppColors.successGreen;
      case 'REJECTED':         return AppColors.errorRed;
      case 'PENDING_APPROVAL': return AppColors.accentGold;
      default:                 return AppColors.textHint;
    }
  }

  String get _label {
    switch (status.toUpperCase()) {
      case 'APPROVED':         return 'Approved';
      case 'REJECTED':         return 'Rejected';
      case 'PENDING_APPROVAL': return 'Pending Approval';
      default:                 return status;
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
      child: Text(_label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _color)),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final double value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text('$label: ${value.toStringAsFixed(1)}', style: AppTextStyles.bodySmall);
  }
}
