import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/booking.dart';
import '../repositories/booking_repository.dart';

class RescheduleParams extends Equatable {
  const RescheduleParams({required this.booking, required this.startAt, this.staffId});

  final Booking booking;
  final DateTime startAt;
  final String? staffId;

  @override
  List<Object?> get props => [booking, startAt, staffId];
}

class RescheduleBooking implements UseCase<Booking, RescheduleParams> {
  RescheduleBooking(this.repository, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final BookingRepository repository;
  final DateTime Function() _now;

  @override
  Future<Either<Failure, Booking>> call(RescheduleParams p) {
    if (!p.booking.canChange(_now())) {
      return Future.value(const Left(ValidationFailure('TOO_LATE_TO_CHANGE')));
    }
    if (!p.startAt.toUtc().isAfter(_now().toUtc())) {
      return Future.value(const Left(ValidationFailure('SLOT_IN_PAST')));
    }
    return repository.rescheduleBooking(p.booking.id, p.startAt, staffId: p.staffId);
  }
}
