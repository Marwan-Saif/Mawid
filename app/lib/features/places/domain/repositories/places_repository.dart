import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/place.dart';

abstract class PlacesRepository {
  Future<Either<Failure, List<Place>>> getPlaces({PlaceCategory? category, String? query});

  Future<Either<Failure, PlaceDetails>> getPlaceDetails(String placeId);
}
