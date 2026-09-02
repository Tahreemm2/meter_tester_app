// =============================================================================
// FILE: lib/features/sdo/screens/sdo_inspections_screen.dart
// PURPOSE: "Inspection Reports" — SDO spec item 2 — "List of all inspections
// within the sub-division, search/filter by meter number, status, or date."
// Tapping a report opens InspectionDetailScreen with currentUser passed
// through, so if that specific report is still awaiting THIS SDO's decision
// (overall_status = PENDING_APPROVAL, current_approval_level = 1), Approve/
// Reject buttons appear right there — a meter tester's submitted report can
// be reviewed from this list directly, not only via the separate "Pending
// Approvals" queue (features/approvals/screens/approvals_list_screen.dart),
// which remains the faster, decision-focused way to work through a queue.
//
// Backed by GET /api/data.php?action=inspections-list, which is server-side
// scoped via enforced_scope_sql() to the caller's own division/sub-division —
// an SDO cannot see another sub-division's inspections regardless of what
// this screen requests. "Status" here is the Approval Workflow outcome
// (PENDING_APPROVAL / APPROVED / REJECTED) — the closest thing an inspection
// record has to a status, per the backend's own filter contract. Category
// (B1-B4) is likewise a real backend filter (VALID_CATEGORIES in
// backend/config/helpers.php) — not invented for this screen.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/scope_defaults.dart';
import '../../../core/widgets/logout_action.dart';
import '../../admin/widgets/admin_widgets.dart';
import '../../inspection/bloc/inspection_summary_model.dart';
import '../../inspection/data/inspection_repository.dart';
import '../../inspection/screens/inspection_detail_screen.dart';

class SdoInspectionsScreen extends StatefulWidget {
  final UserModel currentUser;
  const SdoInspectionsScreen({super.key, required this.currentUser});

  @override
  State<SdoInspectionsScreen> createState() => _SdoInspectionsScreenState();
}

class _SdoInspectionsScreenState extends State<SdoInspectionsScreen> {
  late final InspectionRepository _repo = ApiInspectionRepository();
  late final ScopeDefaults _scope = ScopeDefaults.forUser(widget.currentUser);
  String get _token => widget.currentUser.token;

  List<InspectionSummary> _entries = [];
  int _total = 0;
  bool _isLoading = true;
  String? _error;

  String _search = '';
  String? _statusFilter;
  String? _categoryFilter;
  DateTime? _dateFilter;

  static const _categories = ['B1', 'B2', 'B3', 'B4'];

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
      final dateStr = _dateFilter == null
          ? null
          : '${_dateFilter!.year.toString().padLeft(4, '0')}-${_dateFilter!.month.toString().padLeft(2, '0')}-${_dateFilter!.day.toString().padLeft(2, '0')}';

      final merged = mergeAcrossSubDivisions<InspectionSummary>(
        _scope,
        fetchOne: (sd) async {
          final page = await _repo.listInspections(
            _token,
            search: _search.trim().isEmpty ? null : _search.trim(),
            status: _statusFilter,
            category: _categoryFilter,
            subDivision: sd,
            dateFrom: dateStr,
            dateTo: dateStr,
            page: 1,
            perPage: 300,
          );
          return page.items;
        },
      );

