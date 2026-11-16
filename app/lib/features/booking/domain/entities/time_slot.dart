import 'package:equatable/equatable.dart';

class TimeSlot extends Equatable {
  const TimeSlot({required this.startAt, required this.freeStaffIds});

  /// UTC.
  final DateTime startAt;

  /// Who can take this slot. Empty = booked (shown greyed out).
  final List<String> freeStaffIds;

  bool get available => freeStaffIds.isNotEmpty;

  @override
  List<Object?> get props => [startAt, freeStaffIds];
}
