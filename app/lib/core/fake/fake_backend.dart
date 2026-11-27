import 'dart:async';
import 'dart:math';

import 'package:timezone/timezone.dart' as tz;

import '../../features/booking/domain/services/slot_calculator.dart';
import '../../features/desk/domain/services/display_names.dart';
import '../../features/desk/domain/services/queue_estimator.dart';
import '../error/exceptions.dart';
import '../session/session.dart';

part 'fake_desk.dart';

/// An in-memory copy of the Mawid API, speaking the same JSON.
///
/// It lets the demo build (and recruiters, and clients) use the whole app with no server,
/// no keys and no internet. Because it returns the same JSON as Spring Boot, the real models,
/// repositories and BLoCs run unchanged on top of it; only the data source is swapped in get_it.
///
/// Double booking uses the same idea as the API: one lock per staff member per 15-minute unit.
class FakeBackend {
  FakeBackend(this.session, {DateTime Function()? clock, this.latency = const Duration(milliseconds: 250)})
      : _now = clock ?? DateTime.now {
    _seed();
  }

  final Session session;
  final DateTime Function() _now;
  final Duration latency;

  static const demoCustomerPhone = '+971500000001';
  static const demoOwnerPhone = '+971500000002';
  static const demoReceptionPhone = '+962790000003';
  static const demoCode = '123456';

  final _places = <int, _Place>{};
  final _services = <int, _Service>{};
  final _staff = <int, _Staff>{};
  final _reviews = <_Review>[];
  final _users = <int, _User>{};
  final _bookings = <int, _Booking>{};
  final _invoices = <int, _Invoice>{};
  final _audit = <_Audit>[];

  /// Demo switch: pretend the network is down for the front desk, to show its offline mode.
  bool offline = false;

  /// "staffId|unitStartMillis" → bookingId. The fake twin of the slot_locks unique index.
  final _locks = <String, int>{};
  int _nextId = 1;

  final _newBookings = StreamController<Map<String, dynamic>>.broadcast();

  /// Owner dashboard listens to this to show "new booking" alerts.
  Stream<Map<String, dynamic>> get newBookings => _newBookings.stream;

  DateTime get _nowUtc => _now().toUtc();

