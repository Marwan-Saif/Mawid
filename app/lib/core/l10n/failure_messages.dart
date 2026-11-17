import '../error/failures.dart';
import 'app_localizations.dart';

/// The only place that turns a Failure into words.
extension FailureMessage on Failure {
  String message(AppLocalizations l10n) => switch (this) {
        SlotTakenFailure() => l10n.errSlotTaken,
        OfflineFailure() => l10n.errOffline,
        UnauthorizedFailure() => l10n.errUnauthorized,
        ValidationFailure(code: final c) => switch (c) {
            'TOO_LATE_TO_CHANGE' => l10n.errTooLate,
            'INVALID_PHONE' => l10n.errInvalidPhone,
            'OTP_INVALID' || 'OTP_EXPIRED' || 'OTP_LOCKED' => l10n.errOtp,
            'SLOT_IN_PAST' || 'slot_in_past' => l10n.errPast,
            'INVALID_DURATION' => l10n.errInvalidDuration,
            'SLOT_TAKEN' => l10n.errSlotTaken,
            _ => l10n.errServer,
          },
        ServerFailure() => l10n.errServer,
      };
}
