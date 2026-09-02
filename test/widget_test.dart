// =============================================================================
// FILE: test/widget_test.dart
// PURPOSE: Basic smoke test for the app's real entry point widget,
// MeterTestingApp (see lib/main.dart).
//
// NOTE: If your project previously had a default `flutter create`-generated
// test/widget_test.dart referencing a `MyApp` class, delete/replace it with
// this file — this project's root widget is named MeterTestingApp, not
// MyApp, so the old template test will always fail to compile.
//
// RUN: flutter test test/widget_test.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mnt_module2/main.dart';
import 'package:mnt_module2/core/constants/app_strings.dart';

void main() {
  testWidgets(
    'App launches and shows the login screen when no session is stored',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MeterTestingApp());

      // First frame: splash screen while AuthBloc's AppStarted handler
      // checks secure storage for a saved session (there isn't one in a
      // fresh test environment, so this resolves almost immediately).
      await tester.pump();

      // Give the async session-check a couple of frames to resolve into
      // AuthUnauthenticated → LoginScreen. Deliberately avoids
      // pumpAndSettle() here, since the splash screen's indeterminate
      // CircularProgressIndicator animates forever and would time it out.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(AppStrings.loginTitle), findsOneWidget);
      expect(find.text(AppStrings.loginButtonLabel), findsOneWidget);
    },
  );
}
