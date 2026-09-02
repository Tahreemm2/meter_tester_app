// =============================================================================
// FILE: lib/features/inspection/screens/inspection_detail_screen.dart
// PURPOSE: Full inspection record — every reading, the GPS coordinate
// captured at submission time, equipment-condition codes, and the uploaded
// image gallery (tap to view full-screen). Backed by GET
// /api/data.php?action=inspection-detail&id= (see inspection_detail_model.dart).
//
// This is a shared screen: any supervisory role viewing an inspection within
// their scope can open it, whether from the SDO's Inspection Reports list
// (features/sdo/screens/sdo_inspections_screen.dart) or from an Approval
// Workflow review (features/approvals/screens/approval_detail_screen.dart).
//
// Approve/Reject (spec 3.10): when opened WITH a [currentUser] (the
// Inspection Reports entry point does this), and the inspection is still
// PENDING_APPROVAL at a level matching that user's role (or the caller is
// ADMIN), Approve/Reject buttons appear at the bottom, calling the same
// POST /api/approvals.php?action=decide used by ApprovalDetailScreen — so a
// meter tester's submitted report can be reviewed right from the report
// itself, not only from the separate Approvals queue. When opened WITHOUT a
// currentUser (e.g. ApprovalDetailScreen's own "View GPS, Condition &
// Images" link, which already owns its own decide flow one screen up), this
// stays read-only to avoid duplicate action buttons.
//
// Also loads two supplementary, read-only sections scoped to this one
// inspection: any Discrepancies reported against it (GET
// /api/discrepancies.php?inspection_id=) and its Approval History (GET
// /api/approvals.php?id=, which already returns the full decision trail —
// see approvals/models/approval_models.dart). Both are fetched alongside,
// not instead of, the main record, and a failure in either never blocks the
// rest of the report: approval history in particular 403s for a non-
// supervisory caller (e.g. the M&T viewing their own submission), which is
// expected and simply hides the section rather than showing an error.
//
// Nothing here is fabricated: every field/section only renders when the
// backend actually returned a value, and no map is shown because the
// project has no map-rendering package — GPS is shown as plain
// latitude/longitude/accuracy text per the SDO spec's "do not fabricate
// coordinates" instruction. There is no "observations" field anywhere in
// the inspections schema, so no Observations section is rendered either —
// adding one would mean inventing a field the backend doesn't return.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/widgets/auth_widgets.dart';
import '../../admin/widgets/admin_widgets.dart';
import '../../approvals/data/approvals_repository.dart';
import '../../approvals/models/approval_models.dart';
import '../../approvals/widgets/approval_widgets.dart';
import '../../discrepancies/data/discrepancies_repository.dart';
import '../../discrepancies/models/discrepancy_models.dart';
import '../../discrepancies/widgets/discrepancy_widgets.dart';
import '../bloc/inspection_detail_model.dart';
import '../data/inspection_repository.dart';
import 'inspection_form_screen.dart';

class InspectionDetailScreen extends StatefulWidget {
  final String token;
  final int inspectionId;
  // Optional: when provided, Approve/Reject actions render for this user if
  // they're allowed to decide the inspection right now — see file header.
  final UserModel? currentUser;

