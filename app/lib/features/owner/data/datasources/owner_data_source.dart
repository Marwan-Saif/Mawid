import '../../../../core/fake/fake_backend.dart';
import '../../../../core/network/api_client.dart';

abstract class OwnerDataSource {
  Future<Map<String, dynamic>> place();

  Future<List<Map<String, dynamic>>> bookings(String date);

  Future<Map<String, dynamic>> updateStatus(String bookingId, String status);

  Future<Map<String, dynamic>> manual(Map<String, dynamic> body);

  Future<Map<String, dynamic>> saveService(Map<String, dynamic> body, {String? id});

  Stream<Map<String, dynamic>> newBookings();
}

class OwnerApiDataSource implements OwnerDataSource {
  OwnerApiDataSource(this.api);

  final ApiClient api;

  @override
  Future<Map<String, dynamic>> place() async => Map<String, dynamic>.from(await api.get('/owner/place') as Map);

  @override
  Future<List<Map<String, dynamic>>> bookings(String date) async =>
      (await api.get('/owner/bookings', query: {'date': date}) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  @override
  Future<Map<String, dynamic>> updateStatus(String bookingId, String status) async =>
      Map<String, dynamic>.from(await api.patch('/owner/bookings/$bookingId/status', {'status': status}) as Map);

  @override
  Future<Map<String, dynamic>> manual(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await api.post('/owner/bookings', body) as Map);

  @override
  Future<Map<String, dynamic>> saveService(Map<String, dynamic> body, {String? id}) async =>
      Map<String, dynamic>.from(
          (id == null ? await api.post('/owner/services', body) : await api.put('/owner/services/$id', body)) as Map);

  /// The API version refreshes on pull/resume; push alerts would come from FCM.
  @override
  Stream<Map<String, dynamic>> newBookings() => const Stream.empty();
}

class OwnerFakeDataSource implements OwnerDataSource {
  OwnerFakeDataSource(this.backend);

  final FakeBackend backend;

  @override
  Future<Map<String, dynamic>> place() => backend.ownerPlace();

  @override
  Future<List<Map<String, dynamic>>> bookings(String date) => backend.ownerBookings(date);

  @override
  Future<Map<String, dynamic>> updateStatus(String bookingId, String status) =>
      backend.updateStatus(int.parse(bookingId), status);

  @override
  Future<Map<String, dynamic>> manual(Map<String, dynamic> body) => backend.manualBooking(body);

  @override
  Future<Map<String, dynamic>> saveService(Map<String, dynamic> body, {String? id}) =>
      backend.saveService(body, id: id == null ? null : int.parse(id));

  @override
  Stream<Map<String, dynamic>> newBookings() => backend.newBookings;
}
