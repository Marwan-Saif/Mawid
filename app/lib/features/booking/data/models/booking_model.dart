import '../../domain/entities/booking.dart';
import '../../domain/entities/time_slot.dart';

/// Adapter: API JSON ⇄ domain [Booking]. The only file that knows the wire names.
class BookingModel {
  const BookingModel._();

  static const _statuses = {
    'PENDING': BookingStatus.pending,
    'CONFIRMED': BookingStatus.confirmed,
    'ARRIVED': BookingStatus.arrived,
    'IN_PROGRESS': BookingStatus.inProgress,
    'COMPLETED': BookingStatus.completed,
    'CANCELLED': BookingStatus.cancelled,
    'NO_SHOW': BookingStatus.noShow,
  };

  static BookingStatus status(String value) => _statuses[value] ?? BookingStatus.pending;

  static String statusCode(BookingStatus s) => _statuses.entries.firstWhere((e) => e.value == s).key;

  static BookingSource source(String? value) => switch (value) {
        'WEB' => BookingSource.web,
        'MANUAL' => BookingSource.manual,
        'WALK_IN' => BookingSource.walkIn,
        _ => BookingSource.app,
      };

  static Booking fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'].toString(),
        placeId: j['placeId'].toString(),
        placeSlug: j['placeSlug'] as String?,
        placeNameAr: (j['placeNameAr'] as String?) ?? '',
        placeNameEn: (j['placeNameEn'] as String?) ?? '',
        placeTimezone: (j['placeTimezone'] as String?) ?? 'UTC',
        serviceId: j['serviceId'].toString(),
        serviceNameAr: (j['serviceNameAr'] as String?) ?? '',
        serviceNameEn: (j['serviceNameEn'] as String?) ?? '',
        staffId: j['staffId'].toString(),
        staffName: (j['staffName'] as String?) ?? '',
        customerId: j['customerId'].toString(),
        customerName: j['customerName'] as String?,
        customerPhone: j['customerPhone'] as String?,
        startAt: DateTime.parse(j['startAt'] as String).toUtc(),
        duration: Duration(minutes: (j['durationMin'] as num).toInt()),
        price: (j['price'] as num).toDouble(),
        currency: j['currency'] as String,
        status: status(j['status'] as String),
        source: source(j['source'] as String?),
        createdAt: DateTime.parse(j['createdAt'] as String).toUtc(),
        note: j['note'] as String?,
        checkInCode: j['checkInCode'] as String?,
        ticketNo: (j['ticketNo'] as num?)?.toInt(),
        checkedInAt: _time(j['checkedInAt']),
        calledAt: _time(j['calledAt']),
        room: j['room'] as String?,
        startedAt: _time(j['startedAt']),
        finishedAt: _time(j['finishedAt']),
      );

  static DateTime? _time(Object? v) => v is String ? DateTime.parse(v).toUtc() : null;

  /// Request body for POST /bookings. Ids go back as numbers when they are numeric.
  static Map<String, dynamic> requestJson(BookingRequest r) => {
        'placeId': _id(r.placeId),
        'serviceId': _id(r.serviceId),
        'staffId': r.staffId == null ? null : _id(r.staffId!),
        'startAt': r.startAt.toUtc().toIso8601String(),
        'note': r.note,
      };

  static Object _id(String id) => int.tryParse(id) ?? id;
}

class TimeSlotModel {
  const TimeSlotModel._();

  static TimeSlot fromJson(Map<String, dynamic> j) => TimeSlot(
        startAt: DateTime.parse(j['startAt'] as String).toUtc(),
        freeStaffIds: (j['freeStaffIds'] as List? ?? const []).map((e) => e.toString()).toList(),
      );
}
