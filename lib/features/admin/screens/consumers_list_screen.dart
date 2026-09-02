// =============================================================================
// FILE: lib/features/admin/screens/consumers_list_screen.dart
// PURPOSE: Lists consumer/meter records (GET /api/admin/consumers.php), with
// search, create, edit, and permanent delete. ADMIN role only. These are the
// records looked up by the "Auto-Fetch Data" feature in the inspection form.
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/logout_action.dart';
import '../data/admin_repository.dart';
import '../models/admin_models.dart';
import '../widgets/admin_widgets.dart';
import 'consumer_form_screen.dart';

class ConsumersListScreen extends StatefulWidget {
  final String token;
  const ConsumersListScreen({super.key, required this.token});

  @override
  State<ConsumersListScreen> createState() => _ConsumersListScreenState();
}

class _ConsumersListScreenState extends State<ConsumersListScreen> {
  late final AdminRepository _repo = ApiAdminRepository(token: widget.token);
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  final List<ManagedConsumer> _items = [];
  int _total = 0;
  int _page = 1;
  static const _perPage = 20;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
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
      final result = await _repo.listConsumers(page: _page, perPage: _perPage, search: _search);
      setState(() {
        if (reset) _items.clear();
        _items.addAll(result.items);
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search = value.trim();
      _load(reset: true);
    });
  }

  Future<void> _loadMore() async {
    if (_items.length >= _total) return;
    _page += 1;
    await _load();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ConsumerFormScreen(token: widget.token)),
    );
    if (created == true) _load(reset: true);
  }

  Future<void> _openEdit(ManagedConsumer c) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ConsumerFormScreen(token: widget.token, existing: c)),
    );
    if (updated == true) _load(reset: true);
  }

  Future<void> _delete(ManagedConsumer c) async {
    final confirmed = await confirmDestructiveAction(context, message: AppStrings.adminConfirmDeleteConsumer);
    if (!confirmed) return;
    try {
      await _repo.deleteConsumer(c.id);
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => e.id == c.id));
      showAdminSnack(context, 'Consumer record deleted.');
    } catch (e) {
      if (!mounted) return;
      showAdminSnack(context, e.toString().replaceFirst('ApiException(null, null): ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(title: const Text(AppStrings.adminConsumersTitle), actions: const [LogoutAction()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add_rounded, color: AppColors.white),
        label: const Text(AppStrings.adminAddNew, style: TextStyle(color: AppColors.white)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: AppStrings.adminSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primaryGreen,
                onRefresh: () => _load(reset: true),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                  children: [
                    AdminListState(
                      isLoading: _isLoading,
                      errorMessage: _error,
                      isEmpty: _items.isEmpty,
                      onRetry: () => _load(reset: true),
                    ),
                    ..._items.map((c) => _ConsumerTile(
                          consumer: c,
                          onEdit: () => _openEdit(c),
                          onDelete: () => _delete(c),
                        )),
                    if (!_isLoading && _items.length < _total)
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
          ],
        ),
      ),
    );
  }
}

class _ConsumerTile extends StatelessWidget {
  final ManagedConsumer consumer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ConsumerTile({required this.consumer, required this.onEdit, required this.onDelete});

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
                Text(consumer.referenceNumber,
                    style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryGreen, fontSize: 13)),
                const SizedBox(height: 2),
                Text(consumer.consumerName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text('${consumer.consumerAccount} · ${consumer.tariffCategory} · ${consumer.sanctionedLoad}',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textHint),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text(AppStrings.adminEdit)),
              PopupMenuItem(value: 'delete', child: Text(AppStrings.adminDelete)),
            ],
          ),
        ],
      ),
    );
  }
}
