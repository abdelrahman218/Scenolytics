// Basic widget smoke test for ScenolyticsApp.

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:scenolytics_frontend/branding/app_logo_placeholder.dart';
import 'package:scenolytics_frontend/data/api/auth_api.dart';
import 'package:scenolytics_frontend/data/api/user_management_api.dart';
import 'package:scenolytics_frontend/data/auth_controller.dart';
import 'package:scenolytics_frontend/data/auth_session_store.dart';
import 'package:scenolytics_frontend/main.dart';
import 'package:scenolytics_frontend/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App loads branding and login when signed out', (
    WidgetTester tester,
  ) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    final themeController = ThemeController();
    await themeController.load();

    const apiBase = 'http://localhost';
    final userManagementApi = UserManagementApi(baseUrl: apiBase);
    final auth = AuthController(
      store: const AuthSessionStore(),
      api: AuthApi(baseUrl: apiBase),
      userManagementApi: userManagementApi,
    );
    await auth.hydrate();

    await tester.pumpWidget(
      ScenolyticsApp(
        themeController: themeController,
        auth: auth,
        userManagementApi: userManagementApi,
        logo: buildDefaultAppLogo(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Scenolytics'), findsWidgets);
    expect(find.textContaining('Welcome back'), findsOneWidget);
  });
}
