import 'package:equatable/equatable.dart';

/// What can go wrong, in business terms. The UI turns each one into a translated message.
sealed class Failure extends Equatable {
  const Failure(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

class ServerFailure extends Failure {
  const ServerFailure([super.code = 'SERVER']);
}

class OfflineFailure extends Failure {
  const OfflineFailure() : super('OFFLINE');
}

/// Someone booked the same staff member and time first.
class SlotTakenFailure extends Failure {
  const SlotTakenFailure() : super('SLOT_TAKEN');
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure() : super('UNAUTHORIZED');
}

/// Input rejected before or by the server: slot_in_past, TOO_LATE_TO_CHANGE, OTP_INVALID...
class ValidationFailure extends Failure {
  const ValidationFailure(super.code);
}
