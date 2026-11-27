/// Build-time configuration, chosen with --dart-define.
///
///   flutter run                                  → offline demo (in-memory backend, demo logins)
///   flutter run --dart-define=BACKEND=api \
///               --dart-define=API_URL=http://10.0.2.2:8080   → the Spring Boot API
enum BackendKind { fake, api }

class AppConfig {
  const AppConfig._();

  static const String _backend = String.fromEnvironment('BACKEND', defaultValue: 'fake');
  static const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8080');

  /// Public address customers open (check-in links in QR codes). Defaults to the API's.
  static const String publicUrl = String.fromEnvironment('PUBLIC_URL', defaultValue: apiUrl);

  /// Shows "Try as customer / Try as owner" on the welcome screen.
  static const bool demoMode = bool.fromEnvironment('DEMO', defaultValue: true);

  static BackendKind get backend => _backend == 'api' ? BackendKind.api : BackendKind.fake;

  /// OTP that always works in demo mode (same as the API's MAWID_DEMO_CODE).
  static const String demoOtp = '123456';
}
