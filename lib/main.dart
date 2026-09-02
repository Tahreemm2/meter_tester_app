// =============================================================================
// FILE: lib/main.dart
// PURPOSE: Application entry point.
//          Initializes the BLoC provider tree, applies the government theme,
//          and sets the initial route to LoginScreen.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/home_shell_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait for consistent field device experience
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar styling: light icons on dark green background
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.primaryGreen,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.backgroundPage,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MeterTestingApp());
}

class MeterTestingApp extends StatelessWidget {
  const MeterTestingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      // Dispatch AppStarted immediately: this validates any previously
      // saved session token against GET /api/me.php, so a user who logged
      // in yesterday doesn't have to re-enter credentials every launch.
      create: (_) => AuthBloc()..add(const AppStarted()),
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _AuthGate(),
      ),
    );
  }
}

/// Routes to the right screen based on the current auth state:
///   - AuthInitial          → splash/loading (session check in progress)
///   - AuthAuthenticated    → straight into the dashboard (session restored)
///   - anything else        → LoginScreen (which itself handles OTP routing)
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthInitial) {
          return const _SplashScreen();
        }
        if (state is AuthAuthenticated) {
          return const HomeShellScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primaryGreen),
            const SizedBox(height: 16),
            Text(AppStrings.appName, style: AppTextStyles.headingMedium),
          ],
        ),
      ),
    );
  }
}
