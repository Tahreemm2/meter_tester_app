// =============================================================================
// FILE: lib/core/widgets/id_picker_fields.dart
// PURPOSE: Reusable "pick a consumer / pick a user" inputs shared by the
// Task Assignment and Meter Scheduling forms.
//
// WHY TWO MODES: backend/api/admin/{consumers,users}.php are ADMIN-role
// exclusive (see API.md "Admin management"), while task/schedule assignment
// is open to all supervisory roles (SDO/XEN/SE/ADMIN — see SUPERVISORY_ROLES
// in config/helpers.php). Non-admin supervisors have no backend route to
// search consumers or employees, so they fall back to entering the numeric
// database ID directly (obtainable from an Admin, a schedule listing, or a
// generated report). ADMIN users get a live-search autocomplete instead.
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../models/user_model.dart';
import '../../features/admin/data/admin_repository.dart';
import '../../features/admin/models/admin_models.dart';

// -----------------------------------------------------------------------------
// CONSUMER PICKER
// -----------------------------------------------------------------------------
class ConsumerIdField extends StatefulWidget {
  final UserModel currentUser;
  final ValueChanged<int?> onChanged;
  final String label;

  const ConsumerIdField({
    super.key,
    required this.currentUser,
    required this.onChanged,
    this.label = 'Consumer',
  });

  @override
  State<ConsumerIdField> createState() => _ConsumerIdFieldState();
}

class _ConsumerIdFieldState extends State<ConsumerIdField> {
  final _manualCtrl = TextEditingController();

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUser.role == UserRole.admin) {
      return _AdminConsumerSearch(currentUser: widget.currentUser, onChanged: widget.onChanged, label: widget.label);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${widget.label} ID', style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: _manualCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Numeric consumer ID, e.g. 42'),
          onChanged: (v) => widget.onChanged(int.tryParse(v.trim())),
        ),
        const SizedBox(height: 4),
        Text(
          'Ask an Admin, or pick from an existing schedule entry, if you don\'t know the ID.',
          style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

class _AdminConsumerSearch extends StatefulWidget {
  final UserModel currentUser;
  final ValueChanged<int?> onChanged;
  final String label;

  const _AdminConsumerSearch({required this.currentUser, required this.onChanged, required this.label});

  @override
  State<_AdminConsumerSearch> createState() => _AdminConsumerSearchState();
}

class _AdminConsumerSearchState extends State<_AdminConsumerSearch> {
  late final AdminRepository _repo = ApiAdminRepository(token: widget.currentUser.token);
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<ManagedConsumer> _results = [];
  ManagedConsumer? _selected;
  bool _isSearching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (_selected != null) {
      setState(() => _selected = null);
      widget.onChanged(null);
    }
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _isSearching = true);
      try {
        final page = await _repo.listConsumers(search: query.trim(), perPage: 10);
        if (mounted) setState(() => _results = page.items);
      } catch (_) {
        if (mounted) setState(() => _results = []);
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  void _select(ManagedConsumer c) {
    setState(() {
      _selected = c;
      _results = [];
      _searchCtrl.text = '${c.referenceNumber} — ${c.consumerName}';
    });
    widget.onChanged(c.id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search by reference #, name, or account...',
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : const Icon(Icons.search_rounded, size: 20),
          ),
          onChanged: _onQueryChanged,
        ),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderSubtle),
              itemBuilder: (_, i) {
                final c = _results[i];
                return ListTile(
                  dense: true,
                  title: Text(c.consumerName, style: AppTextStyles.bodyMedium.copyWith(fontSize: 14)),
                  subtitle: Text('${c.referenceNumber} · ${c.meterId}', style: AppTextStyles.bodySmall),
                  onTap: () => _select(c),
                );
              },
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// USER (ASSIGNEE) PICKER
// -----------------------------------------------------------------------------
class UserIdField extends StatefulWidget {
  final UserModel currentUser;
  final ValueChanged<int?> onChanged;
  final String label;
  final String? roleFilter; // e.g. 'MT' — only used client-side to prioritize results

  const UserIdField({
    super.key,
    required this.currentUser,
    required this.onChanged,
    this.label = 'Assign To',
    this.roleFilter,
  });

  @override
  State<UserIdField> createState() => _UserIdFieldState();
}

class _UserIdFieldState extends State<UserIdField> {
  final _manualCtrl = TextEditingController();

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUser.role == UserRole.admin) {
      return _AdminUserPicker(
        currentUser: widget.currentUser,
        onChanged: widget.onChanged,
        label: widget.label,
        roleFilter: widget.roleFilter,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${widget.label} (User ID)', style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: _manualCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Numeric employee user ID, e.g. 7'),
          onChanged: (v) => widget.onChanged(int.tryParse(v.trim())),
        ),
        const SizedBox(height: 4),
        Text(
          'Ask an Admin for the employee\'s user ID if you don\'t know it.',
          style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

class _AdminUserPicker extends StatefulWidget {
  final UserModel currentUser;
  final ValueChanged<int?> onChanged;
  final String label;
  final String? roleFilter;

  const _AdminUserPicker({required this.currentUser, required this.onChanged, required this.label, this.roleFilter});

  @override
  State<_AdminUserPicker> createState() => _AdminUserPickerState();
}

class _AdminUserPickerState extends State<_AdminUserPicker> {
  late final AdminRepository _repo = ApiAdminRepository(token: widget.currentUser.token);
  List<ManagedUser> _allUsers = [];
  ManagedUser? _selected;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Admin lists are typically small in this system; pull enough for a
      // full picker in one page rather than building a second search UI.
      final page = await _repo.listUsers(page: 1, perPage: 100);
      if (!mounted) return;
      var users = page.items.where((u) => u.isActive).toList();
      if (widget.roleFilter != null) {
        final filtered = users.where((u) => u.roleCode == widget.roleFilter).toList();
        if (filtered.isNotEmpty) users = filtered;
      }
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load users.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error != null) {
      return Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.errorRed));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<int>(
          initialValue: _selected?.id,
          isExpanded: true,
          hint: const Text('Select an employee'),
          items: _allUsers
              .map((u) => DropdownMenuItem(
                    value: u.id,
                    child: Text('${u.fullName} (${u.roleCode})', overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (id) {
            setState(() => _selected = _allUsers.firstWhere((u) => u.id == id));
            widget.onChanged(id);
          },
        ),
      ],
    );
  }
}
