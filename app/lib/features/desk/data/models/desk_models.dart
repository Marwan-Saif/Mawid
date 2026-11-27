import '../../../booking/data/models/booking_model.dart';
import '../../../places/data/models/place_models.dart';
import '../../domain/entities/audit_entry.dart';
import '../../domain/entities/desk_board.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/waiting_display.dart';

/// API JSON ⇄ desk entities. The only file that knows the wire names of the desk endpoints.
class DeskModels {
  const DeskModels._();

  static const _presence = {
    'AVAILABLE': StaffPresence.available,
    'BUSY': StaffPresence.busy,
    'BREAK': StaffPresence.onBreak,
    'AWAY': StaffPresence.away,
  };

  static StaffPresence presence(String? v) => _presence[v] ?? StaffPresence.available;

  static String presenceCode(StaffPresence p) => _presence.entries.firstWhere((e) => e.value == p).key;

  static const _invoiceStatus = {
    'ISSUED': InvoiceStatus.issued,
    'PAID': InvoiceStatus.paid,
    'VOID': InvoiceStatus.voided,
  };

  static InvoiceStatus? invoiceStatus(String? v) => v == null ? null : _invoiceStatus[v];

  static String invoiceStatusCode(InvoiceStatus s) => _invoiceStatus.entries.firstWhere((e) => e.value == s).key;

  static PaymentMethod? method(String? v) => switch (v) {
        'CASH' => PaymentMethod.cash,
        'CARD' => PaymentMethod.card,
        'TRANSFER' => PaymentMethod.transfer,
        _ => null,
      };

  static String methodCode(PaymentMethod m) => m.name.toUpperCase();

  static DateTime? _time(Object? v) => v is String ? DateTime.parse(v).toUtc() : null;

  static String? _id(Object? v) => v?.toString();

  static Object _wireId(String id) => int.tryParse(id) ?? id;

