import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF162234) : const Color(0xFFE2E8F0);
    final txt = isDark ? Colors.white : const Color(0xFF0F172A);
    final txt2 = isDark ? const Color(0xFF8896B3) : const Color(0xFF334155);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Terms & Conditions',
          style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: IconThemeData(color: txt),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.12 : 0.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gavel_rounded, color: Color(0xFF3B82F6), size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SaaS Service Agreement', style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('Effective Date: September 2026', style: TextStyle(color: txt2, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _termSection(
              title: '1. Acceptance of Terms',
              content: 'By downloading, accessing, or using Fitnex Gym Management, you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use the application.',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2,
            ),
            const SizedBox(height: 16),
            _termSection(
              title: '2. Gym Owner Account Responsibilities',
              content: 'You are responsible for maintaining the security of your account credentials. Any activity performed under your gym account is your responsibility. Please notify us immediately of any unauthorized access.',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2,
            ),
            const SizedBox(height: 16),
            _termSection(
              title: '3. Subscription, Renewal & Payments',
              content: 'Fitnex operates under a Software-as-a-Service (SaaS) model. Subscriptions are billed periodically based on your chosen plan. Access to premium dashboard features requires an active subscription status.',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2,
            ),
            const SizedBox(height: 16),
            _termSection(
              title: '4. Service Availability & Support',
              content: 'We strive for 99.9% application uptime. Scheduled maintenance will be communicated in advance. Customer support is provided via WhatsApp, Email, and Phone during standard business hours.',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2,
            ),
            const SizedBox(height: 16),
            _termSection(
              title: '5. Limitation of Liability',
              content: 'Fitnex is not liable for indirect, incidental, or consequential damages resulting from lost gym revenue, unauthorized member actions, or third-party service outages.',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _termSection({
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
