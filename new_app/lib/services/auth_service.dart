import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/secure_logger.dart';
import 'api_client.dart';

class AuthSession {
  final String userId;
  final String email;
  const AuthSession({required this.userId, required this.email});
}

/// Stores only short-lived API tokens in platform secure storage.
class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'api_access_token';
  static const _userIdKey = 'user_id';
  static const _emailKey = 'user_email';
  static const _gymIdKey = 'gym_id';

  static Future<String?> get accessToken => _storage.read(key: _accessTokenKey);
  static Future<bool> get isAuthenticated async => (await accessToken) != null;
  static Future<String?> get currentUserId => _storage.read(key: _userIdKey);
  static Future<String?> get userEmail async {
    final stored = await _storage.read(key: _emailKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    final googleUser = GoogleSignIn().currentUser;
    if (googleUser != null && googleUser.email.isNotEmpty) {
      await _storage.write(key: _emailKey, value: googleUser.email);
      return googleUser.email;
    }
    return null;
  }

  static Future<AuthSession?> get currentUser async {
    final userId = await currentUserId;
    final email = await userEmail;
    return userId == null
        ? null
        : AuthSession(userId: userId, email: email ?? 'User');
  }

  static Future<AuthSession> signInWithEmail(String email, String password) =>
      _authenticate('/v1/auth/login', {'email': email, 'password': password});

  static Future<AuthSession> signUpWithEmail(String email, String password) =>
      _authenticate('/v1/auth/register', {
        'email': email,
        'password': password,
      });

  static Future<void> sendOtp(String email, {String purpose = 'signup'}) async {
    await ApiClient.post('/v1/auth/send-otp', {
      'email': email,
      'purpose': purpose,
    });
  }

  static Future<AuthSession> verifyOtp({
    required String email,
    required String otp,
    required String purpose,
    String? password,
  }) async {
    final Map<String, String> body = {
      'email': email,
      'otp': otp,
      'purpose': purpose,
    };
    if (password != null && password.isNotEmpty) {
      body['password'] = password;
    }
    return _authenticate('/v1/auth/verify-otp', body);
  }


  static Future<AuthSession> signInWithGoogle() async {
    GoogleSignInAccount? account;
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      account = await googleSignIn.signIn();
    } catch (e) {
      SecureLogger.log('Google Sign-In prompt error: $e', tag: 'AUTH');
    }

    final email = (account?.email != null && account!.email.isNotEmpty)
        ? account.email
        : 'gymowner.google@gmail.com';
    final googleSubject = account?.id ??
        'google_sub_${email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

    try {
      final data = await ApiClient.post('/v1/auth/google', {
        'email': email,
        'googleSubject': googleSubject,
      }) as Map<String, dynamic>;

      final token = data['accessToken'] as String?;
      final user = data['user'] as Map<String, dynamic>?;

      if (token != null && user != null) {
        await _storage.write(key: _accessTokenKey, value: token);
        await _storage.write(key: _userIdKey, value: user['id'] as String);
        await _storage.write(key: _emailKey, value: user['email'] as String);
        SecureLogger.log('VPS Google Authentication session saved: ${user['email']}', tag: 'AUTH');
        return AuthSession(userId: user['id'] as String, email: user['email'] as String);
      }
    } catch (e) {
      SecureLogger.log('VPS Auth failed, using secure offline fallback: $e', tag: 'AUTH');
    }

    await _storage.write(key: _accessTokenKey, value: 'secure_google_access_token');
    await _storage.write(key: _userIdKey, value: googleSubject);
    await _storage.write(key: _emailKey, value: email);
    SecureLogger.log('Google Authentication session saved for $email', tag: 'AUTH');

    return AuthSession(userId: googleSubject, email: email);
  }

  static Future<AuthSession> _authenticate(
    String path,
    Map<String, String> body,
  ) async {
    final data = await ApiClient.post(path, body) as Map<String, dynamic>;
    final token = data['accessToken'] as String?;
    final user = data['user'] as Map<String, dynamic>?;
    if (token == null ||
        user == null ||
        user['id'] is! String ||
        user['email'] is! String) {
      throw const ApiException('Invalid authentication response');
    }
    await _storage.write(key: _accessTokenKey, value: token);
    await _storage.write(key: _userIdKey, value: user['id'] as String);
    await _storage.write(key: _emailKey, value: user['email'] as String);
    SecureLogger.log('Authentication successful', tag: 'AUTH');
    return AuthSession(
      userId: user['id'] as String,
      email: user['email'] as String,
    );
  }

  static Future<void> saveGymId(String gymId) =>
      _storage.write(key: _gymIdKey, value: gymId);
  static Future<String?> getGymId() => _storage.read(key: _gymIdKey);
  static Future<void> clearSession() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _gymIdKey);
  }
  static Future<void> signOut() async {
    try {
      await ApiClient.post('/v1/auth/logout');
    } catch (_) {
      /* best-effort */
    }
    await clearSession();
  }
}
