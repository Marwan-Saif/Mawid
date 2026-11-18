import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/place.dart';
import '../../domain/usecases/get_place_details.dart';
import 'home_cubit.dart';

class PlaceDetailsState extends Equatable {
  const PlaceDetailsState({this.status = LoadStatus.loading, this.details, this.failure});

  final LoadStatus status;
  final PlaceDetails? details;
  final Failure? failure;

  @override
  List<Object?> get props => [status, details, failure];
}

class PlaceDetailsCubit extends Cubit<PlaceDetailsState> {
  PlaceDetailsCubit(this.getDetails, this.placeId) : super(const PlaceDetailsState());

  final GetPlaceDetails getDetails;
  final String placeId;

  Future<void> load() async {
    emit(const PlaceDetailsState());
    final result = await getDetails(placeId);
    result.fold(
      (f) => emit(PlaceDetailsState(status: LoadStatus.failure, failure: f)),
      (d) => emit(PlaceDetailsState(status: LoadStatus.ready, details: d)),
    );
  }
}
