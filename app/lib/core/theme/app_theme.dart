import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/brand.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

class AppTheme {
  const AppTheme._();

  /// Set to false in tests so no font is fetched over the network.
  static bool useGoogleFonts = true;

  static ThemeData light(Brand brand, Locale locale) =>
      _build(AppColors.light(brand.primary), Brightness.light, locale);

  static ThemeData dark(Brand brand, Locale locale) =>
      _build(AppColors.dark(brand.primaryDark), Brightness.dark, locale);

  static ThemeData _build(AppColors c, Brightness brightness, Locale locale) {
    final scheme = ColorScheme.fromSeed(
      seedColor: c.primary,
      brightness: brightness,
    ).copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      surface: c.surface,
      onSurface: c.textPrimary,
      error: c.danger,
      outline: c.border,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
    TextTheme text = base.textTheme.apply(bodyColor: c.textPrimary, displayColor: c.textPrimary);
    if (useGoogleFonts) {
      text = locale.languageCode == 'ar'
          ? GoogleFonts.notoSansArabicTextTheme(text)
          : GoogleFonts.notoSansTextTheme(text);
    }
    text = text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 24),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 20),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.5, color: c.textSecondary),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
    );

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm + 2));
    return base.copyWith(
      scaffoldBackgroundColor: c.background,
      textTheme: text,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: c.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          minimumSize: const Size(AppSpace.touch, 52),
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(AppSpace.touch, 52),
          side: BorderSide(color: c.border, width: 1.5),
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(AppSpace.touch, AppSpace.touch),
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          borderSide: BorderSide(color: c.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.primarySoft,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected) ? c.primary : c.textSecondary,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? c.primary : c.textSecondary,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
