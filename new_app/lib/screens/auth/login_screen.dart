import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../utils/input_validator.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await AuthService.signInWithGoogle();
      if (mounted) Navigator.pushReplacementNamed(context, '/auth-check');
    } catch (e, stack) {
      debugPrint('Google Sign-In Exception: $e\n$stack');
      setState(
        () => _errorMessage = 'Google sign-in failed: $e',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSendOtp() async {
    if (_emailController.text.trim().isEmpty ||
        InputValidator.validateEmail(_emailController.text.trim()) != null) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final email = _emailController.text.trim();
    final purpose = _isSignUp ? 'signup' : 'login';
    final password = _passwordController.text.trim();

    try {
      await AuthService.sendOtp(email, purpose: purpose);
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/otp-verify',
          arguments: OtpVerificationArgs(
            email: email,
            purpose: purpose,
            password: password.isNotEmpty ? password : null,
          ),
        );
      }
    } catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (_isSignUp) {
        await AuthService.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await AuthService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
      if (mounted) Navigator.pushReplacementNamed(context, '/auth-check');
    } catch (e) {
      setState(
        () => _errorMessage = _isSignUp
            ? 'Sign-up failed. Try again.'
            : 'Invalid email or password.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBg : AppTheme.lightBg;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final divider = isDark ? AppTheme.darkDivider : AppTheme.lightDivider;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo Area ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.primaryGlow,
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 52,
                    height: 52,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Fitnex',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage members, track revenue, grow your gym.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 40),

                // ── Google SSO ──
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    icon: Text(
                      'G',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    label: Text('Continue with Google', style: TextStyle(color: textPrimary)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: border),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Divider(color: divider)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: divider)),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Email Form ──
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: InputValidator.validateEmail,
                        style: TextStyle(color: textPrimary),
                        decoration: _inputDecoration(
                          'Email address',
                          Icons.email_outlined,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        validator: (val) => (val == null || val.length < 12)
                            ? 'Use at least 12 characters'
                            : null,
                        style: TextStyle(color: textPrimary),
                        decoration: _inputDecoration(
                          'Password',
                          Icons.lock_outline,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // Email OTP Verification Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleSendOtp,
                    icon: const Icon(Icons.mark_email_read_rounded, size: 20),
                    label: Text(_isSignUp ? 'Sign Up with Email OTP' : 'Sign In with Email OTP'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Password Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _handleEmailAuth,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: border),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primary,
                            ),
                          )
                        : Text(
                            _isSignUp ? 'Create with Password' : 'Sign In with Password',
                            style: TextStyle(color: textPrimary),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign In'
                        : "Don't have an account? Sign Up",
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon, {required bool isDark}) {
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final surface = isDark ? AppTheme.darkSurfaceAlt : AppTheme.lightSurfaceAlt;
    final muted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: muted),
      prefixIcon: Icon(icon, color: muted),
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.error),
      ),
    );
  }
}