  const InspectionDetailScreen({
    super.key,
    required this.token,
    required this.inspectionId,
    this.currentUser,
  });

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> {
  final InspectionRepository _repo = ApiInspectionRepository();
  late final DiscrepanciesRepository _discrepanciesRepo = ApiDiscrepanciesRepository(token: widget.token);
  late final ApprovalsRepository _approvalsRepo = ApiApprovalsRepository(token: widget.token);

  InspectionDetail? _detail;
  bool _isLoading = true;
  String? _error;

  List<DiscrepancyReport> _discrepancies = [];
  bool _discrepanciesLoading = true;
  String? _discrepanciesError;

  InspectionApproval? _approval;
  bool _approvalLoading = true;
  // Left null (section just hidden) on a 403 — that only means the caller
  // isn't a supervisory role, not that something went wrong.
  String? _approvalError;

  bool _isDeciding = false;
  bool _decisionChanged = false;

  bool get _isAdmin => widget.currentUser?.role.code == 'ADMIN';

  /// True when this screen was opened by the M&T who submitted the
  /// inspection (as opposed to a supervisory reviewer, or read-only from
  /// ApprovalDetailScreen with no [currentUser] at all).
  bool get _isSubmittingFieldWorker =>
      widget.currentUser != null && widget.currentUser!.role.accessLevel == 0;

  /// Rejected inspections dead-end their linked task at COMPLETED unless
  /// the approvals API reopens it (see approvals.php REJECT handling) — once
  /// it does, this lets the submitter go straight back into the form
  /// instead of hunting for the task in their task list.
  bool get _canInspectAgain =>
      _isSubmittingFieldWorker && _detail?.overallStatus == 'REJECTED';

  /// True when this screen was opened read-only from ApprovalDetailScreen's
  /// "View GPS, Condition & Images" link (no currentUser passed — see file
  /// header). That caller already renders a _ReadingsCard with Reference #,
  /// Meter ID, Consumer Account, kWh/kVArh/MDI, Division, Category,
  /// Submitted By/At — so re-rendering "Consumer Information" and "Meter
  /// Information" here duplicated every one of those fields a second time
  /// on screen. Only skip them in that specific entry path; the standalone
  /// SDO Inspection Reports entry point (which always passes a currentUser)
  /// still needs the full record since nothing showed it beforehand.
  bool get _hideCallerDuplicatedSections => widget.currentUser == null;

  /// True if this screen was opened with a user who may decide this
  /// inspection's current approval level right now.
  bool get _canDecide {
    final user = widget.currentUser;
    final approval = _approval;
    if (user == null || approval == null) return false;
    if (approval.overallStatus != ApprovalOverallStatus.pendingApproval) return false;
    if (_isAdmin) return true;
    return user.role.code == approval.pendingRole;
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
      final detail = await _repo.getInspectionDetail(widget.token, widget.inspectionId);
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to load inspection. Please try again.';
        _isLoading = false;
      });
    }
    // Fired regardless of whether the main record load above succeeded —
    // independent, non-blocking sections.
    _loadDiscrepancies();
    _loadApprovalHistory();
  }

  Future<void> _loadDiscrepancies() async {
    setState(() {
      _discrepanciesLoading = true;
      _discrepanciesError = null;
    });
    try {
      final page = await _discrepanciesRepo.listDiscrepancies(
        inspectionId: widget.inspectionId,
        perPage: 50,
      );
      setState(() {
        _discrepancies = page.items;
        _discrepanciesLoading = false;
      });
    } catch (e) {
      setState(() {
        _discrepanciesError = 'Unable to load discrepancies for this inspection.';
        _discrepanciesLoading = false;
      });
    }
  }

  Future<void> _loadApprovalHistory() async {
    setState(() {
      _approvalLoading = true;
      _approvalError = null;
    });
    try {
      final approval = await _approvalsRepo.getApproval(widget.inspectionId);
      setState(() {
        _approval = approval;
        _approvalLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _approval = null;
        _approvalError = e.statusCode == 403 ? null : 'Unable to load approval history.';
        _approvalLoading = false;
      });
    } catch (e) {
      setState(() {
        _approval = null;
        _approvalError = 'Unable to load approval history.';
        _approvalLoading = false;
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

    setState(() => _isDeciding = true);
    try {
      await _approvalsRepo.decide(widget.inspectionId, decision: decision, remarks: remarksCtrl.text.trim());
      _decisionChanged = true;
      if (!mounted) return;
      showAdminSnack(context, isApprove ? 'Approved.' : 'Rejected.');
      // Re-fetch both the main record (status pill) and approval history/
      // pending-level so the buttons correctly disappear or move forward.
      await _load();
    } on ApiException catch (e) {
      if (mounted) showAdminSnack(context, e.message);
    } catch (e) {
      if (mounted) showAdminSnack(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isDeciding = false);
    }
  }

  Future<void> _inspectAgain() async {
    final d = _detail;
    if (d == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InspectionFormScreen(
          initialReferenceNumber: d.referenceNumber,
          taskId: d.taskId,
        ),
      ),
    );
    if (!mounted) return;
    // The re-submission is a brand-new inspection record, so this screen's
    // own (now-rejected) one doesn't change — just let the caller know a
    // fresh submission may have happened, so lists refresh.
    _decisionChanged = true;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_decisionChanged);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundPage,
        appBar: AppBar(
          title: const Text('Inspection Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(_decisionChanged),
          ),
        ),
        body: SafeArea(
          child: _isLoading || _error != null
              ? AdminListState(isLoading: _isLoading, errorMessage: _error, isEmpty: false, onRetry: _load)
              : RefreshIndicator(
                  color: AppColors.primaryGreen,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      ..._buildSections(_detail!),
                      if (_canDecide) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.errorRed),
                                label: const Text(AppStrings.approvalsReject, style: TextStyle(color: AppColors.errorRed)),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.errorRed)),
                                onPressed: _isDeciding ? null : () => _decide('REJECT'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                                label: const Text(AppStrings.approvalsApprove),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.successGreen),
                                onPressed: _isDeciding ? null : () => _decide('APPROVE'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (_canInspectAgain) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.replay_rounded, size: 18),
                            label: const Text('Inspect Again'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                            onPressed: _inspectAgain,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  List<Widget> _buildSections(InspectionDetail d) {
    return [
      // ── Header ──────────────────────────────────────────────────────────
      Row(
        children: [
          Expanded(
            child: Text(
              d.consumerName?.isNotEmpty == true ? d.consumerName! : d.referenceNumber,
              style: AppTextStyles.headingMedium,
            ),
          ),
          if (d.overallStatus != null) _StatusPill(status: d.overallStatus!),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(d.inspectionDatetime, style: AppTextStyles.bodySmall),
      if (d.overallStatus == 'REJECTED') ...[
        const SizedBox(height: AppSpacing.md),
        _RejectionBanner(rejection: d.rejection),
      ],
      const SizedBox(height: AppSpacing.lg),

      // ── SECTION A: Consumer Information ────────────────────────────────
      // Skipped when opened read-only from ApprovalDetailScreen — that
      // screen's _ReadingsCard already shows these same fields, so
      // rendering them again here was pure duplication. See
      // _hideCallerDuplicatedSections above.
      if (!_hideCallerDuplicatedSections) ...[
        _SectionHeader(icon: Icons.person_outline_rounded, title: 'Consumer Information'),
        _InfoCard(rows: [
          _row('Reference #', d.referenceNumber),
          _row('Consumer Name', d.consumerName),
          _row('Address', d.consumerAddress),
          _row('Consumer Account', d.consumerAccount),
          _row('Division', d.division),
          _row('Sub-Division', d.subDivision),
          _row('Category', d.category),
          _row('Tariff Category', d.tariffCategory),
          _row('Sanctioned Load', d.sanctionedLoad),
        ]),
        const SizedBox(height: AppSpacing.lg),
      ],

      // ── SECTION B: Meter Information / Readings ────────────────────────
      // Same duplication as Section A — kWh/kVArh/MDI/Meter ID are already
      // on the Approval Review screen the caller came from.
      if (!_hideCallerDuplicatedSections) ...[
        _SectionHeader(icon: Icons.speed_outlined, title: 'Meter Information'),
        _InfoCard(rows: [
          _row('Meter ID', d.meterId),
          if (d.taskId != null) _row('Linked Task', '#${d.taskId}'),
          _row('kWh', d.kwh?.toStringAsFixed(2)),
          _row('kVArh', d.kvarh?.toStringAsFixed(2)),
          _row('MDI', d.mdi?.toStringAsFixed(2)),
          _row('TOU Peak', d.touPeak?.toStringAsFixed(2)),
          _row('TOU Off-Peak', d.touOffPeak?.toStringAsFixed(2)),
          _row('TOU Day', d.touDay?.toStringAsFixed(2)),
          _row('TOU Night', d.touNight?.toStringAsFixed(2)),
          _row('Load Details', d.loadDetails),
        ]),
        const SizedBox(height: AppSpacing.lg),
      ],

      // ── SECTION C: GPS / Location ───────────────────────────────────────
      _SectionHeader(icon: Icons.location_on_outlined, title: 'GPS / Location'),
      d.hasGps
          ? _InfoCard(rows: [
              _row('Latitude', d.gpsLatitude!.toStringAsFixed(7)),
              _row('Longitude', d.gpsLongitude!.toStringAsFixed(7)),
              _row('Accuracy', d.gpsAccuracyMeters != null ? '±${d.gpsAccuracyMeters!.toStringAsFixed(1)} m' : null),
            ])
          : _EmptyNote(text: 'No GPS location was captured for this inspection.'),
      const SizedBox(height: AppSpacing.lg),

      // ── SECTION D: Meter / Equipment Condition ──────────────────────────
      _SectionHeader(icon: Icons.build_outlined, title: 'Equipment Condition'),
      _InfoCard(rows: [
        _row('Seal Condition', d.sealConditionCode),
        _row('CT/PT Box Status', d.ctptBoxStatusCode),
      ]),
      const SizedBox(height: AppSpacing.lg),

      // ── SECTION E: Images ────────────────────────────────────────────────
      _SectionHeader(icon: Icons.photo_library_outlined, title: 'Images (${d.images.length})'),
      d.images.isEmpty
          ? _EmptyNote(text: 'No images were uploaded with this inspection.')
          : _ImageGallery(images: d.images),
      const SizedBox(height: AppSpacing.lg),

      // ── SECTION F: Discrepancies ──────────────────────────────────────────
      _SectionHeader(icon: Icons.report_problem_outlined, title: 'Discrepancies'),
      _buildDiscrepanciesSection(),
      const SizedBox(height: AppSpacing.lg),

      // ── SECTION G: Approval History ─────────────────────────────────────
      // Hidden entirely (not even an empty-state note) when the caller isn't
      // a supervisory role — see _loadApprovalHistory()'s 403 handling.
      if (_approvalLoading || _approval != null || (_approvalError?.isNotEmpty ?? false)) ...[
        _SectionHeader(icon: Icons.verified_outlined, title: 'Approval History'),
        _buildApprovalHistorySection(),
        const SizedBox(height: AppSpacing.lg),
      ],

      // ── Submission meta ──────────────────────────────────────────────────
      // Submitted By/At are also already on ApprovalDetailScreen's
      // _ReadingsCard when this screen was opened from there.
      if (!_hideCallerDuplicatedSections) ...[
        _SectionHeader(icon: Icons.info_outline_rounded, title: 'Submission'),
        _InfoCard(rows: [
          _row('Submitted By', d.submittedBy),
          _row('Submitted At', d.createdAt),
        ]),
        const SizedBox(height: AppSpacing.xl),
      ],
    ];
  }

  _InfoRow? _row(String label, String? value) {
    if (value == null || value.trim().isEmpty || value == 'null') return null;
    return _InfoRow(label: label, value: value);
  }

  // ── SECTION F builder: Discrepancies ────────────────────────────────────
  Widget _buildDiscrepanciesSection() {
    if (_discrepanciesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen)),
      );
    }
    if (_discrepanciesError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.card)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_discrepanciesError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.errorRed)),
            const SizedBox(height: 4),
            TextButton(onPressed: _loadDiscrepancies, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_discrepancies.isEmpty) {
      return const _EmptyNote(text: 'No discrepancies reported for this inspection.');
    }
    // Read-only here — triaging a discrepancy (status/assignment) is owned
    // by the Discrepancy Reporting feature's own screens, not this report.
    return Column(children: [for (final r in _discrepancies) DiscrepancyTile(report: r)]);
  }

  // ── SECTION G builder: Approval History ─────────────────────────────────
  Widget _buildApprovalHistorySection() {
    if (_approvalLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen)),
      );
    }
    if (_approvalError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.card)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_approvalError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.errorRed)),
            const SizedBox(height: 4),
            TextButton(onPressed: _loadApprovalHistory, child: const Text('Retry')),
          ],
        ),
      );
    }
    final approval = _approval;
    if (approval == null) return const SizedBox.shrink();

    // Which levels apply to THIS inspection is configured server-side per
    // category (approval_workflow_rules) — not hard-coded here. If no
    // decisions have been recorded yet (e.g. still awaiting the very first
    // level, or the category required no review at all), say so plainly
    // instead of drawing a fixed M&T → SDO → XEN → SE chain.
    if (approval.history.isEmpty) {
      return _EmptyNote(
        text: approval.overallStatus == ApprovalOverallStatus.pendingApproval
            ? 'Awaiting ${approval.pendingRole ?? 'review'} — no decisions recorded yet.'
            : 'No approval levels were required for this inspection.',
      );
    }
    return Container(
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
          if (approval.overallStatus == ApprovalOverallStatus.pendingApproval) ...[
            const SectionDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: PendingLevelBadge(level: approval.currentApprovalLevel),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// SHARED PRIVATE WIDGETS
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryGreen),
          const SizedBox(width: 6),
          Text(title, style: AppTextStyles.headingMedium.copyWith(fontSize: 15)),
        ],
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow?> rows;
  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final visible = rows.whereType<_InfoRow>().toList();
    if (visible.isEmpty) {
      return const _EmptyNote(text: 'No details available for this section.');
    }
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
          for (int i = 0; i < visible.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 140, child: Text(visible[i].label, style: AppTextStyles.labelLarge)),
                  Expanded(child: Text(visible[i].value, style: AppTextStyles.bodyMedium)),
                ],
              ),
            ),
            if (i != visible.length - 1) const SectionDivider(),
          ],
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(text, style: AppTextStyles.bodySmall),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

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

