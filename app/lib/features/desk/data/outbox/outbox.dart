import 'dart:math';

import '../../../../core/storage/local_store.dart';

/// One change made at the desk while offline, waiting to be sent.
class OutboxOp {
  const OutboxOp({required this.id, required this.kind, required this.payload, required this.createdAt});

  /// checkIn | call | finish | noShow | presence | createInvoice | payInvoice
  final String id;
  final String kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  OutboxOp withPayload(Map<String, dynamic> p) => OutboxOp(id: id, kind: kind, payload: p, createdAt: createdAt);

  Map<String, dynamic> toJson() => {'id': id, 'kind': kind, 'payload': payload, 'createdAt': createdAt.toIso8601String()};

  static OutboxOp? fromJson(Object? j) {
    if (j is! Map) return null;
    try {
      return OutboxOp(
        id: j['id'] as String,
        kind: j['kind'] as String,
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
    } on Object {
      return null;
    }
  }
}

/// Queued desk changes, kept on the device so they survive closing the app.
/// Sent in the order they were made; every one of them is safe to send twice.
class Outbox {
  Outbox(this.store);

  final LocalStore store;
  static const _key = 'desk.outbox';
  static final _random = Random();

  List<OutboxOp> get ops {
    final raw = store.readJson(_key);
    if (raw is! List) return const [];
    return raw.map(OutboxOp.fromJson).whereType<OutboxOp>().toList();
  }

  bool get isEmpty => ops.isEmpty;

  Future<OutboxOp> add(String kind, Map<String, dynamic> payload, DateTime nowUtc) async {
    final op = OutboxOp(id: newId(nowUtc), kind: kind, payload: payload, createdAt: nowUtc);
    await _save([...ops, op]);
    return op;
  }

  Future<void> remove(String id) => _save(ops.where((o) => o.id != id).toList());

  Future<void> replace(OutboxOp op) => _save([for (final o in ops) o.id == op.id ? op : o]);

  Future<void> _save(List<OutboxOp> list) => store.writeJson(_key, list.map((o) => o.toJson()).toList());

  /// Unique enough for one desk: time + randomness. Also used as an invoice's clientRef.
  static String newId(DateTime nowUtc) =>
      '${nowUtc.microsecondsSinceEpoch.toRadixString(36)}-${_random.nextInt(0x7fffffff).toRadixString(36)}';
}
