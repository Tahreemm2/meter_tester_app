// =============================================================================
// FILE: lib/features/profile/screens/profile_screen.dart
// PURPOSE: Profile Management (spec item 8 — "User profile, change password,
// and logout"). Works for any role, reachable from the home shell AppBar.
// Change password calls POST /api/change_password.php (any authenticated
// user changes their own password) — see AuthRepository.changePassword.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/widgets/auth_widgets.dart';

class ProfileScreen extends StatelessWidget {
  final UserModel currentUser;
  const ProfileScreen({super.key, required this.currentUser});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Log Out', style: AppTextStyles.headingMedium),
        content: const Text('You\'ll need to sign in again to continue.', style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, minimumSize: const Size(80, 40)),
            child: const Text('Log Out', style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(const LogoutRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(title: const Text('My Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ProfileHeader(user: currentUser),
            const SizedBox(height: AppSpacing.xl),
            Text('Account', style: AppTextStyles.headingMedium.copyWith(fontSize: 16)),
            const SizedBox(height: AppSpacing.sm),
            _InfoCard(user: currentUser),
            const SizedBox(height: AppSpacing.xl),
            Text('Security', style: AppTextStyles.headingMedium.copyWith(fontSize: 16)),
            const SizedBox(height: AppSpacing.sm),
            _ChangePasswordCard(token: currentUser.token),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.errorRed),
                label: const Text('Log Out', style: TextStyle(color: AppColors.errorRed)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.errorRed),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _confirmLogout(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel user;
  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.primaryGreenSurface,
          child: Text(
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
            style: AppTextStyles.headingMedium.copyWith(color: AppColors.primaryGreen, fontSize: 24),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.fullName, style: AppTextStyles.headingMedium),
              const SizedBox(height: 2),
              RoleChip(label: user.role.displayName),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final UserModel user;
  const _InfoCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          _row(Icons.badge_outlined, 'Employee ID', user.employeeId),
          const SectionDivider(),
          _row(Icons.person_outline_rounded, 'Username', user.username),
          const SectionDivider(),
          _row(Icons.map_outlined, user.scope.displayLabel, user.scopeName),
          if (user.contactMasked != null) ...[
            const SectionDivider(),
            _row(Icons.phone_outlined, 'Contact', user.contactMasked!),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textHint),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(width: 110, child: Text(label, style: AppTextStyles.labelLarge)),
            Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
          ],
        ),
      );
}

class _ChangePasswordCard extends StatefulWidget {
  final String token;
  const _ChangePasswordCard({required this.token});

  @override
  State<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<_ChangePasswordCard> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _repo = ApiAuthRepository();

  bool _isSubmitting = false;
  String? _currentFieldError;
  String? _newFieldError;
  String? _bannerError;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _bannerError = null;
      _currentFieldError = null;
      _newFieldError = null;
    });

    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _newFieldError = 'Passwords do not match.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      await _repo.changePassword(
        token: widget.token,
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated. You\'ll stay signed in on this device.')),
        );
      }
    } on ApiException catch (e) {
      setState(() {
        if (e.errorCode == 'INVALID_CURRENT_PASSWORD') {
          _currentFieldError = e.message;
        } else if (e.fieldErrors != null) {
          _currentFieldError = e.fieldErrors!['current_password'] as String?;
          _newFieldError     = e.fieldErrors!['new_password'] as String?;
          if (_currentFieldError == null && _newFieldError == null) _bannerError = e.message;
        } else {
          _bannerError = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'Current Password',
              hint: '••••••••',
              controller: _currentCtrl,
              obscureText: true,
              validator: (v) => (v == null || v.isEmpty) ? 'Current password is required.' : null,
            ),
            if (_currentFieldError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_currentFieldError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.errorRed)),
              ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'New Password',
              hint: '••••••••',
              controller: _newCtrl,
              obscureText: true,
              validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters.' : null,
            ),
            if (_newFieldError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_newFieldError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.errorRed)),
              ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Confirm New Password',
              hint: '••••••••',
              controller: _confirmCtrl,
              obscureText: true,
              validator: (v) => (v == null || v.isEmpty) ? 'Please confirm your new password.' : null,
            ),
            if (_bannerError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.accentGoldLight,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Text(_bannerError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.accentGold)),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: 'Update Password',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
