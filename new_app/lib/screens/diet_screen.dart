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
    final bgColor = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final border  = isDark ? const Color(0xFF162234) : const Color(0xFFE2E8F0);
    final txt     = isDark ? Colors.white : const Color(0xFF0F172A);
    final txt2    = isDark ? const Color(0xFF8896B3) : const Color(0xFF64748B);
    final muted   = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    const activeCyan = Color(0xFF00E5C0);

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: activeCyan, strokeWidth: 2))
          : _plans.isEmpty
              ? _emptyState(isDark, txt, muted)
              : RefreshIndicator(
                  color: activeCyan,
                  onRefresh: _loadPlans,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _plans.length,
                    separatorBuilder: (_, i) => Divider(height: 1, color: border),
                    itemBuilder: (context, index) =>
                        _dietTile(_plans[index], isDark, border, txt, txt2, muted),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDietPlanScreen,
        backgroundColor: activeCyan,
        foregroundColor: Colors.black,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Diet Plan', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _dietTile(
    DietPlan plan, bool isDark,
    Color border,
    Color txt, Color txt2, Color muted,
  ) {
    final isVeg    = plan.type.toLowerCase() == 'veg';
    final accent   = isVeg ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final typeIcon = isVeg ? Icons.eco_rounded : Icons.set_meal_rounded;
    final typeLabel= isVeg ? '🥗 Vegetarian' : '🍗 Non-Veg';
    const activeCyan = Color(0xFF00E5C0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(typeIcon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: txt)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(typeLabel, style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.local_fire_department_rounded, size: 12, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(plan.calories, style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ]),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 20, color: const Color(0xFFEF4444).withValues(alpha: 0.8)),
                onPressed: () => _confirmDelete(plan),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
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
          const SizedBox(height: 8),
          Row(children: [
            InkWell(
              onTap: () => _copyPlan(plan),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: activeCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 13, color: activeCyan),
                    SizedBox(width: 4),
                    Text('Copy', style: TextStyle(color: activeCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _shareWhatsApp(plan),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.send_rounded, size: 13, color: Color(0xFF22C55E)),
                    SizedBox(width: 4),
                    Text('WhatsApp', style: TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ]),
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
            color: const Color(0xFF00E5C0).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.restaurant_menu_rounded, size: 36, color: Color(0xFF00E5C0)),
        ),
        const SizedBox(height: 16),
        Text('No diet plans yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: txt)),
        const SizedBox(height: 6),
        Text('Create your first diet template to assign to members.', style: TextStyle(color: muted, fontSize: 13), textAlign: TextAlign.center),
      ],
    ),
  );
}
