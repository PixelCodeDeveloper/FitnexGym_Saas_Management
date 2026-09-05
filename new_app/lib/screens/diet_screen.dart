import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/diet_plan.dart';
import '../models/member.dart';
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
  List<MemberDietPlan> _dueReviews = [];
  List<Member> _members = [];

  String _selectedTab = 'all'; // 'all', 'veg', 'egg', 'nonveg', 'vegan'
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        DbService.getDietPlans(),
        DbService.getDietPlansDueForReview().catchError((_) => <MemberDietPlan>[]),
        DbService.getMembers().catchError((_) => <Member>[]),
      ]);
      _plans = results[0] as List<DietPlan>;
      _dueReviews = results[1] as List<MemberDietPlan>;
      _members = results[2] as List<Member>;
    } catch (_) {
      _plans = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<DietPlan> get _filteredPlans {
    return _plans.where((plan) {
      if (_selectedTab != 'all') {
        final cat = plan.category.toLowerCase();
        if (_selectedTab == 'veg' && cat != 'veg') return false;
        if (_selectedTab == 'nonveg' && cat != 'nonveg') return false;
        if (_selectedTab == 'egg' && cat != 'egg') return false;
        if (_selectedTab == 'vegan' && cat != 'vegan') return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = plan.title.toLowerCase().contains(q);
        final matchGoal = (plan.goalTag ?? '').toLowerCase().contains(q);
        final matchCal = plan.calories.toLowerCase().contains(q);
        if (!matchTitle && !matchGoal && !matchCal) return false;
      }
      return true;
    }).toList();
  }

  int _countCategory(String cat) {
    if (cat == 'all') return _plans.length;
    return _plans.where((p) => p.category.toLowerCase() == cat).length;
  }

  Future<void> _openAddDietPlanScreen() async {
    final newPlan = await Navigator.push<DietPlan>(
      context,
      MaterialPageRoute(builder: (_) => const AddDietPlanScreen()),
    );
    if (newPlan != null) {
      setState(() => _plans.insert(0, newPlan));
    }
  }

  Future<void> _copyPlan(DietPlan plan) async {
    await Clipboard.setData(ClipboardData(text: plan.toShareText()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diet plan text copied to clipboard! 📋')),
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
        title: const Text('Delete Diet Template'),
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

  Future<void> _assignPlanToMemberDialog(DietPlan plan) async {
    if (_members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No gym members found to assign plan to.')),
      );
      return;
    }

    Member selectedMember = _members.first;
    final titleCtrl = TextEditingController(text: '${plan.title} (for Member)');
    final caloriesCtrl = TextEditingController(text: plan.calories);
    final proteinCtrl = TextEditingController(text: plan.macros?['protein'] ?? '150g');
    final carbsCtrl = TextEditingController(text: plan.macros?['carbs'] ?? '200g');
    final fatsCtrl = TextEditingController(text: plan.macros?['fats'] ?? '50g');
    int reviewDays = 30;
    bool isAssigning = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
            final txt = isDark ? Colors.white : Colors.black;

            return Container(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36, height: 4,
                        decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primary, size: 24),
                      const SizedBox(width: 10),
                      Text('Assign Plan to Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: txt)),
                    ]),
                    const SizedBox(height: 6),
                    Text('Customize and set review date for member assignment', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF475569))),
                    const SizedBox(height: 16),

                    // Select Member
                    Text('Select Member *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: txt)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<Member>(
                      value: selectedMember,
                      dropdownColor: bg,
                      style: TextStyle(color: txt, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _members.map((m) => DropdownMenuItem(value: m, child: Text('${m.name} (${m.phone})'))).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedMember = val);
                      },
                    ),

                    const SizedBox(height: 14),

                    // Custom Title
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Assigned Plan Title',
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: caloriesCtrl,
                          decoration: InputDecoration(
                            labelText: 'Calories Target',
                            prefixIcon: const Icon(Icons.local_fire_department_rounded, color: AppTheme.warning),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: proteinCtrl,
                          decoration: InputDecoration(
                            labelText: 'Protein (g)',
                            prefixIcon: const Icon(Icons.fitness_center_rounded, color: AppTheme.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 14),

                    // Review Window selector
                    Row(children: [
                      Text('Review Period: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: txt)),
                      const Spacer(),
                      ChoiceChip(
                        label: const Text('14 Days'),
                        selected: reviewDays == 14,
                        onSelected: (_) => setModalState(() => reviewDays = 14),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('30 Days'),
                        selected: reviewDays == 30,
                        onSelected: (_) => setModalState(() => reviewDays = 30),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isAssigning
                            ? null
                            : () async {
                                setModalState(() => isAssigning = true);
                                try {
                                  final payload = {
                                    'member_id': selectedMember.id,
                                    'template_id': plan.id.isNotEmpty ? plan.id : null,
                                    'custom_title': titleCtrl.text.trim(),
                                    'category': plan.category,
                                    'goal_tag': plan.goalTag,
                                    'calories': caloriesCtrl.text.trim(),
                                    'macros': {
                                      'protein': proteinCtrl.text.trim(),
                                      'carbs': carbsCtrl.text.trim(),
                                      'fats': fatsCtrl.text.trim(),
                                    },
                                    'water_intake': plan.waterIntake,
                                    'meals': plan.meals,
                                    'notes': plan.notes,
                                    'start_date': DateTime.now().toIso8601String(),
                                    'review_date': DateTime.now().add(Duration(days: reviewDays)).toIso8601String(),
                                  };
                                  final assigned = await DbService.assignDietPlanToMember(payload);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted && assigned != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Assigned "${assigned.customTitle}" to ${selectedMember.name}! 🎉')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to assign: $e')));
                                } finally {
                                  if (ctx.mounted) setModalState(() => isAssigning = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: isAssigning
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_rounded),
                        label: Text(isAssigning ? 'Assigning Plan...' : 'Confirm Member Assignment', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendDietEmailDialog(DietPlan plan) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    bool sending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
            final txt = isDark ? Colors.white : Colors.black;

            return Container(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF3B82F6), size: 24),
                    const SizedBox(width: 10),
                    Text('Send Diet Plan PDF', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: txt)),
                  ]),
                  const SizedBox(height: 6),
                  Text('An executive 2-page PDF will be generated and emailed.', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF475569))),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Member Name',
                      hintText: 'e.g. Rahul Sharma',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Member Email',
                      hintText: 'e.g. rahul@gmail.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: sending
                          ? null
                          : () async {
                              final email = emailCtrl.text.trim();
                              final name = nameCtrl.text.trim();
                              if (email.isEmpty || !email.contains('@')) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid email address')));
                                return;
                              }
                              setModalState(() => sending = true);
                              final success = await DbService.sendDietPlanEmail(
                                memberEmail: email,
                                memberName: name.isEmpty ? 'Gym Member' : name,
                                dietPlanId: plan.id,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Diet Plan PDF emailed successfully to $email! 📧'
                                          : 'Failed to send Diet Plan PDF.',
                                    ),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: sending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                      label: Text(sending ? 'Sending PDF...' : 'Send Executive PDF', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bgColor   = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final border    = isDark ? const Color(0xFF162234) : const Color(0xFFE2E8F0);
    final txt       = isDark ? Colors.white : const Color(0xFF0F172A);
    final txt2      = isDark ? const Color(0xFF8896B3) : const Color(0xFF334155);
    final muted     = isDark ? const Color(0xFF64748B) : const Color(0xFF475569);
    final cardBg    = isDark ? const Color(0xFF0F172A) : Colors.white;
    const activeCyan = Color(0xFF00E5C0);

    final filtered = _filteredPlans;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header & Search ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Nutrition & Diet Templates', style: TextStyle(color: txt, fontSize: 18, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: activeCyan.withValues(alpha: isDark ? 0.12 : 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${_plans.length} Templates', style: TextStyle(color: AppTheme.darkColor(activeCyan, isDark), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search Bar
                  TextField(
                    controller: _searchCtrl,
                    style: TextStyle(color: txt, fontSize: 13),
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search templates by title, calories, or goal...',
                      hintStyle: TextStyle(color: muted, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: muted, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: cardBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Category Segment Filter Bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _tabChip('All', 'all', _countCategory('all'), activeCyan, isDark),
                        const SizedBox(width: 8),
                        _tabChip('🥗 Veg', 'veg', _countCategory('veg'), const Color(0xFF22C55E), isDark),
                        const SizedBox(width: 8),
                        _tabChip('🥚 Eggetarian', 'egg', _countCategory('egg'), const Color(0xFFF59E0B), isDark),
                        const SizedBox(width: 8),
                        _tabChip('🍗 Non-Veg', 'nonveg', _countCategory('nonveg'), const Color(0xFFEF4444), isDark),
                        const SizedBox(width: 8),
                        _tabChip('🌱 Vegan', 'vegan', _countCategory('vegan'), const Color(0xFF10B981), isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Due For Review Alert Banner (if any) ──
            if (_dueReviews.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: Color(0xFFF59E0B), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '🔔 ${_dueReviews.length} member diet plans due for 30-day review this week!',
                        style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Diet List ──
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: activeCyan, strokeWidth: 2))
                  : filtered.isEmpty
                      ? _emptyState(isDark, txt, muted)
                      : RefreshIndicator(
                          color: activeCyan,
                          onRefresh: _loadData,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: filtered.length,
                            separatorBuilder: (_, i) => const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _dietCard(filtered[index], isDark, cardBg, border, txt, txt2, muted),
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDietPlanScreen,
        backgroundColor: activeCyan,
        foregroundColor: Colors.black,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Diet Plan', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _tabChip(String label, String value, int count, Color accent, bool isDark) {
    final selected = _selectedTab == value;
    final activeFg = AppTheme.darkColor(accent, isDark);
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: isDark ? 0.25 : 0.18) : (isDark ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? activeFg : (isDark ? const Color(0xFF162234) : const Color(0xFFCBD5E1)), width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? activeFg : (isDark ? Colors.white70 : const Color(0xFF1E293B)),
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? activeFg : (isDark ? Colors.grey.withValues(alpha: 0.2) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF1E293B)),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openViewDietPlanDialog(DietPlan plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
        final txt = isDark ? Colors.white : Colors.black;
        final txt2 = isDark ? const Color(0xFF8896B3) : const Color(0xFF334155);
        final border = isDark ? const Color(0xFF162234) : const Color(0xFFE2E8F0);
        const activeCyan = Color(0xFF00E5C0);

        final isVeg    = plan.category.toLowerCase() == 'veg';
        final isEgg    = plan.category.toLowerCase() == 'egg';
        final isVegan  = plan.category.toLowerCase() == 'vegan';

        Color accent = const Color(0xFFEF4444);
        IconData typeIcon = Icons.set_meal_rounded;
        if (isVeg) {
          accent = const Color(0xFF22C55E);
          typeIcon = Icons.eco_rounded;
        } else if (isEgg) {
          accent = const Color(0xFFF59E0B);
          typeIcon = Icons.egg_rounded;
        } else if (isVegan) {
          accent = const Color(0xFF10B981);
          typeIcon = Icons.spa_rounded;
        }

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(typeIcon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: txt)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6, runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: isDark ? 0.12 : 0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(plan.CategoryBadge, style: TextStyle(color: AppTheme.darkColor(accent, isDark), fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            if (plan.goalTag != null && plan.goalTag!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.12 : 0.16),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('🎯 ${plan.goalTag}', style: TextStyle(color: AppTheme.darkColor(const Color(0xFF3B82F6), isDark), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.12 : 0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('🔥 ${plan.calories}', style: TextStyle(color: AppTheme.darkColor(const Color(0xFFF59E0B), isDark), fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Macros Row
                      if (plan.macros != null && plan.macros!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _macroItem('💪 Protein', plan.macros!['protein'] ?? 'N/A', activeCyan),
                              _macroItem('🌾 Carbs', plan.macros!['carbs'] ?? 'N/A', const Color(0xFF8B5CF6)),
                              _macroItem('🥑 Fats', plan.macros!['fats'] ?? 'N/A', const Color(0xFFEC4899)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Text('Full Meal Schedule & Plan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: txt)),
                      const SizedBox(height: 10),

                      if (plan.meals.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: plan.meals.entries.map((e) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF162234) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatMealKey(e.key),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkColor(accent, isDark)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    e.value,
                                    style: TextStyle(fontSize: 13, color: txt, height: 1.3),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        )
                      else if (plan.items.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: plan.items.map((item) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF162234) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(item, style: TextStyle(fontSize: 13, color: txt)),
                            );
                          }).toList(),
                        ),

                      if (plan.notes != null && plan.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text('Notes & Hydration Advice', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: txt)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
                          ),
                          child: Text(plan.notes!, style: TextStyle(fontSize: 13, color: txt2, height: 1.3)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Bottom Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openEditDietPlanScreen(plan);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _assignPlanToMemberDialog(plan);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                      label: const Text('Assign Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditDietPlanScreen(DietPlan plan) async {
    final updatedPlan = await Navigator.push<DietPlan>(
      context,
      MaterialPageRoute(
        builder: (_) => AddDietPlanScreen(planToEdit: plan),
      ),
    );
    if (updatedPlan != null) {
      final index = _plans.indexWhere((p) => p.id == updatedPlan.id);
      if (index != -1) {
        setState(() => _plans[index] = updatedPlan);
      } else {
        _loadData();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated "${updatedPlan.title}" successfully! ✏️')),
        );
      }
    }
  }

  Widget _mealSlotField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _dietCard(
    DietPlan plan, bool isDark,
    Color cardBg, Color border,
    Color txt, Color txt2, Color muted,
  ) {
    final isVeg    = plan.category.toLowerCase() == 'veg';
    final isEgg    = plan.category.toLowerCase() == 'egg';
    final isVegan  = plan.category.toLowerCase() == 'vegan';

    Color accent = const Color(0xFFEF4444);
    IconData typeIcon = Icons.set_meal_rounded;
    if (isVeg) {
      accent = const Color(0xFF22C55E);
      typeIcon = Icons.eco_rounded;
    } else if (isEgg) {
      accent = const Color(0xFFF59E0B);
      typeIcon = Icons.egg_rounded;
    } else if (isVegan) {
      accent = const Color(0xFF10B981);
      typeIcon = Icons.spa_rounded;
    }

    const activeCyan = Color(0xFF00E5C0);
    final mealsCount = plan.meals.isNotEmpty ? plan.meals.length : plan.items.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(typeIcon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: txt)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6, runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: isDark ? 0.12 : 0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(plan.CategoryBadge, style: TextStyle(color: AppTheme.darkColor(accent, isDark), fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        if (plan.goalTag != null && plan.goalTag!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.12 : 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('🎯 ${plan.goalTag}', style: TextStyle(color: AppTheme.darkColor(const Color(0xFF3B82F6), isDark), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.12 : 0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.local_fire_department_rounded, size: 12, color: AppTheme.darkColor(const Color(0xFFF59E0B), isDark)),
                            const SizedBox(width: 4),
                            Text(plan.calories, style: TextStyle(color: AppTheme.darkColor(const Color(0xFFF59E0B), isDark), fontSize: 11, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 20, color: const Color(0xFFEF4444).withValues(alpha: 0.8)),
                onPressed: () => _confirmDelete(plan),
              ),
            ],
          ),

          // Macros Row
          if (plan.macros != null && plan.macros!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _macroItem('💪 Protein', plan.macros!['protein'] ?? 'N/A', activeCyan),
                  _macroItem('🌾 Carbs', plan.macros!['carbs'] ?? 'N/A', const Color(0xFF8B5CF6)),
                  _macroItem('🥑 Fats', plan.macros!['fats'] ?? 'N/A', const Color(0xFFEC4899)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Minimal Meal Count Summary Badge
          Row(
            children: [
              Icon(Icons.restaurant_menu_rounded, size: 14, color: muted),
              const SizedBox(width: 6),
              Text(
                '$mealsCount Meals Planned',
                style: TextStyle(color: txt2, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action Buttons Bar (View, Edit, Assign, Share, PDF)
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _actionBtn(
                label: 'View',
                icon: Icons.visibility_rounded,
                color: activeCyan,
                onTap: () => _openViewDietPlanDialog(plan),
              ),
              _actionBtn(
                label: 'Edit',
                icon: Icons.edit_rounded,
                color: const Color(0xFF3B82F6),
                onTap: () => _openEditDietPlanScreen(plan),
              ),
              _actionBtn(
                label: 'Assign',
                icon: Icons.person_add_alt_1_rounded,
                color: const Color(0xFF22C55E),
                onTap: () => _assignPlanToMemberDialog(plan),
              ),
              _actionBtn(
                label: 'Copy',
                icon: Icons.copy_rounded,
                color: const Color(0xFFF59E0B),
                onTap: () => _copyPlan(plan),
              ),
              _actionBtn(
                label: 'WhatsApp',
                icon: Icons.send_rounded,
                color: const Color(0xFF10B981),
                onTap: () => _shareWhatsApp(plan),
              ),
              _actionBtn(
                label: 'Email PDF',
                icon: Icons.picture_as_pdf_rounded,
                color: const Color(0xFF8B5CF6),
                onTap: () => _sendDietEmailDialog(plan),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroItem(String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = AppTheme.darkColor(color, isDark);
    return Column(
      children: [
        Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
      ],
    );
  }

  Widget _actionBtn({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = AppTheme.darkColor(color, isDark);
    final bgColor = isDark ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.18);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fgColor),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: fgColor, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  String _formatMealKey(String key) {
    switch (key) {
      case 'early_morning': return 'Early Morning';
      case 'breakfast': return 'Breakfast';
      case 'mid_morning': return 'Mid-Morning';
      case 'lunch': return 'Lunch';
      case 'post_workout': return 'Post-Workout';
      case 'dinner': return 'Dinner';
      case 'bedtime': return 'Bedtime';
      default: return 'Meal';
    }
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
        Text('No diet templates match your filter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: txt)),
        const SizedBox(height: 6),
        Text('Create a new template or change category filter.', style: TextStyle(color: muted, fontSize: 13), textAlign: TextAlign.center),
      ],
    ),
  );
}
