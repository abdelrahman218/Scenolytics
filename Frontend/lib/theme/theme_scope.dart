import 'package:flutter/material.dart';

import 'theme_controller.dart';

/// Provides [ThemeController] below [MaterialApp] for settings and toggles.
class ThemeControllerScope extends InheritedNotifier<ThemeController> {
  const ThemeControllerScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ThemeControllerScope>();
    assert(scope != null, 'ThemeControllerScope not found');
    return scope!.notifier!;
  }
}
