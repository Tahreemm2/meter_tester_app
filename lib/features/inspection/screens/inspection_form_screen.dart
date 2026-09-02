// =============================================================================
// FILE: lib/features/inspection/screens/inspection_form_screen.dart
// PURPOSE: Screen — Smart Field Data Collection Form (Module 2)
//
// Structure:
//   InspectionFormScreen
//   └── BlocProvider<InspectionBloc>
//       └── _FormBody                       ← scrollable form content
//           ├── _FetchSection               ← Section 1: Reference lookup
//           ├── _AutoPopulatedSection       ← Section 2: Read-only fields
//           ├── _ReadingsSection            ← Section 3: KWH/KVARH/MDI + Load
//           ├── _TouSection                 ← Section 4: TOU readings
//           ├── _InfraSection               ← Section 5: Dropdowns
//           ├── _GpsSection                 ← Section 6: Mandatory GPS capture
//           ├── _ImagesSection              ← Section 7: 2-12 geo-tagged photos
//           └── _SubmitSection              ← Submit & Clear buttons
//
// State flows through BlocBuilder — no direct setState calls in this screen.
// All user actions dispatch InspectionEvents to InspectionBloc.
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_theme.dart';
import '../config/inspection_config.dart';
import '../bloc/inspection_bloc.dart';
import '../bloc/inspection_models.dart';
import '../widgets/inspection_widgets.dart';

// =============================================================================
// ENTRY POINT — wraps screen with its own BlocProvider
// Call this from HomeShell or a navigation action.
// =============================================================================
class InspectionFormScreen extends StatelessWidget {
  /// Set when opened from TaskDetailScreen's "Start Inspection" action —
  /// pre-fills the reference number, triggers the auto-fetch immediately,
  /// and links the submission to [taskId] so the backend marks that task
  /// (and its schedule) COMPLETED on submit.
  final String? initialReferenceNumber;
  final int? taskId;

  const InspectionFormScreen({super.key, this.initialReferenceNumber, this.taskId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InspectionBloc(
        initialReferenceNumber: initialReferenceNumber,
        initialTaskId: taskId,
      ),
      child: const _InspectionFormView(),
    );
  }
}

// =============================================================================
// VIEW — contains scaffold, appbar, and the form body
// =============================================================================
class _InspectionFormView extends StatefulWidget {
  const _InspectionFormView();

  @override
  State<_InspectionFormView> createState() => _InspectionFormViewState();
}

