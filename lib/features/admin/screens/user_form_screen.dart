// =============================================================================
// FILE: lib/features/admin/screens/user_form_screen.dart
// PURPOSE: Create or edit an employee account. Mirrors the validation rules
// enforced by backend/api/admin/users.php (role_code / scope_code enums,
// password length, required fields).
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/widgets/auth_widgets.dart';
import '../data/admin_repository.dart';
import '../models/admin_models.dart';
import '../widgets/admin_widgets.dart';

const _roleOptions = ['MT', 'SDO', 'XEN', 'SE', 'ADMIN'];
const _scopeOptions = ['SUB_DIVISION', 'DIVISION', 'CIRCLE', 'REGION', 'NATIONAL'];

class UserFormScreen extends StatefulWidget {
  final String token;
  final ManagedUser? existing; // null = create mode

  const UserFormScreen({super.key, required this.token, this.existing});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AdminRepository _repo = ApiAdminRepository(token: widget.token);

  late final _employeeIdCtrl = TextEditingController(text: widget.existing?.employeeId ?? '');
  late final _fullNameCtrl = TextEditingController(text: widget.existing?.fullName ?? '');
  late final _usernameCtrl = TextEditingController(text: widget.existing?.username ?? '');
  late final _passwordCtrl = TextEditingController();
  late final _scopeNameCtrl = TextEditingController(text: widget.existing?.scopeName ?? '');
  late final _contactCtrl = TextEditingController(text: widget.existing?.contactNumber ?? '');

  late String _roleCode = widget.existing?.roleCode ?? _roleOptions.first;
  late String _scopeCode = widget.existing?.scopeCode ?? _scopeOptions.first;

  bool _isSaving = false;
  String? _error;
  bool _obscurePassword = true;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _employeeIdCtrl.dispose();
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _scopeNameCtrl.dispose();
    _contactCtrl.dispose();
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
        await _repo.updateUser(
          widget.existing!.id,
          fullName: _fullNameCtrl.text.trim(),
          roleCode: _roleCode,
          scopeCode: _scopeCode,
          scopeName: _scopeNameCtrl.text.trim(),
          contactNumber: _contactCtrl.text.trim(),
          password: _passwordCtrl.text.isEmpty ? null : _passwordCtrl.text,
        );
      } else {
        await _repo.createUser(
          employeeId: _employeeIdCtrl.text.trim(),
          fullName: _fullNameCtrl.text.trim(),
          username: _usernameCtrl.text.trim(),
          password: _passwordCtrl.text,
          roleCode: _roleCode,
          scopeCode: _scopeCode,
          scopeName: _scopeNameCtrl.text.trim(),
          contactNumber: _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      showAdminSnack(context, _isEdit ? 'User updated.' : 'User created.');
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
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(title: Text(_isEdit ? 'Edit User' : 'New User')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) ...[
                  ErrorBanner(message: _error!),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppTextField(
                  label: 'Employee ID',
                  hint: 'e.g. EMP-1042',
                  controller: _employeeIdCtrl,
                  enabled: !_isEdit, // immutable after creation
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Employee ID is required.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Full Name',
                  hint: 'e.g. Ghulam Mustafa',
                  controller: _fullNameCtrl,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Username',
                  hint: 'e.g. g.mustafa',
                  controller: _usernameCtrl,
                  enabled: !_isEdit, // backend has no username-change route
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Username is required.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: _isEdit ? 'New Password (leave blank to keep current)' : 'Password',
                  hint: 'At least 8 characters',
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    final value = v ?? '';
                    if (!_isEdit && value.length < 8) return 'Password must be at least 8 characters.';
                    if (_isEdit && value.isNotEmpty && value.length < 8) return 'Password must be at least 8 characters.';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _DropdownField(
                  label: 'Role',
                  value: _roleCode,
                  options: _roleOptions,
                  displayLabel: (c) => c,
                  onChanged: (v) => setState(() => _roleCode = v),
                ),
                const SizedBox(height: AppSpacing.md),
                _DropdownField(
                  label: 'Geographic Scope',
                  value: _scopeCode,
                  options: _scopeOptions,
                  displayLabel: (c) => c.replaceAll('_', ' '),
                  onChanged: (v) => setState(() => _scopeCode = v),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Scope Name',
                  hint: 'e.g. Multan North Sub-Division',
                  controller: _scopeNameCtrl,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Scope name is required.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Contact Number (optional)',
                  hint: 'e.g. 0300-1234892',
                  controller: _contactCtrl,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: AppStrings.adminSave,
                  isLoading: _isSaving,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final String Function(String) displayLabel;
  final ValueChanged<String> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.displayLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<String>(
          value: value,
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(displayLabel(o))))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
