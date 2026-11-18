part of 'booking_bloc.dart';

enum Status { initial, loading, ready, submitting, success, failure }

class BookingState extends Equatable {
  const BookingState({
    this.status = Status.initial,
    this.details,
    this.service,
    this.staffId,
    this.days = const [],
    this.day,
    this.slots = const [],
    this.slotsLoading = false,
    this.selectedSlot,
    this.failure,
    this.booking,
    this.rescheduling,
  });

  const BookingState.initial() : this();

  final Status status;
  final PlaceDetails? details;
  final PlaceService? service;
  final String? staffId;

  /// The next 14 calendar days at the place (date-only values).
  final List<DateTime> days;
  final DateTime? day;
  final List<TimeSlot> slots;
  final bool slotsLoading;
  final TimeSlot? selectedSlot;
  final Failure? failure;

  /// Set on success.
  final Booking? booking;
  final Booking? rescheduling;

  bool get isRescheduling => rescheduling != null;

  bool isClosed(DateTime d) => details?.place.isClosedOn(d.weekday) ?? false;

  BookingState copyWith({
    Status? status,
    PlaceDetails? details,
    PlaceService? service,
    String? Function()? staffId,
    List<DateTime>? days,
    DateTime? day,
    List<TimeSlot>? slots,
    bool? slotsLoading,
    TimeSlot? Function()? selectedSlot,
    Failure? Function()? failure,
    Booking? booking,
    Booking? rescheduling,
  }) =>
      BookingState(
        status: status ?? this.status,
        details: details ?? this.details,
        service: service ?? this.service,
        staffId: staffId != null ? staffId() : this.staffId,
        days: days ?? this.days,
        day: day ?? this.day,
        slots: slots ?? this.slots,
        slotsLoading: slotsLoading ?? this.slotsLoading,
        selectedSlot: selectedSlot != null ? selectedSlot() : this.selectedSlot,
        failure: failure != null ? failure() : this.failure,
        booking: booking ?? this.booking,
        rescheduling: rescheduling ?? this.rescheduling,
      );

  @override
  List<Object?> get props =>
      [status, details, service, staffId, days, day, slots, slotsLoading, selectedSlot, failure, booking, rescheduling];
}