class _RejectionBanner extends StatelessWidget {
  final InspectionRejection? rejection;
  const _RejectionBanner({required this.rejection});

  @override
  Widget build(BuildContext context) {
    final r = rejection;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.errorRed.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cancel_outlined, size: 16, color: AppColors.errorRed),
              const SizedBox(width: 6),
              Text(
                r?.roleCode != null ? 'Rejected by ${r!.roleCode}' : 'Rejected',
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.errorRed),
              ),
            ],
          ),
          if (r?.remarks?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(r!.remarks!, style: AppTextStyles.bodyMedium),
          ],
          if (r?.approverName != null || r?.createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              [r?.approverName, r?.createdAt].where((s) => s != null && s.isNotEmpty).join(' · '),
              style: AppTextStyles.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION E — IMAGE GALLERY + FULL-SCREEN VIEWER
// =============================================================================

class _ImageGallery extends StatelessWidget {
  final List<InspectionImage> images;
  const _ImageGallery({required this.images});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final img = images[index];
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => _FullScreenImageViewer(images: images, initialIndex: index)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: AppColors.surfaceMuted),
                Image.network(
                  img.url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textHint,
                  ),
                ),
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      img.typeLabel,
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FullScreenImageViewer extends StatefulWidget {
  final List<InspectionImage> images;
  final int initialIndex;
  const _FullScreenImageViewer({required this.images, required this.initialIndex});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final img = widget.images[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${img.typeLabel} · ${_index + 1} of ${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Center(
              child: Image.network(
                widget.images[i].url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: img.capturedAt != null
          ? Container(
              color: Colors.black,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Captured: ${img.capturedAt}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            )
          : null,
    );
  }
}
