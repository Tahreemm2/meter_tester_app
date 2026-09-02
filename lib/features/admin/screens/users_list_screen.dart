// =============================================================================
// FILE: lib/features/admin/screens/users_list_screen.dart
// PURPOSE: Lists employee accounts (GET /api/admin/users.php), with create,
// edit, and deactivate actions. ADMIN role only.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/logout_action.dart';
import '../data/admin_repository.dart';
import '../models/admin_models.dart';
import '../widgets/admin_widgets.dart';
import 'user_form_screen.dart';

class UsersListScreen extends StatefulWidget {
  final String token;
  final String currentUsername;

  const UsersListScreen({super.key, required this.token, required this.currentUsername});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  late final AdminRepository _repo = ApiAdminRepository(token: widget.token);

  final List<ManagedUser> _users = [];
  int _total = 0;
  int _page = 1;
  static const _perPage = 20;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

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
      final result = await _repo.listUsers(page: _page, perPage: _perPage);
      setState(() {
        if (reset) _users.clear();
        _users.addAll(result.items);
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
    if (_users.length >= _total) return;
    _page += 1;
    await _load();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => UserFormScreen(token: widget.token)),
    );
    if (created == true) _load(reset: true);
  }

  Future<void> _openEdit(ManagedUser user) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => UserFormScreen(token: widget.token, existing: user)),
    );
    if (updated == true) _load(reset: true);
  }

  Future<void> _deactivate(ManagedUser user) async {
    if (user.username == widget.currentUsername) {
      showAdminSnack(context, 'You cannot deactivate your own account.', isError: true);
      return;
    }
    final confirmed = await confirmDestructiveAction(
      context,
      message: AppStrings.adminConfirmDeleteUser,
      confirmLabel: AppStrings.adminDeactivate,
    );
    if (!confirmed) return;

    try {
      await _repo.deactivateUser(user.id);
      if (!mounted) return;
      setState(() {
        final idx = _users.indexWhere((u) => u.id == user.id);
        if (idx != -1) _users[idx] = user.copyWith(isActive: false);
      });
      showAdminSnack(context, 'User deactivated.');
    } catch (e) {
      if (!mounted) return;
      showAdminSnack(context, e.toString().replaceFirst('ApiException(null, null): ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(title: const Text(AppStrings.adminUsersTitle), actions: const [LogoutAction()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add_rounded, color: AppColors.white),
        label: const Text(AppStrings.adminAddNew, style: TextStyle(color: AppColors.white)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: () => _load(reset: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
            children: [
              AdminListState(
                isLoading: _isLoading,
                errorMessage: _error,
                isEmpty: _users.isEmpty,
                onRetry: () => _load(reset: true),
              ),
              ..._users.map((u) => _UserTile(
                    user: u,
                    isSelf: u.username == widget.currentUsername,
                    onEdit: () => _openEdit(u),
                    onDeactivate: () => _deactivate(u),
                  )),
              if (!_isLoading && _users.length < _total)
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

class _UserTile extends StatelessWidget {
  final ManagedUser user;
  final bool isSelf;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  const _UserTile({required this.user, required this.isSelf, required this.onEdit, required this.onDeactivate});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(user.fullName, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary, fontSize: 15)),
                    ),
                    const SizedBox(width: 6),
                    StatusBadge(isActive: user.isActive),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      Text('(you)', style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text('${user.username} · ${user.employeeId}', style: AppTextStyles.bodySmall),
                const SizedBox(height: 2),
                Text('${user.roleCode} · ${user.scopeName}', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textHint),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'deactivate') onDeactivate();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text(AppStrings.adminEdit)),
              if (user.isActive)
                const PopupMenuItem(value: 'deactivate', child: Text(AppStrings.adminDeactivate)),
            ],
          ),
        ],
      ),
    );
  }
}
