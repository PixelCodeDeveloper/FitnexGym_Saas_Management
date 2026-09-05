import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gym.dart';
import '../models/member.dart';
import '../models/lead.dart';
import '../services/db_service.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;
  final VoidCallback? onAddMember;

  const DashboardScreen({
    super.key,
    this.onNavigateTab,
    this.onAddMember,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  int _totalMembers = 0;
  int _expiringCount = 0;
  int _hotLeadsCount = 0;
  double _monthlyRevenue = 0.0;
  List<dynamic> _recentPayments = [];

  Gym? _gym;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final gym      = await DbService.getGym();
      final members  = await DbService.getMembers();
      final leads    = await DbService.getLeads();
      final rev      = await DbService.getMonthlyRevenue();
      final payments = await DbService.getPayments();

      int expSoon = 0;
      for (final m in members) {
        if (m.status == MemberStatus.expiringSoon) expSoon++;
      }
      setState(() {
        _gym            = gym;
        _totalMembers   = members.length;
        _expiringCount  = expSoon;
        _hotLeadsCount  = leads.where((l) => l.status == LeadStatus.hot).length;
        _monthlyRevenue = rev;
        _recentPayments = payments.take(5).toList();
        _isLoading      = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBgColor  = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final txtPrimary   = isDark ? Colors.white : const Color(0xFF0F172A);
    final txtSecondary = isDark ? const Color(0xFF8896B3) : const Color(0xFF334155);
    final dividerColor = isDark ? const Color(0xFF162234) : const Color(0xFFE2E8F0);
    const activeCyan   = Color(0xFF00E5C0);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: pageBgColor,
        body: const Center(child: CircularProgressIndicator(color: activeCyan, strokeWidth: 2)),
      );
    }

    return Scaffold(
      backgroundColor: pageBgColor,
      body: RefreshIndicator(
        color: activeCyan,
        backgroundColor: isDark ? const Color(0xFF0D1626) : Colors.white,
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Greeting Header (Flat layout on page background) ──
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good Morning,',
                          style: TextStyle(color: txtSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(_gym?.ownerName?.trim().isNotEmpty == true) ? _gym!.ownerName!.trim() : (_gym?.name ?? 'Fitnex Owner')} 👋',
                          style: TextStyle(
                            color: txtPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                          style: TextStyle(color: txtSecondary.withValues(alpha: 0.8), fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: 32,
                          height: 3,
                          decoration: BoxDecoration(
                            color: activeCyan,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'STRONGER PEOPLE EVERYDAY',
                          style: TextStyle(
                            color: txtSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Quick Stats Section (Flat layout) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Stats',
                    style: TextStyle(color: txtPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () => widget.onNavigateTab?.call(1),
                    child: const Row(
                      children: [
                        Text('View All ', style: TextStyle(color: activeCyan, fontSize: 12, fontWeight: FontWeight.w600)),
                        Icon(Icons.arrow_forward_rounded, color: activeCyan, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: _statItem(Icons.groups_rounded, '$_totalMembers', 'Total Members', activeCyan, txtPrimary, txtSecondary)),
                    _vDivider(dividerColor),
                    Expanded(child: _statItem(Icons.currency_rupee_rounded, '₹${_fmt(_monthlyRevenue)}', 'Revenue', const Color(0xFF3B82F6), txtPrimary, txtSecondary)),
                    _vDivider(dividerColor),
                    Expanded(child: _statItem(Icons.timer_outlined, '$_expiringCount', 'Expiring Soon', const Color(0xFFF59E0B), txtPrimary, txtSecondary)),
                    _vDivider(dividerColor),
                    Expanded(child: _statItem(Icons.bar_chart_rounded, '$_hotLeadsCount', 'New Leads', const Color(0xFF8B5CF6), txtPrimary, txtSecondary)),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Quick Actions Section (Flat list layout) ──
              Text(
                'Quick Actions',
                style: TextStyle(color: txtPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  _actionTile(
                    icon: Icons.person_add_alt_1_rounded,
                    iconBg: activeCyan.withValues(alpha: 0.15),
                    iconColor: activeCyan,
                    title: 'Add New Member',
                    subtitle: 'Register a new member',
                    txtPrimary: txtPrimary,
                    txtSecondary: txtSecondary,
                    onTap: () {
                      if (widget.onAddMember != null) {
                        widget.onAddMember!();
                      } else {
                        widget.onNavigateTab?.call(1);
                      }
                    },
                  ),
                  Divider(height: 1, color: dividerColor),
                  _actionTile(
                    icon: Icons.groups_rounded,
                    iconBg: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    iconColor: const Color(0xFF3B82F6),
                    title: 'View Members',
                    subtitle: 'Manage all members',
                    txtPrimary: txtPrimary,
                    txtSecondary: txtSecondary,
                    onTap: () => widget.onNavigateTab?.call(1),
                  ),
                  Divider(height: 1, color: dividerColor),
                  _actionTile(
                    icon: Icons.person_add_rounded,
                    iconBg: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Leads / Inquiries',
                    subtitle: 'Track and convert leads',
                    txtPrimary: txtPrimary,
                    txtSecondary: txtSecondary,
                    onTap: () => widget.onNavigateTab?.call(2),
                  ),
                  Divider(height: 1, color: dividerColor),
                  _actionTile(
                    icon: Icons.assessment_rounded,
                    iconBg: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Reports',
                    subtitle: 'View analytics and insights',
                    txtPrimary: txtPrimary,
                    txtSecondary: txtSecondary,
                    onTap: () => widget.onNavigateTab?.call(5),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Recent Transactions Section (Flat layout) ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: TextStyle(color: txtPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () => widget.onNavigateTab?.call(5),
                    child: const Row(
                      children: [
                        Text('View All ', style: TextStyle(color: activeCyan, fontSize: 12, fontWeight: FontWeight.w600)),
                        Icon(Icons.arrow_forward_rounded, color: activeCyan, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_recentPayments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: txtSecondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.article_outlined, size: 28, color: txtSecondary),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions yet',
                          style: TextStyle(color: txtPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Payments will appear here',
                          style: TextStyle(color: txtSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...List.generate(_recentPayments.length, (i) {
                  final p = _recentPayments[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _transactionTile(
                      p.memberName ?? 'Member',
                      p.planName ?? 'Payment',
                      p.amount,
                      txtPrimary,
                      txtSecondary,
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String val, String label, Color color, Color txtPrimary, Color txtSecondary) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(
          val,
          style: TextStyle(color: txtPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: txtSecondary, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _vDivider(Color dividerColor) {
    return Container(
      height: 44,
      width: 1,
      color: dividerColor,
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color txtPrimary,
    required Color txtSecondary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: txtPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: txtSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: txtSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _transactionTile(String name, String plan, double amount, Color txtPrimary, Color txtSecondary) {
    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'M';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF00E5C0).withValues(alpha: 0.15),
            child: Text(
              initials,
              style: const TextStyle(color: Color(0xFF00E5C0), fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: txtPrimary)),
                const SizedBox(height: 2),
                Text(plan, style: TextStyle(color: txtSecondary, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5C0).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '₹${amount.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Color(0xFF00E5C0),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}
