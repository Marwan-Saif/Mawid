import 'package:dartz/dartz.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/place.dart';
import '../../domain/repositories/places_repository.dart';
import '../datasources/places_data_source.dart';
import '../models/place_models.dart';

class PlacesRepositoryImpl implements PlacesRepository {
  PlacesRepositoryImpl(this.remote);

  final PlacesDataSource remote;

  @override
  Future<Either<Failure, List<Place>>> getPlaces({PlaceCategory? category, String? query}) => guard(() async {
        final rows = await remote.places(
          category: category == null ? null : PlaceModels.categoryCode(category),
          query: query,
        );
        return rows.map(PlaceModels.place).toList();
      });

  @override
  Future<Either<Failure, PlaceDetails>> getPlaceDetails(String placeId) =>
      guard(() async => PlaceModels.details(await remote.details(placeId)));
}
