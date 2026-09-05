import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';
import '../screens/paywall_screen.dart';

class SubscriptionGuard {
  static Future<void> checkActive(
    BuildContext context, {
    required VoidCallback onActive,
    String featureName = 'perform this action',
  }) async {
    final isActive = await DbService.isGymBillingActive();
    if (!context.mounted) return;

    if (isActive) {
      onActive();
      return;
    }

    // Unsubscribed / Free Plan User: Show Paywall Modal
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
        final txt = isDark ? Colors.white : const Color(0xFF0F172A);
        final txt2 = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Color(0xFFF59E0B),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pro Subscription Required',
                style: TextStyle(
                  color: txt,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You are currently on the Free (View-Only) plan. Upgrade to Fitnex Pro to $featureName.',
                style: TextStyle(
                  color: txt2,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const Scaffold(body: PaywallScreen())),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Upgrade to Pro Now ✨',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Maybe Later',
                  style: TextStyle(color: txt2, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
