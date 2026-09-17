import 'package:flutter/material.dart';

import '../services/settings_service.dart';

/// Holds the operator's light/dark choice and persists it.
///
/// A `ValueNotifier` rather than a state-management package: this is one
/// setting, read in one place.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController(this._settings) : super(ThemeMode.system) {
    _restore();
  }

  final SettingsService _settings;

  Future<void> _restore() async {
    value = await _settings.readThemeMode();
  }

  /// Cycles system -> light -> dark -> system, so the operator can pin either
  /// theme or hand the choice back to the phone.
  Future<void> next() async {
    value = switch (value) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await _settings.writeThemeMode(value);
  }

  IconData get icon => switch (value) {
        ThemeMode.system => Icons.brightness_auto_outlined,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
      };

  String get label => switch (value) {
        ThemeMode.system => 'Theme: following the phone',
        ThemeMode.light => 'Theme: light',
        ThemeMode.dark => 'Theme: dark',
      };
}
