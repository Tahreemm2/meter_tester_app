// =============================================================================
// FILE: lib/features/admin/screens/form_options_screen.dart
// PURPOSE: Manage the Seal Condition / CT-PT-BT Box dropdown options that
// populate the inspection form (GET/POST/PUT/DELETE /api/admin/form_options.php).
// Lets an admin add/edit/retire options without an app release, exactly as
// inspection_config.dart's original doc-comment described.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/logout_action.dart';
import '../../auth/widgets/auth_widgets.dart';
import '../data/admin_repository.dart';
import '../models/admin_models.dart';
import '../widgets/admin_widgets.dart';

const _dropdownTabs = [
  ('SEAL_CONDITION', 'Seal Condition'),
  ('CTPT_BOX', 'CT-PT-BT Box'),
];

class FormOptionsScreen extends StatefulWidget {
  final String token;
  const FormOptionsScreen({super.key, required this.token});

  @override
  State<FormOptionsScreen> createState() => _FormOptionsScreenState();
}

class _FormOptionsScreenState extends State<FormOptionsScreen> with SingleTickerProviderStateMixin {
  late final AdminRepository _repo = ApiAdminRepository(token: widget.token);
  late final TabController _tabController = TabController(length: _dropdownTabs.length, vsync: this);

  bool _isLoading = true;
  String? _error;
  List<ManagedFormOption> _options = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final options = await _repo.listFormOptions();
      setState(() {
        _options = options;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('ApiException(null, null): ', '');
        _isLoading = false;
      });
    }
  }

  List<ManagedFormOption> _forKey(String key) {
    final list = _options.where((o) => o.dropdownKey == key).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  Future<void> _openEditor({required String dropdownKey, ManagedFormOption? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _FormOptionEditorDialog(repo: _repo, dropdownKey: dropdownKey, existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(ManagedFormOption option) async {
    final confirmed = await confirmDestructiveAction(context, message: AppStrings.adminConfirmDeleteOption);
    if (!confirmed) return;
    try {
      await _repo.deleteFormOption(option.id);
      if (!mounted) return;
      setState(() => _options.removeWhere((o) => o.id == option.id));
      showAdminSnack(context, 'Form option deleted.');
    } catch (e) {
      if (!mounted) return;
      showAdminSnack(context, e.toString().replaceFirst('ApiException(null, null): ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(
        title: const Text(AppStrings.adminFormOptionsTitle),
        actions: const [LogoutAction()],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.white,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withOpacity(0.7),
          tabs: _dropdownTabs.map((t) => Tab(text: t.$2)).toList(),
        ),
      ),
      body: SafeArea(
        child: _isLoading || _error != null
            ? Center(
                child: AdminListState(isLoading: _isLoading, errorMessage: _error, isEmpty: false, onRetry: _load),
              )
            : TabBarView(
                controller: _tabController,
                children: _dropdownTabs.map((t) => _buildTabBody(t.$1)).toList(),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(dropdownKey: _dropdownTabs[_tabController.index].$1),
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add_rounded, color: AppColors.white),
        label: const Text(AppStrings.adminAddNew, style: TextStyle(color: AppColors.white)),
      ),
    );
  }

  Widget _buildTabBody(String dropdownKey) {
    final options = _forKey(dropdownKey);
    if (options.isEmpty) {
      return Center(child: Text(AppStrings.adminEmptyList, style: AppTextStyles.bodySmall));
    }
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
        itemCount: options.length,
        itemBuilder: (context, index) {
          final o = options[index];
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
                          Text(o.label, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(width: 6),
                          StatusBadge(isActive: o.isActive),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Code: ${o.code} · Order: ${o.sortOrder}', style: AppTextStyles.bodySmall),
                      if (o.description != null && o.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(o.description!, style: AppTextStyles.bodySmall),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textHint),
                  onSelected: (value) {
                    if (value == 'edit') _openEditor(dropdownKey: dropdownKey, existing: o);
                    if (value == 'delete') _delete(o);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text(AppStrings.adminEdit)),
                    PopupMenuItem(value: 'delete', child: Text(AppStrings.adminDelete)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Create/Edit dialog — small record, so a dialog is a better fit than a
// full-screen push (consistent with typical "quick add" admin UX).
// =============================================================================
class _FormOptionEditorDialog extends StatefulWidget {
  final AdminRepository repo;
  final String dropdownKey;
  final ManagedFormOption? existing;

  const _FormOptionEditorDialog({required this.repo, required this.dropdownKey, this.existing});

  @override
  State<_FormOptionEditorDialog> createState() => _FormOptionEditorDialogState();
}

class _FormOptionEditorDialogState extends State<_FormOptionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _codeCtrl = TextEditingController(text: widget.existing?.code ?? '');
  late final _labelCtrl = TextEditingController(text: widget.existing?.label ?? '');
  late final _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
  late final _sortCtrl = TextEditingController(text: '${widget.existing?.sortOrder ?? 0}');
  late bool _isActive = widget.existing?.isActive ?? true;

  bool _isSaving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _labelCtrl.dispose();
    _descCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await widget.repo.updateFormOption(
          widget.existing!.id,
          label: _labelCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          sortOrder: int.tryParse(_sortCtrl.text.trim()) ?? 0,
          isActive: _isActive,
        );
      } else {
        await widget.repo.createFormOption(
          dropdownKey: widget.dropdownKey,
          code: _codeCtrl.text.trim(),
          label: _labelCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          sortOrder: int.tryParse(_sortCtrl.text.trim()) ?? 0,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text(_isEdit ? 'Edit Option' : 'New Option', style: AppTextStyles.headingMedium),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(
                label: 'Code',
                hint: 'e.g. INTACT',
                controller: _codeCtrl,
                enabled: !_isEdit,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Code is required.' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Label',
                hint: 'e.g. Intact',
                controller: _labelCtrl,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Label is required.' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Description (optional)',
                hint: 'Shown as helper text, if any',
                controller: _descCtrl,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Sort Order',
                hint: '0',
                controller: _sortCtrl,
                keyboardType: TextInputType.number,
              ),
              if (_isEdit) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Text('Active', style: AppTextStyles.labelLarge),
                    const Spacer(),
                    Switch(
                      value: _isActive,
                      activeThumbColor: AppColors.primaryGreen,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(AppStrings.adminCancel)),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, minimumSize: const Size(80, 40)),
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
              : Text(AppStrings.adminSave, style: AppTextStyles.buttonLabel.copyWith(fontSize: 14)),
        ),
      ],
    );
  }
}
