import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_user.dart';

abstract class AuthRepository {
  Future<Either<Failure, Unit>> requestOtp(String phone);

  Future<Either<Failure, AppUser>> verifyOtp({required String phone, required String code, String? name});

  /// Signs in as the seeded demo customer or owner, no SMS.
  Future<Either<Failure, AppUser>> demoLogin(UserRole role);

  /// The user saved on this device from a previous sign-in, if any.
  AppUser? savedUser();

  Future<Either<Failure, Unit>> signOut();
}
