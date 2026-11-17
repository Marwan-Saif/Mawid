import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/features/booking/data/models/booking_model.dart';
import 'package:mawid/features/booking/domain/entities/booking.dart';

import '../../../helpers/fixtures.dart';

void main() {
  test('parses the API JSON into the domain entity', () {
    final b = BookingModel.fromJson(tBookingJson());

    expect(b.id, '42');
    expect(b.staffId, '7');
    expect(b.startAt, DateTime.utc(2026, 11, 5, 13));
    expect(b.startAt.isUtc, isTrue);
    expect(b.duration, const Duration(minutes: 45));
    expect(b.status, BookingStatus.inProgress);
    expect(b.source, BookingSource.web);
    expect(b.endAt, DateTime.utc(2026, 11, 5, 13, 45));
  });

  test('status codes round-trip', () {
    for (final s in BookingStatus.values) {
      expect(BookingModel.status(BookingModel.statusCode(s)), s);
    }
  });

  test('request JSON sends numeric ids and UTC time; null staff means anyone', () {
    final json = BookingModel.requestJson(
      BookingRequest(placeId: '1', serviceId: '2', startAt: DateTime.utc(2026, 11, 5, 13)),
    );
    expect(json['placeId'], 1);
    expect(json['staffId'], isNull);
    expect(json['startAt'], '2026-11-05T13:00:00.000Z');
  });
}