      final List<InspectionSummary> entries;
      int total;
      if (merged != null) {
        entries = await merged;
        total = entries.length;
      } else {
        final page = await _repo.listInspections(
          _token,
          search: _search.trim().isEmpty ? null : _search.trim(),
          status: _statusFilter,
          category: _categoryFilter,
          division: _scope.division,
          subDivision: _scope.subDivision,
          dateFrom: dateStr,
          dateTo: dateStr,
          page: 1,
          perPage: 300,
        );
        entries = page.items;
        total = page.total;
      }
      setState(() {
        _entries = entries;
        _total = total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('ApiException(null, null): ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _dateFilter = picked);
      _load();
    }
  }

  Future<void> _openDetail(InspectionSummary entry) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InspectionDetailScreen(
          token: _token,
          inspectionId: entry.id,
          currentUser: widget.currentUser,
        ),
      ),
    );
    // Refresh so a decided report's status badge (and any status filter)
    // reflects the new APPROVED/REJECTED state immediately.
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(title: const Text('Inspection Reports'), actions: const [LogoutAction()]),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (_scope.isScoped)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    _total > 0 ? '$_total inspection(s) in ${_scope.label}' : 'Inspections in ${_scope.label}',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              TextField(
                onChanged: (v) => setState(() => _search = v),
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'Search inspection reports (meter, reference, consumer)',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    onPressed: _load,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceCard,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: AppSpacing.md),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _statusChip(null, 'All'),
                          _statusChip('PENDING_APPROVAL', 'Pending Approval'),
                          _statusChip('APPROVED', 'Approved'),
                          _statusChip('REJECTED', 'Rejected'),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.event_outlined, color: _dateFilter != null ? AppColors.primaryGreen : AppColors.textHint),
                    tooltip: 'Filter by date',
                    onPressed: _pickDate,
                  ),
                  if (_dateFilter != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        setState(() => _dateFilter = null);
                        _load();
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _categoryChip(null, 'All Categories'),
                    for (final c in _categories) _categoryChip(c, c),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AdminListState(
                isLoading: _isLoading,
                errorMessage: _error,
                isEmpty: _entries.isEmpty,
                onRetry: () => _load(),
              ),
              if (!_isLoading && _error == null && _entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: Center(child: Text('No inspections match these filters.', style: AppTextStyles.bodySmall)),
                ),
              ..._entries.map((e) => _InspectionTile(entry: e, onTap: () => _openDetail(e))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String? value, String label) {
    final isSelected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _statusFilter = value);
          _load();
        },
        selectedColor: AppColors.primaryGreenSurface,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
        ),
        backgroundColor: AppColors.surfaceCard,
        side: BorderSide(color: isSelected ? AppColors.primaryGreen : AppColors.borderSubtle),
      ),
    );
  }

  Widget _categoryChip(String? value, String label) {
    final isSelected = _categoryFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _categoryFilter = value);
          _load();
        },
        selectedColor: AppColors.primaryGreenSurface,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
        ),
        backgroundColor: AppColors.surfaceCard,
        side: BorderSide(color: isSelected ? AppColors.primaryGreen : AppColors.borderSubtle),
      ),
    );
  }
}

class _ApprovalStatusBadge extends StatelessWidget {
  final String? status;
  const _ApprovalStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    switch (status) {
      case 'APPROVED':
        color = AppColors.primaryGreen;
        label = 'Approved';
      case 'REJECTED':
        color = AppColors.errorRed;
        label = 'Rejected';
      case 'PENDING_APPROVAL':
        color = AppColors.warningAmber;
        label = 'Pending Approval';
      default:
        color = AppColors.textHint;
        label = status ?? 'Unknown';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Read-only list tile — no edit/delete affordance, since the SDO's
/// inspection view is view-only per the spec.
class _InspectionTile extends StatelessWidget {
  final InspectionSummary entry;
  final VoidCallback onTap;
  const _InspectionTile({required this.entry, required this.onTap});

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.consumerName ?? entry.consumerAccount,
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary, fontSize: 14),
                    ),
                    Text('${entry.referenceNumber} · ${entry.meterId}', style: AppTextStyles.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      entry.category != null && entry.category!.isNotEmpty
                          ? '${entry.category} · ${entry.inspectionDatetime}'
                          : entry.inspectionDatetime,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              if (entry.imageCount > 0) ...[
                Icon(Icons.photo_camera_outlined, size: 14, color: AppColors.textHint),
                const SizedBox(width: 2),
                Text('${entry.imageCount}', style: AppTextStyles.bodySmall),
                const SizedBox(width: 8),
              ],
              _ApprovalStatusBadge(status: entry.overallStatus),
            ],
          ),
        ),
      ),
    );
  }
}
