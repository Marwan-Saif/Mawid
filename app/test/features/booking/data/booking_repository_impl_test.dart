import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/core/error/exceptions.dart';
import 'package:mawid/core/error/failures.dart';
import 'package:mawid/core/session/booking_changes.dart';
import 'package:mawid/features/booking/data/datasources/booking_data_source.dart';
import 'package:mawid/features/booking/data/repositories/booking_repository_impl.dart';
import 'package:mawid/features/booking/domain/entities/booking.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';

class MockDataSource extends Mock implements BookingDataSource {}

void main() {
  late MockDataSource remote;
  late BookingChanges changes;
  late BookingRepositoryImpl repo;
  final request = BookingRequest(placeId: '1', serviceId: '2', startAt: DateTime.utc(2026, 11, 5, 13));

  setUp(() {
    remote = MockDataSource();
    changes = BookingChanges();
    repo = BookingRepositoryImpl(remote, changes: changes);
  });

  test('"anyone available" is sent as a null staffId', () async {
    when(() => remote.create(any())).thenAnswer((_) async => tBookingJson());

    await repo.createBooking(request);

    final body = verify(() => remote.create(captureAny())).captured.single as Map<String, dynamic>;
    expect(body.containsKey('staffId'), isTrue);
    expect(body['staffId'], isNull);
  });

  test('SlotTakenException becomes SlotTakenFailure', () async {
    when(() => remote.create(any())).thenThrow(const SlotTakenException());

    final result = await repo.createBooking(request);

    expect(result.fold((f) => f, (_) => null), isA<SlotTakenFailure>());
  });

  test('no network becomes OfflineFailure', () async {
    when(() => remote.create(any())).thenThrow(const NetworkException());

    final result = await repo.createBooking(request);

    expect(result.fold((f) => f, (_) => null), isA<OfflineFailure>());
  });

  test('a 409 TOO_LATE_TO_CHANGE becomes a ValidationFailure with that code', () async {
    when(() => remote.cancel('42')).thenThrow(const ServerException('TOO_LATE_TO_CHANGE', null, 409));

    final result = await repo.cancelBooking('42');

    expect(result.fold((f) => f, (_) => null), const ValidationFailure('TOO_LATE_TO_CHANGE'));
  });

  test('a successful booking tells the rest of the app to refresh', () async {
    when(() => remote.create(any())).thenAnswer((_) async => tBookingJson());
    final events = <void>[];
    final sub = changes.stream.listen(events.add);

    await repo.createBooking(request);
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    await sub.cancel();
  });
}
