import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists [ThemeMode] (light vs dark) for the app.
class ThemeController extends ChangeNotifier {
  ThemeController();

  static const _prefsKey = 'scenolytics_theme_mode';

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get themeMode => _mode;

  /// Whether the UI is using the dark Material theme.
  bool get isDarkMode => _mode == ThemeMode.dark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored == 'dark') {
      _mode = ThemeMode.dark;
    } else {
      _mode = ThemeMode.light;
    }
    notifyListeners();
  }

  Future<void> setDarkMode(bool enabled) async {
    _mode = enabled ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, enabled ? 'dark' : 'light');
  }
}
