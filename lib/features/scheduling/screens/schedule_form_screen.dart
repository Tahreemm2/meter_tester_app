// =============================================================================
// FILE: lib/features/scheduling/screens/schedule_form_screen.dart
// PURPOSE: Manually create a schedule entry (POST) or edit/override an
// existing one (PUT, with an override_reason when the date changes) against
// backend/api/admin/schedules.php. Supervisory roles only.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/id_picker_fields.dart';
import '../../auth/widgets/auth_widgets.dart';
import '../../admin/widgets/admin_widgets.dart';
import '../data/scheduling_repository.dart';
import '../models/schedule_models.dart';

class ScheduleFormScreen extends StatefulWidget {
  final UserModel currentUser;
  final ScheduleEntry? existing;

  const ScheduleFormScreen({super.key, required this.currentUser, this.existing});

  bool get isEditing => existing != null;

  @override
  State<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends State<ScheduleFormScreen> {
  late final SchedulingRepository _repo = ApiSchedulingRepository(token: widget.currentUser.token);
  final _reasonCtrl = TextEditingController();

  int? _consumerId;
  late String _quarter = widget.existing?.quarter ?? upcomingQuarters().first;
  late String _category = widget.existing?.category ?? kConsumerCategories.first;
  late DateTime? _scheduledDate = _tryParseDate(widget.existing?.scheduledDate);
  late ScheduleStatus _status = widget.existing?.status ?? ScheduleStatus.pending;

  bool _isSaving = false;
  String? _error;

  static DateTime? _tryParseDate(String? raw) => raw == null ? null : DateTime.tryParse(raw);

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_scheduledDate == null) return false;
    if (!widget.isEditing) return _consumerId != null;
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      setState(() => _error = widget.isEditing
          ? 'Select a scheduled date.'
          : 'Select a consumer and a scheduled date.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final dateStr = _scheduledDate!.toIso8601String().split('T').first;
      if (widget.isEditing) {
        await _repo.updateSchedule(
          widget.existing!.id,
          scheduledDate: dateStr,
          status: _status.code,
          category: _category,
          overrideReason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
        );
      } else {
        await _repo.createSchedule(
          consumerId: _consumerId!,
          quarter: _quarter,
          scheduledDate: dateStr,
          category: _category,
        );
      }
      if (!mounted) return;
      showAdminSnack(context, widget.isEditing ? 'Schedule entry updated.' : 'Schedule entry created.');
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
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Schedule Entry' : AppStrings.schedulingAddManual)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: AppSpacing.md),
              ],
              if (widget.isEditing) ...[
                Text(widget.existing!.consumerName, style: AppTextStyles.headingMedium),
                const SizedBox(height: 2),
                Text(
                  '${widget.existing!.referenceNumber} · ${widget.existing!.meterId}',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
              ] else ...[
                ConsumerIdField(
                  currentUser: widget.currentUser,
                  onChanged: (id) => setState(() => _consumerId = id),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Quarter', style: AppTextStyles.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: _quarter,
                  items: upcomingQuarters(count: 6).map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
                  onChanged: (v) => setState(() => _quarter = v ?? _quarter),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text('Category', style: AppTextStyles.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: _category,
                items: kConsumerCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Scheduled Date', style: AppTextStyles.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(_scheduledDate == null
                    ? 'Select date'
                    : _scheduledDate!.toIso8601String().split('T').first),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _scheduledDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked != null) setState(() => _scheduledDate = picked);
                },
              ),
              if (widget.isEditing) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Status', style: AppTextStyles.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<ScheduleStatus>(
                  initialValue: _status,
                  items: ScheduleStatus.values
                      .where((s) => s != ScheduleStatus.unknown)
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.displayLabel)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Override Reason (recommended if changing the date)',
                  hint: 'e.g. Consumer requested reschedule',
                  controller: _reasonCtrl,
                  textInputAction: TextInputAction.done,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: widget.isEditing ? AppStrings.adminSave : AppStrings.schedulingAddManual,
                isLoading: _isSaving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
