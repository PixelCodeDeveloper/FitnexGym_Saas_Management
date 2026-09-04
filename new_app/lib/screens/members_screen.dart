import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/member.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';
import 'forms/add_member_screen.dart';
import 'forms/edit_member_screen.dart';
import 'forms/renew_member_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  String _selectedFilter = 'All';
  String _searchQuery   = '';
  final _filters = ['All', 'Active', 'Expiring Soon', 'Expired'];
  bool _isLoading = true;
  List<Member> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      _members = await DbService.getMembers();
    } catch (_) {
      _members = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(MemberStatus s) {
    switch (s) {
      case MemberStatus.active:       return AppTheme.success;
      case MemberStatus.expiringSoon: return AppTheme.warning;
      case MemberStatus.expired:      return AppTheme.error;
    }
  }

  String _statusLabel(MemberStatus s) {
    switch (s) {
      case MemberStatus.active:       return 'Active';
      case MemberStatus.expiringSoon: return 'Expiring';
      case MemberStatus.expired:      return 'Expired';
    }
  }

  IconData _statusIcon(MemberStatus s) {
    switch (s) {
      case MemberStatus.active:       return Icons.check_circle_rounded;
      case MemberStatus.expiringSoon: return Icons.timer_outlined;
      case MemberStatus.expired:      return Icons.cancel_rounded;
    }
  }

  Future<void> _openAddMemberScreen() async {
    final newMember = await Navigator.push<Member>(
      context,
      MaterialPageRoute(builder: (_) => const AddMemberScreen()),
    );
    if (newMember != null) setState(() => _members.insert(0, newMember));
  }

  Future<void> _openEditMemberScreen(Member member) async {
    final updated = await Navigator.push<Member>(
      context,
      MaterialPageRoute(builder: (_) => EditMemberScreen(member: member)),
    );
    if (updated != null) {
      setState(() {
        final idx = _members.indexWhere((m) => m.id == member.id);
        if (idx != -1) _members[idx] = updated;
      });
    }
  }

  Future<void> _openRenewScreen(Member member) async {
    final updated = await Navigator.push<Member>(
      context,
      MaterialPageRoute(builder: (_) => RenewMemberScreen(member: member)),
    );
    if (updated != null) {
      setState(() {
        final idx = _members.indexWhere((m) => m.id == member.id);
        if (idx != -1) _members[idx] = updated;
      });
    }
  }

  Future<void> _launchWhatsApp(Member member) async {
    final phone = member.phone.replaceAll(RegExp(r'[^\d]'), '');
    final full  = phone.length == 10 ? '91$phone' : phone;
    final msg   = Uri.encodeComponent(
      'Hi ${member.name}, your Fitnex GYM membership expires on '
      '${DateFormat('dd MMM yyyy').format(member.subscriptionEnd)}. '
      'Please renew to keep enjoying your workout sessions!',
    );
    final url = Uri.parse('https://wa.me/$full?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    }
  }

  Future<void> _sendTwilioSMS(Member member) async {
    final msg = 'Hi ${member.name}, your Fitnex GYM membership expires on '
        '${DateFormat('dd MMM yyyy').format(member.subscriptionEnd)}. '
        'Please renew to continue your workout!';
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending SMS… 📲')));
    final ok = await DbService.sendTwilioNotification(phone: member.phone, message: msg, type: 'sms');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'SMS Sent to ${member.name}! 🚀' : 'SMS Delivery Failed'),
        backgroundColor: ok ? AppTheme.success : AppTheme.error,
      ));
    }
  }

  Future<void> _sendTwilioWhatsApp(Member member) async {
    final msg = 'Hi ${member.name}, your Fitnex GYM membership expires on '
        '${DateFormat('dd MMM yyyy').format(member.subscriptionEnd)}. '
        'Please renew to keep enjoying your workout sessions!';
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending Twilio WhatsApp… 💬')));
    final ok = await DbService.sendTwilioNotification(phone: member.phone, message: msg, type: 'whatsapp');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Twilio WhatsApp Sent to ${member.name}! 🚀' : 'Twilio WhatsApp Delivery Failed'),
        backgroundColor: ok ? AppTheme.success : AppTheme.error,
      ));
    }
  }

  void _showWhatsAppOptions(Member member) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final txt    = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final txt2   = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Send WhatsApp to ${member.name}', style: TextStyle(color: txt, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.api_rounded, color: AppTheme.success, size: 22),
              ),
              title: Text('Twilio WhatsApp API', style: TextStyle(color: txt, fontWeight: FontWeight.w600)),
              subtitle: Text('Send automated WhatsApp message via Twilio server API', style: TextStyle(color: txt2, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _sendTwilioWhatsApp(member);
              },
            ),
            Divider(color: border, height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.chat_bubble_rounded, color: AppTheme.primary, size: 22),
              ),
              title: Text('Open WhatsApp App', style: TextStyle(color: txt, fontWeight: FontWeight.w600)),
              subtitle: Text('Open directly in your phone\'s WhatsApp app', style: TextStyle(color: txt2, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _launchWhatsApp(member);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendReceiptEmail(Member member) async {
    if (member.email == null || member.email!.isEmpty) {
      _promptMemberEmailAndSend(member, action: 'receipt');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF Receipt & Sending Email… 📄')));
    final ok = await DbService.sendMemberReceiptEmail(
      memberId: member.id,
      memberEmail: member.email!,
      amount: member.amountPaid,
      startDate: member.subscriptionStart,
      endDate: member.subscriptionEnd,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Receipt PDF sent to ${member.email}! 📧' : 'Failed to send receipt email'),
        backgroundColor: ok ? AppTheme.success : AppTheme.error,
      ));
    }
  }

  Future<void> _sendExpiryReminderEmail(Member member) async {
    if (member.email == null || member.email!.isEmpty) {
      _promptMemberEmailAndSend(member, action: 'expiry');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending Expiry Reminder Email… 📧')));
    final ok = await DbService.sendMemberExpiryReminderEmail(member.id, email: member.email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Expiry Reminder sent to ${member.email}! 🚀' : 'Failed to send expiry email'),
        backgroundColor: ok ? AppTheme.success : AppTheme.error,
      ));
    }
  }

  void _promptMemberEmailAndSend(Member member, {required String action}) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'receipt' ? 'Send Receipt Email' : 'Send Expiry Reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter email address for ${member.name}:'),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'member@email.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              if (action == 'receipt') {
                final ok = await DbService.sendMemberReceiptEmail(
                  memberId: member.id,
                  memberEmail: email,
                  amount: member.amountPaid,
                  startDate: member.subscriptionStart,
                  endDate: member.subscriptionEnd,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok ? 'Receipt PDF sent to $email! 📧' : 'Failed to send receipt email'),
                    backgroundColor: ok ? AppTheme.success : AppTheme.error,
                  ));
                }
              } else {
                final ok = await DbService.sendMemberExpiryReminderEmail(member.id, email: email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok ? 'Expiry Reminder sent to $email! 🚀' : 'Failed to send expiry email'),
                    backgroundColor: ok ? AppTheme.success : AppTheme.error,
                  ));
                }
              }
            },
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

  void _showEmailOptions(Member member) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final txt    = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final txt2   = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Email & PDF Options for ${member.name}', style: TextStyle(color: txt, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF0EA5E9), size: 22),
              ),
              title: Text('Send Payment Receipt PDF', style: TextStyle(color: txt, fontWeight: FontWeight.w600)),
              subtitle: Text('Email official PDF receipt & payment proof to member', style: TextStyle(color: txt2, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _sendReceiptEmail(member);
              },
            ),
            Divider(color: border, height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.mark_email_unread_rounded, color: AppTheme.warning, size: 22),
              ),
              title: Text('Send Expiry Reminder Email', style: TextStyle(color: txt, fontWeight: FontWeight.w600)),
              subtitle: Text('Send membership expiry notice email to member', style: TextStyle(color: txt2, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _sendExpiryReminderEmail(member);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Member member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Member'),
        content: Text('Remove ${member.name} permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await DbService.deleteMember(member.id);
              setState(() => _members.removeWhere((m) => m.id == member.id));
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('${member.name} removed')));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bgColor   = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final barBg     = isDark ? const Color(0xFF08101C) : Colors.white;
    final border    = isDark ? const Color(0xFF162234) : const Color(0xFFE2E8F0);
    final txt       = isDark ? Colors.white : const Color(0xFF0F172A);
    final txt2      = isDark ? const Color(0xFF8896B3) : const Color(0xFF64748B);
    final muted     = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    final inputFill = isDark ? const Color(0xFF131D2D) : const Color(0xFFF1F5F9);
    const activeCyan= Color(0xFF00E5C0);

    final filtered = _members.where((m) {
      final q = _searchQuery.toLowerCase();
      if (!m.name.toLowerCase().contains(q) && !m.phone.contains(q)) return false;
      if (_selectedFilter == 'Active')       return m.status == MemberStatus.active;
      if (_selectedFilter == 'Expiring Soon') return m.status == MemberStatus.expiringSoon;
      if (_selectedFilter == 'Expired')      return m.status == MemberStatus.expired;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // ── Search + Filter bar ──
          Container(
            color: barBg,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: TextStyle(color: txt, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone…',
                    hintStyle: TextStyle(color: muted, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: muted),
                    filled: true,
                    fillColor: inputFill,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
                      borderSide: const BorderSide(color: activeCyan, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (context, i) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final f = _filters[i];
                      final sel = _selectedFilter == f;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? activeCyan : inputFill,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? activeCyan : border,
                            ),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              color: sel ? Colors.black : txt2,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Member count header ──
          if (!_isLoading)
            Container(
              color: bgColor,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Text('${filtered.length} members', style: TextStyle(color: txt2, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),

          // ── Flat Member List ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: activeCyan, strokeWidth: 2))
                : filtered.isEmpty
                    ? _emptyState(isDark, txt, muted)
                    : RefreshIndicator(
                        color: activeCyan,
                        onRefresh: _loadMembers,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: filtered.length,
                          separatorBuilder: (context, idx) => Divider(height: 1, color: border),
                          itemBuilder: (context, index) =>
                              _memberTile(filtered[index], isDark, border, txt, txt2, muted),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddMemberScreen,
        backgroundColor: activeCyan,
        foregroundColor: Colors.black,
        elevation: 0,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _memberTile(
    Member m, bool isDark,
    Color border,
    Color txt, Color txt2, Color muted,
  ) {
    final statusColor  = _statusColor(m.status);
    final statusLabel  = _statusLabel(m.status);
    final statusIcon   = _statusIcon(m.status);
    final initials     = m.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    final daysLeft     = m.subscriptionEnd.difference(DateTime.now()).inDays;
    final expStr       = DateFormat('dd MMM yyyy').format(m.subscriptionEnd);
    const activeCyan   = Color(0xFF00E5C0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: activeCyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials.isEmpty ? 'M' : initials,
                    style: const TextStyle(color: activeCyan, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            m.name,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: txt),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 10, color: statusColor),
                              const SizedBox(width: 3),
                              Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('+91 ${m.phone}', style: TextStyle(color: txt2, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: activeCyan),
                tooltip: 'Edit Member',
                onPressed: () => _openEditMemberScreen(m),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 20, color: const Color(0xFFEF4444).withValues(alpha: 0.8)),
                tooltip: 'Delete Member',
                onPressed: () => _confirmDelete(m),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 12, color: muted),
              const SizedBox(width: 5),
              Text('Exp: $expStr', style: TextStyle(color: txt2, fontSize: 12)),
              if (daysLeft >= 0) ...[
                const SizedBox(width: 8),
                Text('• $daysLeft days left', style: TextStyle(color: _statusColor(m.status), fontSize: 11, fontWeight: FontWeight.w600)),
              ],
              const Spacer(),
              Text('₹${m.amountPaid.toStringAsFixed(0)}', style: const TextStyle(color: activeCyan, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _actionChip(Icons.sms_outlined, 'SMS', const Color(0xFFFF6B2C), () => _sendTwilioSMS(m)),
              const SizedBox(width: 6),
              _actionChip(Icons.chat_rounded, 'WhatsApp', const Color(0xFF22C55E), () => _showWhatsAppOptions(m)),
              const SizedBox(width: 6),
              _actionChip(Icons.picture_as_pdf_rounded, 'PDF / Email', const Color(0xFF0EA5E9), () => _showEmailOptions(m)),
              const SizedBox(width: 6),
              _actionChip(Icons.autorenew_rounded, 'Renew', activeCyan, () => _openRenewScreen(m)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionChip(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(bool isDark, Color txt, Color muted) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.people_outline_rounded, size: 40, color: AppTheme.primary),
        ),
        const SizedBox(height: 16),
        Text('No members found', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: txt)),
        const SizedBox(height: 6),
        Text('Try a different filter or add a new member.', style: TextStyle(color: muted, fontSize: 13)),
      ],
    ),
  );
}
