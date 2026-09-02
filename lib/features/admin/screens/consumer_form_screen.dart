// =============================================================================
// FILE: lib/features/admin/screens/consumer_form_screen.dart
// PURPOSE: Create or edit a consumer/meter record.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/widgets/auth_widgets.dart';
import '../data/admin_repository.dart';
import '../models/admin_models.dart';
import '../widgets/admin_widgets.dart';

class ConsumerFormScreen extends StatefulWidget {
  final String token;
  final ManagedConsumer? existing;

  const ConsumerFormScreen({super.key, required this.token, this.existing});

  @override
  State<ConsumerFormScreen> createState() => _ConsumerFormScreenState();
}

class _ConsumerFormScreenState extends State<ConsumerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AdminRepository _repo = ApiAdminRepository(token: widget.token);

  late final _refCtrl = TextEditingController(text: widget.existing?.referenceNumber ?? '');
  late final _meterIdCtrl = TextEditingController(text: widget.existing?.meterId ?? '');
  late final _nameCtrl = TextEditingController(text: widget.existing?.consumerName ?? '');
  late final _addressCtrl = TextEditingController(text: widget.existing?.consumerAddress ?? '');
  late final _accountCtrl = TextEditingController(text: widget.existing?.consumerAccount ?? '');
  late final _tariffCtrl = TextEditingController(text: widget.existing?.tariffCategory ?? '');
  late final _loadCtrl = TextEditingController(text: widget.existing?.sanctionedLoad ?? '');

  bool _isSaving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _refCtrl.dispose();
    _meterIdCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _accountCtrl.dispose();
    _tariffCtrl.dispose();
    _loadCtrl.dispose();
    super.dispose();
  }

  String? _required(String? v, String label) => (v == null || v.trim().isEmpty) ? '$label is required.' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await _repo.updateConsumer(
          widget.existing!.id,
          referenceNumber: _refCtrl.text.trim(),
          meterId: _meterIdCtrl.text.trim(),
          consumerName: _nameCtrl.text.trim(),
          consumerAddress: _addressCtrl.text.trim(),
          consumerAccount: _accountCtrl.text.trim(),
          tariffCategory: _tariffCtrl.text.trim(),
          sanctionedLoad: _loadCtrl.text.trim(),
        );
      } else {
        await _repo.createConsumer(
          referenceNumber: _refCtrl.text.trim(),
          meterId: _meterIdCtrl.text.trim(),
          consumerName: _nameCtrl.text.trim(),
          consumerAddress: _addressCtrl.text.trim(),
          consumerAccount: _accountCtrl.text.trim(),
          tariffCategory: _tariffCtrl.text.trim(),
          sanctionedLoad: _loadCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      showAdminSnack(context, _isEdit ? 'Consumer record updated.' : 'Consumer record created.');
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
      appBar: AppBar(title: Text(_isEdit ? 'Edit Consumer' : 'New Consumer')),
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
                  label: 'Reference Number',
                  hint: 'e.g. REF-2025-00142',
                  controller: _refCtrl,
                  validator: (v) => _required(v, 'Reference number'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Meter ID',
                  hint: 'e.g. MTR-LHR-2024-00987',
                  controller: _meterIdCtrl,
                  validator: (v) => _required(v, 'Meter ID'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Consumer Name',
                  hint: 'e.g. Haji Textile Mills (Pvt) Ltd.',
                  controller: _nameCtrl,
                  validator: (v) => _required(v, 'Consumer name'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Consumer Address',
                  hint: 'e.g. Plot 14-B, SITE Area, Lahore',
                  controller: _addressCtrl,
                  validator: (v) => _required(v, 'Consumer address'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Consumer Account',
                  hint: 'e.g. LHR-04-2200-1429',
                  controller: _accountCtrl,
                  validator: (v) => _required(v, 'Consumer account'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Tariff Category',
                  hint: 'e.g. Industrial B-2',
                  controller: _tariffCtrl,
                  validator: (v) => _required(v, 'Tariff category'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Sanctioned Load',
                  hint: 'e.g. 250 kW',
                  controller: _loadCtrl,
                  validator: (v) => _required(v, 'Sanctioned load'),
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(label: AppStrings.adminSave, isLoading: _isSaving, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
