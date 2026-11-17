import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';

enum SessionStatus { unknown, signedOut, signedIn }

class SessionState extends Equatable {
  const SessionState._(this.status, this.user);

  const SessionState.unknown() : this._(SessionStatus.unknown, null);
  const SessionState.signedOut() : this._(SessionStatus.signedOut, null);
  const SessionState.signedIn(AppUser user) : this._(SessionStatus.signedIn, user);

  final SessionStatus status;
  final AppUser? user;

  @override
  List<Object?> get props => [status, user];
}

/// Who is signed in, for the whole app. The router redirects on every change.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit({required this.repository, required this.signOutUseCase}) : super(const SessionState.unknown());

  final AuthRepository repository;
  final SignOut signOutUseCase;

  void restore() {
    final user = repository.savedUser();
    emit(user == null ? const SessionState.signedOut() : SessionState.signedIn(user));
  }

  void signedIn(AppUser user) => emit(SessionState.signedIn(user));

  Future<void> signOut() async {
    await signOutUseCase(const NoParams());
    emit(const SessionState.signedOut());
  }
}
