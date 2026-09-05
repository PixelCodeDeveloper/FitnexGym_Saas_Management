import 'package:flutter/material.dart';
import '../models/subscription_plan.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';
import '../utils/subscription_guard.dart';
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
    DbService.plansRefreshNotifier.addListener(_onPlansChanged);
  }

  @override
  void dispose() {
    DbService.plansRefreshNotifier.removeListener(_onPlansChanged);
    super.dispose();
  }

  void _onPlansChanged() {
    if (mounted) _loadPlans();
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
    if (newPlan != null) {
      DbService.notifyPlansChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final bgColor  = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final border   = isDark ? const Color(0xFF162234) : const Color(0xFFE2E8F0);
    final txt      = isDark ? Colors.white : const Color(0xFF0F172A);
    final txt2     = isDark ? const Color(0xFF8896B3) : const Color(0xFF334155);
    final muted    = isDark ? const Color(0xFF64748B) : const Color(0xFF475569);
    const activeCyan = Color(0xFF00E5C0);

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: activeCyan, strokeWidth: 2))
          : RefreshIndicator(
              color: activeCyan,
              onRefresh: _loadPlans,
              child: _plans.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: Center(child: _emptyState(isDark, border, txt, muted)),
                      ),
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _plans.length,
                      separatorBuilder: (_, idx) => Divider(height: 1, color: border),
                      itemBuilder: (context, i) => _planTile(_plans[i], isDark, border, txt, txt2, muted),
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          SubscriptionGuard.checkActive(
            context,
            featureName: 'create new membership plans',
            onActive: _openAddPlanScreen,
          );
        },
        backgroundColor: activeCyan,
        foregroundColor: Colors.black,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Plan', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _planTile(
    SubscriptionPlan plan, bool isDark,
    Color border, Color txt, Color txt2, Color muted,
  ) {
    final isPopular = plan.durationDays >= 85 && plan.durationDays <= 95;
    const activeCyan = Color(0xFF00E5C0);
    final cyanFg     = AppTheme.darkColor(activeCyan, isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cyanFg.withValues(alpha: isDark ? 0.15 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.card_membership_rounded,
              color: cyanFg,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(plan.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: txt)),
                    if (isPopular) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cyanFg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'POPULAR',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  plan.description ?? '${plan.durationDays} days membership plan',
                  style: TextStyle(color: txt2, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cyanFg.withValues(alpha: isDark ? 0.12 : 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${plan.durationDays} Days',
                    style: TextStyle(color: cyanFg, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${plan.price.toStringAsFixed(0)}',
                style: TextStyle(
                  color: cyanFg,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text('per plan', style: TextStyle(color: muted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(bool isDark, Color border, Color txt, Color muted) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5C0).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.card_membership_rounded, size: 36, color: Color(0xFF00E5C0)),
          ),
          const SizedBox(height: 16),
          Text('No plans created yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: txt)),
          const SizedBox(height: 6),
          Text('Tap + to create your first membership plan.', style: TextStyle(color: muted, fontSize: 13)),
        ],
      ),
    );
  }
}
