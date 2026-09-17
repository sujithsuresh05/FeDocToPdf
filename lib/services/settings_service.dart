import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the operator's settings between launches -- retyping a LAN address
/// on a phone keyboard every time is the fastest way to make a tool unused.
class SettingsService {
  static const _baseUrlKey = 'baseUrl';
  static const _markerKey = 'lastMarker';
  static const _keyLabelKey = 'lastKeyLabel';
  static const _filenamePatternKey = 'lastFilenamePattern';
  static const _messageTemplateKey = 'lastMessageTemplate';
  static const _lastJobIdKey = 'lastJobId';
  static const _themeModeKey = 'themeMode';

  Future<String?> readBaseUrl() async =>
      (await SharedPreferences.getInstance()).getString(_baseUrlKey);

  Future<void> writeBaseUrl(String value) async =>
      (await SharedPreferences.getInstance()).setString(_baseUrlKey, value);

  Future<Map<String, String?>> readJobDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'marker': prefs.getString(_markerKey),
      'keyLabel': prefs.getString(_keyLabelKey),
      'filenamePattern': prefs.getString(_filenamePatternKey),
      'messageTemplate': prefs.getString(_messageTemplateKey),
    };
  }

  Future<void> writeJobDefaults({
    String? marker,
    String? keyLabel,
    String? filenamePattern,
    String? messageTemplate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (marker != null) await prefs.setString(_markerKey, marker);
    if (keyLabel != null) await prefs.setString(_keyLabelKey, keyLabel);
    if (filenamePattern != null) await prefs.setString(_filenamePatternKey, filenamePattern);
    if (messageTemplate != null) await prefs.setString(_messageTemplateKey, messageTemplate);
  }

  /// Light/dark preference. Unset means follow the phone.
  Future<ThemeMode> readThemeMode() async {
    final stored = (await SharedPreferences.getInstance()).getString(_themeModeKey);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> writeThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  /// The last job id, so the app can offer to resume after being killed
  /// part-way through a 181-notice run.
  Future<String?> readLastJobId() async =>
      (await SharedPreferences.getInstance()).getString(_lastJobIdKey);

  Future<void> writeLastJobId(String jobId) async =>
      (await SharedPreferences.getInstance()).setString(_lastJobIdKey, jobId);
}
