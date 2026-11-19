import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'app.dart';
import 'injection_container.dart';

/// Entry point.
///
///   flutter run                                    → offline demo with demo logins
///   flutter run --dart-define=BACKEND=api --dart-define=API_URL=http://10.0.2.2:8080
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  await initializeDateFormatting();
  await initDependencies();
  runApp(const MawidApp());
}
