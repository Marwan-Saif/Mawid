import 'package:dartz/dartz.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../booking/data/models/booking_model.dart';
import '../../../booking/domain/entities/booking.dart';
import '../../../places/data/models/place_models.dart';
import '../../../places/domain/entities/place.dart';
import '../../domain/repositories/owner_repository.dart';
import '../datasources/owner_data_source.dart';

class OwnerRepositoryImpl implements OwnerRepository {
  OwnerRepositoryImpl(this.remote);

  final OwnerDataSource remote;

  static Object _id(String id) => int.tryParse(id) ?? id;

  @override
  Future<Either<Failure, PlaceDetails>> getMyPlace() => guard(() async => PlaceModels.details(await remote.place()));

  @override
  Future<Either<Failure, List<Booking>>> getDay(DateTime day) => guard(() async {
        final date = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-'
            '${day.day.toString().padLeft(2, '0')}';
        return (await remote.bookings(date)).map(BookingModel.fromJson).toList();
      });

  @override
  Future<Either<Failure, Booking>> updateStatus(String bookingId, BookingStatus status) => guard(
      () async => BookingModel.fromJson(await remote.updateStatus(bookingId, BookingModel.statusCode(status))));

  @override
  Future<Either<Failure, Booking>> addManualBooking(ManualBookingRequest r) => guard(() async =>
      BookingModel.fromJson(await remote.manual({
        'serviceId': _id(r.serviceId),
        'staffId': r.staffId == null ? null : _id(r.staffId!),
        'startAt': r.startAt.toUtc().toIso8601String(),
        'customerName': r.customerName,
        'customerPhone': r.customerPhone,
      })));

  @override
  Future<Either<Failure, PlaceService>> saveService(ServiceDraft d, {String? id}) => guard(() async =>
      PlaceModels.service(await remote.saveService({
        'nameAr': d.nameAr.trim(),
        'nameEn': d.nameEn.trim(),
        'durationMin': d.durationMin,
        'price': d.price,
        'active': d.active,
      }, id: id)));

  @override
  Stream<Booking> newBookings() => remote.newBookings().map(BookingModel.fromJson);
}
