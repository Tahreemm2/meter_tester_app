// =============================================================================
// FILE: lib/features/auth/screens/otp_screen.dart
// PURPOSE: Screen 2 — First-Time Login OTP Verification Screen
//
// Displays when AuthBloc emits AuthOtpRequired state.
// Features:
//   - 6-box separated PIN entry
//   - "Verify & Proceed" button with loading state
//   - Resend OTP link with 60-second cooldown timer
//   - Auto-submit when all 6 digits are entered
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_widgets.dart';
import '../../home/screens/home_shell_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // Current OTP value — updated as user types
  String _currentOtp = '';

  // Key to imperatively clear OTP boxes on error
  final _otpFieldKey = GlobalKey<_OtpInputFieldState>();

  // ---------------------------------------------------------------------------
  // SUBMIT
  // ---------------------------------------------------------------------------
  void _onVerifyPressed() {
    if (_currentOtp.length < 6) return;
    FocusScope.of(context).unfocus();

    context.read<AuthBloc>().add(OtpSubmitted(otpCode: _currentOtp));
  }

  void _onOtpChanged(String otp) {
    setState(() => _currentOtp = otp);
    // Auto-submit when all 6 digits are entered
    if (otp.length == 6) {
      Future.microtask(_onVerifyPressed);
    }
  }

  void _onResendPressed() {
    context.read<AuthBloc>().add(const OtpResendRequested());
    _currentOtp = '';
    // Note: OtpInputField clear is handled via key in a real implementation
    // For simplicity, user can re-enter. Add GlobalKey<OtpInputFieldState>
    // if you want programmatic clear.
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------
  void _handleStateChange(BuildContext context, AuthState state) {
    if (state is AuthAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShellScreen()),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: _handleStateChange,
      child: Scaffold(
        backgroundColor: AppColors.backgroundPage,
        // Back button returns to Login (clears bloc state)
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textSecondary, size: 20),
            onPressed: () {
              context.read<AuthBloc>().add(const LogoutRequested());
              Navigator.of(context).pop();
            },
          ),
        ),
        body: SafeArea(
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              // Guard: only render if in OTP state
              if (state is! AuthOtpRequired) {
                return const Center(child: CircularProgressIndicator());
              }

              final otpState = state;
              final isLoading = otpState.isLoading;
              final cooldown = otpState.cooldownSeconds;
              final canResend = cooldown <= 0;
              final errorMsg = otpState.errorMessage;
              final contact = otpState.pendingUser.contactMasked;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Icon Header ──────────────────────────────────────
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreenSurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: AppColors.primaryGreen,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Title ────────────────────────────────────────────
                    Text(
                      AppStrings.otpTitle,
                      style: AppTextStyles.displayLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      AppStrings.otpSubtitle,
                      style: AppTextStyles.bodyMedium,
                    ),

                    // ── Contact indicator ────────────────────────────────
                    if (contact != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      RichText(
                        text: TextSpan(
                          text: AppStrings.otpSentTo,
                          style: AppTextStyles.bodySmall,
                          children: [
                            TextSpan(
                              text: contact,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xl),

                    // ── OTP Card ─────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border:
                            Border.all(color: AppColors.borderSubtle, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.textPrimary.withOpacity(0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── OTP label ──────────────────────────────────
                          Text(
                            AppStrings.otpInputLabel,
                            style: AppTextStyles.labelLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // ── 6-box OTP input ────────────────────────────
                          OtpInputField(
                            length: 6,
                            onCompleted: _onOtpChanged,
                            enabled: !isLoading,
                          ),

                          // ── Error message ──────────────────────────────
                          if (errorMsg != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            ErrorBanner(message: errorMsg),
                          ],

                          const SizedBox(height: AppSpacing.xl),

                          // ── Verify button ──────────────────────────────
                          PrimaryButton(
                            label: AppStrings.otpVerifyButton,
                            onPressed: (_currentOtp.length == 6 && !isLoading)
                                ? _onVerifyPressed
                                : null,
                            isLoading: isLoading,
                            loadingLabel: AppStrings.otpLoadingLabel,
                          ),

                          const SizedBox(height: AppSpacing.lg),
                          const SectionDivider(),

                          // ── Resend OTP link with cooldown ──────────────
                          Center(
                            child: canResend
                                ? TextButton.icon(
                                    onPressed: _onResendPressed,
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 16,
                                      color: AppColors.primaryGreenLight,
                                    ),
                                    label: Text(
                                      AppStrings.otpResendActive,
                                      style: AppTextStyles.linkText,
                                    ),
                                  )
                                : _ResendCooldown(seconds: cooldown),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Dev hint ─────────────────────────────────────────
                    _DevOtpHint(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PRIVATE: Resend Cooldown Display
// =============================================================================
class _ResendCooldown extends StatelessWidget {
  final int seconds;

  const _ResendCooldown({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.timer_outlined,
          size: 14,
          color: AppColors.textHint,
        ),
        const SizedBox(width: 4),
        Text(
          '${AppStrings.otpResendCooldown}$seconds${AppStrings.otpResendSuffix}',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// PRIVATE: Developer PIN hint (remove in production)
// =============================================================================
class _DevOtpHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentGoldLight,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border:
            Border.all(color: AppColors.accentGold.withOpacity(0.4), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.developer_mode,
              color: AppColors.accentGold, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'DEV: OTP is server-generated (not fixed). SMS delivery isn\'t\n'
              'wired up yet — check the otp_code column on the users table,\n'
              'or the "Resend OTP" response in Postman, to get the current code.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.accentGold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Expose internal state for programmatic control (clear on error, etc.)
class _OtpInputFieldState extends State<OtpInputField> {
  // @override
  // Widget build(BuildContext context) => widget.build(context);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // your OTP UI here
        TextField(
          maxLength: 6,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}
