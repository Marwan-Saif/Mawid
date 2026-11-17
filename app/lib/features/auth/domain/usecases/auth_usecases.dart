import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/phone.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';


class RequestOtp implements UseCase<String, String> {
  RequestOtp(this.repository);

  final AuthRepository repository;

  /// Returns the normalized phone the code was sent to.
  @override
  Future<Either<Failure, String>> call(String rawPhone) async {
    final phone = normalizePhone(rawPhone);
    if (phone == null) return const Left(ValidationFailure('INVALID_PHONE'));
    final result = await repository.requestOtp(phone);
    return result.map((_) => phone);
  }
}

class VerifyOtpParams extends Equatable {
  const VerifyOtpParams({required this.phone, required this.code, this.name});

  final String phone;
  final String code;
  final String? name;

  @override
  List<Object?> get props => [phone, code, name];
}

class VerifyOtp implements UseCase<AppUser, VerifyOtpParams> {
  VerifyOtp(this.repository);

  final AuthRepository repository;

  @override
  Future<Either<Failure, AppUser>> call(VerifyOtpParams p) {
    final code = p.code.trim();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      return Future.value(const Left(ValidationFailure('OTP_INVALID')));
    }
    return repository.verifyOtp(phone: p.phone, code: code, name: p.name);
  }
}

class DemoLogin implements UseCase<AppUser, UserRole> {
  DemoLogin(this.repository);

  final AuthRepository repository;

  @override
  Future<Either<Failure, AppUser>> call(UserRole role) => repository.demoLogin(role);
}

class SignOut implements UseCase<Unit, NoParams> {
  SignOut(this.repository);

  final AuthRepository repository;

  @override
  Future<Either<Failure, Unit>> call(NoParams params) => repository.signOut();
}
