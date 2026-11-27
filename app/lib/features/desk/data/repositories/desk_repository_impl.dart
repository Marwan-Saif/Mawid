import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/storage/local_store.dart';
import '../../../booking/data/models/booking_model.dart';
import '../../../booking/domain/entities/booking.dart';
import '../../domain/entities/audit_entry.dart';
import '../../domain/entities/desk_board.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/waiting_display.dart';
import '../../domain/repositories/desk_repository.dart';
import '../datasources/desk_data_source.dart';
import '../models/desk_models.dart';
import '../outbox/outbox.dart';

/// The desk, online first, still working offline.
///
/// * Reads are cached on the device; with no network the last copy is shown (with its time).
/// * Changes that are safe to repeat go to an [Outbox] when the network is down and succeed
///   right away on screen; they are sent in order when it's back (every few seconds, and before
///   any new change so the server sees things in the order they happened).
/// * The server stays the judge: if it refuses a queued change later (say the doctor was
///   already busy), it's dropped and reported in [SyncStatus.rejected].
class DeskRepositoryImpl implements DeskRepository {
  DeskRepositoryImpl(this.remote, this.store, {DateTime Function()? now, this.retryEvery = const Duration(seconds: 15)})
      : _now = now ?? DateTime.now,
        outbox = Outbox(store) {
    _status = SyncStatus(pending: outbox.ops.length);
  }

  final DeskDataSource remote;
  final LocalStore store;
  final Outbox outbox;
  final DateTime Function() _now;

  /// Zero turns automatic retries off (tests).
  final Duration retryEvery;

  static const _boardKey = 'desk.board';
  static const _invoicesKey = 'desk.invoices';

  final _sync = StreamController<SyncStatus>.broadcast();
  late SyncStatus _status;
  Timer? _timer;
  bool _syncing = false;

  DateTime get _nowUtc => _now().toUtc();

  @override
  Stream<SyncStatus> get syncStatus => _sync.stream;

  @override
  SyncStatus get currentSync => _status;

  void _emit({bool? online, DateTime? lastSyncedAt, List<String>? rejected}) {
    _status = SyncStatus(
      pending: outbox.ops.length,
      online: online ?? _status.online,
      lastSyncedAt: lastSyncedAt ?? _status.lastSyncedAt,
      rejected: rejected ?? _status.rejected,
    );
    _sync.add(_status);
    _timer?.cancel();
    _timer = null;
    if (_status.pending > 0 && retryEvery > Duration.zero) {
      _timer = Timer(retryEvery, syncNow);
    }
  }

  // ================================================================ reads

  @override
  Future<Either<Failure, DeskBoard>> board() async {
    if (!outbox.isEmpty) await syncNow();
    return guard(() async {
      try {
        final json = await remote.board();
        await store.writeJson(_boardKey, {'at': _nowUtc.toIso8601String(), 'board': json});
        if (!_status.online) _emit(online: true);
        return _applyPending(DeskModels.board(json));
      } on NetworkException {
        if (_status.online) _emit(online: false);
        final cached = store.readJson(_boardKey);
        if (cached is! Map || cached['board'] is! Map) rethrow;
        return _applyPending(DeskModels.board(
          Map<String, dynamic>.from(cached['board'] as Map),
          offlineSince: DateTime.tryParse(cached['at'] as String? ?? '')?.toUtc() ?? _nowUtc,
        ));
      }
    });
  }

