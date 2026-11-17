import '../../../../core/fake/fake_backend.dart';
import '../../../../core/network/api_client.dart';

abstract class BookingDataSource {
  Future<Map<String, dynamic>> availability(String placeId, String serviceId, String date, String? staffId);

  Future<Map<String, dynamic>> create(Map<String, dynamic> body);

  Future<List<Map<String, dynamic>>> mine();

  Future<Map<String, dynamic>> cancel(String bookingId);

  Future<Map<String, dynamic>> reschedule(String bookingId, DateTime startAt, String? staffId);
}

class BookingApiDataSource implements BookingDataSource {
  BookingApiDataSource(this.api);

  final ApiClient api;

  @override
  Future<Map<String, dynamic>> availability(String placeId, String serviceId, String date, String? staffId) async =>
      Map<String, dynamic>.from(await api.get('/places/$placeId/availability', query: {
        'serviceId': serviceId,
        'date': date,
        if (staffId != null) 'staffId': staffId,
      }) as Map);

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await api.post('/bookings', body) as Map);

  @override
  Future<List<Map<String, dynamic>>> mine() async =>
      (await api.get('/bookings/me') as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  @override
  Future<Map<String, dynamic>> cancel(String bookingId) async =>
      Map<String, dynamic>.from(await api.post('/bookings/$bookingId/cancel') as Map);

  @override
  Future<Map<String, dynamic>> reschedule(String bookingId, DateTime startAt, String? staffId) async =>
      Map<String, dynamic>.from(await api.post('/bookings/$bookingId/reschedule', {
        'startAt': startAt.toUtc().toIso8601String(),
        'staffId': staffId == null ? null : (int.tryParse(staffId) ?? staffId),
      }) as Map);
}

class BookingFakeDataSource implements BookingDataSource {
  BookingFakeDataSource(this.backend);

  final FakeBackend backend;

  @override
  Future<Map<String, dynamic>> availability(String placeId, String serviceId, String date, String? staffId) =>
      backend.availability(int.parse(placeId), int.parse(serviceId), date,
          staffId: staffId == null ? null : int.parse(staffId));

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> body) => backend.createBooking(body);

  @override
  Future<List<Map<String, dynamic>>> mine() => backend.myBookings();

  @override
  Future<Map<String, dynamic>> cancel(String bookingId) => backend.cancelBooking(int.parse(bookingId));

  @override
  Future<Map<String, dynamic>> reschedule(String bookingId, DateTime startAt, String? staffId) =>
      backend.rescheduleBooking(int.parse(bookingId), startAt, staffId: staffId == null ? null : int.parse(staffId));
}