class _InspectionFormViewState extends State<_InspectionFormView> {
  @override
  void initState() {
    super.initState();
    // GPS is mandatory server-side (see backend/api/data.php). Kick off the
    // capture once the form is actually on screen, rather than as a bloc
    // construction side-effect — keeps InspectionBloc side-effect-free to
    // construct (important for tests) and only prompts for location
    // permission when the user is actually looking at the form.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<InspectionBloc>().add(const GpsCaptureRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: _buildAppBar(context),
      body: BlocBuilder<InspectionBloc, InspectionState>(
        builder: (context, state) {
          // Show success overlay when form is submitted
          if (state.formData.isSubmitted) {
            return SuccessOverlay(
              onNewInspection: () => context.read<InspectionBloc>().add(
                const FormClearRequested(),
              ),
            );
          }
          return const _FormBody();
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Column(
        children: [
          const Text(InspectionStrings.pageTitle),
          Text(
            InspectionStrings.pageSubtitle,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Colors.white70,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
      actions: [
        BlocBuilder<InspectionBloc, InspectionState>(
          builder: (context, state) {
            return IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: InspectionStrings.clearFormButton,
              onPressed: state.formData.isSubmitting
                  ? null
                  : () => _confirmClear(context),
            );
          },
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: Text(
          InspectionStrings.clearFormButton,
          style: AppTextStyles.headingMedium,
        ),
        content: Text(
          InspectionStrings.clearFormConfirm,
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(InspectionStrings.clearFormCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              minimumSize: const Size(80, 40),
            ),
            child: Text(
              InspectionStrings.clearFormOk,
              style: AppTextStyles.buttonLabel.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<InspectionBloc>().add(const FormClearRequested());
    }
  }
}

// =============================================================================
// FORM BODY — the scrollable container that holds all sections
// =============================================================================
class _FormBody extends StatelessWidget {
  const _FormBody();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MandatoryNote(),
          const SizedBox(height: AppSpacing.sm),

          // Section 1: Reference lookup + auto-fetch
          const _FetchSection(),

          // Section 2: Read-only auto-populated fields
          const _AutoPopulatedSection(),

          // Section 3: Technical readings
          const _ReadingsSection(),

          // Section 4: TOU data
          const _TouSection(),

          // Section 5: Infrastructure dropdowns
          const _InfraSection(),

          // Section 6: GPS location verification (mandatory)
          const _GpsSection(),

          // Section 7: Photo evidence (2-12 geo-tagged images, mandatory)
          const _ImagesSection(),

          // Submit
          const _SubmitSection(),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION 1: Reference Lookup + Auto-Fetch
// =============================================================================
class _FetchSection extends StatefulWidget {
  const _FetchSection();

  @override
  State<_FetchSection> createState() => _FetchSectionState();
}

class _FetchSectionState extends State<_FetchSection> {
  final _refController = TextEditingController();

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InspectionBloc, InspectionState>(
      buildWhen: (prev, curr) =>
          prev.formData.referenceNumber != curr.formData.referenceNumber ||
          prev.formData.fetchStatus != curr.formData.fetchStatus ||
          prev.formData.fetchMessage != curr.formData.fetchMessage,
      builder: (context, state) {
        final isFetching = state.formData.isFetching;
        final fetchStatus = state.formData.fetchStatus;
        final fetchMessage = state.formData.fetchMessage;

        // Sync controller text if form was cleared externally
        if (_refController.text != state.formData.referenceNumber) {
          _refController.text = state.formData.referenceNumber;
        }

        return FormSectionCard(
          title: InspectionStrings.sectionFetch,
          icon: Icons.search_rounded,
          children: [
            // ── Reference number input ──────────────────────────────────────
            FormTextField(
              label: InspectionStrings.refNumberLabel,
              hint: InspectionStrings.refNumberHint,
              controller: _refController,
              isRequired: true,
              enabled: !isFetching,
              onChanged: (v) =>
                  context.read<InspectionBloc>().add(ReferenceNumberChanged(v)),
              suffixIcon: state.formData.referenceNumber.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.textHint,
                      ),
                      onPressed: isFetching
                          ? null
                          : () {
                              _refController.clear();
                              context.read<InspectionBloc>().add(
                                const ReferenceNumberChanged(''),
                              );
                            },
                    )
                  : null,
            ),

            // ── Auto-Fetch button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed:
                    (isFetching ||
                        state.formData.referenceNumber.trim().isEmpty)
                    ? null
                    : () => context.read<InspectionBloc>().add(
                        const FetchConsumerRequested(),
                      ),
                icon: isFetching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.cloud_download_outlined, size: 18),
                label: Text(
                  isFetching
                      ? InspectionStrings.fetchingLabel
                      : InspectionStrings.fetchButton,
                  style: AppTextStyles.buttonLabel,
                ),
              ),
            ),

            // ── Fetch status banner ────────────────────────────────────────
            if (fetchMessage != null && fetchMessage.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              FetchStatusBanner(
                message: fetchMessage,
                isSuccess: fetchStatus == FetchStatus.success,
                isError:
                    fetchStatus == FetchStatus.error ||
                    fetchStatus == FetchStatus.notFound,
              ),
            ],

            // ── Dev hint ───────────────────────────────────────────────────
            _DevRefHint(),
          ],
        );
      },
    );
  }
}

// =============================================================================
// SECTION 2: Auto-Populated Read-Only Fields
// =============================================================================
class _AutoPopulatedSection extends StatefulWidget {
  const _AutoPopulatedSection();

  @override
  State<_AutoPopulatedSection> createState() => _AutoPopulatedSectionState();
}

class _AutoPopulatedSectionState extends State<_AutoPopulatedSection> {
  final _meterIdCtrl = TextEditingController();
  final _consumerCtrl = TextEditingController();

  @override
  void dispose() {
    _meterIdCtrl.dispose();
    _consumerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InspectionBloc, InspectionState>(
      buildWhen: (prev, curr) =>
          prev.formData.meterId != curr.formData.meterId ||
          prev.formData.consumerDetails != curr.formData.consumerDetails ||
          prev.formData.inspectionDateTime !=
              curr.formData.inspectionDateTime ||
          prev.formData.fetchStatus != curr.formData.fetchStatus,
      builder: (context, state) {
        final data = state.formData;
        _meterIdCtrl.text = data.meterId;
        _consumerCtrl.text = data.consumerDetails;

        return FormSectionCard(
          title: InspectionStrings.sectionAutoData,
          icon: Icons.person_outline_rounded,
          children: [
            FormTextField(
              label: InspectionStrings.meterIdLabel,
              hint: InspectionStrings.meterIdHint,
              controller: _meterIdCtrl,
              readOnly: true,
              isAutoFilled: data.isFetched,
              prefixIcon: const Icon(
                Icons.electric_meter_outlined,
                color: AppColors.textHint,
                size: 18,
              ),
            ),
            FormTextField(
              label: InspectionStrings.consumerLabel,
              hint: InspectionStrings.consumerHint,
              controller: _consumerCtrl,
              readOnly: true,
              isAutoFilled: data.isFetched,
              maxLines: 2,
              minLines: 2,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.lg),
                child: Icon(
                  Icons.business_outlined,
                  color: AppColors.textHint,
                  size: 18,
                ),
              ),
            ),
            ReadOnlyDateTimeField(
              dateTime: data.inspectionDateTime,
              label: InspectionStrings.dateTimeLabel,
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// SECTION 3: Technical Readings (KWH, KVARH, MDI + Load Details)
// =============================================================================
class _ReadingsSection extends StatefulWidget {
  const _ReadingsSection();

  @override
  State<_ReadingsSection> createState() => _ReadingsSectionState();
}

class _ReadingsSectionState extends State<_ReadingsSection> {
  final _kwhCtrl = TextEditingController();
  final _kvarhCtrl = TextEditingController();
  final _mdiCtrl = TextEditingController();
  final _loadCtrl = TextEditingController();

  @override
  void dispose() {
    _kwhCtrl.dispose();
    _kvarhCtrl.dispose();
    _mdiCtrl.dispose();
    _loadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InspectionBloc, InspectionState>(
      buildWhen: (prev, curr) =>
          prev.formData.kwh != curr.formData.kwh ||
          prev.formData.kvarh != curr.formData.kvarh ||
          prev.formData.mdi != curr.formData.mdi ||
          prev.formData.loadDetails != curr.formData.loadDetails ||
          prev.validationErrors != curr.validationErrors,
      builder: (context, state) {
        final errors = state.showValidationErrors ? state.validationErrors : {};
        final bloc = context.read<InspectionBloc>();

        // Sync controllers if form was cleared
        if (_kwhCtrl.text != state.formData.kwh)
          _kwhCtrl.text = state.formData.kwh;
        if (_kvarhCtrl.text != state.formData.kvarh)
          _kvarhCtrl.text = state.formData.kvarh;
        if (_mdiCtrl.text != state.formData.mdi)
          _mdiCtrl.text = state.formData.mdi;

        return FormSectionCard(
          title: InspectionStrings.sectionReadings,
          icon: Icons.speed_rounded,
          children: [
            // KWH
            FormTextField(
              label: InspectionStrings.kwhLabel,
              hint: InspectionStrings.kwhHint,
              controller: _kwhCtrl,
              isRequired: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [DecimalInputFormatter()],
              errorText: errors[InspectionField.kwh.name],
              onChanged: (v) =>
                  bloc.add(FieldValueChanged(InspectionField.kwh, v)),
              prefixIcon: const Icon(
                Icons.bolt_rounded,
                color: AppColors.textHint,
                size: 18,
              ),
            ),

            // KVARH
            FormTextField(
              label: InspectionStrings.kvarhLabel,
              hint: InspectionStrings.kvarhHint,
              controller: _kvarhCtrl,
              isRequired: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [DecimalInputFormatter()],
              errorText: errors[InspectionField.kvarh.name],
              onChanged: (v) =>
                  bloc.add(FieldValueChanged(InspectionField.kvarh, v)),
              prefixIcon: const Icon(
                Icons.electric_bolt_outlined,
                color: AppColors.textHint,
                size: 18,
              ),
            ),

            // MDI
            FormTextField(
              label: InspectionStrings.mdiLabel,
              hint: InspectionStrings.mdiHint,
              controller: _mdiCtrl,
              isRequired: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [DecimalInputFormatter()],
              errorText: errors[InspectionField.mdi.name],
              onChanged: (v) =>
                  bloc.add(FieldValueChanged(InspectionField.mdi, v)),
              prefixIcon: const Icon(
                Icons.trending_up_rounded,
                color: AppColors.textHint,
                size: 18,
              ),
            ),

            // Load Details (free text)
            // Load Details (free text)
            FormTextField(
              label: InspectionStrings.loadDetailsLabel,
              hint: InspectionStrings.loadDetailsHint,
              controller: _loadCtrl,
              maxLines: 3,
              minLines: 2,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onChanged: (v) =>
                  bloc.add(FieldValueChanged(InspectionField.loadDetails, v)),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.xl),
                child: Icon(
                  Icons.notes_rounded,
                  color: AppColors.textHint,
                  size: 18,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// SECTION 4: TOU (Time of Use) Readings
// =============================================================================
class _TouSection extends StatefulWidget {
  const _TouSection();

  @override
  State<_TouSection> createState() => _TouSectionState();
}

class _TouSectionState extends State<_TouSection> {
  final _peakCtrl = TextEditingController();
  final _offPeakCtrl = TextEditingController();
  final _dayCtrl = TextEditingController();
  final _nightCtrl = TextEditingController();

  @override
  void dispose() {
    _peakCtrl.dispose();
    _offPeakCtrl.dispose();
    _dayCtrl.dispose();
    _nightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InspectionBloc, InspectionState>(
      buildWhen: (prev, curr) =>
          prev.formData.touPeak != curr.formData.touPeak ||
          prev.formData.touOffPeak != curr.formData.touOffPeak ||
          prev.formData.touDay != curr.formData.touDay ||
          prev.formData.touNight != curr.formData.touNight ||
          prev.validationErrors != curr.validationErrors,
      builder: (context, state) {
        final errors = state.showValidationErrors ? state.validationErrors : {};
        final bloc = context.read<InspectionBloc>();

        // Sync on clear
        if (_peakCtrl.text != state.formData.touPeak)
          _peakCtrl.text = state.formData.touPeak;
        if (_offPeakCtrl.text != state.formData.touOffPeak)
          _offPeakCtrl.text = state.formData.touOffPeak;
        if (_dayCtrl.text != state.formData.touDay)
          _dayCtrl.text = state.formData.touDay;
        if (_nightCtrl.text != state.formData.touNight)
          _nightCtrl.text = state.formData.touNight;

        final numFormatter = [DecimalInputFormatter()];
        const numKb = TextInputType.numberWithOptions(decimal: true);

        return FormSectionCard(
          title: InspectionStrings.sectionTou,
          icon: Icons.access_time_rounded,
          children: [
            // Peak / Off-Peak on same row
            TwoColumnRow(
              left: FormTextField(
                label: InspectionStrings.touPeakLabel,
                hint: '0.00',
                controller: _peakCtrl,
                keyboardType: numKb,
                inputFormatters: numFormatter,
                errorText: errors[InspectionField.touPeak.name],
                onChanged: (v) =>
                    bloc.add(FieldValueChanged(InspectionField.touPeak, v)),
              ),
              right: FormTextField(
                label: InspectionStrings.touOffPeakLabel,
                hint: '0.00',
                controller: _offPeakCtrl,
                keyboardType: numKb,
                inputFormatters: numFormatter,
                errorText: errors[InspectionField.touOffPeak.name],
                onChanged: (v) =>
                    bloc.add(FieldValueChanged(InspectionField.touOffPeak, v)),
              ),
            ),

            // Day / Night on same row
            TwoColumnRow(
              left: FormTextField(
                label: InspectionStrings.touDayLabel,
                hint: '0.00',
                controller: _dayCtrl,
                keyboardType: numKb,
                inputFormatters: numFormatter,
                onChanged: (v) =>
                    bloc.add(FieldValueChanged(InspectionField.touDay, v)),
              ),
              right: FormTextField(
                label: InspectionStrings.touNightLabel,
                hint: '0.00',
                controller: _nightCtrl,
                keyboardType: numKb,
                inputFormatters: numFormatter,
                onChanged: (v) =>
                    bloc.add(FieldValueChanged(InspectionField.touNight, v)),
              ),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// SECTION 5: Infrastructure Dropdowns
// =============================================================================
class _InfraSection extends StatelessWidget {
  const _InfraSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InspectionBloc, InspectionState>(
      buildWhen: (prev, curr) =>
          prev.formData.sealConditionCode != curr.formData.sealConditionCode ||
          prev.formData.ctPtBoxStatusCode != curr.formData.ctPtBoxStatusCode ||
          prev.validationErrors != curr.validationErrors,
      builder: (context, state) {
        final errors = state.showValidationErrors ? state.validationErrors : {};
        final bloc = context.read<InspectionBloc>();
        final config = bloc.optionsConfig;

        return FormSectionCard(
          title: InspectionStrings.sectionInfra,
          icon: Icons.electrical_services_rounded,
          children: [
            FormDropdownField(
              label: InspectionStrings.sealConditionLabel,
              hint: InspectionStrings.sealConditionHint,
              options: config.sealConditions,
              selectedCode: state.formData.sealConditionCode,
              isRequired: true,
              errorText: errors[InspectionDropdown.sealCondition.name],
              onChanged: (code) => bloc.add(
                DropdownChanged(InspectionDropdown.sealCondition, code),
              ),
            ),
            FormDropdownField(
              label: InspectionStrings.ctPtBoxLabel,
              hint: InspectionStrings.ctPtBoxHint,
              options: config.ctPtBoxStatuses,
              selectedCode: state.formData.ctPtBoxStatusCode,
              isRequired: true,
              errorText: errors[InspectionDropdown.ctPtBox.name],
              onChanged: (code) =>
                  bloc.add(DropdownChanged(InspectionDropdown.ctPtBox, code)),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// SECTION 6: GPS Location Verification (mandatory — see backend gps.* fields)
// =============================================================================
class _GpsSection extends StatelessWidget {
  const _GpsSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InspectionBloc, InspectionState>(
      buildWhen: (prev, curr) =>
          prev.formData.gpsStatus != curr.formData.gpsStatus ||
          prev.formData.gpsLatitude != curr.formData.gpsLatitude ||
          prev.formData.gpsLongitude != curr.formData.gpsLongitude ||
          prev.formData.gpsPlaceName != curr.formData.gpsPlaceName ||
          prev.formData.gpsError != curr.formData.gpsError ||
          prev.validationErrors != curr.validationErrors,
      builder: (context, state) {
        final data = state.formData;
        final bloc = context.read<InspectionBloc>();
        final showError = state.showValidationErrors && state.validationErrors['gps'] != null;

        Color statusColor;
        IconData statusIcon;
        String statusText;
        String? coordsSubtext;

        switch (data.gpsStatus) {
          case GpsStatus.loading:
            statusColor = AppColors.accentGold;
            statusIcon = Icons.gps_not_fixed_rounded;
            statusText = InspectionStrings.gpsCapturing;
            break;
          case GpsStatus.success:
            {
              statusColor = AppColors.successGreen;
              statusIcon = Icons.gps_fixed_rounded;
              final lat = data.gpsLatitude!.toStringAsFixed(6);
              final lng = data.gpsLongitude!.toStringAsFixed(6);
              final acc = data.gpsAccuracy != null ? ' (±${data.gpsAccuracy!.toStringAsFixed(0)}m)' : '';
              if (data.gpsPlaceName != null && data.gpsPlaceName!.isNotEmpty) {
                statusText = data.gpsPlaceName!;
                coordsSubtext = '$lat, $lng$acc';
              } else {
                // Reverse geocoding failed or is unavailable — coordinates
                // are still valid and were still captured successfully.
                statusText = '${InspectionStrings.gpsCapturedLabel}: $lat, $lng$acc';
                coordsSubtext = null;
              }
            }
            break;
          case GpsStatus.error:
            statusColor = AppColors.errorRed;
            statusIcon = Icons.gps_off_rounded;
            statusText = data.gpsError ?? 'Could not capture location.';
            break;
          case GpsStatus.idle:
            statusColor = AppColors.textHint;
            statusIcon = Icons.gps_not_fixed_rounded;
            statusText = InspectionStrings.gpsRequiredNote;
            break;
        }

        return FormSectionCard(
          title: InspectionStrings.sectionGps,
          icon: Icons.my_location_rounded,
          accentColor: showError ? AppColors.errorRed : null,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.gpsStatus == GpsStatus.loading)
                  const Padding(
                    padding: EdgeInsets.all(2),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentGold),
                    ),
                  )
                else
                  Icon(statusIcon, size: 20, color: statusColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: AppTextStyles.bodyMedium.copyWith(color: statusColor, fontSize: 13),
                      ),
                      if (coordsSubtext != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          coordsSubtext,
                          style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (showError) ...[
              const SizedBox(height: 4),
              Text(
                state.validationErrors['gps']!,
                style: const TextStyle(color: AppColors.errorRed, fontSize: 12),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(data.gpsStatus == GpsStatus.success ? InspectionStrings.gpsRetryButton : 'Capture Location'),
                onPressed: data.isGpsCapturing ? null : () => bloc.add(const GpsCaptureRequested()),
              ),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// SECTION 7: Photo Evidence (2-12 geo-tagged images — see backend images[])
// =============================================================================
class _ImagesSection extends StatelessWidget {
  const _ImagesSection();

  static const _typeIcons = {
    'METER': Icons.speed_outlined,
    'SEAL': Icons.verified_outlined,
    'INSTALLATION': Icons.electrical_services_rounded,
    'LOAD': Icons.cable_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InspectionBloc, InspectionState>(
      buildWhen: (prev, curr) =>
          prev.formData.images != curr.formData.images ||
          prev.formData.gpsStatus != curr.formData.gpsStatus ||
          prev.validationErrors != curr.validationErrors,
      builder: (context, state) {
        final data = state.formData;
        final bloc = context.read<InspectionBloc>();
        final showError = state.showValidationErrors && state.validationErrors['images'] != null;
        final canAddMore = data.isGpsCaptured && data.images.length < 12;

        return FormSectionCard(
          title: '${InspectionStrings.sectionImages} (${data.images.length}/12)',
          icon: Icons.photo_camera_outlined,
          accentColor: showError ? AppColors.errorRed : null,
          children: [
            Text(InspectionStrings.imagesCountNote, style: AppTextStyles.bodySmall),
            if (!data.isGpsCaptured) ...[
              const SizedBox(height: 6),
              Text(
                'Capture your GPS location above before attaching photos.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.accentGold),
              ),
            ],
            if (showError) ...[
              const SizedBox(height: 4),
              Text(
                state.validationErrors['images']!,
                style: const TextStyle(color: AppColors.errorRed, fontSize: 12),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),

            // Per-type capture buttons
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: kInspectionImageTypes.map((type) {
                return _ImageTypeButton(
                  type: type,
                  icon: _typeIcons[type] ?? Icons.image_outlined,
                  enabled: canAddMore,
                  onCamera: () => bloc.add(ImageCaptureRequested(type, fromCamera: true)),
                  onGallery: () => bloc.add(ImageCaptureRequested(type, fromCamera: false)),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.md),

            // Thumbnail grid
            if (data.images.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(InspectionStrings.imagesEmptyState, style: AppTextStyles.bodySmall),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 0.85,
                ),
                itemCount: data.images.length,
                itemBuilder: (context, index) {
                  final img = data.images[index];
                  return _ImageThumbnail(
                    image: img,
                    onRemove: () => bloc.add(ImageRemoved(index)),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _ImageTypeButton extends StatelessWidget {
  final String type;
  final IconData icon;
  final bool enabled;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _ImageTypeButton({
    required this.type,
    required this.icon,
    required this.enabled,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: enabled ? AppColors.primaryGreen : AppColors.textHint),
          const SizedBox(width: 4),
          Text(
            inspectionImageTypeLabel(type),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: enabled ? AppColors.textSecondary : AppColors.textHint,
            ),
          ),
          const SizedBox(width: 4),
          _MiniIconButton(icon: Icons.photo_camera_outlined, enabled: enabled, onTap: onCamera),
          _MiniIconButton(icon: Icons.photo_library_outlined, enabled: enabled, onTap: onGallery),
        ],
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _MiniIconButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: enabled ? AppColors.primaryGreen : AppColors.textHint),
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final CapturedImage image;
  final VoidCallback onRemove;

  const _ImageThumbnail({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          child: Container(
            color: AppColors.surfaceMuted,
            child: Image.memory(
              base64Decode(image.base64Data),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: AppColors.textHint),
            ),
          ),
        ),
        Positioned(
          left: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              inspectionImageTypeLabel(image.type),
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SECTION 8: Submit + validation error summary
// =============================================================================
class _SubmitSection extends StatelessWidget {
  const _SubmitSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InspectionBloc, InspectionState>(
      buildWhen: (prev, curr) =>
          prev.formData.isSubmitting != curr.formData.isSubmitting ||
          prev.formData.submitError != curr.formData.submitError ||
          prev.validationErrors != curr.validationErrors ||
          prev.showValidationErrors != curr.showValidationErrors,
      builder: (context, state) {
        final isSubmitting = state.formData.isSubmitting;
        final submitError = state.formData.submitError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Validation error summary
            if (state.showValidationErrors && state.hasErrors)
              _ValidationSummary(errors: state.validationErrors),

            // API submit error
            if (submitError != null)
              FetchStatusBanner(message: submitError, isError: true),

            // Submit button
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isSubmitting
                    ? null
                    : () => context.read<InspectionBloc>().add(
                        const FormSubmitRequested(),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  disabledBackgroundColor: AppColors.primaryGreen.withOpacity(
                    0.6,
                  ),
                ),
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.upload_rounded, size: 20),
                label: Text(
                  isSubmitting
                      ? InspectionStrings.submittingLabel
                      : InspectionStrings.submitButton,
                  style: AppTextStyles.buttonLabel,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Mandatory note reminder
            const Center(
              child: Text(
                InspectionStrings.mandatoryNote,
                style: TextStyle(color: AppColors.textHint, fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// PRIVATE: Validation error summary list
// =============================================================================
class _ValidationSummary extends StatelessWidget {
  final Map<String, String?> errors;

  const _ValidationSummary({required this.errors});

  @override
  Widget build(BuildContext context) {
    final messages = errors.values.where((v) => v != null).toList();
    if (messages.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.errorRed.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.errorRed,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Please fix ${messages.length} issue${messages.length > 1 ? "s" : ""} before submitting:',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.errorRed,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...messages.map(
            (msg) => Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                bottom: AppSpacing.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(color: AppColors.errorRed, fontSize: 13),
                  ),
                  Expanded(
                    child: Text(
                      msg!,
                      style: const TextStyle(
                        color: AppColors.errorRed,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PRIVATE: Developer reference number hint (remove before production)
// =============================================================================
class _DevRefHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.accentGoldLight,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(
          color: AppColors.accentGold.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.developer_mode,
                color: AppColors.accentGold,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'DEV: Try these reference numbers',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.accentGold,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'REF-2025-00142  •  REF-2025-00891\n'
            'REF-2025-01203  •  REF-2025-00057',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.accentGold,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
