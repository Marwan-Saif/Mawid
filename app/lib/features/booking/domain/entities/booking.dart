import 'package:equatable/equatable.dart';

enum BookingStatus { pending, confirmed, inProgress, completed, cancelled, noShow }

enum BookingSource { app, web, manual }

extension BookingStatusX on BookingStatus {
  /// Statuses that occupy the staff member's time.
  bool get holdsTime =>
      this == BookingStatus.pending ||
      this == BookingStatus.confirmed ||
      this == BookingStatus.inProgress ||
      this == BookingStatus.completed;

  bool get isActive => this == BookingStatus.pending || this == BookingStatus.confirmed || this == BookingStatus.inProgress;
}

class Booking extends Equatable {
  const Booking({
    required this.id,
    required this.placeId,
    required this.placeNameAr,
    required this.placeNameEn,
    required this.placeTimezone,
    required this.serviceId,
    required this.serviceNameAr,
    required this.serviceNameEn,
    required this.staffId,
    required this.staffName,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.startAt,
    required this.duration,
    required this.price,
    required this.currency,
    required this.status,
    required this.source,
    required this.createdAt,
    this.placeSlug,
    this.note,
  });

  final String id;
  final String placeId;
  final String? placeSlug;
  final String placeNameAr;
  final String placeNameEn;
  final String placeTimezone;
  final String serviceId;
  final String serviceNameAr;
  final String serviceNameEn;

  /// A saved booking always has a real staff member, even if the customer chose "anyone".
  final String staffId;
  final String staffName;
  final String customerId;
  final String? customerName;
  final String? customerPhone;

  /// Always UTC; shown in [placeTimezone].
  final DateTime startAt;
  final Duration duration;
  final double price;
  final String currency;
  final BookingStatus status;
  final BookingSource source;
  final DateTime createdAt;
  final String? note;

  DateTime get endAt => startAt.add(duration);

  String placeName(String lang) => lang == 'ar' ? placeNameAr : placeNameEn;
  String serviceName(String lang) => lang == 'ar' ? serviceNameAr : serviceNameEn;

  /// Customers can cancel or move a booking until 3 hours before it starts.
  bool canChange(DateTime nowUtc) =>
      status.isActive && status != BookingStatus.inProgress && startAt.difference(nowUtc.toUtc()) >= const Duration(hours: 3);

  bool isUpcoming(DateTime nowUtc) => status.isActive && endAt.isAfter(nowUtc.toUtc());

  Booking copyWith({BookingStatus? status, DateTime? startAt, String? staffId, String? staffName}) => Booking(
        id: id,
        placeId: placeId,
        placeSlug: placeSlug,
        placeNameAr: placeNameAr,
        placeNameEn: placeNameEn,
        placeTimezone: placeTimezone,
        serviceId: serviceId,
        serviceNameAr: serviceNameAr,
        serviceNameEn: serviceNameEn,
        staffId: staffId ?? this.staffId,
        staffName: staffName ?? this.staffName,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        startAt: startAt ?? this.startAt,
        duration: duration,
        price: price,
        currency: currency,
        status: status ?? this.status,
        source: source,
        createdAt: createdAt,
        note: note,
      );

  @override
  List<Object?> get props => [id, startAt, status, staffId];
}

/// What the customer asks for. [staffId] null = "anyone available".
class BookingRequest extends Equatable {
  const BookingRequest({
    required this.placeId,
    required this.serviceId,
    required this.startAt,
    this.staffId,
    this.note,
  });

  final String placeId;
  final String serviceId;
  final String? staffId;
  final DateTime startAt;
  final String? note;

  @override
  List<Object?> get props => [placeId, serviceId, staffId, startAt];
}
