import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/booking.dart';
import '../repositories/booking_repository.dart';

class GetMyBookings implements UseCase<List<Booking>, NoParams> {
  GetMyBookings(this.repository);

  final BookingRepository repository;

  @override
  Future<Either<Failure, List<Booking>>> call(NoParams params) => repository.getMyBookings();
}
