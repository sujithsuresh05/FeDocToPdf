import 'package:flutter/material.dart';

/// Colours that have no natural `ColorScheme` role.
///
/// Everything that maps to a Material role is read from the scheme instead, so
/// a widget never needs to know which theme is active: `primary` is the accent,
/// `tertiary` carries "needs attention", `error` carries "cannot be sent",
/// `outlineVariant` is the hairline rule.
@immutable
class AppTones extends ThemeExtension<AppTones> {
  const AppTones({required this.inkSoft, required this.canvas});

  /// Secondary body text: readable, but a step back from `onSurface`.
  final Color inkSoft;

  /// The ground behind surfaces. Also the scaffold background.
  final Color canvas;

  @override
  AppTones copyWith({Color? inkSoft, Color? canvas}) =>
      AppTones(inkSoft: inkSoft ?? this.inkSoft, canvas: canvas ?? this.canvas);

  @override
  AppTones lerp(AppTones? other, double t) => other == null
      ? this
      : AppTones(
          inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
          canvas: Color.lerp(canvas, other.canvas, t)!,
        );
}

/// Convenience accessors so widgets read `context.tones.inkSoft` rather than
/// reaching for a global.
extension ThemeTones on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;
  AppTones get tones => Theme.of(this).extension<AppTones>()!;
}

// --- light ------------------------------------------------------------------
//
// The teal is WhatsApp's green pulled back toward an institutional tone: the
// documents are municipal tax notices, not chat messages. Neutrals carry a
// slight green bias so they read as chosen rather than inherited.

const _lightCanvas = Color(0xFFF7FAF8);
const _lightTones = AppTones(inkSoft: Color(0xFF49594F), canvas: _lightCanvas);

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF0B6E5F),
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFE2F0EB),
  onPrimaryContainer: Color(0xFF064A3F),
  secondary: Color(0xFF0B6E5F),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFE2F0EB),
  onSecondaryContainer: Color(0xFF064A3F),
  tertiary: Color(0xFF8A5A14), // needs attention
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFF8EDDC),
  onTertiaryContainer: Color(0xFF8A5A14),
  error: Color(0xFF97362A), // cannot be sent
  onError: Colors.white,
  errorContainer: Color(0xFFF7E3DF),
  onErrorContainer: Color(0xFF97362A),
  surface: Colors.white,
  onSurface: Color(0xFF101A17),
  onSurfaceVariant: Color(0xFF76867F),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Color(0xFFFBFDFC),
  surfaceContainer: Color(0xFFF2F7F5),
  surfaceContainerHigh: Color(0xFFEDF3F0),
  surfaceContainerHighest: Color(0xFFEDF3F0),
  outline: Color(0xFFC9D8D2),
  outlineVariant: Color(0xFFE1EAE6),
  inverseSurface: Color(0xFF101A17),
  onInverseSurface: Colors.white,
  shadow: Colors.black,
  scrim: Colors.black,
);

// --- dark -------------------------------------------------------------------
//
// Not an inversion of the light theme, and deliberately not near-black: a
// ground lifted off #000 keeps the surfaces and the hairline rules legible
// against each other, which is what the list depends on. The accent is
// brightened enough to carry the filled step and takes dark text, and the
// attention and blocked hues are pushed further from the teal than their light
// counterparts so the three stay distinguishable at low luminance.

const _darkCanvas = Color(0xFF141B19);
const _darkTones = AppTones(inkSoft: Color(0xFFB9C9C3), canvas: _darkCanvas);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF34B69B),
  onPrimary: Color(0xFF05201B),
  primaryContainer: Color(0xFF17332C),
  onPrimaryContainer: Color(0xFFA9E7D7),
  secondary: Color(0xFF34B69B),
  onSecondary: Color(0xFF05201B),
  secondaryContainer: Color(0xFF17332C),
  onSecondaryContainer: Color(0xFFA9E7D7),
  tertiary: Color(0xFFE2A860),
  onTertiary: Color(0xFF24190A),
  tertiaryContainer: Color(0xFF2F2517),
  onTertiaryContainer: Color(0xFFF0CB98),
  error: Color(0xFFE98872),
  onError: Color(0xFF2A100B),
  errorContainer: Color(0xFF34211D),
  onErrorContainer: Color(0xFFF3B6A7),
  surface: Color(0xFF1B2421),
  onSurface: Color(0xFFEAF2EF),
  onSurfaceVariant: Color(0xFF8A9C96),
  surfaceContainerLowest: Color(0xFF111714),
  surfaceContainerLow: Color(0xFF18201D),
  surfaceContainer: Color(0xFF1E2825),
  surfaceContainerHigh: Color(0xFF222D29),
  surfaceContainerHighest: Color(0xFF222D29),
  outline: Color(0xFF3C4C46),
  outlineVariant: Color(0xFF2B3834),
  inverseSurface: Color(0xFFEAF2EF),
  onInverseSurface: Color(0xFF101A17),
  shadow: Colors.black,
  scrim: Colors.black,
);

/// Monospace for identifiers and figures: serial numbers, page ranges, phone
/// numbers and counts all want to line up and be compared.
///
/// No font package: the app ships no font assets and downloads none, so it
/// works offline in the field. `monospace` resolves on Android; the fallback
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
      color: color ?? context.scheme.onSurfaceVariant,
      size: 10.5,
      weight: FontWeight.w500,
    ).copyWith(letterSpacing: 1.1);

ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = dark ? _darkScheme : _lightScheme;
  final tones = dark ? _darkTones : _lightTones;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    extensions: <ThemeExtension<dynamic>>[tones],
    scaffoldBackgroundColor: tones.canvas,
    dividerColor: scheme.outlineVariant,
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      // In dark the bright accent as a full bar is too loud, so the bar becomes
      // a surface and the accent is saved for the step that must be tapped.
      backgroundColor: dark ? scheme.surface : scheme.primary,
      foregroundColor: dark ? scheme.onSurface : scheme.onPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: dark ? scheme.onSurface : scheme.onPrimary,
      ),
      shape: dark
          ? Border(bottom: BorderSide(color: scheme.outlineVariant))
          : null,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      helperStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.outlineVariant,
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: scheme.onSurface),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface),
      titleSmall: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: scheme.onSurface),
      bodyLarge: TextStyle(fontSize: 15, color: scheme.onSurface),
      bodyMedium: TextStyle(fontSize: 14, color: scheme.onSurface),
      bodySmall: TextStyle(fontSize: 12.5, color: tones.inkSoft),
      labelSmall: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
    ),
  );
}
