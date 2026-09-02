// =============================================================================
// FILE: lib/features/scheduling/screens/schedules_list_screen.dart
// PURPOSE: Lists meter inspection schedule entries (GET /api/admin/
// schedules.php). Supervisory roles only (SDO/XEN/SE/ADMIN). Supports
// auto-generating a quarter, manual single-entry creation, filtering by
// division/sub-division/category/quarter/status, and manual override (edit)
// or deletion of any entry.
//
// ROLE GATING: per API.md ("Geographic Scope Enforcement" — SDO's access to
// Scheduling is additionally view-only), an SDO may filter and browse this
// list but cannot generate, manually create, edit, or delete a schedule
// entry — that requires XEN/SE/ADMIN. This is enforced server-side already;
// `_canManage` below hides the corresponding controls client-side too so an
// SDO isn't shown actions that will just 403.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/logout_action.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/scope_defaults.dart';
import '../../admin/widgets/admin_widgets.dart';
import '../data/scheduling_repository.dart';
import '../models/schedule_models.dart';
import '../widgets/scheduling_widgets.dart';
import 'schedule_form_screen.dart';

class SchedulesListScreen extends StatefulWidget {
  final UserModel currentUser;
  const SchedulesListScreen({super.key, required this.currentUser});

  @override
  State<SchedulesListScreen> createState() => _SchedulesListScreenState();
}

class _SchedulesListScreenState extends State<SchedulesListScreen> {
  late final SchedulingRepository _repo = ApiSchedulingRepository(token: widget.currentUser.token);
  // Non-editable sub-division/division restriction — see scope_defaults.dart.
  // Applied to both the list view and Auto-Generate, so an SDO can never see
  // or bulk-create schedules outside their own sub-division.
  late final ScopeDefaults _scope = ScopeDefaults.forUser(widget.currentUser);

  // SDO is view-only for Scheduling (see API.md, "Geographic Scope
  // Enforcement"); generate/manual-create/edit/delete require XEN/SE/ADMIN.
  bool get _canManage => widget.currentUser.role != UserRole.sdo;

  final List<ScheduleEntry> _schedules = [];
  int _total = 0;
  int _page = 1;
  static const _perPage = 20;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isGenerating = false;
  String? _error;

