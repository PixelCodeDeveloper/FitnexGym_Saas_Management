import 'package:flutter/foundation.dart';

/// ── OWASP M6: Inadequate Privacy Controls ──
/// Secure logger that strips PII in release mode.
/// NEVER log sensitive data (tokens, passwords, PII) in production.
class SecureLogger {
  static void log(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '[LOG]';
      debugPrint('$prefix $message');
    }
  }

  static void warn(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '⚠️ [$tag]' : '⚠️ [WARN]';
      debugPrint('$prefix $message');
    }
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stack,
    String? tag,
  }) {
    if (kDebugMode) {
      final prefix = tag != null ? '❌ [$tag]' : '❌ [ERROR]';
      debugPrint('$prefix $message');
      if (error != null) debugPrint('   Error: $error');
      if (stack != null) debugPrint('   Stack: $stack');
    }
    // In production: send to crash reporting (e.g., Sentry) without PII
  }

  /// Masks PII for safe logging: "Rahul Verma" → "Ra***ma"
  static String maskPII(String value) {
    if (value.length <= 4) return '****';
    return '${value.substring(0, 2)}***${value.substring(value.length - 2)}';
  }

  /// Masks phone: "+91 9876543210" → "+91 ****3210"
  static String maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return '****';
    return '****${digits.substring(digits.length - 4)}';
  }
}
