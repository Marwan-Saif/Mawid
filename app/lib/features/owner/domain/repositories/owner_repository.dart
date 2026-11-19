import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../booking/domain/entities/booking.dart';
import '../../../places/domain/entities/place.dart';

/// Walk-in or phone booking typed in by the owner.
class ManualBookingRequest extends Equatable {
  const ManualBookingRequest({
    required this.serviceId,
    required this.startAt,
    required this.customerName,
    required this.customerPhone,
    this.staffId,
  });

  final String serviceId;
  final String? staffId;
  final DateTime startAt;
  final String customerName;
  final String customerPhone;

  @override
  List<Object?> get props => [serviceId, staffId, startAt, customerName, customerPhone];
}

class ServiceDraft extends Equatable {
  const ServiceDraft({
    required this.nameAr,
    required this.nameEn,
    required this.durationMin,
    required this.price,
    this.active = true,
  });

  final String nameAr;
  final String nameEn;
  final int durationMin;
  final double price;
  final bool active;

  @override
  List<Object?> get props => [nameAr, nameEn, durationMin, price, active];
}

abstract class OwnerRepository {
  Future<Either<Failure, PlaceDetails>> getMyPlace();

  Future<Either<Failure, List<Booking>>> getDay(DateTime day);

  Future<Either<Failure, Booking>> updateStatus(String bookingId, BookingStatus status);

  Future<Either<Failure, Booking>> addManualBooking(ManualBookingRequest request);

  Future<Either<Failure, PlaceService>> saveService(ServiceDraft draft, {String? id});

  /// New bookings as they happen (live in the demo backend; the API version can poll or use FCM).
  Stream<Booking> newBookings();
}
