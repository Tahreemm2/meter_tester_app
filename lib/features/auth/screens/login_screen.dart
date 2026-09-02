// =============================================================================
// FILE: lib/features/auth/screens/login_screen.dart
// PURPOSE: Screen 1 — Login Screen
//
// Connects to AuthBloc. Validates inputs locally before dispatching
// LoginSubmitted event. Routes based on resulting state:
//   AuthOtpRequired  → OtpScreen
//   AuthAuthenticated → HomeShell
//   AuthFailure       → shows inline error banner
//
// LAYOUT: a gradient hero banner ("Secure Login" eyebrow + branding) sits
// at the top of the page, with the credential card floating just below it,
// and the primary "Login" action anchored at the bottom of the form —
// so the login action is legible whether the eye lands at the top of the
// screen or the bottom.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_widgets.dart';
import 'otp_screen.dart';
import '../../home/screens/home_shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Form & controllers
  final _formKey      = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // Local UI state
  bool _passwordVisible = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // VALIDATION
  // ---------------------------------------------------------------------------
  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.validUsernameEmpty;
    }
    // Accept plain username OR email format
    final isEmail = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(value);
    final isUsername = RegExp(r'^[\w\.\-]{3,}$').hasMatch(value);
    if (!isEmail && !isUsername) {
      return AppStrings.validUsernameFormat;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return AppStrings.validPasswordEmpty;
    if (value.length < 6) return AppStrings.validPasswordLength;
    return null;
  }

  // ---------------------------------------------------------------------------
  // SUBMIT
  // ---------------------------------------------------------------------------
  void _onLoginPressed() {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    context.read<AuthBloc>().add(LoginSubmitted(
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
    ));
  }

  void _onForgotPasswordTapped() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(AppStrings.loginForgotPasswordMsg),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------
  void _handleStateChange(BuildContext context, AuthState state) {
    if (state is AuthOtpRequired) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OtpScreen()),
      );
    } else if (state is AuthAuthenticated) {
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
        body: SafeArea(
          bottom: false,
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final isLoading = state is AuthLoginLoading;
              final errorMsg  = state is AuthFailure ? state.message : null;

              return SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Hero / Branding (full-bleed, "login" appears here) ──
                      const GovernmentAppHeader(),

                      // ── Card — pulled up to overlap the hero banner ───────
                      Transform.translate(
                        offset: const Offset(0, -28),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          child: _LoginCard(
                            isLoading:        isLoading,
                            errorMsg:         errorMsg,
                            usernameCtrl:     _usernameCtrl,
                            passwordCtrl:     _passwordCtrl,
                            passwordVisible:  _passwordVisible,
                            rememberMe:       _rememberMe,
                            validateUsername: _validateUsername,
                            validatePassword: _validatePassword,
                            onTogglePassword: () => setState(
                              () => _passwordVisible = !_passwordVisible,
                            ),
                            onRememberMeChanged: (value) => setState(
                              () => _rememberMe = value ?? false,
                            ),
                            onForgotPassword: _onForgotPasswordTapped,
                            onLoginPressed: _onLoginPressed,
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Footer branding ───────────────────────────
                            Text(
                              AppStrings.loginFooterTagline,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textHint,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                        ),
                      ),
                    ],
                  ),
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
// PRIVATE: Login Card
// =============================================================================
class _LoginCard extends StatelessWidget {
  final bool isLoading;
  final String? errorMsg;
  final TextEditingController usernameCtrl;
  final TextEditingController passwordCtrl;
  final bool passwordVisible;
  final bool rememberMe;
  final FormFieldValidator<String> validateUsername;
  final FormFieldValidator<String> validatePassword;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool?> onRememberMeChanged;
  final VoidCallback onForgotPassword;
  final VoidCallback onLoginPressed;

  const _LoginCard({
    required this.isLoading,
    required this.errorMsg,
    required this.usernameCtrl,
    required this.passwordCtrl,
    required this.passwordVisible,
    required this.rememberMe,
    required this.validateUsername,
    required this.validatePassword,
    required this.onTogglePassword,
    required this.onRememberMeChanged,
    required this.onForgotPassword,
    required this.onLoginPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card + 4),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card Title ─────────────────────────────────────────────────
          Text(AppStrings.loginWelcome, style: AppTextStyles.headingMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(AppStrings.loginSubtitle, style: AppTextStyles.bodySmall),
          const SizedBox(height: AppSpacing.lg),

          // ── Error Banner ───────────────────────────────────────────────
          if (errorMsg != null) ...[
            ErrorBanner(message: errorMsg!),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── Username Field ─────────────────────────────────────────────
          AppTextField(
            label:       AppStrings.loginUsernameLabel,
            hint:        AppStrings.loginUsernameHint,
            controller:  usernameCtrl,
            validator:   validateUsername,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !isLoading,
            prefixIcon: const Icon(
              Icons.badge_outlined,
              color: AppColors.textHint,
              size: 20,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Password Field ─────────────────────────────────────────────
          AppTextField(
            label:      AppStrings.loginPasswordLabel,
            hint:       AppStrings.loginPasswordHint,
            controller: passwordCtrl,
            validator:  validatePassword,
            obscureText: !passwordVisible,
            textInputAction: TextInputAction.done,
            enabled: !isLoading,
            onEditingComplete: isLoading ? null : onLoginPressed,
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.textHint,
              size: 20,
            ),
            suffixIcon: Semantics(
              label: passwordVisible
                ? AppStrings.semanticPasswordHide
                : AppStrings.semanticPasswordShow,
              child: IconButton(
                icon: Icon(
                  passwordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                  color: AppColors.textHint,
                  size: 20,
                ),
                onPressed: isLoading ? null : onTogglePassword,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Remember me / Forgot password ────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.chip),
                onTap: isLoading ? null : () => onRememberMeChanged(!rememberMe),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: rememberMe,
                          onChanged: isLoading ? null : onRememberMeChanged,
                          activeColor: AppColors.primaryGreen,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        AppStrings.loginRememberMe,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: isLoading ? null : onForgotPassword,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  AppStrings.loginForgotPassword,
                  style: AppTextStyles.linkText.copyWith(fontSize: 13),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Login Button (bottom of the form) ────────────────────────
          PrimaryButton(
            label:       AppStrings.loginButtonLabel,
            onPressed:   isLoading ? null : onLoginPressed,
            isLoading:   isLoading,
            loadingLabel: AppStrings.loginLoadingLabel,
          ),
        ],
      ),
    );
  }
}

