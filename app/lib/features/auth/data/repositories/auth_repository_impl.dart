import 'package:dartz/dartz.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/session/session.dart';
import '../../../../core/storage/local_store.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_data_source.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this.remote, required this.store, required this.session});

  final AuthDataSource remote;
  final LocalStore store;
  final Session session;

  @override
  Future<Either<Failure, Unit>> requestOtp(String phone) => guard(() async {
        await remote.requestOtp(phone);
        return unit;
      });

  @override
  Future<Either<Failure, AppUser>> verifyOtp({required String phone, required String code, String? name}) =>
      guard(() async => _save(await remote.verifyOtp(phone, code, name)));

  @override
  Future<Either<Failure, AppUser>> demoLogin(UserRole role) =>
      guard(() async => _save(await remote.demoLogin(UserModel.roleCode(role))));

  @override
  AppUser? savedUser() {
    final json = store.user;
    final token = store.token;
    if (json == null || token == null) return null;
    final user = UserModel(json).toEntity();
    session.set(token, user);
    return user;
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    await store.clearSession();
    session.clear();
    return const Right(unit);
  }

  Future<AppUser> _save(Map<String, dynamic> body) async {
    final token = body['token'] as String;
    final userJson = Map<String, dynamic>.from(body['user'] as Map);
    final user = UserModel(userJson).toEntity();
    await store.saveSession(token, userJson);
    session.set(token, user);
    return user;
  }
}
