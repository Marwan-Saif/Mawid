import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/formatters.dart';
import '../../../places/domain/entities/place.dart';
import '../../../places/domain/usecases/get_place_details.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/time_slot.dart';
import '../../domain/usecases/create_booking.dart';
import '../../domain/usecases/get_available_slots.dart';
import '../../domain/usecases/reschedule_booking.dart';

part 'booking_event.dart';
part 'booking_state.dart';

/// The slot picker: day strip → staff → time grid → confirm.
/// Talks only to use cases; knows nothing about HTTP or the fake backend.
class BookingBloc extends Bloc<BookingEvent, BookingState> {
  BookingBloc(
    this.getSlots,
    this.createBooking, {
    required this.getPlaceDetails,
    required this.rescheduleBooking,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        super(const BookingState.initial()) {
    on<BookingStarted>(_onStarted);
    on<DaySelected>(_onDaySelected);
    on<StaffSelected>(_onStaffSelected);
    on<SlotSelected>((e, emit) => emit(state.copyWith(selectedSlot: () => e.slot, failure: () => null)));
    on<BookingConfirmed>(_onConfirmed);
  }

  final GetAvailableSlots getSlots;
  final CreateBooking createBooking;
  final GetPlaceDetails getPlaceDetails;
  final RescheduleBooking rescheduleBooking;
  final DateTime Function() _now;

  static const _daysAhead = 14;

  Future<void> _onStarted(BookingStarted e, Emitter<BookingState> emit) async {
    emit(BookingState(status: Status.loading, rescheduling: e.rescheduling));
    var details = e.details;
    if (details == null) {
      final result = await getPlaceDetails(e.placeId);
      if (result.isLeft()) {
        emit(state.copyWith(status: Status.failure, failure: () => result.fold((f) => f, (_) => null)));
        return;
      }
      details = result.getOrElse(() => throw StateError('unreachable'));
    }
    final serviceId = e.rescheduling?.serviceId ?? e.serviceId;
    final service = (serviceId == null ? null : details.serviceById(serviceId)) ??
        (details.services.isEmpty ? null : details.services.first);
    if (service == null) {
      emit(state.copyWith(status: Status.failure, details: details, failure: () => const ServerFailure('NO_SERVICE')));
      return;
    }

    final today = Fmt.inZone(_now().toUtc(), details.place.timezone);
    final days = List.generate(_daysAhead, (i) => DateTime.utc(today.year, today.month, today.day + i));
    final firstOpen = days.firstWhere((d) => !details!.place.isClosedOn(d.weekday), orElse: () => days.first);

    emit(state.copyWith(
      status: Status.ready,
      details: details,
      service: service,
      staffId: () => e.rescheduling?.staffId,
      days: days,
      day: firstOpen,
    ));
    await _loadSlots(emit);
  }

  Future<void> _onDaySelected(DaySelected e, Emitter<BookingState> emit) async {
    emit(state.copyWith(day: e.day, selectedSlot: () => null, failure: () => null));
    await _loadSlots(emit);
  }

  Future<void> _onStaffSelected(StaffSelected e, Emitter<BookingState> emit) async {
    emit(state.copyWith(staffId: () => e.staffId, selectedSlot: () => null, failure: () => null));
    await _loadSlots(emit);
  }

  Future<void> _loadSlots(Emitter<BookingState> emit) async {
    final details = state.details;
    final service = state.service;
    final day = state.day;
    if (details == null || service == null || day == null) return;
    if (state.isClosed(day)) {
      emit(state.copyWith(slots: const [], slotsLoading: false));
      return;
    }
    emit(state.copyWith(slotsLoading: true));
    final result = await getSlots(SlotsParams(
      placeId: details.place.id,
      serviceId: service.id,
      day: day,
      staffId: state.staffId,
    ));
    // Ignore a late answer for a day or person the user already moved away from.
    if (state.day != day) return;
    result.fold(
      (f) => emit(state.copyWith(slotsLoading: false, slots: const [], failure: () => f)),
      (slots) => emit(state.copyWith(slotsLoading: false, slots: slots)),
    );
  }

  Future<void> _onConfirmed(BookingConfirmed e, Emitter<BookingState> emit) async {
    final slot = state.selectedSlot;
    final details = state.details;
    final service = state.service;
    if (slot == null || details == null || service == null) return;
    emit(state.copyWith(status: Status.submitting, failure: () => null));

    final result = state.isRescheduling
        ? await rescheduleBooking(RescheduleParams(booking: state.rescheduling!, startAt: slot.startAt, staffId: state.staffId))
        : await createBooking(BookingRequest(
            placeId: details.place.id,
            serviceId: service.id,
            staffId: state.staffId,
            startAt: slot.startAt,
          ));

    await result.fold(
      (f) async {
        emit(state.copyWith(status: Status.failure, failure: () => f, selectedSlot: () => null));
        // Someone was faster: refresh the grid so the taken time shows as booked.
        if (f is SlotTakenFailure) await _loadSlots(emit);
        emit(state.copyWith(status: Status.ready));
      },
      (b) async => emit(state.copyWith(status: Status.success, booking: b)),
    );
  }
}
