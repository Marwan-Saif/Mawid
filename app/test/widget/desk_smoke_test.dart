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

  testWidgets('demo reception lands on the live front desk and can open a visit', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await initDependencies(backend: BackendKind.fake, prefs: await SharedPreferences.getInstance());
    sl.unregister<FakeBackend>();
    sl.registerLazySingleton<FakeBackend>(() => FakeBackend(sl<Session>(), latency: Duration.zero));

    await tester.pumpWidget(const MawidApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('جرّب كاستقبال عيادة'));
    await tester.pumpAndSettle();

    expect(find.text('عيادة النخيل'), findsOneWidget);
    expect(find.text('أبو سامي'), findsOneWidget);
    expect(find.textContaining('بالانتظار'), findsWidgets);

    await tester.tap(find.text('أبو سامي'));
    await tester.pumpAndSettle();
    expect(find.text('الوصول'), findsOneWidget); // the arrive → doctor → invoice timeline

    // Unmount so the desk's refresh timer stops before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