  Future<T> _delay<T>(T Function() body) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return body();
  }

  int _currentUserId() {
    final user = session.user;
    if (user == null) throw const UnauthorizedException();
    final id = int.tryParse(user.id);
    if (id != null && _users.containsKey(id) && _users[id]!.phone == user.phone) return id;
    // The in-memory data was reset (app restarted) but the device still has a saved session:
    // find the same phone again, or recreate that customer.
    final byPhone = _users.values.where((u) => u.phone == user.phone).firstOrNull;
    return (byPhone ?? _addUser(user.phone, user.name, 'CUSTOMER', null)).id;
  }

  // ======================================================================== auth

  Future<void> requestOtp(String phone) => _delay(() {});

  Future<Map<String, dynamic>> verifyOtp(String phone, String code, String? name) => _delay(() {
        if (code != demoCode) throw const ServerException('OTP_INVALID', 'Wrong code', 401);
        final user = _users.values.where((u) => u.phone == phone).firstOrNull ??
            _addUser(phone, (name == null || name.trim().isEmpty) ? null : name.trim(), 'CUSTOMER', null);
        return _session(user);
      });

  Future<Map<String, dynamic>> demoLogin(String role) => _delay(() {
        final phone = switch (role) {
          'OWNER' => demoOwnerPhone,
          'RECEPTION' => demoReceptionPhone,
          _ => demoCustomerPhone,
        };
        return _session(_users.values.firstWhere((u) => u.phone == phone));
      });

  Map<String, dynamic> _session(_User u) => {'token': 'fake-token-${u.id}', 'user': u.toJson()};

  // ======================================================================== places

  Future<List<Map<String, dynamic>>> places({String? category, String? query}) => _delay(() {
        final q = query?.trim().toLowerCase() ?? '';
        final list = _places.values.where((p) {
          if (category != null && p.category != category) return false;
          if (q.isEmpty) return true;
          if ('${p.nameAr} ${p.nameEn} ${p.areaAr} ${p.areaEn}'.toLowerCase().contains(q)) return true;
          return _services.values
              .any((s) => s.placeId == p.id && s.active && '${s.nameAr} ${s.nameEn}'.toLowerCase().contains(q));
        }).toList()
          ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        return list.map((p) => p.toJson()).toList();
      });

  Future<Map<String, dynamic>> placeDetails(int placeId, {bool includeInactive = false}) =>
      _delay(() => _details(placeId, includeInactive: includeInactive));

  Map<String, dynamic> _details(int placeId, {bool includeInactive = false}) {
    final p = _place(placeId);
    return {
      'place': p.toJson(),
      'services': _services.values
          .where((s) => s.placeId == placeId && (includeInactive || s.active))
          .map((s) => s.toJson())
          .toList(),
      'staff': _staff.values.where((s) => s.placeId == placeId).map((s) => s.toJson()).toList(),
      'reviews': _reviews.where((r) => r.placeId == placeId).map((r) => r.toJson()).toList(),
    };
  }

  Future<Map<String, dynamic>> availability(int placeId, int serviceId, String date, {int? staffId}) =>
      _delay(() {
        final p = _place(placeId);
        final s = _serviceOf(p, serviceId);
        final parts = date.split('-').map(int.parse).toList();
        final candidates = _candidates(p, s, staffId);
        final schedules = candidates.map((st) {
          final busy = _bookings.values
              .where((b) => b.staffId == st.id && _holdsTime(b.status))
              .map((b) => BusyInterval(b.startAt, b.endAt))
              .toList();
          return StaffSchedule(staffId: '${st.id}', daysOff: st.daysOff, busy: busy);
        }).toList();
        final slots = const SlotCalculator().slotsFor(
          year: parts[0],
          month: parts[1],
          day: parts[2],
          timezone: p.timezone,
          hours: p.hours,
          durationMinutes: s.durationMin,
          staff: schedules,
          nowUtc: _nowUtc,
        );
        final location = tz.getLocation(p.timezone);
        return {
          'date': date,
          'timezone': p.timezone,
          'durationMin': s.durationMin,
          'slots': slots.map((slot) {
            final local = tz.TZDateTime.from(slot.startAt, location);
            return {
              'startAt': slot.startAt.toIso8601String(),
              'localTime': '${_two(local.hour)}:${_two(local.minute)}',
              'available': slot.available,
              'freeStaffIds': slot.freeStaffIds.map(int.parse).toList(),
            };
          }).toList(),
        };
      });

  // ======================================================================== bookings (customer)

  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> body) => _delay(() {
        final customerId = _currentUserId();
        final b = _create(
          placeId: body['placeId'] as int,
          serviceId: body['serviceId'] as int,
          staffId: body['staffId'] as int?,
          customerId: customerId,
          startAt: DateTime.parse(body['startAt'] as String).toUtc(),
          source: 'APP',
          note: body['note'] as String?,
        );
        return _bookingJson(b);
      });

  Future<List<Map<String, dynamic>>> myBookings() => _delay(() {
        final me = _currentUserId();
        final list = _bookings.values.where((b) => b.customerId == me).toList()
          ..sort((a, b) => b.startAt.compareTo(a.startAt));
        return list.map(_bookingJson).toList();
      });

  Future<Map<String, dynamic>> cancelBooking(int id) => _delay(() {
        final b = _booking(id);
        final asOwner = _authorize(b);
        if (!_holdsTime(b.status) || b.status == 'COMPLETED' || b.status == 'IN_PROGRESS') {
          throw const ServerException('NOT_CANCELLABLE', null, 409);
        }
        if (!asOwner && !SlotCalculator.customerCanChange(b.startAt, _nowUtc)) {
          throw const ServerException('TOO_LATE_TO_CHANGE', null, 409);
        }
        _unlock(b);
        b.status = 'CANCELLED';
        return _bookingJson(b);
      });

  Future<Map<String, dynamic>> rescheduleBooking(int id, DateTime startAt, {int? staffId}) => _delay(() {
        final b = _booking(id);
        final asOwner = _authorize(b);
        if (!_holdsTime(b.status) || b.status == 'COMPLETED' || b.status == 'IN_PROGRESS') {
          throw const ServerException('NOT_CHANGEABLE', null, 409);
        }
        if (!asOwner && !SlotCalculator.customerCanChange(b.startAt, _nowUtc)) {
          throw const ServerException('TOO_LATE_TO_CHANGE', null, 409);
        }
        final p = _place(b.placeId);
        final s = _serviceOf(p, b.serviceId);
        _validateTime(p, b.durationMin, startAt.toUtc(), trusted: false);
        final oldLocks = _unlock(b);
        try {
          final chosen = _firstFree(_candidates(p, s, staffId), p, startAt.toUtc(), b.durationMin);
          b
            ..startAt = startAt.toUtc()
            ..staffId = chosen.id;
          _lock(b);
        } on ServerException {
          oldLocks.forEach((key, value) => _locks[key] = value); // roll back like a transaction would
          rethrow;
        }
        return _bookingJson(b);
      });

  // ======================================================================== owner

  Future<Map<String, dynamic>> ownerPlace() => _delay(() => _details(_ownerPlaceId(), includeInactive: true));

  Future<List<Map<String, dynamic>>> ownerBookings(String? date) => _delay(() {
        final p = _place(_ownerPlaceId());
        final location = tz.getLocation(p.timezone);
        final today = tz.TZDateTime.from(_nowUtc, location);
        final parts = date?.split('-').map(int.parse).toList() ?? [today.year, today.month, today.day];
        final from = tz.TZDateTime(location, parts[0], parts[1], parts[2]).toUtc();
        final to = tz.TZDateTime(location, parts[0], parts[1], parts[2] + 1).toUtc();
        final list = _bookings.values
            .where((b) => b.placeId == p.id && !b.startAt.isBefore(from) && b.startAt.isBefore(to))
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
        return list.map(_bookingJson).toList();
      });

  Future<Map<String, dynamic>> updateStatus(int id, String status) => _delay(() {
        final b = _booking(id);
        if (b.placeId != _ownerPlaceId()) throw const ServerException('FORBIDDEN', null, 403);
        final held = _holdsTime(b.status);
        final holds = _holdsTime(status);
        if (held && !holds) {
          _unlock(b);
        } else if (!held && holds) {
          final p = _place(b.placeId);
          _firstFree([_staff[b.staffId]!], p, b.startAt, b.durationMin);
          b.status = status;
          _lock(b);
          return _bookingJson(b);
        }
        b.status = status;
        return _bookingJson(b);
      });

  Future<Map<String, dynamic>> manualBooking(Map<String, dynamic> body) => _delay(() {
        final placeId = _ownerPlaceId();
        final phone = body['customerPhone'] as String;
        final customer = _users.values.where((u) => u.phone == phone).firstOrNull ??
            _addUser(phone, body['customerName'] as String, 'CUSTOMER', null);
        final b = _create(
          placeId: placeId,
          serviceId: body['serviceId'] as int,
          staffId: body['staffId'] as int?,
          customerId: customer.id,
          startAt: DateTime.parse(body['startAt'] as String).toUtc(),
          source: 'MANUAL',
          note: body['note'] as String?,
          owner: true,
        );
        return _bookingJson(b);
      });

  Future<List<Map<String, dynamic>>> ownerServices() => _delay(() {
        final placeId = _ownerPlaceId();
        return _services.values.where((s) => s.placeId == placeId).map((s) => s.toJson()).toList();
      });

  Future<Map<String, dynamic>> saveService(Map<String, dynamic> body, {int? id}) => _delay(() {
        final placeId = _ownerPlaceId();
        final duration = body['durationMin'] as int;
        if (duration < 15 || duration > 480 || duration % 15 != 0) {
          throw const ServerException('INVALID_DURATION', null, 400);
        }
        if (id == null) {
          final s = _addService(placeId, body['nameAr'] as String, body['nameEn'] as String, duration,
              (body['price'] as num).toDouble());
          for (final st in _staff.values.where((x) => x.placeId == placeId)) {
            st.serviceIds.add(s.id);
          }
          return s.toJson();
        }
        final s = _services[id];
        if (s == null || s.placeId != placeId) throw const ServerException('NOT_FOUND', null, 404);
        s
          ..nameAr = body['nameAr'] as String
          ..nameEn = body['nameEn'] as String
          ..durationMin = duration
          ..price = (body['price'] as num).toDouble()
          ..active = (body['active'] as bool?) ?? true;
        return s.toJson();
      });

  // ======================================================================== rules

  _Booking _create({
    required int placeId,
    required int serviceId,
    required int? staffId,
    required int customerId,
    required DateTime startAt,
    required String source,
    String? note,
    bool owner = false,
    bool system = false,
    bool desk = false,
    String status = 'CONFIRMED',
  }) {
    final p = _place(placeId);
    final s = _serviceOf(p, serviceId);
    if (!system && !s.active) throw const ServerException('SERVICE_INACTIVE', null, 400);
    _validateTime(p, s.durationMin, startAt, trusted: system || desk);
    final chosen = _firstFree(_candidates(p, s, staffId), p, startAt, s.durationMin);
    final b = _Booking(
      id: _nextId++,
      placeId: p.id,
      serviceId: s.id,
      staffId: chosen.id,
      customerId: customerId,
      startAt: startAt,
      durationMin: s.durationMin,
      price: s.price,
      currency: p.currency,
      status: status,
      source: source,
      note: note,
      createdAt: _nowUtc,
      checkInCode: _newCode(),
    );
    _bookings[b.id] = b;
    _lock(b);
    if (!system) _newBookings.add(_bookingJson(b));
    return b;
  }

  /// [trusted]: the seed or reception adding a walk-in "now" — no past or working-hours checks.
  void _validateTime(_Place p, int durationMin, DateTime start, {required bool trusted}) {
    if (start.millisecondsSinceEpoch % (SlotCalculator.unitMinutes * 60000) != 0) {
      throw const ServerException('SLOT_NOT_ALIGNED', null, 400);
    }
    if (!trusted && !start.isAfter(_nowUtc)) throw const ServerException('SLOT_IN_PAST', null, 400);
    if (!trusted && !SlotCalculator.fitsWorkingHours(start, durationMin, p.timezone, p.hours)) {
      throw const ServerException('OUTSIDE_WORKING_HOURS', null, 400);
    }
  }

  _Staff _firstFree(List<_Staff> candidates, _Place p, DateTime start, int durationMin) {
    final weekday = tz.TZDateTime.from(start, tz.getLocation(p.timezone)).weekday;
    final units = SlotCalculator.lockUnits(start, durationMin);
    for (final s in candidates) {
      if (s.daysOff.contains(weekday)) continue;
      if (units.every((u) => !_locks.containsKey(_lockKey(s.id, u)))) return s;
    }
    throw const SlotTakenException();
  }

  void _lock(_Booking b) {
    for (final u in SlotCalculator.lockUnits(b.startAt, b.durationMin)) {
      _locks[_lockKey(b.staffId, u)] = b.id;
    }
  }

  Map<String, int> _unlock(_Booking b) {
    final removed = <String, int>{};
    _locks.removeWhere((key, value) {
      if (value == b.id) removed[key] = value;
      return value == b.id;
    });
    return removed;
  }

  /// Exposed for tests: how many 15-minute units a booking holds.
  int locksOf(int bookingId) => _locks.values.where((v) => v == bookingId).length;

  String _lockKey(int staffId, DateTime unit) => '$staffId|${unit.millisecondsSinceEpoch}';

  List<_Staff> _candidates(_Place p, _Service s, int? staffId) {
    final all = _staff.values.where((st) => st.placeId == p.id && st.serviceIds.contains(s.id)).toList();
    if (staffId == null) {
      if (all.isEmpty) throw const ServerException('NO_STAFF', null, 400);
      return all;
    }
    final match = all.where((st) => st.id == staffId).toList();
    if (match.isEmpty) throw const ServerException('STAFF_NOT_AVAILABLE', null, 400);
    return match;
  }

  bool _authorize(_Booking b) {
    final me = _users[_currentUserId()]!;
    if ((me.role == 'OWNER' || me.role == 'RECEPTION') && me.placeId == b.placeId) return true;
    if (b.customerId == me.id) return false;
    throw const ServerException('FORBIDDEN', null, 403);
  }

  int _ownerPlaceId() {
    final me = _users[_currentUserId()]!;
    if (me.role != 'OWNER' || me.placeId == null) throw const ServerException('FORBIDDEN', null, 403);
    return me.placeId!;
  }

  static bool _holdsTime(String status) =>
      status == 'PENDING' ||
      status == 'CONFIRMED' ||
      status == 'ARRIVED' ||
      status == 'IN_PROGRESS' ||
      status == 'COMPLETED';

  _Place _place(int id) => _places[id] ?? (throw const ServerException('NOT_FOUND', 'Place', 404));

  _Service _serviceOf(_Place p, int id) {
    final s = _services[id];
    if (s == null || s.placeId != p.id) throw const ServerException('NOT_FOUND', 'Service', 404);
    return s;
  }

  _Booking _booking(int id) => _bookings[id] ?? (throw const ServerException('NOT_FOUND', 'Booking', 404));

  Map<String, dynamic> _bookingJson(_Booking b) {
    final p = _places[b.placeId]!;
    final s = _services[b.serviceId]!;
    final st = _staff[b.staffId]!;
    final c = _users[b.customerId];
    return {
      'id': b.id,
      'placeId': p.id,
      'placeSlug': p.slug,
      'placeNameAr': p.nameAr,
      'placeNameEn': p.nameEn,
      'placeTimezone': p.timezone,
      'serviceId': s.id,
      'serviceNameAr': s.nameAr,
      'serviceNameEn': s.nameEn,
      'staffId': st.id,
      'staffName': st.name,
      'customerId': b.customerId,
      'customerName': c?.name,
      'customerPhone': c?.phone,
      'startAt': b.startAt.toIso8601String(),
      'endAt': b.endAt.toIso8601String(),
      'durationMin': b.durationMin,
      'price': b.price,
      'currency': b.currency,
      'status': b.status,
      'source': b.source,
      'note': b.note,
      'createdAt': b.createdAt.toIso8601String(),
      'canChange': (b.status == 'PENDING' || b.status == 'CONFIRMED') &&
          SlotCalculator.customerCanChange(b.startAt, _nowUtc),
      'checkInCode': b.checkInCode,
      'ticketNo': b.ticketNo,
      'checkedInAt': b.checkedInAt?.toIso8601String(),
      'calledAt': b.calledAt?.toIso8601String(),
      'room': b.room,
      'startedAt': b.startedAt?.toIso8601String(),
      'finishedAt': b.finishedAt?.toIso8601String(),
    };
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  // ======================================================================== seed (mirrors the API's DemoDataSeeder)

  _User _addUser(String phone, String? name, String role, int? placeId) {
    final u = _User(_nextId++, phone, name, role, placeId);
    _users[u.id] = u;
    return u;
  }

  _Service _addService(int placeId, String ar, String en, int minutes, double price) {
    final s = _Service(_nextId++, placeId, ar, en, minutes, price);
    _services[s.id] = s;
    return s;
  }

  _Staff _addStaff(int placeId, String name, String titleAr, String titleEn, Set<int> serviceIds,
      {Set<int> daysOff = const {}, String? room}) {
    final s = _Staff(_nextId++, placeId, name, titleAr, titleEn, {...serviceIds}, daysOff)..room = room;
    _staff[s.id] = s;
    return s;
  }

  _Place _addPlace(_Place p) {
    _places[p.id] = p;
    return p;
  }

  void _review(int placeId, String author, int rating, String text, int daysAgo) {
    _reviews.add(_Review(_nextId++, placeId, author, rating, text, _nowUtc.subtract(Duration(days: daysAgo))));
  }

  void _seed() {
    final lamsa = _addPlace(_Place(_nextId++, 'lamsa-salon', 'صالون لمسة', 'Lamsa Salon', 'SALON', 'القرهود، دبي',
        'Al Garhoud, Dubai', 4.8, 214, 1.2, 'Asia/Dubai', 'AED', '+971500000010', 10 * 60, 22 * 60, {}));
    final haircut = _addService(lamsa.id, 'قص شعر وتصفيف', 'Haircut & styling', 45, 120);
    final colour = _addService(lamsa.id, 'صبغة كاملة', 'Full colour', 90, 350);
    final protein = _addService(lamsa.id, 'بروتين وعلاج', 'Protein treatment', 120, 600);
    final nails = _addService(lamsa.id, 'مانيكير وباديكير', 'Manicure & pedicure', 60, 150);
    final noura = _addStaff(lamsa.id, 'نورا', 'خبيرة شعر', 'Hair specialist',
        {haircut.id, colour.id, protein.id, nails.id},
        room: 'كرسي ١');
    final reem = _addStaff(lamsa.id, 'ريم', 'مصففة شعر', 'Stylist', {haircut.id, nails.id},
        daysOff: {DateTime.sunday}, room: 'كرسي ٢');
    _review(lamsa.id, 'سارة م.', 5, 'خدمة ممتازة ونورا شاطرة جدًا في الصبغة.', 3);
    _review(lamsa.id, 'Hind A.', 5, 'Booked in seconds, no calls needed. Lovely place.', 9);
    _review(lamsa.id, 'منى ع.', 4, 'المكان نضيف والمواعيد مظبوطة.', 20);

    final spa = _addPlace(_Place(_nextId++, 'serenity-spa', 'سيرينيتي سبا', 'Serenity Spa', 'SPA', 'جميرا، دبي',
        'Jumeirah, Dubai', 4.7, 98, 3.4, 'Asia/Dubai', 'AED', '+971500000020', 10 * 60, 23 * 60, {}));
    final massage = _addService(spa.id, 'مساج استرخاء', 'Relaxing massage', 60, 300);
    final hammam = _addService(spa.id, 'حمام مغربي', 'Moroccan bath', 90, 400);
    _addStaff(spa.id, 'ليلى', 'معالجة', 'Therapist', {massage.id, hammam.id});
    _addStaff(spa.id, 'هالة', 'معالجة', 'Therapist', {massage.id, hammam.id}, daysOff: {DateTime.friday});
    _review(spa.id, 'Aisha K.', 5, 'The Moroccan bath was perfect.', 5);

    final smile = _addPlace(_Place(_nextId++, 'smile-clinic', 'عيادة سمايل', 'Smile Clinic', 'DENTAL',
        'مدينة نصر، القاهرة', 'Nasr City, Cairo', 4.9, 167, 2.1, 'Africa/Cairo', 'EGP', '+201000000010', 12 * 60,
        22 * 60, {DateTime.friday}));
    final checkup = _addService(smile.id, 'كشف أسنان', 'Dental check-up', 30, 300);
    final cleaning = _addService(smile.id, 'تنظيف جير', 'Scaling & cleaning', 45, 600);
    final filling = _addService(smile.id, 'حشو تجميلي', 'Cosmetic filling', 60, 900);
    final drSara = _addStaff(smile.id, 'د. سارة خالد', 'طبيبة أسنان', 'Dentist', {checkup.id, cleaning.id, filling.id});
    _addStaff(smile.id, 'د. عمر حسن', 'طبيب أسنان', 'Dentist', {checkup.id, cleaning.id, filling.id},
        daysOff: {DateTime.sunday});
    _review(smile.id, 'محمد ف.', 5, 'د. سارة محترمة جدًا والكشف كان سريع.', 2);
    _review(smile.id, 'Youssef T.', 5, 'Got the reminder and the booking was exactly on time.', 12);

    final care = _addPlace(_Place(_nextId++, 'care-clinic', 'عيادة كير', 'Care Clinic', 'CLINIC', 'المعادي، القاهرة',
        'Maadi, Cairo', 4.6, 75, 4.8, 'Africa/Cairo', 'EGP', '+201000000020', 9 * 60, 17 * 60, {DateTime.friday}));
    final consult = _addService(care.id, 'كشف باطنة', 'Internal medicine consult', 30, 400);
    final followUp = _addService(care.id, 'متابعة', 'Follow-up visit', 15, 250);
    _addStaff(care.id, 'د. أحمد منصور', 'استشاري باطنة', 'Consultant physician', {consult.id, followUp.id});

    final ahmed = _addUser(demoCustomerPhone, 'أحمد', 'CUSTOMER', null);
    _addUser(demoOwnerPhone, 'مدام نهى', 'OWNER', lamsa.id);
    final customers = [
      _addUser('+971500000101', 'مريم ع.', 'CUSTOMER', null),
      _addUser('+971500000102', 'هالة م.', 'CUSTOMER', null),
      _addUser('+971500000103', 'دينا س.', 'CUSTOMER', null),
      _addUser('+971500000104', 'لمى ك.', 'CUSTOMER', null),
      _addUser('+971500000105', 'سلمى ر.', 'CUSTOMER', null),
    ];

    // A believable "today" at Lamsa for the owner dashboard.
    final dubai = tz.getLocation(lamsa.timezone);
    final today = tz.TZDateTime.from(_nowUtc, dubai);
    DateTime at(tz.Location loc, int dayOffset, int h, int m) =>
        tz.TZDateTime(loc, today.year, today.month, today.day + dayOffset, h, m).toUtc();
    final plan = [
      (colour, noura, customers[0], 10, 0),
      (haircut, reem, customers[1], 11, 30),
      (protein, noura, customers[2], 13, 0),
      (nails, noura, customers[3], 16, 0),
      (haircut, reem, customers[4], 18, 30),
    ];
    for (final (service, staff, customer, h, m) in plan) {
      final start = at(dubai, 0, h, m);
      final end = start.add(Duration(minutes: service.durationMin));
      final status = !end.isAfter(_nowUtc)
          ? 'COMPLETED'
          : (!start.isAfter(_nowUtc) ? 'IN_PROGRESS' : 'CONFIRMED');
      _trySeed(lamsa, service, staff, customer, start, status);
    }

    // Ahmed's own bookings: one soon at the dental clinic, one in 3 days, one last week.
    final nextDental = _firstOpenTimeAfter(smile, checkup.durationMin, _nowUtc.add(const Duration(hours: 2)));
    if (nextDental != null) _trySeed(smile, checkup, drSara, ahmed, nextDental, 'CONFIRMED');
    _trySeed(lamsa, haircut, null, ahmed, at(dubai, 3, 17, 0), 'CONFIRMED');
    _trySeed(lamsa, haircut, reem, ahmed, at(dubai, -7, 17, 0), 'COMPLETED');

    _seedNakheel(ahmed);
  }

  void _trySeed(_Place p, _Service s, _Staff? st, _User c, DateTime start, String status) {
    try {
      _create(
        placeId: p.id,
        serviceId: s.id,
        staffId: st?.id,
        customerId: c.id,
        startAt: start,
        source: 'APP',
        system: true,
        status: status,
      );
    } on ServerException {
      if (st != null) _trySeed(p, s, null, c, start, status); // that person is off today
    }
  }

  DateTime? _firstOpenTimeAfter(_Place p, int durationMin, DateTime from) {
    var t = SlotCalculator.alignDown(from).add(const Duration(minutes: SlotCalculator.unitMinutes));
    final limit = from.add(const Duration(days: 7));
    while (t.isBefore(limit)) {
      if (SlotCalculator.fitsWorkingHours(t, durationMin, p.timezone, p.hours)) return t;
      t = t.add(const Duration(minutes: SlotCalculator.unitMinutes));
    }
    return null;
  }
}

