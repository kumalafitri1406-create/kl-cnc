// lib/theme.dart
import 'package:flutter/material.dart';

const kNeon = Color(0xFFAAFF00);
const kRed = Color(0xFFFF1A1A);
const kDark = Color(0xFF0A0A0A);
const kPanel = Color(0xE0101010);
const kBorder = Color(0x40AAFF00);
const kDim = Color(0xFF888888);
const kWarn = Color(0xFFFF6600);
const kBlue = Color(0xFF00AAFF);
const kPurple = Color(0xFFAA00FF);
const kBg = Color(0xFF1A1A1A);

const kFontMono = 'monospace';

ThemeData buildTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(
      primary: kNeon,
      secondary: kBlue,
      error: kRed,
      surface: kPanel,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kDark,
      foregroundColor: kNeon,
      elevation: 0,
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: kNeon,
      unselectedLabelColor: kDim,
      indicatorColor: kNeon,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: kNeon,
        side: const BorderSide(color: kNeon),
        minimumSize: const Size(44, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black54,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kNeon),
      ),
      labelStyle: const TextStyle(color: kDim, fontFamily: kFontMono),
      hintStyle: TextStyle(color: kNeon.withOpacity(0.3), fontFamily: kFontMono),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Color(0xFFE0E0E0)),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: kNeon,
      thumbColor: kNeon,
      inactiveTrackColor: kBorder,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? kNeon : kDim),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? kNeon.withOpacity(0.3)
              : Colors.white10),
    ),
  );
}

// Reusable card decoration
BoxDecoration cardDecoration() => BoxDecoration(
      color: kPanel,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kBorder),
    );

// Neon text style
TextStyle neonText({double size = 13, FontWeight weight = FontWeight.normal}) =>
    TextStyle(
        color: kNeon, fontSize: size, fontFamily: kFontMono, fontWeight: weight);

TextStyle dimText({double size = 11}) =>
    TextStyle(color: kDim, fontSize: size, fontFamily: kFontMono);

TextStyle monoText({double size = 13, Color color = Colors.white}) =>
    TextStyle(color: color, fontSize: size, fontFamily: kFontMono);
