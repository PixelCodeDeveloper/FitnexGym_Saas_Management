import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../utils/secure_logger.dart';

/// ── OWASP M3: Auth Guard Middleware ──
/// Checks: (1) Is user logged in? (2) Is gym billing active?
/// Routes to Login or Paywall accordingly.
class AuthGuard {
  /// Determines the correct initial route widget.
  static Future<String> getInitialRoute() async {
    try {
      if (!await AuthService.isAuthenticated) {
        SecureLogger.log('Not authenticated → Login', tag: 'GUARD');
        return '/login';
      }

      final userId = await AuthService.currentUserId;
      if (userId == null) return '/login';

      final gym = await DbService.getGym(userId);

      if (gym != null) {
        await AuthService.saveGymId(gym.id);
        final billingActive = await DbService.isGymBillingActive(userId);
        if (!billingActive) {
          SecureLogger.log('Billing expired → Paywall', tag: 'GUARD');
          return '/paywall';
        }
        SecureLogger.log('All checks passed → Dashboard', tag: 'GUARD');
        return '/dashboard';
      }

      // Check if user already has a saved gym ID in secure storage
      final savedGymId = await AuthService.getGymId();
      if (savedGymId != null && savedGymId.isNotEmpty) {
        SecureLogger.log('Saved gym ID exists → Dashboard', tag: 'GUARD');
        return '/dashboard';
      }

      SecureLogger.log('No gym found → Onboarding', tag: 'GUARD');
      return '/onboarding';
    } catch (e) {
      SecureLogger.log('Guard exception ($e) → Fallback', tag: 'GUARD');
      if (await AuthService.isAuthenticated) {
        return '/dashboard';
      }
      return '/login';
    }
  }
}
