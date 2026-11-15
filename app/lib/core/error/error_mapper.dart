import 'package:dartz/dartz.dart';

import 'exceptions.dart';
import 'failures.dart';

/// One place that converts data-layer exceptions into domain failures.
/// Every RepositoryImpl wraps its calls with this, so there is no try/catch in the UI.
Future<Either<Failure, T>> guard<T>(Future<T> Function() call) async {
  try {
    return Right(await call());
  } on SlotTakenException {
    return const Left(SlotTakenFailure());
  } on UnauthorizedException {
    return const Left(UnauthorizedFailure());
  } on ServerException catch (e) {
    if (e.code == 'SLOT_TAKEN') return const Left(SlotTakenFailure());
    if (e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
      return Left(ValidationFailure(e.code));
    }
    return Left(ServerFailure(e.code));
  } on NetworkException {
    return const Left(OfflineFailure());
  }
}
