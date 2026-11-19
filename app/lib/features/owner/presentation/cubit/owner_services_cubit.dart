import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../places/domain/entities/place.dart';
import '../../../places/presentation/cubit/home_cubit.dart';
import '../../domain/repositories/owner_repository.dart';
import '../../domain/usecases/owner_usecases.dart';

class OwnerServicesState extends Equatable {
  const OwnerServicesState({this.status = LoadStatus.loading, this.place, this.failure});

  final LoadStatus status;
  final PlaceDetails? place;
  final Failure? failure;

  List<PlaceService> get services => place?.services ?? const [];

  @override
  List<Object?> get props => [status, place, failure];
}

class OwnerServicesCubit extends Cubit<OwnerServicesState> {
  OwnerServicesCubit({required this.getPlace, required this.saveService}) : super(const OwnerServicesState());

  final GetOwnerPlace getPlace;
  final SaveService saveService;

  Future<void> load() async {
    emit(OwnerServicesState(place: state.place));
    final result = await getPlace(const NoParams());
    result.fold(
      (f) => emit(OwnerServicesState(status: LoadStatus.failure, failure: f)),
      (p) => emit(OwnerServicesState(status: LoadStatus.ready, place: p)),
    );
  }

  /// Returns the failure to show in the form, or null on success.
  Future<Failure?> save(ServiceDraft draft, {String? id}) async {
    final result = await saveService(SaveServiceParams(draft, id: id));
    return result.fold((f) => f, (_) {
      load();
      return null;
    });
  }
}
