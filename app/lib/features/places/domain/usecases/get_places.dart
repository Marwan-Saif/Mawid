import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/place.dart';
import '../repositories/places_repository.dart';

class GetPlacesParams extends Equatable {
  const GetPlacesParams({this.category, this.query});

  final PlaceCategory? category;
  final String? query;

  @override
  List<Object?> get props => [category, query];
}

class GetPlaces implements UseCase<List<Place>, GetPlacesParams> {
  GetPlaces(this.repository);

  final PlacesRepository repository;

  @override
  Future<Either<Failure, List<Place>>> call(GetPlacesParams params) =>
      repository.getPlaces(category: params.category, query: params.query?.trim());
}
