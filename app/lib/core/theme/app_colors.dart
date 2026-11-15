import 'package:flutter/material.dart';

/// Design tokens from the Mawid design (ui-ux-pro-max "Booking & Appointment" palette).
/// Widgets read them with `context.colors`, never raw hex.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.background,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.taken,
  });

  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color background;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  /// Background of a booked (unavailable) time slot.
  final Color taken;

  /// Light: #0369A1 on white is 5.9:1; textSecondary #475569 is 7.5:1.
  static AppColors light(Color brandPrimary) => AppColors(
        primary: brandPrimary,
        onPrimary: Colors.white,
        primarySoft: const Color(0xFFE0F2FE),
        success: const Color(0xFF047857),
        successSoft: const Color(0xFFECFDF5),
        warning: const Color(0xFFB45309),
        warningSoft: const Color(0xFFFFF7ED),
        danger: const Color(0xFFB91C1C),
        background: const Color(0xFFF0F9FF),
        surface: Colors.white,
        border: const Color(0xFFD6E6F0),
        textPrimary: const Color(0xFF0F172A),
        textSecondary: const Color(0xFF475569),
        taken: const Color(0xFFE2E8F0),
      );

  /// Dark: lighter accents on deep navy; all text pairs stay above 4.5:1.
  static AppColors dark(Color brandPrimaryDark) => AppColors(
        primary: brandPrimaryDark,
        onPrimary: const Color(0xFF0B1220),
        primarySoft: const Color(0xFF0C2A40),
        success: const Color(0xFF34D399),
        successSoft: const Color(0xFF0B2A22),
        warning: const Color(0xFFFBBF24),
        warningSoft: const Color(0xFF2E2210),
        danger: const Color(0xFFF87171),
        background: const Color(0xFF0B1220),
        surface: const Color(0xFF111A2E),
        border: const Color(0xFF23324D),
        textPrimary: const Color(0xFFE2E8F0),
        textSecondary: const Color(0xFFA3B3C9),
        taken: const Color(0xFF1E293B),
      );

  @override
  AppColors copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? background,
    Color? surface,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? taken,
  }) =>
      AppColors(
        primary: primary ?? this.primary,
        onPrimary: onPrimary ?? this.onPrimary,
        primarySoft: primarySoft ?? this.primarySoft,
        success: success ?? this.success,
        successSoft: successSoft ?? this.successSoft,
        warning: warning ?? this.warning,
        warningSoft: warningSoft ?? this.warningSoft,
        danger: danger ?? this.danger,
        background: background ?? this.background,
        surface: surface ?? this.surface,
        border: border ?? this.border,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        taken: taken ?? this.taken,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      taken: Color.lerp(taken, other.taken, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
