import 'package:flutter/material.dart';
import 'middleware/auth_guard.dart';
import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/main_layout.dart';
import 'screens/paywall_screen.dart';
import 'screens/subscription_screen.dart';

// Global theme notifier — accessible from anywhere
final themeNotifier = ThemeNotifier();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeNotifier.init();
  runApp(const GymOwnerApp());
}

class GymOwnerApp extends StatelessWidget {
  const GymOwnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, child) => MaterialApp(
        title: 'Fitnex',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        home: const AuthCheckScreen(),
        routes: {
          '/login':      (_) => const LoginScreen(),
          '/otp-verify': (_) => const OtpVerificationScreen(),
          '/onboarding': (_) => const OnboardingScreen(),
          '/dashboard':  (_) => const MainLayout(),
          '/paywall':    (_) => const Scaffold(body: PaywallScreen()),
          '/subscription': (_) => const SubscriptionScreen(),
          '/auth-check': (_) => const AuthCheckScreen(),
        },
      ),
    );
  }
}


/// Splash / auth-check screen
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final route = await AuthGuard.getInitialRoute();
    if (mounted) {
      Navigator.pushReplacementNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppTheme.primaryGlow,
              ),
              child: Image.asset(
                'assets/images/logo.png',
                width: 64,
                height: 64,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 28),
            const CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 20),
            Text(
              'Fitnex',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

