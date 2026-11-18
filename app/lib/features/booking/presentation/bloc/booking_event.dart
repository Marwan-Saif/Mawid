part of 'booking_bloc.dart';

sealed class BookingEvent extends Equatable {
  const BookingEvent();

  @override
  List<Object?> get props => [];
}

/// Opens the slot picker for a service, or for moving an existing booking.
class BookingStarted extends BookingEvent {
  const BookingStarted({required this.placeId, this.serviceId, this.details, this.rescheduling});

  final String placeId;
  final String? serviceId;

  /// Passed from the place page to skip a reload; fetched when missing (deep link, reschedule).
  final PlaceDetails? details;
  final Booking? rescheduling;

  @override
  List<Object?> get props => [placeId, serviceId, rescheduling];
}

class DaySelected extends BookingEvent {
  const DaySelected(this.day);
  final DateTime day;

  @override
  List<Object?> get props => [day];
}

/// null = "anyone available".
class StaffSelected extends BookingEvent {
  const StaffSelected(this.staffId);
  final String? staffId;

  @override
  List<Object?> get props => [staffId];
}

class SlotSelected extends BookingEvent {
  const SlotSelected(this.slot);
  final TimeSlot slot;

  @override
  List<Object?> get props => [slot];
}

class BookingConfirmed extends BookingEvent {
  const BookingConfirmed();
}
