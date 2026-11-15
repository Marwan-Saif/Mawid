/// Thrown by data sources only. Repositories turn them into Failures; screens never see them.
class ServerException implements Exception {
  const ServerException(this.code, [this.message, this.statusCode]);

  /// Stable code from the API, e.g. SLOT_TAKEN, TOO_LATE_TO_CHANGE.
  final String code;
  final String? message;
  final int? statusCode;

  @override
  String toString() => 'ServerException($code, $statusCode, $message)';
}

class SlotTakenException extends ServerException {
  const SlotTakenException() : super('SLOT_TAKEN', null, 409);
}

class UnauthorizedException extends ServerException {
  const UnauthorizedException() : super('UNAUTHORIZED', null, 401);
}

class NetworkException implements Exception {
  const NetworkException([this.cause]);
  final Object? cause;
}
