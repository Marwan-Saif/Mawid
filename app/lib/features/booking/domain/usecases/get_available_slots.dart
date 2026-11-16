import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/time_slot.dart';
import '../repositories/booking_repository.dart';

class SlotsParams extends Equatable {
  const SlotsParams({required this.placeId, required this.serviceId, required this.day, this.staffId});

  final String placeId;
  final String serviceId;

  /// A calendar day at the place (only year, month, day are used).
  final DateTime day;
  final String? staffId;

  @override
  List<Object?> get props => [placeId, serviceId, day, staffId];
}

class GetAvailableSlots implements UseCase<List<TimeSlot>, SlotsParams> {
  GetAvailableSlots(this.repository);

  final BookingRepository repository;

  @override
  Future<Either<Failure, List<TimeSlot>>> call(SlotsParams p) => repository.getAvailableSlots(
        placeId: p.placeId,
        serviceId: p.serviceId,
        day: DateTime.utc(p.day.year, p.day.month, p.day.day),
        staffId: p.staffId,
      );
}
