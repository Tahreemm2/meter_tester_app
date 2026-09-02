// =============================================================================
// FILE: lib/features/approvals/screens/approvals_list_screen.dart
// PURPOSE: Lists inspections in the Approval Workflow (GET /api/approvals.php).
// For SDO/XEN/SE, the PENDING tab is their own review queue (inspections
// sitting at their level); APPROVED/REJECTED shows inspections THEY decided.
// ADMIN sees the global pool for every tab. Supervisory roles only — this
// screen is only reachable from the home shell for accessLevel >= 1.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/scope_defaults.dart';
import '../../../core/widgets/logout_action.dart';
import '../../admin/widgets/admin_widgets.dart';
import '../data/approvals_repository.dart';
import '../models/approval_models.dart';
import '../widgets/approval_widgets.dart';
import 'approval_detail_screen.dart';

class ApprovalsListScreen extends StatefulWidget {
  final UserModel currentUser;
  const ApprovalsListScreen({super.key, required this.currentUser});

  @override
  State<ApprovalsListScreen> createState() => _ApprovalsListScreenState();
}

class _ApprovalsListScreenState extends State<ApprovalsListScreen> {
  late final ApprovalsRepository _repo = ApiApprovalsRepository(token: widget.currentUser.token);
  // The review-level queue alone doesn't restrict by geography — an SDO's
  // PENDING queue would otherwise span every sub-division. This applies the
  // same non-editable sub-division/division restriction as the rest of the
  // app (see scope_defaults.dart).
  late final ScopeDefaults _scope = ScopeDefaults.forUser(widget.currentUser);

  final List<InspectionApproval> _approvals = [];
  int _total = 0;
  int _page = 1;
  static const _perPage = 20;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  String _statusFilter = 'PENDING';
  String? _categoryFilter;

  static const _categories = ['B1', 'B2', 'B3', 'B4'];

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
      final result = await _repo.listApprovals(
        status: _statusFilter,
        division: _scope.division,
        subDivision: _scope.subDivision,
        category: _categoryFilter,
        page: _page,
        perPage: _perPage,
      );
      setState(() {
        if (reset) _approvals.clear();
        _approvals.addAll(result.items);
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
    if (_approvals.length >= _total) return;
    _page += 1;
    await _load();
  }

  void _onStatusFilterChanged(String status) {
    setState(() => _statusFilter = status);
    _load(reset: true);
  }

  void _onCategoryFilterChanged(String? category) {
    setState(() => _categoryFilter = category);
    _load(reset: true);
  }

  Future<void> _openDetail(InspectionApproval approval) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ApprovalDetailScreen(currentUser: widget.currentUser, approval: approval),
      ),
    );
    if (changed == true) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(title: const Text(AppStrings.approvalsTitle), actions: const [LogoutAction()]),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: () => _load(reset: true),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              ApprovalStatusFilterBar(selected: _statusFilter, onChanged: _onStatusFilterChanged),
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
              if (_scope.division != null || _scope.subDivision != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Showing ${_scope.subDivision ?? _scope.division} only',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              AdminListState(
                isLoading: _isLoading,
                errorMessage: _error,
                isEmpty: _approvals.isEmpty,
                onRetry: () => _load(reset: true),
              ),
              if (!_isLoading && _error == null && _approvals.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Center(
                    child: Text(
                      _statusFilter == 'PENDING' ? AppStrings.approvalsEmptyPending : AppStrings.approvalsEmptyDecided,
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ..._approvals.map((a) => ApprovalTile(approval: a, onTap: () => _openDetail(a))),
              if (!_isLoading && _approvals.length < _total)
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

  Widget _categoryChip(String? value, String label) {
    final isSelected = _categoryFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _onCategoryFilterChanged(value),
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
