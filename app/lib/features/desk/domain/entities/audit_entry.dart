import 'package:equatable/equatable.dart';

/// "Sara (reception) edited invoice #1042 at 11:12: total 20 → 25".
class AuditEntry extends Equatable {
  const AuditEntry({
    required this.id,
    required this.at,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.entityType,
    this.entityId,
    this.entityLabel,
    this.details = const {},
  });

  final String id;
  final DateTime at;
  final String actorName;

  /// OWNER, RECEPTION, CUSTOMER, PATIENT (self check-in) or SYSTEM.
  final String actorRole;

  /// INVOICE_EDITED, CHECKED_IN, CALLED, ...
  final String action;
  final String entityType;
  final String? entityId;
  final String? entityLabel;
  final Map<String, dynamic> details;

  @override
  List<Object?> get props => [id, at, action, entityId];
}
