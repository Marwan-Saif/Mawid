import 'package:url_launcher/url_launcher.dart';

/// Opens WhatsApp chat (to [phone] if known) with a prefilled message. Free, no API key.
Future<bool> openWhatsApp(String? phone, String message) {
  final digits = phone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
  final uri = Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}');
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<bool> openDirections(String query) => launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}'),
      mode: LaunchMode.externalApplication,
    );

Future<bool> callPhone(String phone) => launchUrl(Uri(scheme: 'tel', path: phone));
