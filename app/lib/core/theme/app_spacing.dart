/// 4/8 spacing rhythm and shared radii.
class AppSpace {
  const AppSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Minimum touch target (Android 48dp; we use 48 everywhere).
  static const double touch = 48;
}

class AppRadius {
  const AppRadius._();

  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double pill = 999;
}

/// Shared motion tokens: short for taps, a bit longer for content changes.
class AppMotion {
  const AppMotion._();

  static const Duration tap = Duration(milliseconds: 150);
  static const Duration content = Duration(milliseconds: 250);
}
