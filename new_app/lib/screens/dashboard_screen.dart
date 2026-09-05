import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/gym.dart';
import '../models/member.dart';
import '../models/lead.dart';
import '../models/payment.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';

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
  List<Member> _expiringMembers = [];
  List<Lead> _hotLeads = [];
  List<Payment> _recentPayments = [];
  List<_PlanDistributionItem> _planDistribution = [];

  Gym? _gym;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    DbService.membersRefreshNotifier.addListener(_onMembersChanged);
  }

  @override
  void dispose() {
    DbService.membersRefreshNotifier.removeListener(_onMembersChanged);
    super.dispose();
  }

  void _onMembersChanged() {
    if (mounted) _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final gym      = await DbService.getGym();
      final members  = await DbService.getMembers();
      final leads    = await DbService.getLeads();
      final plans    = await DbService.getPlans();
      final rev      = await DbService.getMonthlyRevenue();
      final payments = await DbService.getPayments();

      final expList = members.where((m) => m.status == MemberStatus.expiringSoon || m.isExpiringSoon || m.isExpired).toList();
      final hotList = leads.where((l) => l.status == LeadStatus.hot || l.status == LeadStatus.warm).toList();

      final membersTotal = members.fold(0.0, (sum, m) => sum + m.amountPaid);
      final double finalRev = rev > membersTotal ? rev : membersTotal;

      final planNameMap = <String, String>{};
      for (var p in plans) {
        planNameMap[p.id] = p.name;
      }

      final planCounts = <String, int>{};
      for (var m in members) {
        final name = (m.planId != null && planNameMap.containsKey(m.planId))
            ? planNameMap[m.planId]!
            : 'Standard Plan';
        planCounts[name] = (planCounts[name] ?? 0) + 1;
      }

      final colors = [
        const Color(0xFF00E5C0),
        const Color(0xFF3B82F6),
        const Color(0xFF8B5CF6),
        const Color(0xFFF59E0B),
        const Color(0xFF10B981),
      ];

      final distList = <_PlanDistributionItem>[];
      int cIdx = 0;
      planCounts.forEach((name, count) {
        final pct = members.isEmpty ? 0.0 : (count / members.length);
        distList.add(_PlanDistributionItem(
          name: name,
          count: count,
          percentage: pct,
          color: colors[cIdx % colors.length],
        ));
        cIdx++;
      });

      setState(() {
        _gym             = gym;
        _totalMembers    = members.length;
        _expiringCount   = expList.length;
        _hotLeadsCount   = hotList.length;
        _expiringMembers = expList.take(4).toList();
        _hotLeads        = hotList.take(3).toList();
        _monthlyRevenue  = finalRev;
        _recentPayments  = payments.take(5).toList();
        _planDistribution= distList;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBgColor  = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final cardBg       = isDark ? const Color(0xFF0F172A) : Colors.white;
    final txtPrimary   = isDark ? Colors.white : const Color(0xFF0F172A);
    final txtSecondary = isDark ? const Color(0xFF8896B3) : const Color(0xFF334155);
    final dividerColor = isDark ? const Color(0xFF162234) : const Color(0xFFE2E8F0);
    const activeCyan   = Color(0xFF00E5C0);
    final cyanFg       = AppTheme.darkColor(activeCyan, isDark);
    final amberFg      = AppTheme.darkColor(const Color(0xFFF59E0B), isDark);
    final purpleFg     = AppTheme.darkColor(const Color(0xFF8B5CF6), isDark);
    final blueFg       = AppTheme.darkColor(const Color(0xFF3B82F6), isDark);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: pageBgColor,
        body: Center(child: CircularProgressIndicator(color: cyanFg, strokeWidth: 2)),
      );
    }

    return Scaffold(
      backgroundColor: pageBgColor,
      body: RefreshIndicator(
        color: cyanFg,
        backgroundColor: isDark ? const Color(0xFF0D1626) : Colors.white,
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Greeting Header ──
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
                            color: cyanFg,
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

              const SizedBox(height: 24),

              // ── Quick Stats Section ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Stats',
                    style: TextStyle(color: txtPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () => widget.onNavigateTab?.call(1),
                    child: Row(
                      children: [
                        Text('View All ', style: TextStyle(color: cyanFg, fontSize: 12, fontWeight: FontWeight.w600)),
                        Icon(Icons.arrow_forward_rounded, color: cyanFg, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: _statItem(Icons.groups_rounded, '$_totalMembers', 'Total Members', cyanFg, txtPrimary, txtSecondary)),
                    _vDivider(dividerColor),
                    Expanded(child: _statItem(Icons.currency_rupee_rounded, '₹${_fmt(_monthlyRevenue)}', 'Revenue', blueFg, txtPrimary, txtSecondary)),
                    _vDivider(dividerColor),
                    Expanded(child: _statItem(Icons.timer_outlined, '$_expiringCount', 'Expiring Soon', amberFg, txtPrimary, txtSecondary)),
                    _vDivider(dividerColor),
                    Expanded(child: _statItem(Icons.bar_chart_rounded, '$_hotLeadsCount', 'New Leads', purpleFg, txtPrimary, txtSecondary)),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Expiring Members Action Required ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer_rounded, color: amberFg, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Expiring Members Alert',
                        style: TextStyle(color: txtPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => widget.onNavigateTab?.call(1),
                    child: Row(
                      children: [
                        Text('Members ', style: TextStyle(color: cyanFg, fontSize: 12, fontWeight: FontWeight.w600)),
                        Icon(Icons.arrow_forward_rounded, color: cyanFg, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_expiringMembers.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: dividerColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppTheme.darkColor(AppTheme.success, isDark), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'All memberships up to date! 🎉',
                          style: TextStyle(color: txtPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: _expiringMembers.map((m) {
                    final daysLeft = m.subscriptionEnd.difference(DateTime.now()).inDays;
                    final isExp = daysLeft < 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: dividerColor),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: amberFg.withValues(alpha: isDark ? 0.15 : 0.12),
                            child: Text(
                              m.avatarInitials,
                              style: TextStyle(color: amberFg, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name, style: TextStyle(color: txtPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(
                                  isExp ? 'Expired ${daysLeft.abs()} days ago' : 'Expires in ${daysLeft == 0 ? "today" : "$daysLeft days"}',
                                  style: TextStyle(color: isExp ? AppTheme.darkColor(AppTheme.error, isDark) : amberFg, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => _launchWhatsApp(m),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.darkColor(AppTheme.success, isDark).withValues(alpha: isDark ? 0.15 : 0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.send_rounded, size: 13, color: AppTheme.darkColor(AppTheme.success, isDark)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Reminder',
                                    style: TextStyle(color: AppTheme.darkColor(AppTheme.success, isDark), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 24),

              // ── Hot Leads / Inquiries Follow-up ──
              if (_hotLeads.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_fire_department_rounded, color: amberFg, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Hot Leads Follow-up',
                          style: TextStyle(color: txtPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => widget.onNavigateTab?.call(2),
                      child: Row(
                        children: [
                          Text('Leads ', style: TextStyle(color: cyanFg, fontSize: 12, fontWeight: FontWeight.w600)),
                          Icon(Icons.arrow_forward_rounded, color: cyanFg, size: 14),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  children: _hotLeads.map((l) {
                    final followUpStr = DateFormat('dd MMM').format(l.followUpDate);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: dividerColor),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: blueFg.withValues(alpha: isDark ? 0.15 : 0.12),
                            child: Text(
                              l.name.isNotEmpty ? l.name[0].toUpperCase() : 'L',
                              style: TextStyle(color: blueFg, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.name, style: TextStyle(color: txtPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text('Follow-up: $followUpStr', style: TextStyle(color: txtSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => _makeCall(l),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: blueFg.withValues(alpha: isDark ? 0.15 : 0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.call_rounded, size: 13, color: blueFg),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Call',
                                    style: TextStyle(color: blueFg, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              // ── Plan Popularity & Distribution Breakdown ──
              if (_planDistribution.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.pie_chart_rounded, color: cyanFg, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Plan Popularity & Distribution',
                          style: TextStyle(color: txtPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => widget.onNavigateTab?.call(4),
                      child: Row(
                        children: [
                          Text('Plans ', style: TextStyle(color: cyanFg, fontSize: 12, fontWeight: FontWeight.w600)),
                          Icon(Icons.arrow_forward_rounded, color: cyanFg, size: 14),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_totalMembers total member${_totalMembers == 1 ? '' : 's'} across ${_planDistribution.length} active plan${_planDistribution.length == 1 ? '' : 's'}',
                        style: TextStyle(color: txtSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 14),
                      // Multi-segmented proportion bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 10,
                          child: Row(
                            children: _planDistribution.map((item) {
                              final flexVal = (item.percentage * 100).round().clamp(1, 100);
                              return Expanded(
                                flex: flexVal,
                                child: Container(color: item.color),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Plan detail rows
                      Column(
                        children: _planDistribution.map((item) {
                          final darkItemColor = AppTheme.darkColor(item.color, isDark);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: item.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: TextStyle(color: txtPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: darkItemColor.withValues(alpha: isDark ? 0.15 : 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${item.count} ${item.count == 1 ? 'member' : 'members'}',
                                    style: TextStyle(color: darkItemColor, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${(item.percentage * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(color: txtSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // ── Recent Transactions Section ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: TextStyle(color: txtPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () => widget.onNavigateTab?.call(5),
                    child: Row(
                      children: [
                        Text('View All ', style: TextStyle(color: cyanFg, fontSize: 12, fontWeight: FontWeight.w600)),
                        Icon(Icons.arrow_forward_rounded, color: cyanFg, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_recentPayments.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: dividerColor),
                  ),
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
                          'Logged member payments will appear here',
                          style: TextStyle(color: txtSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  children: List.generate(_recentPayments.length, (i) {
                    final p = _recentPayments[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: dividerColor),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: cyanFg.withValues(alpha: isDark ? 0.15 : 0.12),
                            child: Text(
                              (p.memberName != null && p.memberName!.isNotEmpty) ? p.memberName![0].toUpperCase() : 'M',
                              style: TextStyle(color: cyanFg, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.memberName ?? 'Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: txtPrimary)),
                                const SizedBox(height: 2),
                                Text(p.planName ?? 'Payment Entry', style: TextStyle(color: txtSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: cyanFg.withValues(alpha: isDark ? 0.15 : 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '₹${p.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: cyanFg,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
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

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _PlanDistributionItem {
  final String name;
  final int count;
  final double percentage;
  final Color color;

  _PlanDistributionItem({
    required this.name,
    required this.count,
    required this.percentage,
    required this.color,
  });
}
