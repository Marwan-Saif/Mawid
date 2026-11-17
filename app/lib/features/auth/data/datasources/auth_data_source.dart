import '../../../../core/fake/fake_backend.dart';
import '../../../../core/network/api_client.dart';

/// Both implementations return the API's JSON: {token, user: {...}}.
abstract class AuthDataSource {
  Future<void> requestOtp(String phone);

  Future<Map<String, dynamic>> verifyOtp(String phone, String code, String? name);

  Future<Map<String, dynamic>> demoLogin(String role);
}

class AuthApiDataSource implements AuthDataSource {
  AuthApiDataSource(this.api);

  final ApiClient api;

  @override
  Future<void> requestOtp(String phone) => api.post('/auth/otp/request', {'phone': phone});

  @override
  Future<Map<String, dynamic>> verifyOtp(String phone, String code, String? name) async =>
      await api.post('/auth/otp/verify', {'phone': phone, 'code': code, 'name': name}) as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>> demoLogin(String role) async =>
      await api.post('/auth/demo', {'role': role}) as Map<String, dynamic>;
}

class AuthFakeDataSource implements AuthDataSource {
  AuthFakeDataSource(this.backend);

  final FakeBackend backend;

  @override
  Future<void> requestOtp(String phone) => backend.requestOtp(phone);

  @override
  Future<Map<String, dynamic>> verifyOtp(String phone, String code, String? name) =>
      backend.verifyOtp(phone, code, name);

  @override
  Future<Map<String, dynamic>> demoLogin(String role) => backend.demoLogin(role);
}
