// =============================================================================
// FILE: lib/features/discrepancies/screens/discrepancy_detail_screen.dart
// PURPOSE: View a discrepancy report; supervisory roles can triage it
// (PUT /api/discrepancies.php?id=). Mirrors VALID_DISCREPANCY_STATUSES.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/id_picker_fields.dart';
import '../../admin/widgets/admin_widgets.dart';
import '../../auth/widgets/auth_widgets.dart';
import '../data/discrepancies_repository.dart';
import '../models/discrepancy_models.dart';
import '../widgets/discrepancy_widgets.dart';

class DiscrepancyDetailScreen extends StatefulWidget {
  final UserModel currentUser;
  final DiscrepancyReport report;

  const DiscrepancyDetailScreen({super.key, required this.currentUser, required this.report});

  @override
  State<DiscrepancyDetailScreen> createState() => _DiscrepancyDetailScreenState();
}

class _DiscrepancyDetailScreenState extends State<DiscrepancyDetailScreen> {
  late final DiscrepanciesRepository _repo = ApiDiscrepanciesRepository(token: widget.currentUser.token);
  late DiscrepancyReport _report = widget.report;
  late final bool _isSupervisor = widget.currentUser.role.accessLevel >= 1;
  bool _isBusy = false;
  String? _error;
  bool _changed = false;

  Future<void> _setStatus(String status) async {
    String? notes;
    if (status == 'RESOLVED' || status == 'DISMISSED') {
      notes = await _promptResolutionNotes();
      if (notes == null) return; // cancelled
    }

    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await _repo.triageDiscrepancy(
        _report.id,
        status: status,
        resolutionNotes: (notes != null && notes.isNotEmpty) ? notes : null,
      );
      final updated = await _repo.getDiscrepancy(_report.id);
      setState(() {
        _report = updated;
        _changed = true;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _assignWorker() async {
    final selectedId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card))),
      builder: (sheetContext) {
        int? picked = _report.assignedToUserId;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.lg,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assign M&T Worker', style: AppTextStyles.headingMedium),
                const SizedBox(height: AppSpacing.md),
                UserIdField(
                  currentUser: widget.currentUser,
                  label: 'Assign To',
                  roleFilter: 'MT',
                  onChanged: (id) => setSheetState(() => picked = id),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Confirm',
                  onPressed: picked == null ? null : () => Navigator.of(sheetContext).pop(picked),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selectedId == null) return; // cancelled

    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await _repo.triageDiscrepancy(_report.id, assignedToUserId: selectedId);
      final updated = await _repo.getDiscrepancy(_report.id);
      setState(() {
        _report = updated;
        _changed = true;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<String?> _promptResolutionNotes() async {
    final ctrl = TextEditingController(text: _report.resolutionNotes ?? '');
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resolution Notes', style: AppTextStyles.headingMedium),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Notes (optional)',
              hint: 'Explain the outcome...',
              controller: ctrl,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Confirm',
              onPressed: () => Navigator.of(sheetContext).pop(ctrl.text.trim()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(
        title: const Text('Discrepancy Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(_changed),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                  Expanded(child: Text(_report.type.discrepancyTypeLabel, style: AppTextStyles.headingMedium)),
                  SeverityBadge(severity: _report.severity),
                  const SizedBox(width: 6),
                  DiscrepancyStatusBadge(status: _report.status),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _InfoCard(report: _report),
              const SizedBox(height: AppSpacing.xl),
              if (_isSupervisor && _report.status != DiscrepancyStatus.resolved && _report.status != DiscrepancyStatus.dismissed) ...[
                Text('Triage', style: AppTextStyles.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                      onPressed: _isBusy ? null : _assignWorker,
                      label: Text(_report.assignedToUserId == null ? 'Assign M&T Worker' : 'Reassign'),
                    ),
                    if (_report.status == DiscrepancyStatus.open)
                      OutlinedButton(
                        onPressed: _isBusy ? null : () => _setStatus('UNDER_REVIEW'),
                        child: const Text('Mark Under Review'),
                      ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.successGreen),
                      onPressed: _isBusy ? null : () => _setStatus('RESOLVED'),
                      child: const Text('Resolve'),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.errorRed)),
                      onPressed: _isBusy ? null : () => _setStatus('DISMISSED'),
                      child: const Text('Dismiss', style: TextStyle(color: AppColors.errorRed)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final DiscrepancyReport report;
  const _InfoCard({required this.report});

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
          _row('Description', report.description),
          if (report.consumerName != null) ...[
            const SectionDivider(),
            _row('Consumer', '${report.referenceNumber ?? ''} — ${report.consumerName}'),
          ],
          const SectionDivider(),
          _row('Reported By', report.reportedByName),
          const SectionDivider(),
          _row('Assigned To', report.assignedToName ?? 'Unassigned'),
          if (report.resolvedByName != null) ...[
            const SectionDivider(),
            _row('Resolved By', report.resolvedByName!),
          ],
          if (report.resolutionNotes != null && report.resolutionNotes!.isNotEmpty) ...[
            const SectionDivider(),
            _row('Resolution Notes', report.resolutionNotes!),
          ],
          if (report.photoEvidenceUrl != null) ...[
            const SectionDivider(),
            _row('Photo Evidence', 'Attached'),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Image.network(
                report.photoEvidenceUrl!,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
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
            SizedBox(width: 120, child: Text(label, style: AppTextStyles.labelLarge)),
            Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
          ],
        ),
      );
}
