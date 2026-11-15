import 'package:flutter/material.dart';

/// White-label settings. A new client = a new Brand, not a fork of the code.
///
/// Change the name, colors and support contact here (or add another `Brand` and pick it in
/// `main.dart`) to ship the same app under a clinic's or salon's own name.
class Brand {
  const Brand({
    required this.nameAr,
    required this.nameEn,
    required this.primary,
    required this.primaryDark,
    this.supportWhatsApp,
  });

  final String nameAr;
  final String nameEn;

  /// Main color in light mode. Keep contrast with white text at 4.5:1 or more.
  final Color primary;

  /// Main color in dark mode (lighter, so it reads on dark surfaces).
  final Color primaryDark;

  final String? supportWhatsApp;

  String name(Locale locale) => locale.languageCode == 'ar' ? nameAr : nameEn;

  static const mawid = Brand(
    nameAr: 'موعد',
    nameEn: 'Mawid',
    primary: Color(0xFF0369A1),
    primaryDark: Color(0xFF38BDF8),
  );
}
