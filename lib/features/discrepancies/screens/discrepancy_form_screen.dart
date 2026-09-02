// =============================================================================
// FILE: lib/features/discrepancies/screens/discrepancy_form_screen.dart
// PURPOSE: Report a new discrepancy (POST /api/discrepancies.php). Open to
// any authenticated role. The consumer is identified by reference number
// (the same lookup pattern used on the Inspection form), optionally linked
// to a specific inspection ID.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/widgets/auth_widgets.dart';
import '../../admin/widgets/admin_widgets.dart';
import '../data/discrepancies_repository.dart';
import '../models/discrepancy_models.dart';

class DiscrepancyFormScreen extends StatefulWidget {
  final UserModel currentUser;
  const DiscrepancyFormScreen({super.key, required this.currentUser});

  @override
  State<DiscrepancyFormScreen> createState() => _DiscrepancyFormScreenState();
}

class _DiscrepancyFormScreenState extends State<DiscrepancyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final DiscrepanciesRepository _repo = ApiDiscrepanciesRepository(token: widget.currentUser.token);

  final _refCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _inspectionIdCtrl = TextEditingController();

  String _type = kDiscrepancyTypes.first;
  String _severity = kDiscrepancySeverities.first;

  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _refCtrl.dispose();
    _descriptionCtrl.dispose();
    _inspectionIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await _repo.reportDiscrepancy(
        referenceNumber: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        inspectionId: int.tryParse(_inspectionIdCtrl.text.trim()),
        type: _type,
        description: _descriptionCtrl.text.trim(),
        severity: _severity,
      );
      if (!mounted) return;
      showAdminSnack(context, 'Discrepancy reported.');
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
      appBar: AppBar(title: const Text(AppStrings.discrepanciesReportNew)),
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
                  label: 'Reference Number (optional)',
                  hint: 'e.g. REF-2025-00142',
                  controller: _refCtrl,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Linked Inspection ID (optional)',
                  hint: 'e.g. 12',
                  controller: _inspectionIdCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                _DropdownField(
                  label: 'Type',
                  value: _type,
                  options: kDiscrepancyTypes,
                  displayLabel: (c) => c.discrepancyTypeLabel,
                  onChanged: (v) => setState(() => _type = v),
                ),
                const SizedBox(height: AppSpacing.md),
                _DropdownField(
                  label: 'Severity',
                  value: _severity,
                  options: kDiscrepancySeverities,
                  displayLabel: (c) => '${c[0]}${c.substring(1).toLowerCase()}',
                  onChanged: (v) => setState(() => _severity = v),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Description',
                  hint: 'Describe what you observed...',
                  controller: _descriptionCtrl,
                  textInputAction: TextInputAction.done,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'A description is required.' : null,
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: AppStrings.discrepanciesReportNew,
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
          initialValue: value,
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(displayLabel(o)))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
