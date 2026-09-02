// =============================================================================
// FILE: lib/features/auth/widgets/auth_widgets.dart
// PURPOSE: Shared, reusable UI components for the Auth feature.
//          Keeping widgets small and composable keeps screens clean and
//          makes individual components easy to test or swap out.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';

// =============================================================================
// WIDGET 1: GovernmentAppHeader
// Full-bleed gradient hero banner shown at the top of the login screen.
// Carries the "SECURE LOGIN" eyebrow tag, the app emblem, and branding —
// gives the login page a clear, welcoming identity above the form card.
// =============================================================================
class GovernmentAppHeader extends StatelessWidget {
  const GovernmentAppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl + AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryGreen, AppColors.primaryGreenLight],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          // ── Eyebrow tag ("login" appears at the very top of the page) ──
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.white, size: 13),
                  const SizedBox(width: 6),
                  Text(
                    AppStrings.loginEyebrow,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.white,
                      letterSpacing: 1.2,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Emblem
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.bolt_rounded, // Replace with Image.asset('assets/logo.png')
              color: AppColors.primaryGreen,
              size: 34,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            AppStrings.appName,
            style: AppTextStyles.displayLarge.copyWith(color: AppColors.white),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.xs),

          Text(
            AppStrings.appDepartment,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.white.withOpacity(0.75),
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WIDGET 2: AppTextField
// Standardized input field with large tap target for outdoor field use.
// =============================================================================
class AppTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final TextInputAction textInputAction;
  final VoidCallback? onEditingComplete;
  final bool enabled;
  final int maxLines;

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
    this.textInputAction = TextInputAction.next,
    this.onEditingComplete,
    this.enabled = true,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Field label
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.xs),

        // Input field
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          textInputAction: textInputAction,
          onEditingComplete: onEditingComplete,
          enabled: enabled,
          maxLines: obscureText ? 1 : maxLines,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// WIDGET 3: PrimaryButton
// The main CTA button — large, full-width, with loading state support.
// =============================================================================
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? loadingLabel;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.loadingLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isLoading
            ? AppColors.primaryGreen.withOpacity(0.7)
            : AppColors.primaryGreen,
        ),
        child: isLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: AppColors.white,
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  loadingLabel ?? 'Loading...',
                  style: AppTextStyles.buttonLabel,
                ),
              ],
            )
          : Text(label, style: AppTextStyles.buttonLabel),
      ),
    );
  }
}

// =============================================================================
// WIDGET 4: ErrorBanner
// Inline error message styled as a subtle warning strip.
// =============================================================================
class ErrorBanner extends StatelessWidget {
  final String message;

  const ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(
          color: AppColors.errorRed.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.errorRed,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.errorRed,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WIDGET 5: OtpInputField
// A row of 6 separated digit boxes for PIN entry.
// =============================================================================
class OtpInputField extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final bool enabled;

  const OtpInputField({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.enabled = true,
  });

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes  = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes)  { f.dispose(); }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.isNotEmpty) {
      // Auto-advance to next box
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else {
      // Auto-retreat to previous box on backspace
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }

    // Check if all boxes are filled
    final fullCode = _controllers.map((c) => c.text).join();
    if (fullCode.length == widget.length) {
      widget.onCompleted(fullCode);
    }
  }

  /// Clears all OTP boxes and focuses the first one.
  void clear() {
    for (final c in _controllers) { c.clear(); }
    _focusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (index) {
        return _OtpBox(
          controller: _focusNodes[index],
          textController: _controllers[index],
          onChanged: (val) => _onChanged(val, index),
          enabled: widget.enabled,
        );
      }),
    );
  }
}

/// A single OTP digit input box.
class _OtpBox extends StatelessWidget {
  final FocusNode controller;
  final TextEditingController textController;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const _OtpBox({
    required this.controller,
    required this.textController,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 56,
      child: TextFormField(
        controller: textController,
        focusNode: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',   // Hide the maxLength counter
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: enabled ? AppColors.surfaceCard : AppColors.surfaceMuted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.borderSubtle, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.borderSubtle, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2.5),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// =============================================================================
// WIDGET 6: SectionDivider
// A subtle horizontal rule for visual separation in cards/forms.
// =============================================================================
class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: AppColors.borderSubtle,
      thickness: 1,
      height: AppSpacing.xl,
    );
  }
}

// =============================================================================
// WIDGET 7: RoleChip
// A small tag widget for displaying the user's role label.
// =============================================================================
class RoleChip extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;

  const RoleChip({
    super.key,
    required this.label,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.primaryGreenSurface,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(
          color: AppColors.primaryGreen.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.roleTag.copyWith(
          color: textColor ?? AppColors.primaryGreen,
          fontSize: 12,
        ),
      ),
    );
  }
}
