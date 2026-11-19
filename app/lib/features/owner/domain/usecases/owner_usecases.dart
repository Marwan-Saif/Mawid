import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/phone.dart';
import '../../../booking/domain/entities/booking.dart';
import '../../../places/domain/entities/place.dart';
import '../repositories/owner_repository.dart';

class GetOwnerPlace implements UseCase<PlaceDetails, NoParams> {
  GetOwnerPlace(this.repository);
  final OwnerRepository repository;

  @override
  Future<Either<Failure, PlaceDetails>> call(NoParams params) => repository.getMyPlace();
}

class GetDaySchedule implements UseCase<List<Booking>, DateTime> {
  GetDaySchedule(this.repository);
  final OwnerRepository repository;

  @override
  Future<Either<Failure, List<Booking>>> call(DateTime day) => repository.getDay(day);
}

class UpdateBookingStatusParams {
  const UpdateBookingStatusParams(this.bookingId, this.status);
  final String bookingId;
  final BookingStatus status;
}

class UpdateBookingStatus implements UseCase<Booking, UpdateBookingStatusParams> {
  UpdateBookingStatus(this.repository);
  final OwnerRepository repository;

  @override
  Future<Either<Failure, Booking>> call(UpdateBookingStatusParams p) => repository.updateStatus(p.bookingId, p.status);
}

class AddManualBooking implements UseCase<Booking, ManualBookingRequest> {
  AddManualBooking(this.repository);
  final OwnerRepository repository;

  @override
  Future<Either<Failure, Booking>> call(ManualBookingRequest r) {
    final phone = normalizePhone(r.customerPhone);
    if (phone == null) return Future.value(const Left(ValidationFailure('INVALID_PHONE')));
    return repository.addManualBooking(ManualBookingRequest(
      serviceId: r.serviceId,
      staffId: r.staffId,
      startAt: r.startAt,
      customerName: r.customerName.trim(),
      customerPhone: phone,
    ));
  }
}

class SaveServiceParams {
  const SaveServiceParams(this.draft, {this.id});
  final ServiceDraft draft;
  final String? id;
}

class SaveService implements UseCase<PlaceService, SaveServiceParams> {
  SaveService(this.repository);
  final OwnerRepository repository;

  @override
  Future<Either<Failure, PlaceService>> call(SaveServiceParams p) {
    final d = p.draft;
    if (d.durationMin < 15 || d.durationMin > 480 || d.durationMin % 15 != 0) {
      return Future.value(const Left(ValidationFailure('INVALID_DURATION')));
    }
    if (d.nameAr.trim().isEmpty || d.nameEn.trim().isEmpty || d.price < 0) {
      return Future.value(const Left(ValidationFailure('VALIDATION')));
    }
    return repository.saveService(d, id: p.id);
  }
}
