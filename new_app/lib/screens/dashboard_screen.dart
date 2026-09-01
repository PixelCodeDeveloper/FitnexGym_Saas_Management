import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/member.dart';
import '../models/lead.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  int _totalMembers = 0;
  int _activeCount = 0;
  int _expiringCount = 0;
  int _expiredCount = 0;
  int _hotLeadsCount = 0;
  double _monthlyRevenue = 0.0;
  List<dynamic> _recentPayments = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final members  = await DbService.getMembers();
      final leads    = await DbService.getLeads();
      final rev      = await DbService.getMonthlyRevenue();
      final payments = await DbService.getPayments();

      int act = 0, expSoon = 0, exp = 0;
      for (final m in members) {
        if (m.status == MemberStatus.active)      act++;
        if (m.status == MemberStatus.expiringSoon) expSoon++;
        if (m.status == MemberStatus.expired)      exp++;
      }
      setState(() {
        _totalMembers   = members.length;
        _activeCount    = act;
        _expiringCount  = expSoon;
        _expiredCount   = exp;
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
    final bgColor  = isDark ? AppTheme.darkBg        : AppTheme.lightBg;
    final cardBg   = isDark ? AppTheme.darkCard       : AppTheme.lightSurface;
    final border   = isDark ? AppTheme.darkBorder     : AppTheme.lightBorder;
    final txt      = isDark ? AppTheme.darkTextPrimary: AppTheme.lightTextPrimary;
    final txt2     = isDark ? AppTheme.darkTextSecondary: AppTheme.lightTextSecondary;
    final muted    = isDark ? AppTheme.darkTextMuted  : AppTheme.lightTextMuted;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: cardBg,
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero Banner ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: isDark ? 0.35 : 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome Back 👋',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'FitnexGym',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: AppTheme.success, size: 7),
                              SizedBox(width: 6),
                              Text(
                                'Live VPS Active',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Mini stats bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _heroStat('Total', '$_totalMembers', Icons.people_alt_rounded),
                          _heroDivider(),
                          _heroStat('Revenue', '₹${_fmt(_monthlyRevenue)}', Icons.currency_rupee_rounded),
                          _heroDivider(),
                          _heroStat('Expiring', '$_expiringCount', Icons.timer_outlined),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Section label ──
              _sectionLabel('Overview', txt),
              const SizedBox(height: 12),

              // ── KPI Cards 2x2 ──
              Row(children: [
                Expanded(child: _kpiCard('Active Members', '$_activeCount', Icons.people_alt_rounded,
                    AppTheme.success, AppTheme.successBg, cardBg, border, txt, txt2, isDark)),
                const SizedBox(width: 12),
                Expanded(child: _kpiCard('Expiring Soon', '$_expiringCount', Icons.timer_outlined,
                    AppTheme.warning, AppTheme.warningBg, cardBg, border, txt, txt2, isDark)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _kpiCard('Expired', '$_expiredCount', Icons.cancel_outlined,
                    AppTheme.error, AppTheme.errorBg, cardBg, border, txt, txt2, isDark)),
                const SizedBox(width: 12),
                Expanded(child: _kpiCard('Hot Leads', '$_hotLeadsCount', Icons.local_fire_department_rounded,
                    AppTheme.accent, const Color(0xFFFFF0E8), cardBg, border, txt, txt2, isDark)),
              ]),

              const SizedBox(height: 28),

              // ── Revenue highlight ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: isDark ? AppTheme.darkCardGradient : null,
                  color: isDark ? null : AppTheme.lightSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppTheme.primary.withValues(alpha: 0.25) : border),
                  boxShadow: isDark ? [BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  )] : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.currency_rupee_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Monthly Revenue', style: TextStyle(color: txt2, fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          '₹${_fmt(_monthlyRevenue)}',
                          style: TextStyle(
                            color: txt,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Recent Transactions ──
              _sectionLabel('Recent Transactions', txt),
              const SizedBox(height: 12),

              if (_recentPayments.isEmpty)
                _emptyState(
                  Icons.receipt_long_outlined,
                  'No transactions yet',
                  'Payments will appear here after members are added.',
                  cardBg, border, txt, muted,
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
                      cardBg, border, txt, txt2, muted, isDark,
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroStat(String label, String value, IconData icon) => Column(
    children: [
      Icon(icon, color: Colors.white70, size: 18),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
    ],
  );

  Widget _heroDivider() => Container(
    height: 40,
    width: 1,
    color: Colors.white.withValues(alpha: 0.2),
  );

  Widget _sectionLabel(String text, Color txtColor) => Text(
    text,
    style: TextStyle(
      color: txtColor,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
  );

  Widget _kpiCard(
    String title, String value, IconData icon, Color accent,
    Color lightBg, Color cardBg, Color border, Color txt, Color txt2,
    bool isDark,
  ) {
    final iconBg = isDark ? accent.withValues(alpha: 0.15) : lightBg;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppTheme.darkBorder : border),
        boxShadow: isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: txt,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 13, color: txt2, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _transactionTile(
    String name, String plan, double amount,
    Color cardBg, Color border, Color txt, Color txt2, Color muted,
    bool isDark,
  ) {
    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'M';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
            child: Text(
              initials,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: txt)),
                const SizedBox(height: 2),
                Text(plan, style: TextStyle(color: txt2, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '₹${amount.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppTheme.success,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(
    IconData icon, String title, String desc,
    Color cardBg, Color border, Color txt, Color muted,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 32, color: AppTheme.primary),
          ),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: txt)),
          const SizedBox(height: 6),
          Text(desc, style: TextStyle(color: muted, fontSize: 12), textAlign: TextAlign.center),
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
