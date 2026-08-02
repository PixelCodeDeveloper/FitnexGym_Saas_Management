/// Public configuration only. Never put database credentials, JWT secrets,
/// Razorpay secrets, or any other privileged value in a mobile application.
class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://80.225.214.213:3000',
  );
  static const allowInsecureLocalApi = bool.fromEnvironment(
    'ALLOW_INSECURE_LOCAL_API',
    defaultValue: true,
  );

  static Uri uri(String path, [Map<String, dynamic>? query]) {
    if (baseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is missing. Run with --dart-define=API_BASE_URL=https://api.example.com',
      );
    }
    final base = Uri.parse(baseUrl);
    final localHost = base.host == 'localhost' || base.host == '127.0.0.1';
    if (base.scheme != 'https' && !localHost && !allowInsecureLocalApi) {
      throw StateError('The production API must use HTTPS.');
    }
    return base
        .resolve(path)
        .replace(
          queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
        );
  }
}
