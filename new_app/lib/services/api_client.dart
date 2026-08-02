import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, [this.statusCode = 0]);
  @override
  String toString() => message;
}

/// Single HTTP boundary for the app. Auth credentials are never logged.
class ApiClient {
  static const _timeout = Duration(seconds: 20);

  static Future<dynamic> get(String path) => _request('GET', path);
  static Future<dynamic> post(String path, [Object? body]) =>
      _request('POST', path, body);
  static Future<dynamic> patch(String path, [Object? body]) =>
      _request('PATCH', path, body);
  static Future<dynamic> delete(String path) => _request('DELETE', path);

  static Future<dynamic> _request(
    String method,
    String path, [
    Object? body,
  ]) async {
    final headers = <String, String>{'Accept': 'application/json'};
    final token = await AuthService.accessToken;
    if (token != null) headers['Authorization'] = 'Bearer $token';
    if (body != null) headers['Content-Type'] = 'application/json';

    final request = http.Request(method, ApiConfig.uri(path));
    request.headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    final dynamic data = response.body.isEmpty
        ? null
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) await AuthService.clearSession();
      final message = data is Map && data['error'] is String
          ? data['error'] as String
          : 'Request failed. Please try again.';
      throw ApiException(message, response.statusCode);
    }
    return data;
  }
}
