import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/app.dart';
import 'package:mawid/config/app_config.dart';
import 'package:mawid/core/fake/fake_backend.dart';
import 'package:mawid/core/session/session.dart';
import 'package:mawid/core/theme/app_theme.dart';
import 'package:mawid/injection_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_setup.dart';

void main() {
  setUpAll(() async {
    await initTestEnvironment();
    AppTheme.useGoogleFonts = false;
  });

  testWidgets('demo customer can sign in and lands on Home (Arabic, RTL)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await initDependencies(backend: BackendKind.fake, prefs: prefs);
    // Same Session instance the app uses, with no artificial latency.
    sl.unregister<FakeBackend>();
    sl.registerLazySingleton<FakeBackend>(() => FakeBackend(sl<Session>(), latency: Duration.zero));

    await tester.pumpWidget(const MawidApp());
    await tester.pumpAndSettle();

    expect(find.text('جرّب كعميل'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('جرّب كعميل'))), TextDirection.rtl);

    await tester.tap(find.text('جرّب كعميل'));
    await tester.pumpAndSettle();

    expect(find.text('أحمد'), findsOneWidget);
    expect(find.text('قريب منك'), findsOneWidget);
  });
}
