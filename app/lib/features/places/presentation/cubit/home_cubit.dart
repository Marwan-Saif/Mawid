import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/session/booking_changes.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../booking/domain/entities/booking.dart';
import '../../../booking/domain/usecases/get_my_bookings.dart';
import '../../domain/entities/place.dart';
import '../../domain/usecases/get_places.dart';

enum LoadStatus { loading, ready, failure }

class HomeState extends Equatable {
  const HomeState({this.status = LoadStatus.loading, this.places = const [], this.next, this.failure});

  final LoadStatus status;
  final List<Place> places;

  /// The customer's next upcoming appointment, if any.
  final Booking? next;
  final Failure? failure;

  @override
  List<Object?> get props => [status, places, next, failure];
}

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({required this.getPlaces, required this.getMyBookings, BookingChanges? changes, DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(const HomeState()) {
    _sub = changes?.stream.listen((_) => load());
  }

  StreamSubscription<void>? _sub;

  final GetPlaces getPlaces;
  final GetMyBookings getMyBookings;
  final DateTime Function() _now;

  Future<void> load() async {
    if (isClosed) return;
    emit(HomeState(places: state.places, next: state.next));
    final places = await getPlaces(const GetPlacesParams());
    final bookings = await getMyBookings(const NoParams());
    if (isClosed) return;
    places.fold(
      (f) => emit(HomeState(status: LoadStatus.failure, failure: f)),
      (list) {
        final upcoming = bookings.fold((_) => <Booking>[], (b) => b.where((x) => x.isUpcoming(_now())).toList())
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
        emit(HomeState(status: LoadStatus.ready, places: list, next: upcoming.isEmpty ? null : upcoming.first));
      },
    );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
