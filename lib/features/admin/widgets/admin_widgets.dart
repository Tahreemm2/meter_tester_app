// =============================================================================
// FILE: lib/features/admin/widgets/admin_widgets.dart
// PURPOSE: Shared, reusable UI components for the Admin feature's list/CRUD
// screens — kept separate so individual screens stay focused on layout.
// =============================================================================

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';

// =============================================================================
// WIDGET 1: AdminSectionCard — a tappable tile on the Admin Panel home screen.
// =============================================================================
class AdminSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const AdminSectionCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderSubtle, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreenSurface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Icon(icon, color: AppColors.primaryGreen, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.headingMedium.copyWith(fontSize: 16)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTextStyles.bodySmall),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// WIDGET 2: StatusBadge — small Active/Inactive pill.
// =============================================================================
class StatusBadge extends StatelessWidget {
  final bool isActive;
  const StatusBadge({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.successGreen : AppColors.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// =============================================================================
// WIDGET 3: AdminListState — one widget for loading / error / empty, so every
// list screen handles these three cases identically.
// =============================================================================
class AdminListState extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final bool isEmpty;
  final VoidCallback onRetry;

  const AdminListState({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.isEmpty,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
      );
    }
    if (errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(errorMessage!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.errorRed), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(AppStrings.adminEmptyList, style: AppTextStyles.bodySmall),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// =============================================================================
// HELPER: confirmDestructiveAction — reusable Yes/No dialog for delete actions.
// =============================================================================
Future<bool> confirmDestructiveAction(
  BuildContext context, {
  required String message,
  String confirmLabel = AppStrings.adminDelete,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text(AppStrings.adminConfirmDeleteTitle, style: AppTextStyles.headingMedium),
      content: Text(message, style: AppTextStyles.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(AppStrings.adminCancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, minimumSize: const Size(80, 40)),
          child: Text(confirmLabel, style: AppTextStyles.buttonLabel.copyWith(fontSize: 14)),
        ),
      ],
    ),
  );
  return result == true;
}

/// Shows a small floating snackbar — success (green) or error (red).
void showAdminSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: AppTextStyles.bodySmall.copyWith(color: AppColors.white)),
      backgroundColor: isError ? AppColors.errorRed : AppColors.primaryGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
    ),
  );
}
