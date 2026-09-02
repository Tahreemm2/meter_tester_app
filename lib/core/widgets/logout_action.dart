// =============================================================================
// FILE: lib/core/widgets/logout_action.dart
// PURPOSE: Shared logout button + confirmation dialog, reused in every
// screen's AppBar so a user can log out from anywhere in the app, not just
// the Home screen. Dispatches LogoutRequested on AuthBloc; the top-level
// BlocListener in home_shell_screen.dart reacts to AuthUnauthenticated and
// resets navigation back to the login screen, so screens using this widget
// don't need to handle navigation themselves.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../constants/app_theme.dart';
import '../constants/app_strings.dart';
import '../../features/auth/bloc/auth_bloc.dart';

/// Drop this into any AppBar's `actions` list to add a logout button.
class LogoutAction extends StatelessWidget {
  const LogoutAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout_rounded, size: 20),
      tooltip: AppStrings.homeLogoutButton,
      onPressed: () => confirmLogout(context),
    );
  }
}

/// Shows the Yes/No confirmation dialog and dispatches LogoutRequested if
/// confirmed. Exposed separately so non-AppBar logout buttons (e.g. Profile
/// screen's full-width button) can reuse the same confirmation flow.
Future<void> confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      title: Text(AppStrings.homeLogoutButton, style: AppTextStyles.headingMedium),
      content: Text(AppStrings.homeLogoutConfirm, style: AppTextStyles.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(AppStrings.homeLogoutCancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.errorRed,
            minimumSize: const Size(80, 40),
          ),
          child: Text(
            AppStrings.homeLogoutConfirmBtn,
            style: AppTextStyles.buttonLabel.copyWith(fontSize: 14),
          ),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    context.read<AuthBloc>().add(const LogoutRequested());
  }
}
