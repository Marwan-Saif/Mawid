import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tzdata;

bool _done = false;

/// Timezone database + date symbols, once per test file.
Future<void> initTestEnvironment() async {
  if (_done) return;
  tzdata.initializeTimeZones();
  await initializeDateFormatting();
  _done = true;
}