  String? _statusFilter;
  String? _categoryFilter;
  String? _quarterFilter;
  bool _overdueOnly = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      if (reset) {
        _isLoading = true;
        _error = null;
        _page = 1;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final result = await _repo.listSchedules(
        status: _statusFilter,
        category: _categoryFilter,
        quarter: _quarterFilter,
        division: _scope.division,
        subDivision: _scope.subDivision,
        page: _page,
        perPage: _perPage,
      );
      setState(() {
        if (reset) _schedules.clear();
        _schedules.addAll(result.items);
        _total = result.total;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('ApiException(null, null): ', '');
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_schedules.length >= _total) return;
    _page += 1;
    await _load();
  }

  /// Overdue is a derived client-side property (see ScheduleEntry.isOverdue),
  /// not a server-side status, so this filters the already-loaded page.
  List<ScheduleEntry> get _visibleSchedules =>
      _overdueOnly ? _schedules.where((s) => s.isOverdue).toList() : _schedules;

  Future<void> _openGenerateDialog() async {
    String? selectedQuarter = upcomingQuarters().first;
    final confirmed = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
          title: const Text(AppStrings.schedulingGenerate, style: AppTextStyles.headingMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creates one schedule entry for every consumer that doesn\'t already have one this quarter. Safe to re-run.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Quarter', style: AppTextStyles.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: selectedQuarter,
                items: upcomingQuarters(count: 6).map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
                onChanged: (v) => setDialogState(() => selectedQuarter = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text(AppStrings.adminCancel)),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(selectedQuarter),
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == null) return;

    setState(() => _isGenerating = true);
    try {
      final result = await _repo.generateQuarter(
        quarter: confirmed,
        division: _scope.division,
        subDivision: _scope.subDivision,
      );
      if (!mounted) return;
      showAdminSnack(context, result.message);
      _load(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showAdminSnack(context, e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      showAdminSnack(context, 'Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _openManualCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ScheduleFormScreen(currentUser: widget.currentUser)),
    );
    if (created == true) _load(reset: true);
  }

  Future<void> _openEdit(ScheduleEntry schedule) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ScheduleFormScreen(currentUser: widget.currentUser, existing: schedule)),
    );
    if (updated == true) _load(reset: true);
  }

  Future<void> _delete(ScheduleEntry schedule) async {
    final confirmed = await confirmDestructiveAction(
      context,
      message: 'This will permanently remove this schedule entry.',
    );
    if (!confirmed) return;

    try {
      await _repo.deleteSchedule(schedule.id);
      if (!mounted) return;
      setState(() => _schedules.removeWhere((s) => s.id == schedule.id));
      showAdminSnack(context, 'Schedule entry deleted.');
    } catch (e) {
      if (!mounted) return;
      showAdminSnack(context, e.toString().replaceFirst('ApiException(null, null): ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(title: const Text(AppStrings.schedulingTitle), actions: const [LogoutAction()]),
      floatingActionButton: !_canManage
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'generate',
                  onPressed: _isGenerating ? null : _openGenerateDialog,
                  backgroundColor: AppColors.accentGold,
                  icon: _isGenerating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                      : const Icon(Icons.auto_awesome_rounded, color: AppColors.white),
                  label: const Text(AppStrings.schedulingGenerate, style: TextStyle(color: AppColors.white)),
                ),
                const SizedBox(height: AppSpacing.sm),
                FloatingActionButton.extended(
                  heroTag: 'manual',
                  onPressed: _openManualCreate,
                  backgroundColor: AppColors.primaryGreen,
                  icon: const Icon(Icons.add_rounded, color: AppColors.white),
                  label: const Text(AppStrings.schedulingAddManual, style: TextStyle(color: AppColors.white)),
                ),
              ],
            ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: () => _load(reset: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 160),
            children: [
              _FilterRow(
                statusFilter: _statusFilter,
                categoryFilter: _categoryFilter,
                quarterFilter: _quarterFilter,
                onStatusChanged: (v) {
                  setState(() => _statusFilter = v);
                  _load(reset: true);
                },
                onCategoryChanged: (v) {
                  setState(() => _categoryFilter = v);
                  _load(reset: true);
                },
                onQuarterChanged: (v) {
                  setState(() => _quarterFilter = v);
                  _load(reset: true);
                },
              ),
              if (_scope.division != null || _scope.subDivision != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Showing ${_scope.subDivision ?? _scope.division} only',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  label: const Text('Overdue only'),
                  avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.errorRed),
                  selected: _overdueOnly,
                  onSelected: (v) => setState(() => _overdueOnly = v),
                  selectedColor: AppColors.errorRed.withOpacity(0.12),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _overdueOnly ? AppColors.errorRed : AppColors.textSecondary,
                  ),
                  backgroundColor: AppColors.surfaceCard,
                  side: BorderSide(color: _overdueOnly ? AppColors.errorRed : AppColors.borderSubtle),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AdminListState(
                isLoading: _isLoading,
                errorMessage: _error,
                isEmpty: _visibleSchedules.isEmpty,
                onRetry: () => _load(reset: true),
              ),
              if (!_isLoading && _error == null && _visibleSchedules.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Center(
                    child: Text(
                      _overdueOnly ? 'Nothing overdue right now.' : AppStrings.schedulingEmpty,
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ),
              ..._visibleSchedules.map((s) => ScheduleTile(
                    schedule: s,
                    onTap: _canManage ? () => _openEdit(s) : null,
                    onDelete: _canManage ? () => _delete(s) : null,
                  )),
              if (!_isLoading && !_overdueOnly && _schedules.length < _total)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(
                    child: _isLoadingMore
                        ? const CircularProgressIndicator(color: AppColors.primaryGreen)
                        : TextButton(onPressed: _loadMore, child: const Text(AppStrings.adminLoadMore)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String? statusFilter;
  final String? categoryFilter;
  final String? quarterFilter;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onQuarterChanged;

  const _FilterRow({
    required this.statusFilter,
    required this.categoryFilter,
    required this.quarterFilter,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onQuarterChanged,
  });

  static const _statuses = <String?, String>{
    null: 'All Status',
    'PENDING': 'Pending',
    'ASSIGNED': 'Assigned',
    'COMPLETED': 'Completed',
    'CANCELLED': 'Cancelled',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ..._statuses.entries.map((entry) {
            final isSelected = statusFilter == entry.key;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: isSelected,
                onSelected: (_) => onStatusChanged(entry.key),
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
          }),
          const SizedBox(width: AppSpacing.sm),
          ...kConsumerCategories.map((cat) {
            final isSelected = categoryFilter == cat;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                onSelected: (_) => onCategoryChanged(isSelected ? null : cat),
                selectedColor: AppColors.accentGoldLight,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.accentGold : AppColors.textSecondary,
                ),
                backgroundColor: AppColors.surfaceCard,
                side: BorderSide(color: isSelected ? AppColors.accentGold : AppColors.borderSubtle),
              ),
            );
          }),
        ],
      ),
    );
  }
}