// ========================================================================== rows

const _dayNames = {
  DateTime.monday: 'MONDAY',
  DateTime.tuesday: 'TUESDAY',
  DateTime.wednesday: 'WEDNESDAY',
  DateTime.thursday: 'THURSDAY',
  DateTime.friday: 'FRIDAY',
  DateTime.saturday: 'SATURDAY',
  DateTime.sunday: 'SUNDAY',
};

String _hhmmss(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}:00';

class _Place {
  _Place(this.id, this.slug, this.nameAr, this.nameEn, this.category, this.areaAr, this.areaEn, this.rating,
      this.reviewsCount, this.distanceKm, this.timezone, this.currency, this.phone, this.openMin, this.closeMin,
      this.closedDays);

  int nextInvoiceNo = 1001;

  final int id;
  final String slug, nameAr, nameEn, category, areaAr, areaEn, timezone, currency, phone;
  final double rating, distanceKm;
  final int reviewsCount, openMin, closeMin;
  final Set<int> closedDays;

  WorkingHours get hours => WorkingHours(openMinutes: openMin, closeMinutes: closeMin, closedDays: closedDays);

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'category': category,
        'areaAr': areaAr,
        'areaEn': areaEn,
        'rating': rating,
        'reviewsCount': reviewsCount,
        'distanceKm': distanceKm,
        'timezone': timezone,
        'currency': currency,
        'phone': phone,
        'openTime': _hhmmss(openMin),
        'closeTime': _hhmmss(closeMin),
        'closedDays': closedDays.map((d) => _dayNames[d]).toList(),
      };
}

