import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/core/error/exceptions.dart';
import 'package:mawid/core/fake/fake_backend.dart';
import 'package:mawid/core/session/session.dart';
import 'package:mawid/features/auth/data/models/user_model.dart';
import 'package:timezone/timezone.dart' as tz;

import '../helpers/test_setup.dart';

/// The demo backend must enforce the same rules as the API, or the demo would lie.
void main() {
  late Session session;
  late FakeBackend backend;
  late Map<String, dynamic> lamsa;
  late int haircutId;
  late int nouraId;

  setUpAll(initTestEnvironment);

  setUp(() async {
    session = Session();
    backend = FakeBackend(session, latency: Duration.zero);
    final login = await backend.demoLogin('CUSTOMER');
    session.set(login['token'] as String, UserModel(Map<String, dynamic>.from(login['user'] as Map)).toEntity());
    lamsa = (await backend.places(query: 'Lamsa')).single;
    final details = await backend.placeDetails(lamsa['id'] as int);
    haircutId = (details['services'] as List).cast<Map>().firstWhere((s) => s['nameEn'] == 'Haircut & styling')['id'] as int;
    nouraId = (details['staff'] as List).cast<Map>().firstWhere((s) => s['name'] == 'نورا')['id'] as int;
  });

  /// 11:00 Dubai, ten days from now, on a day Reem works (not Sunday).
  DateTime futureSlot([int hour = 11, int minute = 0]) {
    final loc = tz.getLocation('Asia/Dubai');
    var d = tz.TZDateTime.now(loc).add(const Duration(days: 10));
    if (d.weekday == DateTime.sunday) d = d.add(const Duration(days: 1));
    return tz.TZDateTime(loc, d.year, d.month, d.day, hour, minute).toUtc();
  }

  Future<Map<String, dynamic>> book(int? staffId, DateTime start) => backend.createBooking({
        'placeId': lamsa['id'],
        'serviceId': haircutId,
        'staffId': staffId,
        'startAt': start.toIso8601String(),
      });

  test('same staff member, overlapping time: the second booking is rejected', () async {
    await book(nouraId, futureSlot(11, 0));
    await expectLater(book(nouraId, futureSlot(11, 15)), throwsA(isA<SlotTakenException>()));
  });

  test('"anyone available" picks the other stylist', () async {
    await book(nouraId, futureSlot(11, 0));
    final second = await book(null, futureSlot(11, 15));
    expect(second['staffId'], isNot(nouraId));
  });

  test('cancelling frees the lock units', () async {
    final b = await book(nouraId, futureSlot(14, 0));
    expect(backend.locksOf(b['id'] as int), 3);
    await backend.cancelBooking(b['id'] as int);
    expect(backend.locksOf(b['id'] as int), 0);
    await book(nouraId, futureSlot(14, 0)); // free again
  });

  test('rejects times outside working hours', () async {
    await expectLater(
      book(nouraId, futureSlot(21, 30)),
      throwsA(isA<ServerException>().having((e) => e.code, 'code', 'OUTSIDE_WORKING_HOURS')),
    );
  });

  test('seed data gives the owner a schedule for today', () async {
    final owner = await backend.demoLogin('OWNER');
    session.set(owner['token'] as String, UserModel(Map<String, dynamic>.from(owner['user'] as Map)).toEntity());
    final today = await backend.ownerBookings(null);
    expect(today, isNotEmpty);
  });
}
