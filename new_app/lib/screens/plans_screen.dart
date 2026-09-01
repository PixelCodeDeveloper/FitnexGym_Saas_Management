import 'package:flutter/material.dart';
import '../models/subscription_plan.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';
import 'forms/add_plan_screen.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  bool _isLoading = true;
  List<SubscriptionPlan> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      _plans = await DbService.getPlans();
    } catch (_) {
      _plans = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openAddPlanScreen() async {
    final newPlan = await Navigator.push<SubscriptionPlan>(
      context,
      MaterialPageRoute(builder: (_) => const AddPlanScreen()),
    );
    if (newPlan != null) setState(() => _plans.insert(0, newPlan));
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final bgColor  = isDark ? AppTheme.darkBg         : AppTheme.lightBg;
    final cardBg   = isDark ? AppTheme.darkCard        : AppTheme.lightSurface;
    final border   = isDark ? AppTheme.darkBorder      : AppTheme.lightBorder;
    final txt      = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final txt2     = isDark ? AppTheme.darkTextSecondary: AppTheme.lightTextSecondary;
    final muted    = isDark ? AppTheme.darkTextMuted   : AppTheme.lightTextMuted;

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2))
          : _plans.isEmpty
              ? _emptyState(isDark, cardBg, border, txt, muted)
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _loadPlans,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _plans.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) => _planCard(_plans[i], isDark, cardBg, border, txt, txt2, muted),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPlanScreen,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Plan', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _planCard(
    SubscriptionPlan plan, bool isDark,
    Color cardBg, Color border, Color txt, Color txt2, Color muted,
  ) {
    // Mark 3-month plans as "popular"
    final isPopular = plan.durationDays >= 85 && plan.durationDays <= 95;
    final accentColor = isPopular ? AppTheme.primary : txt2;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPopular ? AppTheme.primary.withValues(alpha: 0.5) : border,
          width: isPopular ? 1.5 : 1,
        ),
        boxShadow: isPopular
            ? [BoxShadow(color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1), blurRadius: 16, offset: const Offset(0, 4))]
            : (isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))] : null),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: isPopular ? AppTheme.primaryGradient : null,
                    color: isPopular ? null : (isDark ? AppTheme.darkSurfaceAlt : AppTheme.lightSurfaceAlt),
                    borderRadius: BorderRadius.circular(14),
                    border: isPopular ? null : Border.all(color: border),
                  ),
                  child: Icon(
                    Icons.card_membership_rounded,
                    color: isPopular ? Colors.white : txt2,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: txt)),
                      const SizedBox(height: 5),
                      Text(
                        plan.description ?? '${plan.durationDays} days membership plan',
                        style: TextStyle(color: txt2, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${plan.durationDays} Days',
                          style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${plan.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: isPopular ? AppTheme.primary : txt,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('per plan', style: TextStyle(color: muted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          // Popular badge
          if (isPopular)
            Positioned(
              top: 0,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: const Text(
                  '⭐ POPULAR',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState(bool isDark, Color cardBg, Color border, Color txt, Color muted) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.card_membership_rounded, size: 36, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text('No plans created yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: txt)),
          const SizedBox(height: 6),
          Text('Tap + to create your first membership plan.', style: TextStyle(color: muted, fontSize: 13)),
        ],
      ),
    );
  }
}
