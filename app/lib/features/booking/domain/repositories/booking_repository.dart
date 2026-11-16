import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/booking.dart';
import '../entities/time_slot.dart';

abstract class BookingRepository {
  Future<Either<Failure, List<TimeSlot>>> getAvailableSlots({
    required String placeId,
    required String serviceId,
    required DateTime day,
    String? staffId,
  });

  Future<Either<Failure, Booking>> createBooking(BookingRequest request);

  Future<Either<Failure, Booking>> cancelBooking(String bookingId);

  Future<Either<Failure, Booking>> rescheduleBooking(String bookingId, DateTime startAt, {String? staffId});

  Future<Either<Failure, List<Booking>>> getMyBookings();
}
