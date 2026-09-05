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
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  Future<void> _handleEmailSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isSignUp) {
        // Sign Up Flow: Register user directly -> Redirect to Sign In
        await AuthService.signUpWithEmail(email, password);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully! Please sign in with your password.'),
              backgroundColor: AppTheme.primary,
              duration: Duration(seconds: 4),
            ),
          );
          setState(() {
            _isSignUp = false;
            _passwordController.clear();
            _confirmPasswordController.clear();
          });
        }
      } else {
        // Sign In Flow: Validate credentials & send OTP -> Open OTP Verification Screen
        await AuthService.loginRequestOtp(email, password);
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/otp-verify',
            arguments: OtpVerificationArgs(
              email: email,
              purpose: 'login',
              password: password,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w900,
          fontSize: 18,
          fontFamily: 'sans-serif',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF0F131C);
    const cardDark = Color(0xFF161B26);
    const borderColor = Color(0xFF222B3D);
    const textWhite = Color(0xFFF1F5F9);
    const textSub = Color(0xFF8E9BAE);
    const accentCyan = Color(0xFF00C9A7);

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Top Header Logo & Tagline ──
                Image.asset(
                  'assets/images/logo.png',
                  width: 76,
                  height: 76,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.fitness_center_rounded,
                    size: 64,
                    color: accentCyan,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Fitnex',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: textWhite,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Manage members, track revenue, grow your gym.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textSub,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Segmented Control (Sign In / Sign Up) ──
                Container(
                  height: 50,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isSignUp = false;
                            _errorMessage = null;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: !_isSignUp ? accentCyan : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: !_isSignUp ? Colors.white : textSub,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isSignUp = true;
                            _errorMessage = null;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _isSignUp ? accentCyan : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Sign Up',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: _isSignUp ? Colors.white : textSub,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Continue with Google Button ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: cardDark,
                      side: const BorderSide(color: borderColor, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildGoogleIcon(),
                        const SizedBox(width: 12),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            color: textWhite,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // ── OR Divider ──
                Row(
                  children: [
                    const Expanded(child: Divider(color: borderColor, height: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: textSub.withValues(alpha: 0.6),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: borderColor, height: 1)),
                  ],
                ),
                const SizedBox(height: 22),

                // ── Form Inputs ──
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: InputValidator.validateEmail,
                        style: const TextStyle(color: textWhite, fontSize: 14),
                        decoration: _buildInputDecoration(
                          hint: 'Email address',
                          prefixIcon: Icons.mail_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        validator: (val) => (val == null || val.length < 8)
                            ? 'Password must be at least 8 characters'
                            : null,
                        style: const TextStyle(color: textWhite, fontSize: 14),
                        decoration: _buildInputDecoration(
                          hint: 'Password',
                          prefixIcon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: textSub,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),

                      // Confirm Password Field (Sign Up Mode)
                      if (_isSignUp) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Please confirm your password';
                            if (val != _passwordController.text) return 'Passwords do not match';
                            return null;
                          },
                          style: const TextStyle(color: textWhite, fontSize: 14),
                          decoration: _buildInputDecoration(
                            hint: 'Confirm Password',
                            prefixIcon: Icons.restore_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: textSub,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Error Banner
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    margin: const EdgeInsets.only(top: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.errorBg.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppTheme.error, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // ── Primary Action Button (Sign Up / Sign In) ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleEmailSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentCyan,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              Center(
                                child: Text(
                                  _isSignUp ? 'Sign Up' : 'Sign In',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const Positioned(
                                right: 12,
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Footer Link ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                      style: const TextStyle(color: textSub, fontSize: 13.5),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _isSignUp = !_isSignUp;
                        _errorMessage = null;
                      }),
                      child: Text(
                        _isSignUp ? 'Sign In' : 'Sign Up',
                        style: const TextStyle(
                          color: accentCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    const inputFill = Color(0xFF131824);
    const borderColor = Color(0xFF222B3D);
    const textSub = Color(0xFF8E9BAE);
    const accentCyan = Color(0xFF00C9A7);

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: textSub, fontSize: 13.5),
      prefixIcon: Icon(prefixIcon, color: textSub, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: accentCyan, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
      ),
    );
  }
}
