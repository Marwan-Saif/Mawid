import 'package:dartz/dartz.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/session/booking_changes.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/time_slot.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_data_source.dart';
import '../models/booking_model.dart';

/// Implements the domain contract on top of either data source (Spring API or in-memory).
/// Exceptions become Failures in [guard]; nothing above this layer needs try/catch.
class BookingRepositoryImpl implements BookingRepository {
  BookingRepositoryImpl(this.remote, {BookingChanges? changes}) : _changes = changes;

  final BookingDataSource remote;
  final BookingChanges? _changes;

  Future<Either<Failure, Booking>> _changing(Future<Either<Failure, Booking>> call) async {
    final result = await call;
    if (result.isRight()) _changes?.notify();
    return result;
  }

  @override
  Future<Either<Failure, List<TimeSlot>>> getAvailableSlots({
    required String placeId,
    required String serviceId,
    required DateTime day,
    String? staffId,
  }) =>
      guard(() async {
        final date = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-'
            '${day.day.toString().padLeft(2, '0')}';
        final body = await remote.availability(placeId, serviceId, date, staffId);
        return (body['slots'] as List)
            .map((e) => TimeSlotModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });

  @override
  Future<Either<Failure, Booking>> createBooking(BookingRequest request) =>
      _changing(guard(() async => BookingModel.fromJson(await remote.create(BookingModel.requestJson(request)))));

  @override
  Future<Either<Failure, Booking>> cancelBooking(String bookingId) =>
      _changing(guard(() async => BookingModel.fromJson(await remote.cancel(bookingId))));

  @override
  Future<Either<Failure, Booking>> rescheduleBooking(String bookingId, DateTime startAt, {String? staffId}) =>
      _changing(guard(() async => BookingModel.fromJson(await remote.reschedule(bookingId, startAt, staffId))));

  @override
  Future<Either<Failure, List<Booking>>> getMyBookings() =>
      guard(() async => (await remote.mine()).map(BookingModel.fromJson).toList());
}
