import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/usecases/auth_usecases.dart';
import 'session_cubit.dart';

enum LoginStatus { idle, loading, codeSent, success, failure }

class LoginState extends Equatable {
  const LoginState({this.status = LoginStatus.idle, this.phone, this.failure, this.busyRole});

  final LoginStatus status;

  /// Normalized phone the code was sent to.
  final String? phone;
  final Failure? failure;

  /// Which demo button is spinning.
  final UserRole? busyRole;

  bool get isLoading => status == LoginStatus.loading;

  LoginState copyWith({LoginStatus? status, String? phone, Failure? failure, UserRole? busyRole}) => LoginState(
        status: status ?? this.status,
        phone: phone ?? this.phone,
        failure: failure,
        busyRole: busyRole,
      );

  @override
  List<Object?> get props => [status, phone, failure, busyRole];
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit({
    required this.requestOtp,
    required this.verifyOtp,
    required this.demoLogin,
    required this.session,
  }) : super(const LoginState());

  final RequestOtp requestOtp;
  final VerifyOtp verifyOtp;
  final DemoLogin demoLogin;
  final SessionCubit session;

  Future<void> tryDemo(UserRole role) async {
    emit(state.copyWith(status: LoginStatus.loading, busyRole: role));
    _finish(await demoLogin(role));
  }

  Future<void> sendCode(String rawPhone) async {
    emit(state.copyWith(status: LoginStatus.loading));
    final result = await requestOtp(rawPhone);
    result.fold(
      (f) => emit(state.copyWith(status: LoginStatus.failure, failure: f)),
      (phone) => emit(state.copyWith(status: LoginStatus.codeSent, phone: phone)),
    );
  }

  Future<void> verify(String code, {String? name}) async {
    final phone = state.phone;
    if (phone == null) return;
    emit(state.copyWith(status: LoginStatus.loading));
    _finish(await verifyOtp(VerifyOtpParams(phone: phone, code: code, name: name)));
  }

  void _finish(Either<Failure, AppUser> result) {
    result.fold(
      (f) => emit(state.copyWith(status: LoginStatus.failure, failure: f)),
      (user) {
        emit(state.copyWith(status: LoginStatus.success));
        session.signedIn(user);
      },
    );
  }
}
