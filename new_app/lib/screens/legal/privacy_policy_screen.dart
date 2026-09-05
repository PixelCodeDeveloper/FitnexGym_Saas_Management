import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF162234) : const Color(0xFFE2E8F0);
    final txt = isDark ? Colors.white : const Color(0xFF0F172A);
    final txt2 = isDark ? const Color(0xFF8896B3) : const Color(0xFF334155);
    const activeCyan = Color(0xFF00E5C0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Privacy Policy',
          style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: IconThemeData(color: txt),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: activeCyan.withValues(alpha: isDark ? 0.12 : 0.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: activeCyan.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: activeCyan, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Data Privacy is Protected', style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('Last updated: September 2026', style: TextStyle(color: txt2, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _policySection(
              title: '1. Information We Collect',
              content: 'When you register and use Fitnex Gym Management, we collect information required to operate your gym business smoothly. This includes your Gym Name, Owner Name, Contact Email, Phone Number, Gym Member Profiles, Subscriptions, and Payment logs.',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2,
            ),
            const SizedBox(height: 16),
            _policySection(
              title: '2. How We Use Your Information',
              content: 'We use the collected information exclusively to:\n• Manage your gym members, diet plans, and attendance.\n• Process billing, subscription renewals, and invoice generation.\n• Send automated WhatsApp & SMS payment reminders to your members.\n• Provide support and sync data securely across your devices.',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2,
            ),
            const SizedBox(height: 16),
            _policySection(
              title: '3. Data Protection & Encryption Security',
              content: 'We enforce industry-standard security protocols:\n• All access tokens and sensitive session credentials are saved using hardware-backed platform secure storage.\n• Passwords are strictly hashed using Argon2id.\n• Communication with backend APIs uses mandatory TLS 1.3 encryption.',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2,
            ),
            const SizedBox(height: 16),
            _policySection(
              title: '4. Data Sharing & Third Parties',
              content: 'We do NOT sell, rent, or trade your personal or gym member data to third-party marketers. Data is only shared with essential infrastructure providers (Google Sign-In, Razorpay Payment Gateway, and SMTP Mail Servers) strictly to perform requested app functionality.',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2,
            ),
            const SizedBox(height: 16),
            _policySection(
              title: '5. Data Ownership & Retention',
              content: 'You maintain 100% ownership of your gym data. You can export or request complete deletion of your account and associated member records at any time by contacting our privacy compliance team.',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2,
            ),
            const SizedBox(height: 16),
            _policySection(
              title: '6. Contact Privacy Team',
              content: 'If you have any questions or concerns regarding this Privacy Policy, please email us at privacy@fitnexgym.com.',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _policySection({
    required String title,
    required String content,
    required bool isDark,
    required Color cardBg,
    required Color border,
    required Color txt,
    required Color txt2,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Text(content, style: TextStyle(color: txt2, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}
