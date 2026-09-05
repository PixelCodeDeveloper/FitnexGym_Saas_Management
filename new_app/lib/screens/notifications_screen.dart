import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/member.dart';
import '../models/lead.dart';
import '../models/payment.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  int _selectedFilter = 0; // 0: All, 1: Expiring Members, 2: Hot Leads, 3: Activity Logs
  List<Member> _expiringMembers = [];
  List<Lead> _hotLeads = [];
  List<Payment> _recentPayments = [];

  @override
  void initState() {
    super.initState();
    _loadNotificationData();
    DbService.membersRefreshNotifier.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    DbService.membersRefreshNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadNotificationData();
  }

  Future<void> _loadNotificationData() async {
    setState(() => _isLoading = true);
    try {
      final members  = await DbService.getMembers();
      final leads    = await DbService.getLeads();
      final payments = await DbService.getPayments();

      final expList = members.where((m) => m.status == MemberStatus.expiringSoon || m.isExpiringSoon || m.isExpired).toList();
      final hotList = leads.where((l) => l.status == LeadStatus.hot || l.status == LeadStatus.warm).toList();

      setState(() {
        _expiringMembers = expList;
        _hotLeads        = hotList;
        _recentPayments  = payments.take(8).toList();
        _isLoading       = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
    }
  }

  Future<void> _makeCall(Lead lead) async {
    final url = Uri.parse('tel:${lead.phone}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final pageBgColor  = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final cardBg       = isDark ? const Color(0xFF0F172A) : Colors.white;
    final txtPrimary   = isDark ? Colors.white : const Color(0xFF0F172A);
    final txtSecondary = isDark ? const Color(0xFF8896B3) : const Color(0xFF334155);
    final dividerColor = isDark ? const Color(0xFF162234) : const Color(0xFFE2E8F0);

    const activeCyan   = Color(0xFF00E5C0);
    final cyanFg       = AppTheme.darkColor(activeCyan, isDark);
    final amberFg      = AppTheme.darkColor(const Color(0xFFF59E0B), isDark);
    final blueFg       = AppTheme.darkColor(const Color(0xFF3B82F6), isDark);
    final greenFg      = AppTheme.darkColor(const Color(0xFF22C55E), isDark);

    final totalAlerts = _expiringMembers.length + _hotLeads.length;

    return Scaffold(
      backgroundColor: pageBgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF08101C) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: txtPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications & Alerts',
          style: TextStyle(
            color: txtPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: cyanFg.withValues(alpha: isDark ? 0.15 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$totalAlerts Actionable',
              style: TextStyle(
                color: cyanFg,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: cyanFg, strokeWidth: 2))
          : RefreshIndicator(
              color: cyanFg,
              backgroundColor: isDark ? const Color(0xFF0D1626) : Colors.white,
              onRefresh: _loadNotificationData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Filter Chips ──
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip(0, 'All Notifications', totalAlerts, cyanFg, isDark, txtPrimary, txtSecondary),
                          const SizedBox(width: 8),
                          _filterChip(1, 'Expiring Members', _expiringMembers.length, amberFg, isDark, txtPrimary, txtSecondary),
                          const SizedBox(width: 8),
                          _filterChip(2, 'Hot Leads', _hotLeads.length, blueFg, isDark, txtPrimary, txtSecondary),
                          const SizedBox(width: 8),
                          _filterChip(3, 'Recent Payments', _recentPayments.length, greenFg, isDark, txtPrimary, txtSecondary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Expiring Members Section ──
                    if ((_selectedFilter == 0 || _selectedFilter == 1) && _expiringMembers.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.timer_rounded, color: amberFg, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Expiring Member Subscriptions',
                            style: TextStyle(color: txtPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: amberFg.withValues(alpha: isDark ? 0.15 : 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_expiringMembers.length}',
                              style: TextStyle(color: amberFg, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._expiringMembers.map((m) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: dividerColor),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: amberFg.withValues(alpha: isDark ? 0.15 : 0.12),
                                child: Text(
                                  m.avatarInitials,
                                  style: TextStyle(color: amberFg, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.name,
                                      style: TextStyle(color: txtPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Expires: ${DateFormat('dd MMM yyyy').format(m.subscriptionEnd)} (${m.daysRemaining} days left)',
                                      style: TextStyle(color: txtSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => _launchWhatsApp(m),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: greenFg.withValues(alpha: isDark ? 0.15 : 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.chat_bubble_outline_rounded, size: 14, color: greenFg),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Remind',
                                        style: TextStyle(color: greenFg, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // ── Hot Leads Follow-up Section ──
                    if ((_selectedFilter == 0 || _selectedFilter == 2) && _hotLeads.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.local_fire_department_rounded, color: blueFg, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Hot Leads Follow-up',
                            style: TextStyle(color: txtPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: blueFg.withValues(alpha: isDark ? 0.15 : 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_hotLeads.length}',
                              style: TextStyle(color: blueFg, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._hotLeads.map((l) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: dividerColor),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: blueFg.withValues(alpha: isDark ? 0.15 : 0.12),
                                child: Text(
                                  l.name.isNotEmpty ? l.name[0].toUpperCase() : 'L',
                                  style: TextStyle(color: blueFg, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.name,
                                      style: TextStyle(color: txtPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Phone: ${l.phone}',
                                      style: TextStyle(color: txtSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => _makeCall(l),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: blueFg.withValues(alpha: isDark ? 0.15 : 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.call_rounded, size: 14, color: blueFg),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Call',
                                        style: TextStyle(color: blueFg, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // ── Recent Activity Logs ──
                    if ((_selectedFilter == 0 || _selectedFilter == 3) && _recentPayments.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.receipt_long_rounded, color: greenFg, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Recent Payments & Logs',
                            style: TextStyle(color: txtPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._recentPayments.map((p) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: dividerColor),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: greenFg.withValues(alpha: isDark ? 0.15 : 0.12),
                                child: Icon(Icons.check_circle_rounded, color: greenFg, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.memberName ?? 'Member Payment',
                                      style: TextStyle(color: txtPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      p.planName ?? 'Payment Collected',
                                      style: TextStyle(color: txtSecondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${p.amount.toStringAsFixed(0)}',
                                style: TextStyle(color: greenFg, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    // Empty State if no notifications under selected filter
                    if (totalAlerts == 0 && _recentPayments.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                        margin: const EdgeInsets.only(top: 20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: dividerColor),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 56, color: cyanFg),
                              const SizedBox(height: 16),
                              Text(
                                'All Caught Up! 🎉',
                                style: TextStyle(color: txtPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'There are no pending member renewals or urgent leads requiring attention.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: txtSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _filterChip(int index, String label, int count, Color color, bool isDark, Color txtPrimary, Color txtSecondary) {
    final isSelected = _selectedFilter == index;
    final activeColor = isSelected ? color : txtSecondary;

    return InkWell(
      onTap: () => setState(() => _selectedFilter = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: isDark ? 0.2 : 0.15) : (isDark ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : (isDark ? const Color(0xFF162234) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : txtSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: activeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
