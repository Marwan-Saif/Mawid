import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/place.dart';
import '../../domain/usecases/get_places.dart';
import 'home_cubit.dart';

class ExploreState extends Equatable {
  const ExploreState({this.status = LoadStatus.loading, this.places = const [], this.category, this.query = '', this.failure});

  final LoadStatus status;
  final List<Place> places;
  final PlaceCategory? category;
  final String query;
  final Failure? failure;

  @override
  List<Object?> get props => [status, places, category, query, failure];
}

/// Search + category filter. Typing is debounced so we don't hit the API on every key.
class ExploreCubit extends Cubit<ExploreState> {
  ExploreCubit(this.getPlaces, {PlaceCategory? initialCategory, String initialQuery = ''})
      : super(ExploreState(category: initialCategory, query: initialQuery));

  final GetPlaces getPlaces;
  Timer? _debounce;
  int _request = 0;

  Future<void> load() => _fetch(state.category, state.query);

  void setCategory(PlaceCategory? category) => _fetch(category, state.query);

  void setQuery(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _fetch(state.category, query));
  }

  Future<void> _fetch(PlaceCategory? category, String query) async {
    final id = ++_request;
    emit(ExploreState(status: LoadStatus.loading, places: state.places, category: category, query: query));
    final result = await getPlaces(GetPlacesParams(category: category, query: query));
    if (id != _request || isClosed) return; // a newer search already started
    result.fold(
      (f) => emit(ExploreState(status: LoadStatus.failure, category: category, query: query, failure: f)),
      (list) => emit(ExploreState(status: LoadStatus.ready, places: list, category: category, query: query)),
    );
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
