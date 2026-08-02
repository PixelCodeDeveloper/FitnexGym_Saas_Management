/// ── OWASP M4: Input Validation & Sanitization ──
/// Centralized input validator to prevent injection attacks.
/// Every user-facing input MUST pass through these methods before
/// being sent to the database or rendered in the UI.
class InputValidator {
  // ── Max lengths ──
  static const int maxNameLength = 100;
  static const int maxPhoneLength = 15;
  static const int maxTextLength = 500;
  static const int maxAmountDigits = 10;

  // ── Dangerous patterns ──
  static final RegExp _htmlScriptTag = RegExp(r'<[^>]*>', caseSensitive: false);
  static final RegExp _sqlInjection = RegExp(
    r'''(--|;|'|"|(\bSELECT\b)|(\bINSERT\b)|(\bUPDATE\b)|(\bDELETE\b)|(\bDROP\b)|(\bALTER\b)|(\bCREATE\b)|(\bEXEC\b)|(\bUNION\b))''',
    caseSensitive: false,
  );
  static final RegExp _xssPayload = RegExp(
    r'(javascript:|eval\(|expression\()',
    caseSensitive: false,
  );

  // ── Allowed patterns ──
  static final RegExp _validName = RegExp(r'^[a-zA-Z\s.\-]+$');
  static final RegExp _validPhone = RegExp(r'^\+?[0-9\s\-]{7,15}$');
  static final RegExp _validAmount = RegExp(r'^[0-9]+\.?[0-9]{0,2}$');
  static final RegExp _validEmail = RegExp(r'^[\w.\-]+@[\w.\-]+\.\w{2,}$');

  /// Strip all dangerous characters and enforce max length.
  static String _stripDangerous(String input, int maxLen) {
    String cleaned = input.trim();
    cleaned = cleaned.replaceAll(_htmlScriptTag, '');
    cleaned = cleaned.replaceAll(_sqlInjection, '');
    cleaned = cleaned.replaceAll(_xssPayload, '');
    if (cleaned.length > maxLen) {
      cleaned = cleaned.substring(0, maxLen);
    }
    return cleaned;
  }

  /// Sanitize a person's name.
  static String sanitizeName(String input) {
    return _stripDangerous(input, maxNameLength);
  }

  /// Validate a name strictly (only letters, spaces, dots, hyphens).
  static String? validateName(String? input) {
    if (input == null || input.trim().isEmpty) return 'Name is required';
    final cleaned = sanitizeName(input);
    if (cleaned.length < 2) return 'Name too short';
    if (!_validName.hasMatch(cleaned)) {
      return 'Only letters, spaces, dots, hyphens allowed';
    }
    return null;
  }

  /// Sanitize a phone number.
  static String sanitizePhone(String input) {
    return input.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Validate a phone number (strictly 10 digits).
  static String? validatePhone(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Mobile number is required';
    }
    final digits = sanitizePhone(input);
    if (digits.length != 10) {
      return 'Mobile number must be exactly 10 digits';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  /// Sanitize a monetary amount string.
  static String sanitizeAmount(String input) {
    return _stripDangerous(
      input,
      maxAmountDigits,
    ).replaceAll(RegExp(r'[^\d.]'), '');
  }

  /// Validate a monetary amount.
  static String? validateAmount(String? input) {
    if (input == null || input.trim().isEmpty) return 'Amount is required';
    final cleaned = sanitizeAmount(input);
    if (!_validAmount.hasMatch(cleaned)) return 'Invalid amount';
    final value = double.tryParse(cleaned);
    if (value == null || value <= 0) return 'Amount must be greater than 0';
    return null;
  }

  /// Sanitize free-text (notes, descriptions).
  static String sanitizeText(String input) {
    return _stripDangerous(input, maxTextLength);
  }

  /// Validate email address.
  static String? validateEmail(String? input) {
    if (input == null || input.trim().isEmpty) return 'Email is required';
    final cleaned = _stripDangerous(input, 254);
    if (!_validEmail.hasMatch(cleaned)) return 'Invalid email format';
    return null;
  }

  /// Check if a string contains any injection payload.
  static bool containsInjection(String input) {
    return _htmlScriptTag.hasMatch(input) ||
        _sqlInjection.hasMatch(input) ||
        _xssPayload.hasMatch(input);
  }
}
