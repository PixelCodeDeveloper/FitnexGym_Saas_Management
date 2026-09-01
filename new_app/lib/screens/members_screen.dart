import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/member.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';
import 'forms/add_member_screen.dart';
import 'forms/renew_member_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final filters = ['All', 'Active', 'Expiring Soon', 'Expired'];
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
      final list = await DbService.getMembers();
      setState(() {
        _members = list;
      });
    } catch (_) {
      setState(() {
        _members = [];
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(MemberStatus status) {
    switch (status) {
      case MemberStatus.active:
        return AppTheme.success;
      case MemberStatus.expiringSoon:
        return AppTheme.warning;
      case MemberStatus.expired:
        return AppTheme.error;
    }
  }

  String _statusLabel(MemberStatus status) {
    switch (status) {
      case MemberStatus.active:
        return 'Active';
      case MemberStatus.expiringSoon:
        return 'Expiring Soon';
      case MemberStatus.expired:
        return 'Expired';
    }
  }

  Future<void> _openAddMemberScreen() async {
    final newMember = await Navigator.push<Member>(
      context,
      MaterialPageRoute(builder: (_) => const AddMemberScreen()),
    );
    if (newMember != null) {
      setState(() {
        _members.insert(0, newMember);
      });
    }
  }

  Future<void> _openRenewScreen(Member member) async {
    final updatedMember = await Navigator.push<Member>(
      context,
      MaterialPageRoute(builder: (_) => RenewMemberScreen(member: member)),
    );
    if (updatedMember != null) {
      setState(() {
        final idx = _members.indexWhere((m) => m.id == member.id);
        if (idx != -1) _members[idx] = updatedMember;
      });
    }
  }

  Future<void> _launchWhatsApp(Member member) async {
    final phone = member.phone.replaceAll(RegExp(r'[^\d]'), '');
    final fullPhone = phone.length == 10 ? '91$phone' : phone;
    final message = Uri.encodeComponent(
      'Hi ${member.name}, your Fitnex GYM membership expires on ${DateFormat('dd MMM yyyy').format(member.subscriptionEnd)}. Please renew to keep enjoying your workout sessions!',
    );
    final url = Uri.parse('https://wa.me/$fullPhone?text=$message');
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

  void _confirmDelete(Member member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Member'),
        content: Text('Are you sure you want to delete ${member.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await DbService.deleteMember(member.id);
              setState(() {
                _members.removeWhere((m) => m.id == member.id);
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${member.name} deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  Future<void> _sendTwilioSMS(Member member) async {
    final msg = 'Hi ${member.name}, your Fitnex GYM membership expires on ${DateFormat('dd MMM yyyy').format(member.subscriptionEnd)}. Please renew to continue workout!';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sending Twilio SMS... 📲')),
    );
    final success = await DbService.sendTwilioNotification(
      phone: member.phone,
      message: msg,
      type: 'sms',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Twilio SMS Sent to ${member.name}! 🚀' : 'SMS Delivery Failed'),
          backgroundColor: success ? AppTheme.success : AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _members.where((m) {
      final matchesSearch = m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.phone.contains(_searchQuery);
      if (!matchesSearch) return false;
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Active') return m.status == MemberStatus.active;
      if (_selectedFilter == 'Expiring Soon') return m.status == MemberStatus.expiringSoon;
      if (_selectedFilter == 'Expired') return m.status == MemberStatus.expired;
      return true;
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          // ── Search + Filter Bar ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone…',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.background,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final f = filters[i];
                      final selected = _selectedFilter == f;
                      return ChoiceChip(
                        label: Text(f),
                        selected: selected,
                        selectedColor: AppTheme.primary.withOpacity(0.15),
                        backgroundColor: AppTheme.surfaceAlt,
                        labelStyle: TextStyle(
                          color: selected ? AppTheme.primaryDark : AppTheme.textSecondary,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: selected ? AppTheme.primary.withOpacity(0.3) : AppTheme.divider,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onSelected: (_) => setState(() => _selectedFilter = f),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Members List ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off, size: 48, color: AppTheme.textMuted),
                            const SizedBox(height: 12),
                            Text('No members found', style: TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadMembers,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final m = filtered[index];
                            final statusColor = _statusColor(m.status);
                            final statusText = _statusLabel(m.status);
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                                          child: Text(
                                            m.name.isNotEmpty
                                                ? m.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
                                                : 'M',
                                            style: const TextStyle(
                                              color: AppTheme.primaryDark,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                m.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '+91 ${m.phone} • ₹${m.amountPaid.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            statusText,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
                                          onPressed: () => _confirmDelete(m),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.surfaceAlt,
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(16),
                                        bottomRight: Radius.circular(16),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textMuted),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Exp: ${DateFormat('dd MMM yyyy').format(m.subscriptionEnd)}',
                                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                        ),
                                        const Spacer(),
                                        _ActionChip(
                                          icon: Icons.sms_outlined,
                                          label: 'Twilio SMS',
                                          color: AppTheme.accent,
                                          onTap: () => _sendTwilioSMS(m),
                                        ),
                                        const SizedBox(width: 8),
                                        _ActionChip(
                                          icon: Icons.chat_bubble_outline,
                                          label: 'WhatsApp',
                                          color: AppTheme.success,
                                          onTap: () => _launchWhatsApp(m),
                                        ),
                                        const SizedBox(width: 8),
                                        _ActionChip(
                                          icon: Icons.refresh,
                                          label: 'Renew',
                                          color: AppTheme.primary,
                                          onTap: () => _openRenewScreen(m),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddMemberScreen,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Member'),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
