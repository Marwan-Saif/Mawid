import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/core/error/failures.dart';
import 'package:mawid/features/booking/domain/entities/booking.dart';
import 'package:mawid/features/booking/domain/repositories/booking_repository.dart';
import 'package:mawid/features/booking/domain/usecases/cancel_booking.dart';
import 'package:mawid/features/booking/domain/usecases/create_booking.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fixtures.dart';

class MockBookingRepository extends Mock implements BookingRepository {}

void main() {
  late MockBookingRepository repo;
  final now = DateTime.utc(2026, 11, 5, 8);

  setUpAll(() => registerFallbackValue(BookingRequest(placeId: '1', serviceId: '1', startAt: DateTime.utc(2026))));
  setUp(() => repo = MockBookingRepository());

  group('CreateBooking', () {
    test('rejects a time in the past without calling the repository', () async {
      final useCase = CreateBooking(repo, now: () => now);
      final result = await useCase(BookingRequest(placeId: '1', serviceId: '2', startAt: now.subtract(const Duration(minutes: 1))));

      expect(result, const Left<Failure, Booking>(ValidationFailure('SLOT_IN_PAST')));
      verifyNever(() => repo.createBooking(any()));
    });

    test('passes a future booking to the repository', () async {
      final booking = tBooking(start: now.add(const Duration(days: 1)));
      when(() => repo.createBooking(any())).thenAnswer((_) async => Right(booking));

      final result = await CreateBooking(repo, now: () => now)(
          BookingRequest(placeId: '1', serviceId: '2', startAt: booking.startAt));

      expect(result, Right<Failure, Booking>(booking));
    });
  });

  group('CancelBooking', () {
    test('refuses less than 3 hours before', () async {
      final soon = tBooking(start: now.add(const Duration(hours: 2)));
      final result = await CancelBooking(repo, now: () => now)(soon);

      expect(result, const Left<Failure, Booking>(ValidationFailure('TOO_LATE_TO_CHANGE')));
      verifyNever(() => repo.cancelBooking(any()));
    });

    test('cancels when there is enough notice', () async {
      final later = tBooking(start: now.add(const Duration(hours: 5)));
      when(() => repo.cancelBooking(later.id))
          .thenAnswer((_) async => Right(later.copyWith(status: BookingStatus.cancelled)));

      final result = await CancelBooking(repo, now: () => now)(later);

      expect(result.isRight(), isTrue);
    });
  });
}
