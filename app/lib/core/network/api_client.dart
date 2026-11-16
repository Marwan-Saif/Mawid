import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../error/exceptions.dart';

/// Thin JSON client for the Spring Boot API. Reads the problem+json `code` on errors,
/// so the app can react to SLOT_TAKEN, TOO_LATE_TO_CHANGE and so on.
class ApiClient {
  ApiClient({required this.baseUrl, required this.tokenProvider, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final String? Function() tokenProvider;
  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);

  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);

  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body: body);

  Future<dynamic> _send(String method, String path, {Map<String, String>? query, Object? body}) async {
    final uri = Uri.parse('$baseUrl/api/v1$path').replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Content-Type'] = 'application/json; charset=utf-8';
    final token = tokenProvider();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request).timeout(_timeout));
    } on TimeoutException catch (e) {
      throw NetworkException(e);
    } on http.ClientException catch (e) {
      throw NetworkException(e);
    }

    final text = utf8.decode(response.bodyBytes);
    final decoded = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    final code = decoded is Map<String, dynamic> ? (decoded['code'] as String? ?? 'SERVER') : 'SERVER';
    final message = decoded is Map<String, dynamic> ? decoded['detail'] as String? : null;
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (code == 'SLOT_TAKEN') throw const SlotTakenException();
    throw ServerException(code, message, response.statusCode);
  }
}
