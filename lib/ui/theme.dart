import 'package:flutter/material.dart';

/// The app's palette, light only.
///
/// Deliberately not `ColorScheme.fromSeed`: a generated scheme derives the
/// warning and error roles from the same seed as the accent, and this screen
/// needs "needs attention" and "cannot be sent" to be unmistakably *not* the
/// accent. Each role is therefore set by hand.
///
/// The teal is WhatsApp's green pulled back toward an institutional tone -- the
/// documents being sent are municipal tax notices, not chat messages. Neutrals
/// carry a slight green bias so they read as chosen rather than inherited.
abstract final class AppColors {
  static const canvas = Color(0xFFF7FAF8); // page ground behind surfaces
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSunken = Color(0xFFEDF3F0);

  static const ink = Color(0xFF101A17); // primary text
  static const inkSoft = Color(0xFF49594F); // secondary text
  static const muted = Color(0xFF76867F); // metadata, labels
  static const line = Color(0xFFE1EAE6);
  static const lineStrong = Color(0xFFC9D8D2);

  static const accent = Color(0xFF0B6E5F);
  static const accentInk = Color(0xFF064A3F);
  static const accentSoft = Color(0xFFE2F0EB);

  /// "Needs attention" -- a count mismatch, a skipped row. Never the accent.
  static const warn = Color(0xFF8A5A14);
  static const warnSoft = Color(0xFFF8EDDC);

  /// "Cannot be sent" -- no phone number, no matching row.
  static const blocked = Color(0xFF97362A);
  static const blockedSoft = Color(0xFFF7E3DF);
}

/// Monospace for identifiers and figures: serial numbers, page ranges,
/// phone numbers and counts all want to line up and be compared.
///
/// No font package: the app ships no font assets and does not download any, so
/// it works offline in the field. `monospace` resolves on Android; the fallback
/// list covers iOS and desktop.
const List<String> _monoFallback = <String>['monospace', 'Menlo', 'Courier New'];

TextStyle mono(TextStyle base, {Color? color, double? size, FontWeight? weight}) =>
    base.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: _monoFallback,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: color,
      fontSize: size,
      fontWeight: weight,
    );

/// A short uppercase label: "NEXT · NOTICE 38 OF 181", "BACKEND".
TextStyle kicker(BuildContext context, {Color? color}) => mono(
      Theme.of(context).textTheme.labelSmall ?? const TextStyle(),
      color: color ?? AppColors.muted,
      size: 10.5,
      weight: FontWeight.w500,
    ).copyWith(letterSpacing: 1.1);

ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.accent,
    onPrimary: Colors.white,
    primaryContainer: AppColors.accentSoft,
    onPrimaryContainer: AppColors.accentInk,
    secondary: AppColors.accent,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.accentSoft,
    onSecondaryContainer: AppColors.accentInk,
    // Tertiary carries "needs attention" throughout the app.
    tertiary: AppColors.warn,
    onTertiary: Colors.white,
    tertiaryContainer: AppColors.warnSoft,
    onTertiaryContainer: AppColors.warn,
    error: AppColors.blocked,
    onError: Colors.white,
    errorContainer: AppColors.blockedSoft,
    onErrorContainer: AppColors.blocked,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFFBFDFC),
    surfaceContainer: Color(0xFFF2F7F5),
    surfaceContainerHigh: Color(0xFFEDF3F0),
    surfaceContainerHighest: AppColors.surfaceSunken,
    outline: AppColors.lineStrong,
    outlineVariant: AppColors.line,
    inverseSurface: AppColors.ink,
    onInverseSurface: Colors.white,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    dividerColor: AppColors.line,
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.muted),
      helperStyle: const TextStyle(color: AppColors.muted, fontSize: 11.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.ink),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
      titleSmall: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
      bodyLarge: TextStyle(fontSize: 15, color: AppColors.ink),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.ink),
      bodySmall: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
      labelSmall: TextStyle(fontSize: 11, color: AppColors.muted),
    ),
  );
}
