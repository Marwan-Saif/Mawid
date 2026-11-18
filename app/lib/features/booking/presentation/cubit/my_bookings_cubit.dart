import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/session/booking_changes.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../places/presentation/cubit/home_cubit.dart';
import '../../domain/entities/booking.dart';
import '../../domain/usecases/get_my_bookings.dart';

class MyBookingsState extends Equatable {
  const MyBookingsState({this.status = LoadStatus.loading, this.bookings = const [], this.failure});

  final LoadStatus status;
  final List<Booking> bookings;
  final Failure? failure;

  List<Booking> upcoming(DateTime now) =>
      bookings.where((b) => b.isUpcoming(now)).toList()..sort((a, b) => a.startAt.compareTo(b.startAt));

  List<Booking> past(DateTime now) =>
      bookings.where((b) => !b.isUpcoming(now)).toList()..sort((a, b) => b.startAt.compareTo(a.startAt));

  @override
  List<Object?> get props => [status, bookings, failure];
}

class MyBookingsCubit extends Cubit<MyBookingsState> {
  MyBookingsCubit(this.getMyBookings, {BookingChanges? changes}) : super(const MyBookingsState()) {
    _sub = changes?.stream.listen((_) => load());
  }

  final GetMyBookings getMyBookings;
  StreamSubscription<void>? _sub;

  Future<void> load() async {
    if (isClosed) return;
    emit(MyBookingsState(bookings: state.bookings));
    final result = await getMyBookings(const NoParams());
    if (isClosed) return;
    result.fold(
      (f) => emit(MyBookingsState(status: LoadStatus.failure, failure: f)),
      (list) => emit(MyBookingsState(status: LoadStatus.ready, bookings: list)),
    );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
