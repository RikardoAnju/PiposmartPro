import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';

import 'app_palette.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.primary,
      primary: AppPalette.primary,
      secondary: AppPalette.primaryWarm,
      error: AppPalette.danger,
      surface: AppPalette.surface,
    );
    const baseText = TextStyle(
      fontFamily: 'Inter',
      color: AppPalette.ink,
      letterSpacing: -0.2,
    );
    final textTheme =
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 34,
            height: 1.08,
            fontWeight: AppFont.w800,
            letterSpacing: -1.0,
          ),
          displayMedium: TextStyle(
            fontSize: 30,
            height: 1.1,
            fontWeight: AppFont.w800,
            letterSpacing: -0.8,
          ),
          displaySmall: TextStyle(
            fontSize: 26,
            height: 1.14,
            fontWeight: AppFont.w800,
            letterSpacing: -0.6,
          ),
          headlineLarge: TextStyle(
            fontSize: 24,
            height: 1.16,
            fontWeight: AppFont.w800,
            letterSpacing: -0.5,
          ),
          headlineMedium: TextStyle(
            fontSize: 22,
            height: 1.18,
            fontWeight: AppFont.w700,
            letterSpacing: -0.4,
          ),
          headlineSmall: TextStyle(
            fontSize: 20,
            height: 1.2,
            fontWeight: AppFont.w700,
            letterSpacing: -0.3,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            height: 1.24,
            fontWeight: AppFont.w700,
            letterSpacing: -0.2,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            height: 1.28,
            fontWeight: AppFont.w700,
            letterSpacing: -0.1,
          ),
          titleSmall: TextStyle(
            fontSize: 14,
            height: 1.28,
            fontWeight: AppFont.w700,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.5,
            fontWeight: AppFont.w500,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.5,
            fontWeight: AppFont.w500,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            height: 1.45,
            fontWeight: AppFont.w500,
            letterSpacing: 0,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            height: 1.2,
            fontWeight: AppFont.w700,
            letterSpacing: 0.1,
          ),
          labelMedium: TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: AppFont.w700,
            letterSpacing: 0.15,
          ),
          labelSmall: TextStyle(
            fontSize: 11,
            height: 1.2,
            fontWeight: AppFont.w700,
            letterSpacing: 0.2,
          ),
        ).apply(
          bodyColor: AppPalette.ink,
          displayColor: AppPalette.ink,
          fontFamily: 'Inter',
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      primaryColor: AppPalette.primary,
      scaffoldBackgroundColor: AppPalette.surface,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppPalette.primary,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppPalette.primary,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppPalette.primary.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppPalette.primary),
      ),
      chipTheme: ChipThemeData(
        selectedColor: AppPalette.primary,
        secondarySelectedColor: AppPalette.primary,
        backgroundColor: Colors.white,
        checkmarkColor: Colors.white,
        labelStyle: baseText.copyWith(fontSize: 13, fontWeight: AppFont.w600),
        secondaryLabelStyle: baseText.copyWith(
          fontSize: 13,
          fontWeight: AppFont.w700,
          color: Colors.white,
        ),
        side: const BorderSide(color: Color(0xFFE9EEF4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppPalette.primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppPalette.primary.withValues(alpha: 0.28)
              : null,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: baseText.copyWith(
          color: AppPalette.muted,
          fontSize: 14,
          fontWeight: AppFont.w500,
        ),
        labelStyle: baseText.copyWith(
          color: AppPalette.ink,
          fontSize: 14,
          fontWeight: AppFont.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE7EBF0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE7EBF0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppPalette.primary, width: 1.4),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppPalette.ink,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: AppPalette.ink,
          fontSize: 16,
          fontWeight: AppFont.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
