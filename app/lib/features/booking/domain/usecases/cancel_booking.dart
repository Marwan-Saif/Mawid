import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/booking.dart';
import '../repositories/booking_repository.dart';

class CancelBooking implements UseCase<Booking, Booking> {
  CancelBooking(this.repository, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final BookingRepository repository;
  final DateTime Function() _now;

  @override
  Future<Either<Failure, Booking>> call(Booking booking) {
    if (!booking.canChange(_now())) {
      return Future.value(const Left(ValidationFailure('TOO_LATE_TO_CHANGE')));
    }
    return repository.cancelBooking(booking.id);
  }
}