  @override
  Future<Either<Failure, List<Invoice>>> invoices() => guard(() async {
        List<Map<String, dynamic>> list;
        try {
          list = await remote.invoices();
          await store.writeJson(_invoicesKey, list);
        } on NetworkException {
          final cached = store.readJson(_invoicesKey);
          if (cached is! List) rethrow;
          list = cached.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        final pending = outbox.ops.where((o) => o.kind == 'createInvoice').map(_provisional).toList();
        final paidLater = {
          for (final o in outbox.ops.where((o) => o.kind == 'payInvoice')) o.payload['invoiceId'].toString(): o
        };
        final server = list.map(DeskModels.invoice).map((i) {
          final pay = paidLater[i.id];
          if (pay == null) return i;
          return i.copyWith(
              status: InvoiceStatus.paid, paymentMethod: DeskModels.method(pay.payload['method'] as String?), pendingSync: true);
        });
        return [...pending.reversed, ...server];
      });

  @override
  Future<Either<Failure, List<AuditEntry>>> audit({String? entityType, String? entityId}) =>
      guard(() async => (await remote.audit(entityType: entityType, entityId: entityId)).map(DeskModels.audit).toList());

  @override
  Future<Either<Failure, WaitingDisplay>> display(String slug) =>
      guard(() async => DeskModels.display(await remote.display(slug)));

  // ================================================================ arrive & the room (work offline)

  @override
  Future<Either<Failure, Booking>> checkInByCode(String code) async {
    // Needs the server to find whose code it is; offline, reception taps "arrived" on the list.
    if (!outbox.isEmpty) await syncNow();
    return guard(() async => BookingModel.fromJson(await remote.checkInByCode(code)));
  }

  @override
  Future<Either<Failure, Booking>> checkIn(Booking b) =>
      _bookingOp('checkIn', b, () => remote.checkIn(b.id));

  @override
  Future<Either<Failure, Booking>> call(Booking b, {String? room}) =>
      _bookingOp('call', b, () => remote.call(b.id), room: room);

  @override
  Future<Either<Failure, Booking>> finish(Booking b) => _bookingOp('finish', b, () => remote.finish(b.id));

  @override
  Future<Either<Failure, Booking>> noShow(Booking b) => _bookingOp('noShow', b, () => remote.noShow(b.id));

  @override
  Future<Either<Failure, Booking>> walkIn(WalkInRequest r) async {
    if (!outbox.isEmpty) await syncNow();
    return guard(() async => BookingModel.fromJson(await remote.walkIn({
          'serviceId': int.tryParse(r.serviceId) ?? r.serviceId,
          'staffId': r.staffId == null ? null : (int.tryParse(r.staffId!) ?? r.staffId),
          'customerName': r.customerName,
          'customerPhone': r.customerPhone,
        })));
  }

  @override
  Future<Either<Failure, DeskStaff>> setPresence(DeskStaff s, StaffPresence p) async {
    final code = DeskModels.presenceCode(p);
    final result = await _offlineCapable<DeskStaff>(
      kind: 'presence',
      payload: {'staffId': s.id, 'presence': code},
      send: () async => DeskModels.staff(await remote.presence(s.id, code)),
      optimistic: () => s.copyWith(presence: p),
    );
    return result;
  }

  Future<Either<Failure, Booking>> _bookingOp(String kind, Booking b, Future<Map<String, dynamic>> Function() send,
          {String? room}) =>
      _offlineCapable<Booking>(
        kind: kind,
        payload: {'bookingId': b.id, if (room != null) 'room': room},
        send: () async => BookingModel.fromJson(await send()),
        optimistic: () => applyLocally(kind, b, _nowUtc, room: room),
      );

  /// Try now; if the network is down, queue it and answer as if it worked.
  Future<Either<Failure, T>> _offlineCapable<T>({
    required String kind,
    required Map<String, dynamic> payload,
    required Future<T> Function() send,
    required T Function() optimistic,
  }) async {
    if (!outbox.isEmpty) await syncNow();
    if (outbox.isEmpty) {
      final result = await guard(send);
      final offline = result.fold((f) => f is OfflineFailure, (_) => false);
      if (!offline) {
        if (result.isRight() && !_status.online) _emit(online: true);
        return result;
      }
    }
    await outbox.add(kind, payload, _nowUtc);
    _emit(online: false);
    return Right(optimistic());
  }

  // ================================================================ invoices

  @override
  Future<Either<Failure, Invoice>> createInvoice(InvoiceDraft d) async {
    final body = DeskModels.draftJson(d);
    return _offlineCapable<Invoice>(
      kind: 'createInvoice',
      payload: {'body': body, 'currency': _currency(), 'staffName': d.staffName},
      send: () async => DeskModels.invoice(await remote.createInvoice(body)),
      optimistic: () => DeskModels.provisional(d, _currency(), _nowUtc),
    );
  }

  @override
  Future<Either<Failure, Invoice>> payInvoice(Invoice inv, PaymentMethod m) async {
    if (inv.id.startsWith('local-')) {
      // Made offline and not sent yet: pay inside the queued "create" instead.
      final op = outbox.ops.where((o) => o.kind == 'createInvoice' && o.payload['body']['clientRef'] == inv.clientRef).firstOrNull;
      if (op != null) {
        final body = Map<String, dynamic>.from(op.payload['body'] as Map)..['paidWith'] = DeskModels.methodCode(m);
        await outbox.replace(op.withPayload({...op.payload, 'body': body}));
      }
      return Right(inv.copyWith(status: InvoiceStatus.paid, paymentMethod: m, paidAt: _nowUtc, pendingSync: true));
    }
    return _offlineCapable<Invoice>(
      kind: 'payInvoice',
      payload: {'invoiceId': inv.id, 'method': DeskModels.methodCode(m)},
      send: () async => DeskModels.invoice(await remote.payInvoice(inv.id, DeskModels.methodCode(m))),
      optimistic: () => inv.copyWith(status: InvoiceStatus.paid, paymentMethod: m, paidAt: _nowUtc, pendingSync: true),
    );
  }

  @override
  Future<Either<Failure, Invoice>> updateInvoice(Invoice inv, List<InvoiceLine> lines, double discount) => guard(() async =>
      DeskModels.invoice(await remote.updateInvoice(inv.id, {
        'lines': lines.map(DeskModels.lineJson).toList(),
        'discount': discount,
        'version': inv.version,
      })));

  @override
  Future<Either<Failure, Invoice>> voidInvoice(Invoice inv, String reason) =>
      guard(() async => DeskModels.invoice(await remote.voidInvoice(inv.id, reason)));

  Invoice _provisional(OutboxOp op) {
    final b = Map<String, dynamic>.from(op.payload['body'] as Map);
    final lines = (b['lines'] as List).map((e) => DeskModels.line(Map<String, dynamic>.from(e as Map))).toList();
    return DeskModels.provisional(
      InvoiceDraft(
        bookingId: b['bookingId']?.toString(),
        customerName: (b['customerName'] as String?) ?? '',
        customerPhone: b['customerPhone'] as String?,
        staffName: op.payload['staffName'] as String?,
        lines: lines,
        discount: (b['discount'] as num? ?? 0).toDouble(),
        paidWith: DeskModels.method(b['paidWith'] as String?),
        clientRef: b['clientRef'] as String,
      ),
      op.payload['currency'] as String? ?? _currency(),
      op.createdAt.toUtc(),
    );
  }

  String _currency() {
    final cached = store.readJson(_boardKey);
    if (cached is Map && cached['board'] is Map) {
      final place = (cached['board'] as Map)['place'];
      if (place is Map && place['currency'] is String) return place['currency'] as String;
    }
    return '';
  }

  // ================================================================ sync

  @override
  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;
    final rejected = <String>[];
    try {
      for (final op in outbox.ops) {
        try {
          await _send(op);
          await outbox.remove(op.id);
        } on NetworkException {
          _emit(online: false, rejected: rejected.isEmpty ? null : [..._status.rejected, ...rejected]);
          return;
        } on ServerException catch (e) {
          await outbox.remove(op.id); // the server said no; keeping it would block the queue forever
          rejected.add(e.code);
        }
      }
      _emit(online: true, lastSyncedAt: _nowUtc, rejected: rejected);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _send(OutboxOp op) async {
    final p = op.payload;
    switch (op.kind) {
      case 'checkIn':
        await remote.checkIn(p['bookingId'].toString());
      case 'call':
        await remote.call(p['bookingId'].toString());
      case 'finish':
        await remote.finish(p['bookingId'].toString());
      case 'noShow':
        await remote.noShow(p['bookingId'].toString());
      case 'presence':
        await remote.presence(p['staffId'].toString(), p['presence'] as String);
      case 'createInvoice':
        await remote.createInvoice(Map<String, dynamic>.from(p['body'] as Map));
      case 'payInvoice':
        await remote.payInvoice(p['invoiceId'].toString(), p['method'] as String);
    }
  }

  /// The last saved board with this device's unsent changes laid on top.
  DeskBoard _applyPending(DeskBoard board) {
    final ops = outbox.ops;
    if (ops.isEmpty) return board;
    var queue = board.queue;
    var staff = board.staff;
    for (final op in ops) {
      final p = op.payload;
      switch (op.kind) {
        case 'checkIn' || 'call' || 'finish' || 'noShow':
          final id = p['bookingId'].toString();
          queue = [
            for (final q in queue)
              if (q.id == id)
                q.copyWith(
                  booking: applyLocally(op.kind, q.booking, op.createdAt.toUtc(),
                      room: p['room'] as String? ?? board.staffById(q.booking.staffId)?.room),
                  pendingSync: true,
                )
              else
                q,
          ];
          final entry = queue.where((q) => q.id == id).firstOrNull;
          if (entry != null && (op.kind == 'call' || op.kind == 'finish')) {
            staff = [
              for (final s in staff)
                if (s.id == entry.booking.staffId)
                  s.copyWith(
                    presence: op.kind == 'call' ? StaffPresence.busy : StaffPresence.available,
                    currentBookingId: () => op.kind == 'call' ? id : null,
                  )
                else
                  s,
            ];
          }
        case 'presence':
          staff = [
            for (final s in staff)
              if (s.id == p['staffId'].toString()) s.copyWith(presence: DeskModels.presence(p['presence'] as String?)) else s,
          ];
        case 'createInvoice':
          final bookingId = (p['body'] as Map)['bookingId']?.toString();
          final paid = (p['body'] as Map)['paidWith'] != null;
          queue = [
            for (final q in queue)
              if (bookingId != null && q.id == bookingId)
                q.copyWith(invoiceStatus: paid ? InvoiceStatus.paid : InvoiceStatus.issued, pendingSync: true)
              else
                q,
          ];
      }
    }
    return board.copyWith(queue: queue, staff: staff);
  }

  /// What a change does to a booking, decided on the device (the server does the same).
  static Booking applyLocally(String kind, Booking b, DateTime nowUtc, {String? room}) => switch (kind) {
        'checkIn' => b.status.isBooked || b.status == BookingStatus.noShow
            ? b.copyWith(status: BookingStatus.arrived, checkedInAt: nowUtc)
            : b,
        'call' => b.copyWith(
            status: BookingStatus.inProgress,
            calledAt: nowUtc,
            startedAt: b.status == BookingStatus.inProgress ? b.startedAt : nowUtc,
            room: room ?? b.room,
          ),
        'finish' => b.copyWith(status: BookingStatus.completed, finishedAt: nowUtc),
        'noShow' => b.copyWith(status: BookingStatus.noShow),
        _ => b,
      };

  @override
  bool get canSimulateOffline => remote.canSimulateOffline;

  @override
  void simulateOffline(bool offline) {
    remote.simulateOffline(offline);
    if (!offline) syncNow();
  }

  void dispose() {
    _timer?.cancel();
    _sync.close();
  }
}
