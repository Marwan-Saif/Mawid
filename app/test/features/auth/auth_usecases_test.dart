import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/core/error/failures.dart';
import 'package:mawid/core/utils/phone.dart';
import 'package:mawid/features/auth/domain/repositories/auth_repository.dart';
import 'package:mawid/features/auth/domain/usecases/auth_usecases.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  test('normalizePhone accepts international formats', () {
    expect(normalizePhone('00971 50 123 4567'), '+971501234567');
    expect(normalizePhone('+20 100 000 0002'), '+201000000002');
    expect(normalizePhone('123'), isNull);
  });

  test('RequestOtp rejects a bad number before calling the server', () async {
    final repo = MockAuthRepository();
    final result = await RequestOtp(repo)('12');
    expect(result, const Left<Failure, String>(ValidationFailure('INVALID_PHONE')));
    verifyNever(() => repo.requestOtp(any()));
  });

  test('VerifyOtp needs exactly 6 digits', () async {
    final repo = MockAuthRepository();
    final result = await VerifyOtp(repo)(const VerifyOtpParams(phone: '+971501234567', code: '12a'));
    expect(result.isLeft(), isTrue);
  });
}