  static List<Map<String, dynamic>> _list(Object? v) =>
      (v as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  // ---------------------------------------------------------------- board

  static DeskPlace place(Map<String, dynamic> j) => DeskPlace(
        id: j['id'].toString(),
        slug: j['slug'] as String,
        nameAr: j['nameAr'] as String,
        nameEn: j['nameEn'] as String,
        timezone: j['timezone'] as String,
        currency: j['currency'] as String,
      );

  static DeskStaff staff(Map<String, dynamic> j) => DeskStaff(
        id: j['id'].toString(),
        name: j['name'] as String,
        titleAr: (j['titleAr'] as String?) ?? '',
        titleEn: (j['titleEn'] as String?) ?? '',
        room: j['room'] as String?,
        presence: presence(j['presence'] as String?),
        presenceSince: _time(j['presenceSince']),
        currentBookingId: _id(j['currentBookingId']),
        waiting: (j['waiting'] as num?)?.toInt() ?? 0,
      );

  static QueueEntry entry(Map<String, dynamic> j) => QueueEntry(
        booking: BookingModel.fromJson(Map<String, dynamic>.from(j['booking'] as Map)),
        expectedStartAt: DateTime.parse(j['expectedStartAt'] as String).toUtc(),
        delayMin: (j['delayMin'] as num?)?.toInt() ?? 0,
        ahead: (j['ahead'] as num?)?.toInt() ?? 0,
        late: (j['late'] as bool?) ?? false,
        invoiceId: _id(j['invoiceId']),
        invoiceNumber: (j['invoiceNumber'] as num?)?.toInt(),
        invoiceStatus: invoiceStatus(j['invoiceStatus'] as String?),
      );

  static DeskBoard board(Map<String, dynamic> j, {DateTime? offlineSince}) {
    final queue = _list(j['queue']).map(entry).toList();
    final c = j['counts'] is Map ? Map<String, dynamic>.from(j['counts'] as Map) : null;
    return DeskBoard(
      date: j['date'] as String,
      place: place(Map<String, dynamic>.from(j['place'] as Map)),
      staff: _list(j['staff']).map(staff).toList(),
      queue: queue,
      services: _list(j['services']).map(PlaceModels.service).toList(),
      counts: c == null
          ? DeskCounts.of(queue)
          : DeskCounts(
              booked: (c['booked'] as num).toInt(),
              waiting: (c['waiting'] as num).toInt(),
              inRoom: (c['inRoom'] as num).toInt(),
              done: (c['done'] as num).toInt(),
              noShow: (c['noShow'] as num).toInt(),
            ),
      serverTime: DateTime.parse(j['serverTime'] as String).toUtc(),
      offlineSince: offlineSince,
    );
  }

  // ---------------------------------------------------------------- invoices

  static InvoiceLine line(Map<String, dynamic> j) => InvoiceLine(
        description: j['description'] as String,
        qty: (j['qty'] as num).toInt(),
        unitPrice: (j['unitPrice'] as num).toDouble(),
        serviceId: _id(j['serviceId']),
      );

  static Map<String, dynamic> lineJson(InvoiceLine l) => {
        'description': l.description,
        'qty': l.qty,
        'unitPrice': l.unitPrice,
        'serviceId': l.serviceId == null ? null : _wireId(l.serviceId!),
      };

  static Invoice invoice(Map<String, dynamic> j, {bool pendingSync = false}) => Invoice(
        id: j['id'].toString(),
        number: (j['number'] as num?)?.toInt(),
        bookingId: _id(j['bookingId']),
        customerName: (j['customerName'] as String?) ?? '',
        customerPhone: j['customerPhone'] as String?,
        staffName: j['staffName'] as String?,
        lines: _list(j['lines']).map(line).toList(),
        subtotal: (j['subtotal'] as num).toDouble(),
        discount: (j['discount'] as num? ?? 0).toDouble(),
        total: (j['total'] as num).toDouble(),
        currency: j['currency'] as String,
        status: invoiceStatus(j['status'] as String?) ?? InvoiceStatus.issued,
        paymentMethod: method(j['paymentMethod'] as String?),
        createdAt: DateTime.parse(j['createdAt'] as String).toUtc(),
        updatedAt: _time(j['updatedAt']),
        paidAt: _time(j['paidAt']),
        createdByName: j['createdByName'] as String?,
        voidReason: j['voidReason'] as String?,
        version: (j['version'] as num?)?.toInt() ?? 0,
        printUrl: j['printUrl'] as String?,
        clientRef: j['clientRef'] as String?,
        pendingSync: pendingSync,
      );

  static Map<String, dynamic> draftJson(InvoiceDraft d) => {
        'bookingId': d.bookingId == null ? null : _wireId(d.bookingId!),
        'customerName': d.customerName,
        'customerPhone': d.customerPhone,
        'lines': d.lines.map(lineJson).toList(),
        'discount': d.discount,
        'paidWith': d.paidWith == null ? null : methodCode(d.paidWith!),
        'clientRef': d.clientRef,
      };

  /// How an invoice made offline looks until the server numbers it.
  static Invoice provisional(InvoiceDraft d, String currency, DateTime nowUtc) => Invoice(
        id: 'local-${d.clientRef}',
        number: null,
        bookingId: d.bookingId,
        customerName: d.customerName,
        customerPhone: d.customerPhone,
        staffName: d.staffName,
        lines: d.lines,
        subtotal: d.subtotal,
        discount: d.discount,
        total: d.total,
        currency: currency,
        status: d.paidWith == null ? InvoiceStatus.issued : InvoiceStatus.paid,
        paymentMethod: d.paidWith,
        createdAt: nowUtc,
        paidAt: d.paidWith == null ? null : nowUtc,
        version: 0,
        clientRef: d.clientRef,
        pendingSync: true,
      );

  // ---------------------------------------------------------------- audit & display

  static AuditEntry audit(Map<String, dynamic> j) => AuditEntry(
        id: j['id'].toString(),
        at: DateTime.parse(j['at'] as String).toUtc(),
        actorName: (j['actorName'] as String?) ?? '',
        actorRole: (j['actorRole'] as String?) ?? 'SYSTEM',
        action: j['action'] as String,
        entityType: j['entityType'] as String,
        entityId: _id(j['entityId']),
        entityLabel: j['entityLabel'] as String?,
        details: j['details'] is Map ? Map<String, dynamic>.from(j['details'] as Map) : const {},
      );

  static WaitingDisplay display(Map<String, dynamic> j) {
    final call = j['lastCall'] is Map ? Map<String, dynamic>.from(j['lastCall'] as Map) : null;
    return WaitingDisplay(
      place: place(Map<String, dynamic>.from(j['place'] as Map)),
      staff: _list(j['staff'])
          .map((s) => DisplayStaff(
                id: s['id'].toString(),
                name: s['name'] as String,
                titleAr: (s['titleAr'] as String?) ?? '',
                titleEn: (s['titleEn'] as String?) ?? '',
                room: s['room'] as String?,
                presence: presence(s['presence'] as String?),
                nowServingTicket: (s['nowServingTicket'] as num?)?.toInt(),
                nowServingName: s['nowServingName'] as String?,
              ))
          .toList(),
      waiting: _list(j['waiting'])
          .map((w) => DisplayEntry(
                ticketNo: (w['ticketNo'] as num).toInt(),
                name: (w['name'] as String?) ?? '',
                staffName: w['staffName'] as String?,
                room: w['room'] as String?,
                etaMin: (w['etaMin'] as num?)?.toInt() ?? 0,
                delayMin: (w['delayMin'] as num?)?.toInt() ?? 0,
              ))
          .toList(),
      lastCall: call == null || call['ticketNo'] == null
          ? null
          : DisplayCall(
              seq: call['seq'] as String,
              ticketNo: (call['ticketNo'] as num).toInt(),
              name: (call['name'] as String?) ?? '',
              room: call['room'] as String?,
              staffName: call['staffName'] as String?,
              at: DateTime.parse(call['at'] as String).toUtc(),
            ),
      servedToday: (j['servedToday'] as num?)?.toInt() ?? 0,
      serverTime: DateTime.parse(j['serverTime'] as String).toUtc(),
    );
  }
}
