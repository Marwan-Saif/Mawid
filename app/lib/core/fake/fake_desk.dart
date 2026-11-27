part of 'fake_backend.dart';

final _codeRandom = Random();
const _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// 10 characters without look-alikes, like the API's check-in codes.
String _newCode() => List.generate(10, (_) => _codeAlphabet[_codeRandom.nextInt(_codeAlphabet.length)]).join();

/// The front desk half of the demo backend: same JSON and rules as DeskService, InvoiceService
/// and AuditService in the API.
extension FakeDesk on FakeBackend {
  Future<T> _desk<T>(T Function() body) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (offline) throw const NetworkException('demo: offline');
    return body();
  }

  _User _staffUser() {
    final me = _users[_currentUserId()]!;
    if ((me.role != 'OWNER' && me.role != 'RECEPTION') || me.placeId == null) {
      throw const ServerException('FORBIDDEN', null, 403);
    }
    return me;
  }

  ({DateTime from, DateTime to}) _dayRange(_Place p, [DateTime? at]) {
    final loc = tz.getLocation(p.timezone);
    final local = tz.TZDateTime.from(at ?? _nowUtc, loc);
    return (
      from: tz.TZDateTime(loc, local.year, local.month, local.day).toUtc(),
      to: tz.TZDateTime(loc, local.year, local.month, local.day + 1).toUtc(),
    );
  }

  List<_Booking> _today(_Place p) {
    final r = _dayRange(p);
    return _bookings.values
        .where((b) => b.placeId == p.id && !b.startAt.isBefore(r.from) && b.startAt.isBefore(r.to))
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  bool _isToday(_Place p, DateTime t) {
    final r = _dayRange(p);
    return !t.isBefore(r.from) && t.isBefore(r.to);
  }

  Map<int, QueueEstimate> _eta(List<_Booking> list) => QueueEstimator.estimate([
        for (final b in list)
          if (_visitState(b.status) != null)
            QueueVisit(b.id, b.staffId, b.startAt, b.durationMin, _visitState(b.status)!, b.startedAt),
      ], _nowUtc);

  static VisitState? _visitState(String s) => switch (s) {
        'PENDING' || 'CONFIRMED' => VisitState.booked,
        'ARRIVED' => VisitState.arrived,
        'IN_PROGRESS' => VisitState.inRoom,
        _ => null,
      };

  void _record(int placeId, _User? actor, String action, String entityType, int? entityId, String? label,
      [Map<String, dynamic> details = const {}]) {
    _audit.add(_Audit(
      id: _nextId++,
      placeId: placeId,
      at: _nowUtc,
      actorId: actor?.id,
      actorName: actor?.name ?? (actor == null ? 'PATIENT' : actor.role),
      actorRole: actor?.role ?? 'PATIENT',
      action: action,
      entityType: entityType,
      entityId: entityId,
      entityLabel: label,
      details: details,
    ));
  }

  String _customerName(_Booking b) => _users[b.customerId]?.name ?? '#${b.id}';

  _Booking _own(int placeId, int bookingId) {
    final b = _bookings[bookingId];
    if (b == null || b.placeId != placeId) throw const ServerException('NOT_FOUND', 'Booking', 404);
    return b;
  }

  Map<String, dynamic> _placeInfo(_Place p) => {
        'id': p.id,
        'slug': p.slug,
        'nameAr': p.nameAr,
        'nameEn': p.nameEn,
        'category': p.category,
        'timezone': p.timezone,
        'currency': p.currency,
      };

  Map<String, dynamic> _staffBoard(_Staff s, List<_Booking> today) => {
        'id': s.id,
        'name': s.name,
        'titleAr': s.titleAr,
        'titleEn': s.titleEn,
        'room': s.room,
        'presence': s.presence,
        'presenceSince': s.presenceSince?.toIso8601String(),
        'currentBookingId': today.where((b) => b.staffId == s.id && b.status == 'IN_PROGRESS').firstOrNull?.id,
        'waiting': today.where((b) => b.staffId == s.id && b.status == 'ARRIVED').length,
      };

  // ======================================================================== board

  Future<Map<String, dynamic>> deskBoard() => _desk(() {
        final p = _place(_staffUser().placeId!);
        final today = _today(p);
        final eta = _eta(today);
        final shown = today.where((b) => b.status != 'CANCELLED').toList();
        int count(String s) => shown.where((b) => b.status == s).length;
        final billed = {
          for (final i in _invoices.values.where((i) => i.placeId == p.id && i.status != 'VOID' && i.bookingId != null))
            i.bookingId!: i
        };
        final local = tz.TZDateTime.from(_nowUtc, tz.getLocation(p.timezone));
        return {
          'date': '${local.year.toString().padLeft(4, '0')}-${FakeBackend._two(local.month)}-${FakeBackend._two(local.day)}',
          'place': _placeInfo(p),
          'staff': _staff.values.where((s) => s.placeId == p.id).map((s) => _staffBoard(s, shown)).toList(),
          'queue': [
            for (final b in shown)
              {
                'booking': _bookingJson(b),
                'expectedStartAt': (eta[b.id]?.expectedStart ?? b.startAt).toIso8601String(),
                'delayMin': eta[b.id]?.delayMin ?? 0,
                'ahead': eta[b.id]?.ahead ?? 0,
                'late': eta[b.id]?.late ?? false,
                'invoiceId': billed[b.id]?.id,
                'invoiceNumber': billed[b.id]?.number,
                'invoiceStatus': billed[b.id]?.status,
              },
          ],
          'services': _services.values.where((s) => s.placeId == p.id && s.active).map((s) => s.toJson()).toList(),
          'counts': {
            'booked': count('PENDING') + count('CONFIRMED'),
            'waiting': count('ARRIVED'),
            'inRoom': count('IN_PROGRESS'),
            'done': count('COMPLETED'),
            'noShow': count('NO_SHOW'),
          },
          'serverTime': _nowUtc.toIso8601String(),
        };
      });

  // ======================================================================== arrive

  Future<Map<String, dynamic>> deskCheckInByCode(String code) => _desk(() {
        final me = _staffUser();
        final clean = checkInCodeFrom(code);
        final b = _bookings.values.where((x) => x.checkInCode == clean && x.placeId == me.placeId).firstOrNull;
        if (b == null) throw const ServerException('NOT_FOUND', 'Booking', 404);
        return _bookingJson(_checkIn(b, me, 'QR'));
      });

  Future<Map<String, dynamic>> deskCheckIn(int bookingId) => _desk(() {
        final me = _staffUser();
        return _bookingJson(_checkIn(_own(me.placeId!, bookingId), me, 'DESK'));
      });

  _Booking _checkIn(_Booking b, _User? me, String via) {
    if (b.status == 'ARRIVED' || b.status == 'IN_PROGRESS' || b.status == 'COMPLETED') return b;
    if (b.status == 'CANCELLED') throw const ServerException('BOOKING_CANCELLED', null, 409);
    final p = _place(b.placeId);
    if (!_isToday(p, b.startAt)) throw const ServerException('NOT_TODAY', null, 409);
    if (b.status == 'NO_SHOW') {
      _firstFree([_staff[b.staffId]!], p, b.startAt, b.durationMin);
      _lock(b);
    }
    final ticket = _today(p).map((x) => x.ticketNo ?? 0).fold<int>(0, max) + 1;
    b
      ..status = 'ARRIVED'
      ..ticketNo = ticket
      ..checkedInAt = _nowUtc;
    _record(p.id, me, 'CHECKED_IN', 'BOOKING', b.id, _customerName(b), {'ticket': ticket, 'via': via});
    return b;
  }

  Future<Map<String, dynamic>> deskWalkIn(Map<String, dynamic> body) => _desk(() {
        final me = _staffUser();
        final p = _place(me.placeId!);
        final phone = body['customerPhone'] as String;
        final customer = _users.values.where((u) => u.phone == phone).firstOrNull ??
            _addUser(phone, body['customerName'] as String, 'CUSTOMER', null);
        final s = _serviceOf(p, body['serviceId'] as int);
        final candidates = _candidates(p, s, body['staffId'] as int?);
        DateTime? start;
        var t = SlotCalculator.alignDown(_nowUtc);
        final limit = _nowUtc.add(const Duration(hours: 6));
        while (start == null && t.isBefore(limit)) {
          final weekday = tz.TZDateTime.from(t, tz.getLocation(p.timezone)).weekday;
          final units = SlotCalculator.lockUnits(t, s.durationMin);
          final free = candidates.any((st) =>
              !st.daysOff.contains(weekday) && units.every((u) => !_locks.containsKey(_lockKey(st.id, u))));
          if (free) start = t;
          t = t.add(const Duration(minutes: SlotCalculator.unitMinutes));
        }
        if (start == null) throw const ServerException('NO_FREE_TIME', null, 409);
        final b = _create(
          placeId: p.id,
          serviceId: s.id,
          staffId: body['staffId'] as int?,
          customerId: customer.id,
          startAt: start,
          source: 'WALK_IN',
          desk: true,
        );
        _record(p.id, me, 'WALK_IN_ADDED', 'BOOKING', b.id, customer.name,
            {'serviceId': s.id, 'startAt': start.toIso8601String()});
        return _bookingJson(_checkIn(b, me, 'WALK_IN'));
      });

  // ======================================================================== the room

  Future<Map<String, dynamic>> deskCall(int bookingId) => _desk(() {
        final me = _staffUser();
        final b = _own(me.placeId!, bookingId);
        final repeat = b.status == 'IN_PROGRESS';
        if (!repeat) {
          if (b.status == 'CONFIRMED' || b.status == 'PENDING') throw const ServerException('NOT_CHECKED_IN', null, 409);
          if (b.status != 'ARRIVED') throw const ServerException('NOT_CALLABLE', null, 409);
          final busy = _today(_place(b.placeId))
              .any((x) => x.staffId == b.staffId && x.status == 'IN_PROGRESS' && x.id != b.id);
          if (busy) throw const ServerException('STAFF_BUSY', null, 409);
        }
        final s = _staff[b.staffId]!;
        if (!repeat) {
          b
            ..status = 'IN_PROGRESS'
            ..startedAt = _nowUtc;
        }
        b
          ..room = s.room
          ..calledAt = _nowUtc
          ..callCount += 1;
        s.setPresence('BUSY', _nowUtc);
        _record(b.placeId, me, 'CALLED', 'BOOKING', b.id, _customerName(b),
            {'ticket': b.ticketNo, 'room': s.room, 'staff': s.name, 'repeat': repeat});
        return _bookingJson(b);
      });

  Future<Map<String, dynamic>> deskFinish(int bookingId) => _desk(() {
        final me = _staffUser();
        final b = _own(me.placeId!, bookingId);
        if (b.status == 'COMPLETED') return _bookingJson(b);
        if (b.status != 'IN_PROGRESS' && b.status != 'ARRIVED') throw const ServerException('NOT_IN_ROOM', null, 409);
        b
          ..status = 'COMPLETED'
          ..finishedAt = _nowUtc;
        final s = _staff[b.staffId]!;
        final stillBusy = _today(_place(b.placeId)).any((x) => x.staffId == s.id && x.status == 'IN_PROGRESS');
        if (!stillBusy && s.presence == 'BUSY') s.setPresence('AVAILABLE', _nowUtc);
        _record(b.placeId, me, 'VISIT_FINISHED', 'BOOKING', b.id, _customerName(b), {
          'ticket': b.ticketNo,
          'staff': s.name,
          if (b.startedAt != null) 'minutes': _nowUtc.difference(b.startedAt!).inMinutes,
        });
        return _bookingJson(b);
      });

  Future<Map<String, dynamic>> deskNoShow(int bookingId) => _desk(() {
        final me = _staffUser();
        final b = _own(me.placeId!, bookingId);
        if (b.status == 'NO_SHOW') return _bookingJson(b);
        if (b.status != 'CONFIRMED' && b.status != 'PENDING' && b.status != 'ARRIVED') {
          throw const ServerException('NOT_CHANGEABLE', null, 409);
        }
        _unlock(b);
        b.status = 'NO_SHOW';
        _record(b.placeId, me, 'NO_SHOW', 'BOOKING', b.id, _customerName(b), {'startAt': b.startAt.toIso8601String()});
        return _bookingJson(b);
      });

  Future<Map<String, dynamic>> deskPresence(int staffId, String presence) => _desk(() {
        final me = _staffUser();
        final s = _staff[staffId];
        if (s == null || s.placeId != me.placeId) throw const ServerException('NOT_FOUND', 'Staff', 404);
        final before = s.presence;
        s.setPresence(presence, _nowUtc);
        if (before != presence) {
          _record(s.placeId, me, 'PRESENCE_CHANGED', 'STAFF', s.id, s.name, {'from': before, 'to': presence});
        }
        return _staffBoard(s, const []);
      });

  // ======================================================================== invoices

  Future<List<Map<String, dynamic>>> deskInvoices() => _desk(() {
        final p = _place(_staffUser().placeId!);
        final r = _dayRange(p);
        final list = _invoices.values
            .where((i) => i.placeId == p.id && !i.createdAt.isBefore(r.from) && i.createdAt.isBefore(r.to))
            .toList()
          ..sort((a, b) => b.number.compareTo(a.number));
        return list.map(_invoiceJson).toList();
      });

  Future<Map<String, dynamic>> deskCreateInvoice(Map<String, dynamic> body) =>
      _desk(() => _invoiceJson(_createInvoice(_staffUser(), body)));

  _Invoice _createInvoice(_User me, Map<String, dynamic> body) {
    final p = _place(me.placeId!);
    final ref = body['clientRef'] as String?;
    if (ref != null) {
      final existing = _invoices.values.where((i) => i.placeId == p.id && i.clientRef == ref).firstOrNull;
      if (existing != null) return existing;
    }
    final lines = _lines(body['lines']);
    final discount = _discount(body['discount'], lines);
    var customerName = body['customerName'] as String?;
    var phone = body['customerPhone'] as String?;
    String? staffName;
    final bookingId = body['bookingId'] as int?;
    if (bookingId != null) {
      final b = _own(p.id, bookingId);
      if (_invoices.values.any((i) => i.bookingId == b.id && i.status != 'VOID')) {
        throw const ServerException('ALREADY_INVOICED', null, 409);
      }
      customerName = _users[b.customerId]?.name ?? customerName;
      phone = _users[b.customerId]?.phone ?? phone;
      staffName = _staff[b.staffId]?.name;
    }
    if (customerName == null || customerName.trim().isEmpty) {
      throw const ServerException('CUSTOMER_REQUIRED', null, 400);
    }
    final paidWith = body['paidWith'] as String?;
    final inv = _Invoice(
      id: _nextId++,
      placeId: p.id,
      number: p.nextInvoiceNo++,
      bookingId: bookingId,
      customerName: customerName.trim(),
      customerPhone: phone,
      staffName: staffName,
      currency: p.currency,
      createdAt: _nowUtc,
      createdById: me.id,
      clientRef: ref,
      publicToken: _newCode() + _newCode(),
    )..setLines(lines, discount);
    if (paidWith != null) {
      inv
        ..status = 'PAID'
        ..paymentMethod = paidWith
        ..paidAt = _nowUtc;
    }
    _invoices[inv.id] = inv;
    _record(p.id, me, 'INVOICE_CREATED', 'INVOICE', inv.id, '#${inv.number}', {
      'number': inv.number,
      'total': inv.total,
      'currency': inv.currency,
      if (paidWith != null) 'paidWith': paidWith,
    });
    return inv;
  }

  Future<Map<String, dynamic>> deskUpdateInvoice(int id, Map<String, dynamic> body) =>
      _desk(() => _invoiceJson(_updateInvoice(_staffUser(), id, body)));

  _Invoice _updateInvoice(_User me, int id, Map<String, dynamic> body) {
    final inv = _ownInvoice(me.placeId!, id);
    if (inv.status == 'VOID') throw const ServerException('INVOICE_VOID', null, 409);
    if ((body['version'] as num).toInt() != inv.version) throw const ServerException('STALE_INVOICE', null, 409);
    final lines = _lines(body['lines']);
    final discount = _discount(body['discount'], lines);
    final before = inv.lines.map(_describe).toList();
    final after = lines.map(_describe).toList();
    final totalBefore = inv.total;
    final discountBefore = inv.discount;
    inv
      ..setLines(lines, discount)
      ..updatedAt = _nowUtc
      ..version += 1;
    final added = [...after];
    before.forEach(added.remove);
    final removed = [...before];
    after.forEach(removed.remove);
    _record(inv.placeId, me, 'INVOICE_EDITED', 'INVOICE', inv.id, '#${inv.number}', {
      'number': inv.number,
      'totalFrom': totalBefore,
      'totalTo': inv.total,
      'currency': inv.currency,
      if (added.isNotEmpty) 'added': added,
      if (removed.isNotEmpty) 'removed': removed,
      if (discountBefore != inv.discount) ...{'discountFrom': discountBefore, 'discountTo': inv.discount},
    });
    return inv;
  }

  Future<Map<String, dynamic>> deskPayInvoice(int id, String method) => _desk(() {
        final me = _staffUser();
        final inv = _ownInvoice(me.placeId!, id);
        if (inv.status == 'VOID') throw const ServerException('INVOICE_VOID', null, 409);
        if (inv.status == 'PAID') return _invoiceJson(inv);
        inv
          ..status = 'PAID'
          ..paymentMethod = method
          ..paidAt = _nowUtc
          ..version += 1;
        _record(inv.placeId, me, 'INVOICE_PAID', 'INVOICE', inv.id, '#${inv.number}',
            {'number': inv.number, 'total': inv.total, 'currency': inv.currency, 'paidWith': method});
        return _invoiceJson(inv);
      });

  Future<Map<String, dynamic>> deskVoidInvoice(int id, String reason) => _desk(() {
        final me = _staffUser();
        final inv = _ownInvoice(me.placeId!, id);
        if (inv.status == 'VOID') return _invoiceJson(inv);
        if (reason.trim().isEmpty) throw const ServerException('VALIDATION', null, 400);
        inv
          ..status = 'VOID'
          ..voidReason = reason.trim()
          ..updatedAt = _nowUtc
          ..version += 1;
        _record(inv.placeId, me, 'INVOICE_VOIDED', 'INVOICE', inv.id, '#${inv.number}',
            {'number': inv.number, 'total': inv.total, 'currency': inv.currency, 'reason': inv.voidReason});
        return _invoiceJson(inv);
      });

  _Invoice _ownInvoice(int placeId, int id) {
    final inv = _invoices[id];
    if (inv == null || inv.placeId != placeId) throw const ServerException('NOT_FOUND', 'Invoice', 404);
    return inv;
  }

  List<_Line> _lines(Object? raw) {
    final list = (raw as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (list.isEmpty) throw const ServerException('VALIDATION', null, 400);
    return [
      for (final l in list)
        if ((l['unitPrice'] as num) < 0)
          throw const ServerException('INVALID_PRICE', null, 400)
        else
          _Line(l['description'] as String, (l['qty'] as num).toInt(), (l['unitPrice'] as num).toDouble(),
              l['serviceId'] as int?),
    ];
  }

  double _discount(Object? raw, List<_Line> lines) {
    final d = (raw as num? ?? 0).toDouble();
    final subtotal = lines.fold<double>(0, (s, l) => s + l.amount);
    if (d < 0 || d > subtotal) throw const ServerException('INVALID_DISCOUNT', null, 400);
    return d;
  }

  static String _describe(_Line l) => '${l.description} × ${l.qty} @ ${_plain(l.unitPrice)}';

  static String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Map<String, dynamic> _invoiceJson(_Invoice i) => {
        'id': i.id,
        'number': i.number,
        'placeId': i.placeId,
        'bookingId': i.bookingId,
        'customerName': i.customerName,
        'customerPhone': i.customerPhone,
        'staffName': i.staffName,
        'lines': i.lines
            .map((l) => {
                  'description': l.description,
                  'qty': l.qty,
                  'unitPrice': l.unitPrice,
                  'amount': l.amount,
                  'serviceId': l.serviceId,
                })
            .toList(),
        'subtotal': i.subtotal,
        'discount': i.discount,
        'total': i.total,
        'currency': i.currency,
        'status': i.status,
        'paymentMethod': i.paymentMethod,
        'createdAt': i.createdAt.toIso8601String(),
        'updatedAt': i.updatedAt?.toIso8601String(),
        'paidAt': i.paidAt?.toIso8601String(),
        'createdByName': _users[i.createdById]?.name,
        'voidReason': i.voidReason,
        'version': i.version,
        'publicToken': i.publicToken,
        'clientRef': i.clientRef,
        'printUrl': null, // no server in the demo: the app shows its own print preview
      };

  // ======================================================================== audit

  Future<List<Map<String, dynamic>>> deskAudit({String? entityType, int? entityId}) => _desk(() {
        final placeId = _staffUser().placeId!;
        final list = _audit
            .where((a) =>
                a.placeId == placeId &&
                (entityType == null || entityId == null || (a.entityType == entityType && a.entityId == entityId)))
            .toList()
          ..sort((a, b) {
            final c = b.at.compareTo(a.at);
            return c != 0 ? c : b.id.compareTo(a.id);
          });
        return list.take(150).map((a) => a.toJson()).toList();
      });

  // ======================================================================== waiting-room screen

  Future<Map<String, dynamic>> display(String slug) => _desk(() {
        final p = _places.values.where((x) => x.slug == slug).firstOrNull;
        if (p == null) throw const ServerException('NOT_FOUND', 'Place', 404);
        final today = _today(p);
        final eta = _eta(today);
        String name(_Booking b) => screenName(_users[b.customerId]?.name) ?? '';
        final staff = _staff.values.where((s) => s.placeId == p.id).toList();
        final waiting = today.where((b) => b.status == 'ARRIVED').toList()
          ..sort((a, b) {
            final c = (eta[a.id]?.expectedStart ?? a.startAt).compareTo(eta[b.id]?.expectedStart ?? b.startAt);
            return c != 0 ? c : a.id.compareTo(b.id);
          });
        final called = today.where((b) => b.calledAt != null && b.calledAt!.isAfter(_nowUtc.subtract(const Duration(hours: 2))))
            .toList()
          ..sort((a, b) => b.calledAt!.compareTo(a.calledAt!));
        final last = called.firstOrNull;
        return {
          'place': _placeInfo(p),
          'staff': [
            for (final s in staff)
              () {
                final serving = today.where((b) => b.staffId == s.id && b.status == 'IN_PROGRESS').firstOrNull;
                return {
                  'id': s.id,
                  'name': s.name,
                  'titleAr': s.titleAr,
                  'titleEn': s.titleEn,
                  'room': s.room,
                  'presence': s.presence,
                  'nowServingTicket': serving?.ticketNo,
                  'nowServingName': serving == null ? null : name(serving),
                };
              }(),
          ],
          'waiting': [
            for (final b in waiting)
              {
                'ticketNo': b.ticketNo ?? 0,
                'name': name(b),
                'staffId': b.staffId,
                'staffName': _staff[b.staffId]?.name,
                'room': _staff[b.staffId]?.room,
                'etaMin': max(0, (eta[b.id]?.expectedStart ?? b.startAt).difference(_nowUtc).inMinutes),
                'delayMin': eta[b.id]?.delayMin ?? 0,
              },
          ],
          'lastCall': last == null
              ? null
              : {
                  'seq': '${last.id}-${last.callCount}',
                  'ticketNo': last.ticketNo,
                  'name': name(last),
                  'room': last.room,
                  'staffName': _staff[last.staffId]?.name,
                  'at': last.calledAt!.toIso8601String(),
                },
          'servedToday': today.where((b) => b.status == 'COMPLETED').length,
          'serverTime': _nowUtc.toIso8601String(),
        };
      });

  // ======================================================================== seed: Al Nakheel Clinic, live

  void _seedNakheel(_User ahmed) {
    final p = _addPlace(_Place(_nextId++, 'nakheel-clinic', 'عيادة النخيل', 'Al Nakheel Clinic', 'CLINIC',
        'عبدون، عمّان', 'Abdoun, Amman', 4.8, 132, 2.6, 'Asia/Amman', 'JOD', '+962790000010', 8 * 60, 23 * 60, {}))
      ..nextInvoiceNo = 1041;
    final consult = _addService(p.id, 'كشفية', 'Consultation', 30, 20);
    final followUp = _addService(p.id, 'مراجعة', 'Follow-up', 15, 10);
    final pressure = _addService(p.id, 'قياس ضغط', 'Blood pressure check', 15, 5);
    final sugar = _addService(p.id, 'فحص سكر', 'Blood sugar test', 15, 7);
    final all = {consult.id, followUp.id, pressure.id, sugar.id};
    final khaled = _addStaff(p.id, 'د. خالد العمري', 'طبيب عام', 'General practitioner', all, room: 'غرفة ١');
    final lina = _addStaff(p.id, 'د. لينا حداد', 'طبيبة أطفال', 'Paediatrician', all, room: 'غرفة ٢');
    _review(p.id, 'أم خالد', 5, 'صرت أعرف دوري من الشاشة بدل ما أسأل الاستقبال كل شوي.', 4);
    _review(p.id, 'Omar S.', 5, 'Checked in with the QR in two seconds.', 11);

    final sara = _addUser(FakeBackend.demoReceptionPhone, 'سارة', 'RECEPTION', p.id);
    _User c(String phone, String name) => _addUser(phone, name, 'CUSTOMER', null);
    final abuSami = c('+962790000101', 'أبو سامي');
    final ummKhaled = c('+962790000102', 'أم خالد');
    final yousef = c('+962790000103', 'يوسف النجار');
    final layan = c('+962790000104', 'ليان عيسى');
    final mahmoud = c('+962790000105', 'محمود الرواشدة');
    final rana = c('+962790000106', 'رنا حداد');
    final ali = c('+962790000107', 'علي الخطيب');
    final huda = c('+962790000108', 'هدى سليمان');

    final now = _nowUtc;
    final t0 = SlotCalculator.alignDown(now);
    DateTime m(int minutes) => t0.add(Duration(minutes: minutes));
    _Booking? visit(_Service s, _Staff st, _User who, DateTime start) {
      try {
        return _create(
            placeId: p.id, serviceId: s.id, staffId: st.id, customerId: who.id, startAt: start, source: 'APP', system: true);
      } on ServerException {
        return null;
      }
    }

    final k1 = visit(consult, khaled, ummKhaled, m(-60));
    final k2 = visit(consult, khaled, yousef, m(-30));
    final k3 = visit(consult, khaled, abuSami, m(0));
    visit(consult, khaled, mahmoud, m(30));
    final k5 = visit(followUp, khaled, huda, m(60));
    visit(consult, khaled, ahmed, m(120)); // the demo customer's own visit: his QR works here
    final l1 = visit(consult, lina, layan, m(-45));
    final l2 = visit(followUp, lina, rana, m(15));
    visit(consult, lina, ali, m(45));
    if (k1 == null || k2 == null || k3 == null || l1 == null || l2 == null) return;

    void arrive(_Booking b, int ticket, DateTime at) => b
      ..status = 'ARRIVED'
      ..ticketNo = ticket
      ..checkedInAt = at;
    void callIn(_Booking b, _Staff st, DateTime at) => b
      ..status = 'IN_PROGRESS'
      ..startedAt = at
      ..calledAt = at
      ..room = st.room
      ..callCount += 1;
    void done(_Booking b, DateTime at) => b
      ..status = 'COMPLETED'
      ..finishedAt = at;

    arrive(k1, 1, m(-70));
    callIn(k1, khaled, m(-58));
    done(k1, m(-31));
    arrive(l1, 2, m(-52));
    callIn(l1, lina, m(-45));
    done(l1, m(-16));
    arrive(k2, 3, m(-38));
    callIn(k2, khaled, now.subtract(const Duration(minutes: 20)));
    arrive(k3, 4, now.subtract(const Duration(minutes: 10)));
    arrive(l2, 5, now.subtract(const Duration(minutes: 6)));
    if (k5 != null) arrive(k5, 6, now.subtract(const Duration(minutes: 3)));
    khaled.setPresence('BUSY', now.subtract(const Duration(minutes: 20)));
    lina.setPresence('AVAILABLE', m(-16));

    _record(p.id, sara, 'CHECKED_IN', 'BOOKING', k3.id, abuSami.name, {'ticket': 4, 'via': 'QR'});
    _record(p.id, sara, 'CALLED', 'BOOKING', k2.id, yousef.name,
        {'ticket': 3, 'room': khaled.room, 'staff': khaled.name, 'repeat': false});
    Map<String, dynamic> line(_Service s) =>
        {'description': s.nameAr, 'qty': 1, 'unitPrice': s.price, 'serviceId': s.id};
    _createInvoice(sara, {
      'bookingId': k1.id,
      'lines': [line(consult)],
      'paidWith': 'CASH',
      'clientRef': 'seed-1041',
    });
    final second = _createInvoice(sara, {
      'bookingId': l1.id,
      'lines': [line(consult)],
      'clientRef': 'seed-1042',
    });
    _updateInvoice(sara, second.id, {
      'lines': [line(consult), line(pressure)],
      'version': second.version,
    });
  }
}

// ========================================================================== desk rows

class _Line {
  _Line(this.description, this.qty, this.unitPrice, this.serviceId);

  final String description;
  final int qty;
  final double unitPrice;
  final int? serviceId;

  double get amount => unitPrice * qty;
}

class _Invoice {
  _Invoice({
    required this.id,
    required this.placeId,
    required this.number,
    required this.customerName,
    required this.currency,
    required this.createdAt,
    required this.createdById,
    required this.publicToken,
    this.bookingId,
    this.customerPhone,
    this.staffName,
    this.clientRef,
  });

  final int id, placeId, number, createdById;
  final int? bookingId;
  final String customerName, currency, publicToken;
  final String? customerPhone, staffName, clientRef;
  final DateTime createdAt;
  List<_Line> lines = [];
  double subtotal = 0, discount = 0, total = 0;
  String status = 'ISSUED';
  String? paymentMethod, voidReason;
  DateTime? updatedAt, paidAt;
  int version = 0;

  void setLines(List<_Line> l, double d) {
    lines = l;
    subtotal = l.fold(0, (s, x) => s + x.amount);
    discount = d;
    total = max(0, subtotal - d);
  }
}

class _Audit {
  _Audit({
    required this.id,
    required this.placeId,
    required this.at,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.entityType,
    this.actorId,
    this.entityId,
    this.entityLabel,
    this.details = const {},
  });

  final int id, placeId;
  final DateTime at;
  final int? actorId, entityId;
  final String actorName, actorRole, action, entityType;
  final String? entityLabel;
  final Map<String, dynamic> details;

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'actorId': actorId,
        'actorName': actorName,
        'actorRole': actorRole,
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        'entityLabel': entityLabel,
        'details': details,
      };
}
