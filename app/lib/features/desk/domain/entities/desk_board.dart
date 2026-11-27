import 'package:equatable/equatable.dart';

import '../../../booking/domain/entities/booking.dart';
import '../../../places/domain/entities/place.dart';
import 'invoice.dart';

/// What the waiting room and the desk show next to each doctor or stylist.
enum StaffPresence { available, busy, onBreak, away }

class DeskPlace extends Equatable {
  const DeskPlace({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.nameEn,
    required this.timezone,
    required this.currency,
  });

  final String id;
  final String slug;
  final String nameAr;
  final String nameEn;
  final String timezone;
  final String currency;

  String name(String lang) => lang == 'ar' ? nameAr : nameEn;

  @override
  List<Object?> get props => [id, slug, nameAr, nameEn, timezone, currency];
}

class DeskStaff extends Equatable {
  const DeskStaff({
    required this.id,
    required this.name,
    required this.titleAr,
    required this.titleEn,
    required this.presence,
    this.room,
    this.presenceSince,
    this.currentBookingId,
    this.waiting = 0,
  });

  final String id;
  final String name;
  final String titleAr;
  final String titleEn;
  final String? room;
  final StaffPresence presence;
  final DateTime? presenceSince;

  /// The visit in the room right now, if any.
  final String? currentBookingId;

  /// Checked-in people waiting for this person.
  final int waiting;

  String title(String lang) => lang == 'ar' ? titleAr : titleEn;

  DeskStaff copyWith({StaffPresence? presence, String? Function()? currentBookingId, int? waiting}) => DeskStaff(
        id: id,
        name: name,
        titleAr: titleAr,
        titleEn: titleEn,
        room: room,
        presence: presence ?? this.presence,
        presenceSince: presence != null && presence != this.presence ? DateTime.now().toUtc() : presenceSince,
        currentBookingId: currentBookingId != null ? currentBookingId() : this.currentBookingId,
        waiting: waiting ?? this.waiting,
      );

  @override
  List<Object?> get props => [id, name, room, presence, presenceSince, currentBookingId, waiting];
}

/// A visit today and where it stands in the queue.
class QueueEntry extends Equatable {
  const QueueEntry({
    required this.booking,
    required this.expectedStartAt,
    this.delayMin = 0,
    this.ahead = 0,
    this.late = false,
    this.invoiceId,
    this.invoiceNumber,
    this.invoiceStatus,
    this.pendingSync = false,
  });

  final Booking booking;

  /// When they are expected to go in (for someone in the room: when they went in).
  final DateTime expectedStartAt;

  /// Minutes after the booked time.
  final int delayMin;

  /// People before them with the same doctor, including whoever is in the room.
  final int ahead;

  /// Booked, not here, and more than 15 minutes past their time.
  final bool late;
  final String? invoiceId;
  final int? invoiceNumber;
  final InvoiceStatus? invoiceStatus;

  /// Changed on this device while offline; not on the server yet.
  final bool pendingSync;

  String get id => booking.id;

  QueueEntry copyWith({Booking? booking, bool? pendingSync, String? invoiceId, int? invoiceNumber, InvoiceStatus? invoiceStatus}) =>
      QueueEntry(
        booking: booking ?? this.booking,
        expectedStartAt: expectedStartAt,
        delayMin: delayMin,
        ahead: ahead,
        late: late,
        invoiceId: invoiceId ?? this.invoiceId,
        invoiceNumber: invoiceNumber ?? this.invoiceNumber,
        invoiceStatus: invoiceStatus ?? this.invoiceStatus,
        pendingSync: pendingSync ?? this.pendingSync,
      );

  @override
  List<Object?> get props =>
      [booking, expectedStartAt, delayMin, ahead, late, invoiceId, invoiceNumber, invoiceStatus, pendingSync];
}

class DeskCounts extends Equatable {
  const DeskCounts({this.booked = 0, this.waiting = 0, this.inRoom = 0, this.done = 0, this.noShow = 0});

  final int booked;
  final int waiting;
  final int inRoom;
  final int done;
  final int noShow;

  factory DeskCounts.of(List<QueueEntry> queue) {
    int n(bool Function(BookingStatus) test) => queue.where((q) => test(q.booking.status)).length;
    return DeskCounts(
      booked: n((s) => s.isBooked),
      waiting: n((s) => s == BookingStatus.arrived),
      inRoom: n((s) => s == BookingStatus.inProgress),
      done: n((s) => s == BookingStatus.completed),
      noShow: n((s) => s == BookingStatus.noShow),
    );
  }

  @override
  List<Object?> get props => [booked, waiting, inRoom, done, noShow];
}

/// Everything the front desk shows, in one load.
class DeskBoard extends Equatable {
  const DeskBoard({
    required this.date,
    required this.place,
    required this.staff,
    required this.queue,
    required this.services,
    required this.counts,
    required this.serverTime,
    this.offlineSince,
  });

  final String date;
  final DeskPlace place;
  final List<DeskStaff> staff;
  final List<QueueEntry> queue;
  final List<PlaceService> services;
  final DeskCounts counts;
  final DateTime serverTime;

  /// Set when this is the last saved copy because the network is down.
  final DateTime? offlineSince;

  bool get isOffline => offlineSince != null;

  List<QueueEntry> withStatus(BookingStatus s) => queue.where((q) => q.booking.status == s).toList();

  List<QueueEntry> get inRoom => withStatus(BookingStatus.inProgress);

  /// Checked in, in the order they'll go in.
  List<QueueEntry> get waiting => withStatus(BookingStatus.arrived)..sort((a, b) => a.expectedStartAt.compareTo(b.expectedStartAt));

  List<QueueEntry> get notArrived =>
      queue.where((q) => q.booking.status.isBooked).toList()..sort((a, b) => a.booking.startAt.compareTo(b.booking.startAt));

  List<QueueEntry> get finished => queue
      .where((q) => q.booking.status == BookingStatus.completed || q.booking.status == BookingStatus.noShow)
      .toList()
    ..sort((a, b) => b.booking.startAt.compareTo(a.booking.startAt));

  DeskStaff? staffById(String id) => staff.where((s) => s.id == id).firstOrNull;

  DeskBoard copyWith({List<DeskStaff>? staff, List<QueueEntry>? queue, DateTime? Function()? offlineSince}) {
    final q = queue ?? this.queue;
    return DeskBoard(
      date: date,
      place: place,
      staff: staff ?? this.staff,
      queue: q,
      services: services,
      counts: queue == null ? counts : DeskCounts.of(q),
      serverTime: serverTime,
      offlineSince: offlineSince != null ? offlineSince() : this.offlineSince,
    );
  }

  @override
  List<Object?> get props => [date, place, staff, queue, services, counts, serverTime, offlineSince];
}

/// Someone at the desk without a booking.
class WalkInRequest extends Equatable {
  const WalkInRequest({required this.serviceId, required this.customerName, required this.customerPhone, this.staffId});

  final String serviceId;
  final String? staffId;
  final String customerName;
  final String customerPhone;

  @override
  List<Object?> get props => [serviceId, staffId, customerName, customerPhone];
}