class _Service {
  _Service(this.id, this.placeId, this.nameAr, this.nameEn, this.durationMin, this.price);

  final int id, placeId;
  String nameAr, nameEn;
  int durationMin;
  double price;
  bool active = true;

  Map<String, dynamic> toJson() => {
        'id': id,
        'placeId': placeId,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'durationMin': durationMin,
        'price': price,
        'active': active,
      };
}

class _Staff {
  _Staff(this.id, this.placeId, this.name, this.titleAr, this.titleEn, this.serviceIds, this.daysOff);

  final int id, placeId;
  final String name, titleAr, titleEn;
  final Set<int> serviceIds;
  final Set<int> daysOff;
  String? room;
  String presence = 'AVAILABLE';
  DateTime? presenceSince;

  void setPresence(String p, DateTime at) {
    if (presence != p) {
      presence = p;
      presenceSince = at;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'titleAr': titleAr,
        'titleEn': titleEn,
        'serviceIds': serviceIds.toList()..sort(),
        'daysOff': daysOff.map((d) => _dayNames[d]).toList(),
      };
}

class _Review {
  _Review(this.id, this.placeId, this.author, this.rating, this.text, this.createdAt);

  final int id, placeId, rating;
  final String author, text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorName': author,
        'rating': rating,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };
}

class _User {
  _User(this.id, this.phone, this.name, this.role, this.placeId);

  final int id;
  final String phone;
  final String? name;
  final String role;
  final int? placeId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'role': role,
        'placeId': placeId,
        'lang': 'ar',
      };
}

class _Booking {
  _Booking({
    required this.id,
    required this.placeId,
    required this.serviceId,
    required this.staffId,
    required this.customerId,
    required this.startAt,
    required this.durationMin,
    required this.price,
    required this.currency,
    required this.status,
    required this.source,
    required this.createdAt,
    required this.checkInCode,
    this.note,
  });

  final int id, placeId, serviceId, customerId, durationMin;
  int staffId;
  DateTime startAt;
  final double price;
  final String currency, source;
  String status;
  final String? note;
  final DateTime createdAt;
  final String checkInCode;
  int? ticketNo;
  DateTime? checkedInAt, calledAt, startedAt, finishedAt;
  int callCount = 0;
  String? room;

  DateTime get endAt => startAt.add(Duration(minutes: durationMin));
}
