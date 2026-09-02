// =============================================================================
// FILE: lib/features/inspection/widgets/inspection_widgets.dart
// PURPOSE: Shared reusable UI components for the Smart Inspection Form.
//          All widgets are stateless and receive data/callbacks as parameters.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_theme.dart';
import '../config/inspection_config.dart';

// =============================================================================
// WIDGET: FormSectionCard
// Wraps a group of related fields in a titled card with consistent styling.
// =============================================================================
class FormSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color? accentColor;

  const FormSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.primaryGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card),
              ),
              border: Border(
                bottom: BorderSide(color: accent.withOpacity(0.15), width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: accent,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WIDGET: FormTextField
// Standardised text input with mandatory indicator, error state, read-only mode.
// Sized generously for outdoor/field use (min height 52px).
// =============================================================================
class FormTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool isRequired;
  final bool readOnly;
  final bool isAutoFilled; // Shows "Auto-filled" badge instead of mandatory *
  final String? errorText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int minLines;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;
  final bool enabled;

  const FormTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.isRequired = false,
    this.readOnly = false,
    this.isAutoFilled = false,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines = 1,
    this.suffixIcon,
    this.prefixIcon,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  color: readOnly
                      ? AppColors.textHint
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (isRequired && !readOnly && !isAutoFilled)
              Text(
                ' *',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.errorRed,
                ),
              ),
            if (isAutoFilled) _AutoFilledBadge(),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),

        // Input field
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          enabled: enabled && !readOnly,
          onChanged: onChanged,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          minLines: minLines,
          textInputAction: textInputAction,
          style: AppTextStyles.bodyMedium.copyWith(
            color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
            errorText: errorText,
            filled: true,
            fillColor: readOnly
                ? AppColors.surfaceMuted
                : (errorText != null
                      ? AppColors.errorRed.withOpacity(0.03)
                      : AppColors.surfaceCard),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(
                color: errorText != null
                    ? AppColors.errorRed.withOpacity(0.6)
                    : AppColors.borderSubtle,
                width: errorText != null ? 1.5 : 1,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: const BorderSide(
                color: AppColors.borderSubtle,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: 2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: const BorderSide(color: AppColors.errorRed, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(
                color: AppColors.errorRed.withOpacity(0.6),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

// =============================================================================
// WIDGET: FormDropdownField
// A styled dropdown that accepts a list of FormOption objects.
// Shows mandatory indicator and error state.
// =============================================================================
class FormDropdownField extends StatelessWidget {
  final String label;
  final String hint;
  final List<FormOption> options;
  final String? selectedCode;
  final ValueChanged<String?> onChanged;
  final bool isRequired;
  final String? errorText;

  const FormDropdownField({
    super.key,
    required this.label,
    required this.hint,
    required this.options,
    required this.selectedCode,
    required this.onChanged,
    this.isRequired = false,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.labelLarge)),
            if (isRequired)
              Text(
                ' *',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.errorRed,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),

        // Dropdown
        Container(
          decoration: BoxDecoration(
            color: errorText != null
                ? AppColors.errorRed.withOpacity(0.03)
                : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(
              color: errorText != null
                  ? AppColors.errorRed.withOpacity(0.6)
                  : AppColors.borderSubtle,
              width: errorText != null ? 1.5 : 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedCode,
              itemHeight: null,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  hint,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ),
              isExpanded: true,
              icon: const Padding(
                padding: EdgeInsets.only(right: AppSpacing.sm),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: AppColors.textHint,
                  size: 22,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              borderRadius: BorderRadius.circular(AppRadius.card),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              onChanged: onChanged,
              items: options
                  .map(
                    (opt) => DropdownMenuItem<String>(
                      value: opt.code,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 56),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              opt.label,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (opt.description != null)
                              Text(
                                opt.description!,
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),

        // Error text
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.errorRed,
                size: 13,
              ),
              const SizedBox(width: 4),
              Text(
                errorText!,
                style: const TextStyle(
                  color: AppColors.errorRed,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

// =============================================================================
// WIDGET: ReadOnlyDateTimeField
// Displays the current date/time with a clock icon. Non-editable.
// =============================================================================
class ReadOnlyDateTimeField extends StatelessWidget {
  final DateTime dateTime;
  final String label;

  const ReadOnlyDateTimeField({
    super.key,
    required this.dateTime,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('dd MMM yyyy  •  HH:mm:ss').format(dateTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textHint,
              ),
            ),
            const Spacer(),
            _AutoFilledBadge(),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: AppColors.borderSubtle, width: 1),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: AppColors.textHint,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                formatted,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

// =============================================================================
// WIDGET: FetchStatusBanner
// Shows success/error/not-found message after the auto-fetch attempt.
// =============================================================================
class FetchStatusBanner extends StatelessWidget {
  final String message;
  final bool isSuccess;
  final bool isError;

  const FetchStatusBanner({
    super.key,
    required this.message,
    this.isSuccess = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final Color text;
    final IconData icon;

    if (isSuccess) {
      bg = AppColors.successGreen.withOpacity(0.08);
      border = AppColors.successGreen.withOpacity(0.3);
      text = AppColors.successGreen;
      icon = Icons.check_circle_outline_rounded;
    } else if (isError) {
      bg = AppColors.errorRed.withOpacity(0.07);
      border = AppColors.errorRed.withOpacity(0.3);
      text = AppColors.errorRed;
      icon = Icons.error_outline_rounded;
    } else {
      bg = AppColors.warningAmber.withOpacity(0.08);
      border = AppColors.warningAmber.withOpacity(0.3);
      text = AppColors.warningAmber;
      icon = Icons.info_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: text),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: text,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WIDGET: TwoColumnRow
// Places two form fields side-by-side on wider screens.
// Useful for paired readings like TOU Peak/Off-Peak.
// =============================================================================
class TwoColumnRow extends StatelessWidget {
  final Widget left;
  final Widget right;

  const TwoColumnRow({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: right),
      ],
    );
  }
}

// =============================================================================
// WIDGET: MandatoryNote
// Small legend displayed at the top of the form.
// =============================================================================
class MandatoryNote extends StatelessWidget {
  const MandatoryNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '* ',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.errorRed,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              'Required fields must be completed before submission',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WIDGET: SuccessOverlay
// Full-screen success state shown after successful form submission.
// =============================================================================
class SuccessOverlay extends StatelessWidget {
  final VoidCallback onNewInspection;

  const SuccessOverlay({super.key, required this.onNewInspection});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundPage,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreenSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: AppColors.primaryGreen,
                  size: 44,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                InspectionStrings.submitSuccess,
                style: AppTextStyles.headingMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'The inspection report has been recorded and queued for upload.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onNewInspection,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Start New Inspection'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PRIVATE: Auto-filled badge
// =============================================================================
class _AutoFilledBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryGreenSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_fix_high_rounded,
            size: 10,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: 3),
          Text(
            InspectionStrings.readOnlyBadge,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primaryGreen,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// NUMERIC INPUT FORMATTER — restricts input to decimal numbers only
// =============================================================================
class DecimalInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow empty, digits, and single decimal point
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    // Regex: optional digits, optional single dot, optional digits
    if (RegExp(r'^\d*\.?\d*$').hasMatch(text)) {
      return newValue;
    }
    return oldValue; // Reject invalid input
  }
}
