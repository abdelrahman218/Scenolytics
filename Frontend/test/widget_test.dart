// Basic widget smoke test for ScenolyticsApp.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenolytics_frontend/branding/app_logo_placeholder.dart';
import 'package:scenolytics_frontend/main.dart';

void main() {
  testWidgets('App loads with branding and rankings shell', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(ScenolyticsApp(logo: buildDefaultAppLogo()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Scenolytics'), findsWidgets);
    expect(find.textContaining('Audition'), findsWidgets);
    });
}
