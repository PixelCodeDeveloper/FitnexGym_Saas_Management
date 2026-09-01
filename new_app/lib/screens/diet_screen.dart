import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/diet_plan.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';
import 'forms/add_diet_plan_screen.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({super.key});

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  bool _isLoading = true;
  List<DietPlan> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      _plans = await DbService.getDietPlans();
    } catch (_) {
      _plans = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openAddDietPlanScreen() async {
    final newPlan = await Navigator.push<DietPlan>(
      context,
      MaterialPageRoute(builder: (_) => const AddDietPlanScreen()),
    );
    if (newPlan != null) setState(() => _plans.insert(0, newPlan));
  }

  Future<void> _copyPlan(DietPlan plan) async {
    await Clipboard.setData(ClipboardData(text: plan.toShareText()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diet plan copied to clipboard! 📋')),
      );
    }
  }

  Future<void> _shareWhatsApp(DietPlan plan) async {
    final text = Uri.encodeComponent(plan.toShareText());
    final url  = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  void _confirmDelete(DietPlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Diet Plan'),
        content: Text('Remove "${plan.title}" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await DbService.deleteDietPlan(plan.id);
              setState(() => _plans.removeWhere((p) => p.id == plan.id));
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted "${plan.title}"')));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBg          : AppTheme.lightBg;
    final cardBg  = isDark ? AppTheme.darkCard         : Colors.white;
    final border  = isDark ? AppTheme.darkBorder       : AppTheme.lightBorder;
    final footBg  = isDark ? AppTheme.darkSurfaceAlt   : AppTheme.lightSurfaceAlt;
    final txt     = isDark ? AppTheme.darkTextPrimary  : AppTheme.lightTextPrimary;
    final txt2    = isDark ? AppTheme.darkTextSecondary: AppTheme.lightTextSecondary;
    final muted   = isDark ? AppTheme.darkTextMuted    : AppTheme.lightTextMuted;

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2))
          : _plans.isEmpty
              ? _emptyState(isDark, txt, muted)
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _loadPlans,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _plans.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) =>
                        _dietCard(_plans[index], isDark, cardBg, border, footBg, txt, txt2, muted),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDietPlanScreen,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Diet Plan', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _dietCard(
    DietPlan plan, bool isDark,
    Color cardBg, Color border, Color footBg,
    Color txt, Color txt2, Color muted,
  ) {
    final isVeg    = plan.type.toLowerCase() == 'veg';
    final accent   = isVeg ? AppTheme.success : AppTheme.error;
    final iconBg   = isVeg
        ? (isDark ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.successBg)
        : (isDark ? AppTheme.error.withValues(alpha: 0.15)   : AppTheme.errorBg);
    final typeIcon = isVeg ? Icons.eco_rounded : Icons.set_meal_rounded;
    final typeLabel= isVeg ? '🥗 Vegetarian' : '🍗 Non-Veg';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)),
                  child: Icon(typeIcon, color: accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: txt)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: isDark ? 0.15 : 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(typeLabel, style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: isDark ? 0.15 : 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.local_fire_department_rounded, size: 12, color: AppTheme.warning),
                            const SizedBox(width: 4),
                            Text(plan.calories, style: const TextStyle(color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ]),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.error.withValues(alpha: 0.7)),
                  onPressed: () => _confirmDelete(plan),
                ),
              ],
            ),
          ),

          // ── Meal items ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: footBg,
              border: Border.symmetric(horizontal: BorderSide(color: border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: plan.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: 5, height: 5,
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item, style: TextStyle(fontSize: 13, color: txt2, height: 1.4))),
                  ],
                ),
              )).toList(),
            ),
          ),

          // ── Actions ──
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyPlan(plan),
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: const Text('Copy', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _shareWhatsApp(plan),
                  icon: const Icon(Icons.send_rounded, size: 15),
                  label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ),
        ],
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
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.restaurant_menu_rounded, size: 36, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text('No diet plans yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: txt)),
        const SizedBox(height: 6),
        Text('Create your first diet template to assign to members.', style: TextStyle(color: muted, fontSize: 13), textAlign: TextAlign.center),
      ],
    ),
  );
}
