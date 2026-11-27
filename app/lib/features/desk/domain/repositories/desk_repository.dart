import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../booking/domain/entities/booking.dart';
import '../entities/audit_entry.dart';
import '../entities/desk_board.dart';
import '../entities/invoice.dart';
import '../entities/waiting_display.dart';

/// Offline state of the desk: how many changes wait to be sent, and the last ones the server refused.
class SyncStatus extends Equatable {
  const SyncStatus({this.pending = 0, this.online = true, this.lastSyncedAt, this.rejected = const []});

  final int pending;
  final bool online;
  final DateTime? lastSyncedAt;

  /// Server codes for queued changes it didn't accept when they were finally sent (e.g. STAFF_BUSY).
  final List<String> rejected;

  @override
  List<Object?> get props => [pending, online, lastSyncedAt, rejected];
}

/// The front desk. Changes that make sense offline (check-in, call, finish, no-show, presence,
/// new invoice, payment) succeed locally when the network is down and are sent later, in order.
abstract class DeskRepository {
  Future<Either<Failure, DeskBoard>> board();

  Future<Either<Failure, Booking>> checkInByCode(String code);

  Future<Either<Failure, Booking>> checkIn(Booking booking);

  Future<Either<Failure, Booking>> walkIn(WalkInRequest request);

  Future<Either<Failure, Booking>> call(Booking booking, {String? room});

  Future<Either<Failure, Booking>> finish(Booking booking);

  Future<Either<Failure, Booking>> noShow(Booking booking);

  Future<Either<Failure, DeskStaff>> setPresence(DeskStaff staff, StaffPresence presence);

  Future<Either<Failure, List<Invoice>>> invoices();

  Future<Either<Failure, Invoice>> createInvoice(InvoiceDraft draft);

  /// Needs the network: the server checks [invoice.version] so two desks can't overwrite each other.
  Future<Either<Failure, Invoice>> updateInvoice(Invoice invoice, List<InvoiceLine> lines, double discount);

  Future<Either<Failure, Invoice>> payInvoice(Invoice invoice, PaymentMethod method);

  Future<Either<Failure, Invoice>> voidInvoice(Invoice invoice, String reason);

  Future<Either<Failure, List<AuditEntry>>> audit({String? entityType, String? entityId});

  Future<Either<Failure, WaitingDisplay>> display(String slug);

  Stream<SyncStatus> get syncStatus;

  SyncStatus get currentSync;

  /// Sends queued changes now (also runs by itself every few seconds while any are waiting).
  Future<void> syncNow();

  /// Demo only: pretend the network is down, to show the offline mode.
  bool get canSimulateOffline;

  void simulateOffline(bool offline);
}
