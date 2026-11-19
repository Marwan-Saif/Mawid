import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/formatters.dart';
import '../../../booking/domain/entities/booking.dart';
import '../../../places/domain/entities/place.dart';
import '../../../places/presentation/cubit/home_cubit.dart';
import '../../domain/repositories/owner_repository.dart';
import '../../domain/usecases/owner_usecases.dart';

class OwnerDashboardState extends Equatable {
  const OwnerDashboardState({
    this.status = LoadStatus.loading,
    this.place,
    this.day,
    this.bookings = const [],
    this.failure,
    this.alert,
    this.updatingId,
  });

  final LoadStatus status;
  final PlaceDetails? place;

  /// Calendar day at the place (date-only).
  final DateTime? day;
  final List<Booking> bookings;
  final Failure? failure;

  /// Latest "new booking" to announce; the page shows it once.
  final Booking? alert;
  final String? updatingId;

  int get total => bookings.where((b) => b.status != BookingStatus.cancelled).length;
  int get completed => bookings.where((b) => b.status == BookingStatus.completed).length;

  /// Booked today (by the customer, the web link or the owner).
  int newSince(DateTime nowUtc) => bookings
      .where((b) => b.status != BookingStatus.cancelled && nowUtc.difference(b.createdAt) < const Duration(hours: 24))
      .length;

  OwnerDashboardState copyWith({
    LoadStatus? status,
    PlaceDetails? place,
    DateTime? day,
    List<Booking>? bookings,
    Failure? failure,
    Booking? alert,
    String? Function()? updatingId,
  }) =>
      OwnerDashboardState(
        status: status ?? this.status,
        place: place ?? this.place,
        day: day ?? this.day,
        bookings: bookings ?? this.bookings,
        failure: failure,
        alert: alert,
        updatingId: updatingId != null ? updatingId() : this.updatingId,
      );

  @override
  List<Object?> get props => [status, place, day, bookings, failure, alert, updatingId];
}

class OwnerDashboardCubit extends Cubit<OwnerDashboardState> {
  OwnerDashboardCubit({
    required this.getPlace,
    required this.getDay,
    required this.updateStatus,
    required this.repository,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        super(const OwnerDashboardState()) {
    _sub = repository.newBookings().listen(_onNewBooking);
  }

  final GetOwnerPlace getPlace;
  final GetDaySchedule getDay;
  final UpdateBookingStatus updateStatus;
  final OwnerRepository repository;
  final DateTime Function() _now;
  late final StreamSubscription<Booking> _sub;

  Future<void> load({DateTime? day}) async {
    emit(state.copyWith(status: LoadStatus.loading));
    var place = state.place;
    if (place == null) {
      final result = await getPlace(const NoParams());
      if (result.isLeft()) {
        emit(state.copyWith(status: LoadStatus.failure, failure: result.fold((f) => f, (_) => null)));
        return;
      }
      place = result.getOrElse(() => throw StateError('unreachable'));
    }
    final today = Fmt.inZone(_now().toUtc(), place.place.timezone);
    final target = day ?? state.day ?? DateTime.utc(today.year, today.month, today.day);
    final result = await getDay(target);
    result.fold(
      (f) => emit(state.copyWith(status: LoadStatus.failure, failure: f, place: place, day: target)),
      (list) => emit(state.copyWith(status: LoadStatus.ready, place: place, day: target, bookings: list)),
    );
  }

  Future<void> shiftDay(int days) {
    final d = state.day;
    if (d == null) return load();
    return load(day: DateTime.utc(d.year, d.month, d.day + days));
  }

  Future<Failure?> setStatus(Booking booking, BookingStatus status) async {
    emit(state.copyWith(updatingId: () => booking.id));
    final result = await updateStatus(UpdateBookingStatusParams(booking.id, status));
    return result.fold(
      (f) {
        emit(state.copyWith(updatingId: () => null));
        return f;
      },
      (updated) {
        emit(state.copyWith(
          updatingId: () => null,
          bookings: [for (final b in state.bookings) b.id == updated.id ? updated : b],
        ));
        return null;
      },
    );
  }

  void _onNewBooking(Booking b) {
    if (isClosed) return;
    emit(state.copyWith(alert: b));
    load();
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
