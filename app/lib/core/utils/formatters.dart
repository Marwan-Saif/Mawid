import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

/// Dates, times, money and numbers per language, always shown in the place's own timezone
/// (a customer in Cairo booking a salon in Dubai sees Dubai time).
class Fmt {
  Fmt(Locale locale) : _tag = _resolve(locale);

  factory Fmt.of(BuildContext context) => Fmt(Localizations.localeOf(context));

  final String _tag;

  /// Arabic uses Eastern Arabic digits (٥:٠٠ م) through the ar_EG data when available.
  static String _resolve(Locale locale) {
    if (locale.languageCode != 'ar') return 'en';
    return DateFormat.localeExists('ar_EG') ? 'ar_EG' : 'ar';
  }

  bool get isArabic => _tag.startsWith('ar');

  /// Converts a UTC instant to wall-clock time at the place.
  static DateTime inZone(DateTime utc, String timezone) {
    try {
      return tz.TZDateTime.from(utc.toUtc(), tz.getLocation(timezone));
    } on Object {
      return utc.toLocal();
    }
  }

  String time(DateTime utc, String timezone) => DateFormat.jm(_tag).format(inZone(utc, timezone));

  /// For wall-clock values already in place time (e.g. working hours).
  String wallTime(int hour, int minute) =>
      DateFormat.jm(_tag).format(DateTime(2000, 1, 1, hour, minute));

  String weekdayShort(DateTime day) => DateFormat.E(_tag).format(day);

  String weekday(DateTime day) => DateFormat.EEEE(_tag).format(day);

  String dayNumber(DateTime day) => DateFormat.d(_tag).format(day);

  String monthYear(DateTime day) => DateFormat.yMMMM(_tag).format(day);

  /// "الخميس ٢٢ أكتوبر · ٥:٠٠ م"
  String dateTime(DateTime utc, String timezone) {
    final local = inZone(utc, timezone);
    return '${DateFormat.MMMMEEEEd(_tag).format(local)} · ${DateFormat.jm(_tag).format(local)}';
  }

  String shortDate(DateTime utc, String timezone) => DateFormat.MMMEd(_tag).format(inZone(utc, timezone));

  String number(num value, {int decimals = 0}) {
    final f = NumberFormat.decimalPattern(_tag)
      ..minimumFractionDigits = decimals
      ..maximumFractionDigits = decimals;
    return f.format(value);
  }

  String money(num value, String currency) {
    final symbol = switch (currency) {
      'AED' => isArabic ? 'د.إ' : 'AED',
      'EGP' => isArabic ? 'ج.م' : 'EGP',
      'JOD' => isArabic ? 'د.أ' : 'JOD',
      'SAR' => isArabic ? 'ر.س' : 'SAR',
      _ => currency,
    };
    final whole = value == value.roundToDouble();
    return '${number(value, decimals: whole ? 0 : 2)} $symbol'.trim();
  }
}
