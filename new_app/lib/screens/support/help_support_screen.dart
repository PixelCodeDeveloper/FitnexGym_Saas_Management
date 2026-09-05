import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final String _supportPhone = '9876543210';
  final String _supportEmail = 'support@fitnexgym.com';

  Future<void> _launchWhatsApp() async {
    final text = Uri.encodeComponent('Hello Fitnex Support Team, I need help with my gym account.');
    final url = Uri.parse('https://wa.me/91$_supportPhone?text=$text');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp.')),
      );
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: 'subject=Fitnex App Support Request',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email client.')),
      );
    }
  }

  Future<void> _launchPhoneCall() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: _supportPhone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open phone dialer.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF162234) : const Color(0xFFE2E8F0);
    final txt = isDark ? Colors.white : const Color(0xFF0F172A);
    final txt2 = isDark ? const Color(0xFF8896B3) : const Color(0xFF334155);
    final muted = isDark ? const Color(0xFF64748B) : const Color(0xFF475569);
    const activeCyan = Color(0xFF00E5C0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Help & Support',
          style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: IconThemeData(color: txt),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Banner Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.primaryGlow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.headset_mic_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'How can we help you?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Our dedicated support team is here 24/7 to assist with your gym operations.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text(
              'GET IN TOUCH',
              style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),

            // ── Support Contact Options ──
            _contactCard(
              icon: Icons.chat_rounded,
              iconColor: const Color(0xFF22C55E),
              title: 'WhatsApp Support',
              subtitle: 'Chat directly with support (+91 9876543210)',
              actionText: 'Chat Now',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2,
              onTap: _launchWhatsApp,
            ),
            const SizedBox(height: 12),
            _contactCard(
              icon: Icons.email_rounded,
              iconColor: const Color(0xFF3B82F6),
              title: 'Email Support',
              subtitle: 'Send us an email at support@fitnexgym.com',
              actionText: 'Send Email',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2,
              onTap: _launchEmail,
            ),
            const SizedBox(height: 12),
            _contactCard(
              icon: Icons.phone_in_talk_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: 'Helpline Call',
              subtitle: 'Mon - Sat (9:00 AM to 8:00 PM IST)',
              actionText: 'Call Support',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2,
              onTap: _launchPhoneCall,
            ),

            const SizedBox(height: 32),
            Text(
              'FREQUENTLY ASKED QUESTIONS',
              style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),

            // ── FAQ Accordion Items ──
            _faqTile(
              question: 'How do I add or renew gym members?',
              answer: 'Go to the Members screen from the bottom navigation bar. Click "+ Add Member" to register a new member. To renew an existing member, open their profile and click "Renew Subscription".',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2, activeCyan: activeCyan,
            ),
            const SizedBox(height: 10),
            _faqTile(
              question: 'How do I send WhatsApp receipts to members?',
              answer: 'Open any Member Detail screen, tap on the "Share Receipt" or "WhatsApp" button. A pre-formatted receipt message with plan details and dates will open directly in WhatsApp.',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2, activeCyan: activeCyan,
            ),
            const SizedBox(height: 10),
            _faqTile(
              question: 'How do I create and edit custom diet plans?',
              answer: 'Navigate to the Diet tab. Click "New Diet Plan" to build a 7-meal slot nutrition schedule. To edit an existing template, tap the "Edit" button on any diet card.',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2, activeCyan: activeCyan,
            ),
            const SizedBox(height: 10),
            _faqTile(
              question: 'Is my gym data secure and backed up?',
              answer: 'Yes! All your data is encrypted locally with secure storage and synced with our enterprise cloud servers. Automatic daily backups ensure your data is always safe.',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2, activeCyan: activeCyan,
            ),
            const SizedBox(height: 10),
            _faqTile(
              question: 'What happens when my gym SaaS subscription ends?',
              answer: 'You can upgrade or renew your gym subscription anytime from Settings -> Subscription Plan. Your data will remain completely safe.',
              isDark: isDark, cardBg: cardBg, border: border, txt: txt, txt2: txt2, activeCyan: activeCyan,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _contactCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String actionText,
    required bool isDark,
    required Color cardBg,
    required Color border,
    required Color txt,
    required Color txt2,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: txt2, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: iconColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(actionText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _faqTile({
    required String question,
    required String answer,
    required bool isDark,
    required Color cardBg,
    required Color border,
    required Color txt,
    required Color txt2,
    required Color activeCyan,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: activeCyan,
          collapsedIconColor: txt2,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            question,
            style: TextStyle(color: txt, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                style: TextStyle(color: txt2, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
