import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/place.dart';
import '../repositories/places_repository.dart';

class GetPlaceDetails implements UseCase<PlaceDetails, String> {
  GetPlaceDetails(this.repository);

  final PlacesRepository repository;

  @override
  Future<Either<Failure, PlaceDetails>> call(String placeId) => repository.getPlaceDetails(placeId);
}
