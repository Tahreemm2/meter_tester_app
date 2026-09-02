// =============================================================================
// FILE: lib/features/discrepancies/screens/discrepancies_list_screen.dart
// PURPOSE: Lists discrepancy reports (GET /api/discrepancies.php). Any role
// can report a new one; field team (MT) sees only their own reports;
// supervisory roles see the full list, filterable by status, and can triage.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/scope_defaults.dart';
import '../../../core/widgets/logout_action.dart';
import '../../admin/widgets/admin_widgets.dart';
import '../data/discrepancies_repository.dart';
import '../models/discrepancy_models.dart';
import '../widgets/discrepancy_widgets.dart';
import 'discrepancy_detail_screen.dart';
import 'discrepancy_form_screen.dart';

class DiscrepanciesListScreen extends StatefulWidget {
  final UserModel currentUser;
  const DiscrepanciesListScreen({super.key, required this.currentUser});

  @override
  State<DiscrepanciesListScreen> createState() => _DiscrepanciesListScreenState();
}

class _DiscrepanciesListScreenState extends State<DiscrepanciesListScreen> {
  late final DiscrepanciesRepository _repo = ApiDiscrepanciesRepository(token: widget.currentUser.token);
  late final bool _isSupervisor = widget.currentUser.role.accessLevel >= 1;
  // Not user-editable — SDO/XEN must not be able to opt into another area.
  // See sdo_home_screen.dart / worker_monitoring_screen.dart for the same
  // pattern applied elsewhere.
  late final ScopeDefaults _scope = ScopeDefaults.forUser(widget.currentUser);

  final List<DiscrepancyReport> _reports = [];
  int _total = 0;
  int _page = 1;
  static const _perPage = 20;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  String? _statusFilter;

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
      final merged = mergeAcrossSubDivisions<DiscrepancyReport>(
        _scope,
        fetchOne: (sd) async {
          final page = await _repo.listDiscrepancies(
            status: _statusFilter,
            subDivision: sd,
            page: 1,
            perPage: 300,
          );
          return page.items;
        },
      );

      final List<DiscrepancyReport> items;
      final int total;
      if (merged != null) {
        items = await merged;
        total = items.length;
      } else {
        final result = await _repo.listDiscrepancies(
          status: _statusFilter,
          division: _scope.division,
          subDivision: _scope.subDivision,
          page: _page,
          perPage: _perPage,
        );
        items = result.items;
        total = result.total;
      }

      setState(() {
        if (reset) _reports.clear();
        _reports.addAll(items);
        _total = total;
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
    if (_reports.length >= _total) return;
    _page += 1;
    await _load();
  }

  void _onStatusFilterChanged(String? status) {
    setState(() => _statusFilter = status);
    _load(reset: true);
  }

  Future<void> _openReport() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DiscrepancyFormScreen(currentUser: widget.currentUser)),
    );
    if (created == true) _load(reset: true);
  }

  Future<void> _openDetail(DiscrepancyReport report) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DiscrepancyDetailScreen(currentUser: widget.currentUser, report: report),
      ),
    );
    if (changed == true) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(title: const Text(AppStrings.discrepanciesTitle), actions: const [LogoutAction()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openReport,
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.report_problem_outlined, color: AppColors.white),
        label: const Text(AppStrings.discrepanciesReportNew, style: TextStyle(color: AppColors.white)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: () => _load(reset: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
            children: [
              DiscrepancyFilterBar(selectedStatus: _statusFilter, onChanged: _onStatusFilterChanged),
              if (_scope.isScoped)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Showing ${_scope.label} only',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              AdminListState(
                isLoading: _isLoading,
                errorMessage: _error,
                isEmpty: _reports.isEmpty,
                onRetry: () => _load(reset: true),
              ),
              if (!_isLoading && _error == null && _reports.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Center(
                    child: Text(
                      _isSupervisor ? AppStrings.discrepanciesEmptyAll : AppStrings.discrepanciesEmptyMine,
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ..._reports.map((r) => DiscrepancyTile(report: r, onTap: () => _openDetail(r))),
              if (!_isLoading && _reports.length < _total)
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
