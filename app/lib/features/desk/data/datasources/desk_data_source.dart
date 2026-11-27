import '../../../../core/fake/fake_backend.dart';
import '../../../../core/network/api_client.dart';

/// Both implementations speak the API's JSON for /desk, /desk/invoices, /desk/audit and the
/// public waiting-room endpoint.
abstract class DeskDataSource {
  Future<Map<String, dynamic>> board();

  Future<Map<String, dynamic>> checkInByCode(String code);

  Future<Map<String, dynamic>> checkIn(String bookingId);

  Future<Map<String, dynamic>> walkIn(Map<String, dynamic> body);

  Future<Map<String, dynamic>> call(String bookingId);

  Future<Map<String, dynamic>> finish(String bookingId);

  Future<Map<String, dynamic>> noShow(String bookingId);

  Future<Map<String, dynamic>> presence(String staffId, String presence);

  Future<List<Map<String, dynamic>>> invoices();

  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> body);

  Future<Map<String, dynamic>> updateInvoice(String id, Map<String, dynamic> body);

  Future<Map<String, dynamic>> payInvoice(String id, String method);

  Future<Map<String, dynamic>> voidInvoice(String id, String reason);

  Future<List<Map<String, dynamic>>> audit({String? entityType, String? entityId});

  Future<Map<String, dynamic>> display(String slug);

  bool get canSimulateOffline;

  void simulateOffline(bool offline);
}

Map<String, dynamic> _map(Object? v) => Map<String, dynamic>.from(v! as Map);

List<Map<String, dynamic>> _maps(Object? v) => (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

class DeskApiDataSource implements DeskDataSource {
  DeskApiDataSource(this.api);

  final ApiClient api;

  @override
  Future<Map<String, dynamic>> board() async => _map(await api.get('/desk/board'));

  @override
  Future<Map<String, dynamic>> checkInByCode(String code) async => _map(await api.post('/desk/check-in', {'code': code}));

  @override
  Future<Map<String, dynamic>> checkIn(String bookingId) async => _map(await api.post('/desk/bookings/$bookingId/check-in'));

  @override
  Future<Map<String, dynamic>> walkIn(Map<String, dynamic> body) async => _map(await api.post('/desk/walk-ins', body));

  @override
  Future<Map<String, dynamic>> call(String bookingId) async => _map(await api.post('/desk/bookings/$bookingId/call'));

  @override
  Future<Map<String, dynamic>> finish(String bookingId) async => _map(await api.post('/desk/bookings/$bookingId/finish'));

  @override
  Future<Map<String, dynamic>> noShow(String bookingId) async => _map(await api.post('/desk/bookings/$bookingId/no-show'));

  @override
  Future<Map<String, dynamic>> presence(String staffId, String presence) async =>
      _map(await api.patch('/desk/staff/$staffId/presence', {'presence': presence}));

  @override
  Future<List<Map<String, dynamic>>> invoices() async => _maps(await api.get('/desk/invoices'));

  @override
  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> body) async => _map(await api.post('/desk/invoices', body));

  @override
  Future<Map<String, dynamic>> updateInvoice(String id, Map<String, dynamic> body) async =>
      _map(await api.put('/desk/invoices/$id', body));

  @override
  Future<Map<String, dynamic>> payInvoice(String id, String method) async =>
      _map(await api.post('/desk/invoices/$id/pay', {'method': method}));

  @override
  Future<Map<String, dynamic>> voidInvoice(String id, String reason) async =>
      _map(await api.post('/desk/invoices/$id/void', {'reason': reason}));

  @override
  Future<List<Map<String, dynamic>>> audit({String? entityType, String? entityId}) async => _maps(await api.get(
        '/desk/audit',
        query: {
          'limit': '150',
          if (entityType != null) 'entityType': entityType,
          if (entityId != null) 'entityId': entityId,
        },
      ));

  @override
  Future<Map<String, dynamic>> display(String slug) async =>
      _map(await api.get('/public/places/${Uri.encodeComponent(slug)}/display'));

  @override
  bool get canSimulateOffline => false;

  @override
  void simulateOffline(bool offline) {}
}

class DeskFakeDataSource implements DeskDataSource {
  DeskFakeDataSource(this.backend);

  final FakeBackend backend;

  @override
  Future<Map<String, dynamic>> board() => backend.deskBoard();

  @override
  Future<Map<String, dynamic>> checkInByCode(String code) => backend.deskCheckInByCode(code);

  @override
  Future<Map<String, dynamic>> checkIn(String bookingId) => backend.deskCheckIn(int.parse(bookingId));

  @override
  Future<Map<String, dynamic>> walkIn(Map<String, dynamic> body) => backend.deskWalkIn(body);

  @override
  Future<Map<String, dynamic>> call(String bookingId) => backend.deskCall(int.parse(bookingId));

  @override
  Future<Map<String, dynamic>> finish(String bookingId) => backend.deskFinish(int.parse(bookingId));

  @override
  Future<Map<String, dynamic>> noShow(String bookingId) => backend.deskNoShow(int.parse(bookingId));

  @override
  Future<Map<String, dynamic>> presence(String staffId, String presence) =>
      backend.deskPresence(int.parse(staffId), presence);

  @override
  Future<List<Map<String, dynamic>>> invoices() => backend.deskInvoices();

  @override
  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> body) => backend.deskCreateInvoice(body);

  @override
  Future<Map<String, dynamic>> updateInvoice(String id, Map<String, dynamic> body) =>
      backend.deskUpdateInvoice(int.parse(id), body);

  @override
  Future<Map<String, dynamic>> payInvoice(String id, String method) => backend.deskPayInvoice(int.parse(id), method);

  @override
  Future<Map<String, dynamic>> voidInvoice(String id, String reason) => backend.deskVoidInvoice(int.parse(id), reason);

  @override
  Future<List<Map<String, dynamic>>> audit({String? entityType, String? entityId}) =>
      backend.deskAudit(entityType: entityType, entityId: entityId == null ? null : int.tryParse(entityId));

  @override
  Future<Map<String, dynamic>> display(String slug) => backend.display(slug);

  @override
  bool get canSimulateOffline => true;

  @override
  void simulateOffline(bool offline) => backend.offline = offline;
}
