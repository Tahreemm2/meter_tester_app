// =============================================================================
// FILE: lib/features/approvals/screens/approval_detail_screen.dart
// PURPOSE: View a single inspection's readings + full decision history, and
// (if the caller's role matches the currently-pending level, or the caller
// is ADMIN) approve or reject it. Mirrors the PUT ?action=decide rules in
// backend/api/approvals.php.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_exception.dart';
import '../../admin/widgets/admin_widgets.dart';
import '../../auth/widgets/auth_widgets.dart';
import '../../inspection/screens/inspection_detail_screen.dart';
import '../data/approvals_repository.dart';
import '../models/approval_models.dart';
import '../widgets/approval_widgets.dart';

class ApprovalDetailScreen extends StatefulWidget {
  final UserModel currentUser;
  final InspectionApproval approval;

  const ApprovalDetailScreen({super.key, required this.currentUser, required this.approval});

  @override
  State<ApprovalDetailScreen> createState() => _ApprovalDetailScreenState();
}

class _ApprovalDetailScreenState extends State<ApprovalDetailScreen> {
  late final ApprovalsRepository _repo = ApiApprovalsRepository(token: widget.currentUser.token);
  InspectionApproval? _full; // re-fetched for full readings + history
  bool _isLoadingDetail = true;
  bool _isBusy = false;
  String? _error;
  bool _changed = false;

  bool get _isAdmin => widget.currentUser.role.code == 'ADMIN';

  /// True if the caller may decide this inspection right now.
  bool _canDecide(InspectionApproval a) {
    if (a.overallStatus != ApprovalOverallStatus.pendingApproval) return false;
    if (_isAdmin) return true;
    return widget.currentUser.role.code == a.pendingRole;
  }

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoadingDetail = true);
    try {
      final full = await _repo.getApproval(widget.approval.id);
      setState(() {
        _full = full;
        _isLoadingDetail = false;
      });
    } catch (e) {
      setState(() {
        _full = widget.approval; // fall back to what we already have (no history)
        _isLoadingDetail = false;
      });
    }
  }

  Future<void> _decide(String decision) async {
    final isApprove = decision == 'APPROVE';
    final remarksCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text(isApprove ? AppStrings.approvalsApprove : AppStrings.approvalsReject, style: AppTextStyles.headingMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isApprove ? AppStrings.approvalsConfirmApprove : AppStrings.approvalsConfirmReject,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Remarks (optional)',
              hint: AppStrings.approvalsRemarksHint,
              controller: remarksCtrl,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.adminCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? AppColors.successGreen : AppColors.errorRed,
              minimumSize: const Size(80, 40),
            ),
            child: Text(
              isApprove ? AppStrings.approvalsApprove : AppStrings.approvalsReject,
              style: AppTextStyles.buttonLabel.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await _repo.decide(widget.approval.id, decision: decision, remarks: remarksCtrl.text.trim());
      setState(() => _changed = true);
      if (!mounted) return;
      showAdminSnack(context, isApprove ? 'Approved.' : 'Rejected.');
      await _loadDetail();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final approval = _full ?? widget.approval;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundPage,
        appBar: AppBar(
          title: const Text('Inspection Review'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
        ),
        body: SafeArea(
          child: _isLoadingDetail
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null) ...[
                        ErrorBanner(message: _error!),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              approval.consumerName?.isNotEmpty == true ? approval.consumerName! : approval.referenceNumber,
                              style: AppTextStyles.headingMedium,
                            ),
                          ),
                          if (approval.overallStatus == ApprovalOverallStatus.pendingApproval)
                            PendingLevelBadge(level: approval.currentApprovalLevel)
                          else
                            ApprovalStatusBadge(status: approval.overallStatus),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _ReadingsCard(approval: approval),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: const Text('View GPS, Condition & Images'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          side: const BorderSide(color: AppColors.primaryGreen),
                          foregroundColor: AppColors.primaryGreen,
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => InspectionDetailScreen(
                              token: widget.currentUser.token,
                              inspectionId: approval.id,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (approval.history.isNotEmpty) ...[
                        Text(AppStrings.approvalsHistoryTitle, style: AppTextStyles.headingMedium.copyWith(fontSize: 16)),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Column(
                            children: [
                              for (final entry in approval.history) ...[
                                ApprovalHistoryTile(entry: entry),
                                if (entry != approval.history.last) const SectionDivider(),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                      if (approval.overallStatus == ApprovalOverallStatus.pendingApproval) ...[
                        if (_canDecide(approval)) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.errorRed),
                                  label: const Text(AppStrings.approvalsReject, style: TextStyle(color: AppColors.errorRed)),
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.errorRed)),
                                  onPressed: _isBusy ? null : () => _decide('REJECT'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                                  label: const Text(AppStrings.approvalsApprove),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.successGreen),
                                  onPressed: _isBusy ? null : () => _decide('APPROVE'),
                                ),
                              ),
                            ],
                          ),
                        ] else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(AppRadius.card),
                            ),
                            child: Text(
                              AppStrings.approvalsNotYourLevel,
                              style: AppTextStyles.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _ReadingsCard extends StatelessWidget {
  final InspectionApproval approval;
  const _ReadingsCard({required this.approval});

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
        children: [
          _row('Reference #', approval.referenceNumber),
          const SectionDivider(),
          _row('Meter ID', approval.meterId),
          const SectionDivider(),
          _row('Consumer Account', approval.consumerAccount),
          const SectionDivider(),
          _row('kWh', approval.kwh.toStringAsFixed(2)),
          const SectionDivider(),
          _row('kVArh', approval.kvarh.toStringAsFixed(2)),
          const SectionDivider(),
          _row('MDI', approval.mdi.toStringAsFixed(2)),
          if (approval.division != null) ...[
            const SectionDivider(),
            _row('Division', approval.division!),
          ],
          if (approval.category != null) ...[
            const SectionDivider(),
            _row('Category', approval.category!),
          ],
          const SectionDivider(),
          _row('Submitted By', approval.submittedByName),
          if (approval.createdAt != null) ...[
            const SectionDivider(),
            _row('Submitted At', approval.createdAt!),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: Text(label, style: AppTextStyles.labelLarge)),
            Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
          ],
        ),
      );
}
