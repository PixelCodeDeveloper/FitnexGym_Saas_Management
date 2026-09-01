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
    final bgColor   = isDark ? AppTheme.darkBg          : AppTheme.lightBg;
    final barBg     = isDark ? AppTheme.darkSurface      : AppTheme.lightSurface;
    final cardBg    = isDark ? AppTheme.darkCard         : AppTheme.lightSurface;
    final border    = isDark ? AppTheme.darkBorder       : AppTheme.lightBorder;
    final footerBg  = isDark ? AppTheme.darkSurfaceAlt   : AppTheme.lightSurfaceAlt;
    final txt       = isDark ? AppTheme.darkTextPrimary  : AppTheme.lightTextPrimary;
    final txt2      = isDark ? AppTheme.darkTextSecondary: AppTheme.lightTextSecondary;
    final muted     = isDark ? AppTheme.darkTextMuted    : AppTheme.lightTextMuted;
    final inputFill = isDark ? AppTheme.darkSurfaceAlt   : AppTheme.lightSurfaceAlt;

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
                      borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final f = _filters[i];
                      final sel = _selectedFilter == f;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: sel ? AppTheme.primaryGradient : null,
                            color: sel ? null : footerBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? Colors.transparent : border,
                            ),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              color: sel ? Colors.white : txt2,
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
                  Text('${filtered.length} members', style: TextStyle(color: txt2, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),

          // ── List ──
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2))
                : filtered.isEmpty
                    ? _emptyState(isDark, txt, muted)
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: _loadMembers,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _memberCard(filtered[index], isDark, cardBg, border, footerBg, txt, txt2, muted),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddMemberScreen,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _memberCard(
    Member m, bool isDark,
    Color cardBg, Color border, Color footerBg,
    Color txt, Color txt2, Color muted,
  ) {
    final statusColor  = _statusColor(m.status);
    final statusLabel  = _statusLabel(m.status);
    final statusIcon   = _statusIcon(m.status);
    final initials     = m.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    final daysLeft     = m.subscriptionEnd.difference(DateTime.now()).inDays;
    final expStr       = DateFormat('dd MMM yyyy').format(m.subscriptionEnd);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))] : null,
      ),
      child: Column(
        children: [
          // Top row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      initials.isEmpty ? 'M' : initials,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: txt)),
                      const SizedBox(height: 3),
                      Text('+91 ${m.phone}', style: TextStyle(color: txt2, fontSize: 12)),
                    ],
                  ),
                ),
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                // Edit
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 20, color: AppTheme.primary),
                  tooltip: 'Edit Member',
                  onPressed: () => _openEditMemberScreen(m),
                ),
                // Delete
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.error.withValues(alpha: 0.7)),
                  tooltip: 'Delete Member',
                  onPressed: () => _confirmDelete(m),
                ),
              ],
            ),
          ),

          // Expiry + amount row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 13, color: muted),
                const SizedBox(width: 5),
                Text('Exp: $expStr', style: TextStyle(color: txt2, fontSize: 12)),
                const SizedBox(width: 12),
                if (daysLeft >= 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(m.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$daysLeft days left',
                      style: TextStyle(color: _statusColor(m.status), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const Spacer(),
                Text('₹${m.amountPaid.toStringAsFixed(0)}', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),

          // Action strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: footerBg,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionBtn(Icons.sms_outlined,          'SMS',      AppTheme.accent,   () => _sendTwilioSMS(m)),
                _vDivider(isDark),
                _actionBtn(Icons.chat_rounded,           'WhatsApp', AppTheme.success,  () => _showWhatsAppOptions(m)),
                _vDivider(isDark),
                _actionBtn(Icons.autorenew_rounded,      'Renew',    AppTheme.primary,  () => _openRenewScreen(m)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vDivider(bool isDark) => Container(
    width: 1,
    height: 28,
    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
  );

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
