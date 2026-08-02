import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/diet_plan.dart';
import '../services/db_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/input_validator.dart';
// start
class DietScreen extends StatefulWidget {
  const DietScreen({super.key});

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  bool _isLoading = true;
  List<DietPlan> _plans = [];

  final List<DietPlan> _fallbackPlans = [
    DietPlan(
      id: 'd1',
      gymId: 'g1',
      title: 'Weight Loss Plan (Lacto-Veg)',
      type: 'veg',
      calories: '1500 kcal',
      items: [
        'Breakfast: Oats + Almond Milk + Chia Seeds',
        'Mid-Morning: Apple + Green Tea',
        'Lunch: Brown Rice + Dal + Mixed Veg Sabzi',
        'Evening: Roasted Makhana',
        'Dinner: Paneer Salad + Cucumber Soup',
      ],
      createdAt: DateTime.now(),
    ),
    DietPlan(
      id: 'd2',
      gymId: 'g1',
      title: 'Muscle Mass Building (High Protein)',
      type: 'nonveg',
      calories: '2800 kcal',
      items: [
        'Breakfast: 5 Whole Eggs + Peanut Butter Toast',
        'Mid-Morning: Whey Protein Shake + Banana',
        'Lunch: Grilled Chicken Breast + Rice + Broccoli',
        'Pre-Workout: Black Coffee + Rice Cakes',
        'Dinner: Fish Fillet + Sweet Potato + Salad',
      ],
      createdAt: DateTime.now(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final list = await DbService.getDietPlans();
      setState(() {
        _plans = list.isEmpty ? _fallbackPlans : list;
      });
    } catch (_) {
      setState(() {
        _plans = _fallbackPlans;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddDietModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddDietForm(
        onPlanAdded: (newPlan) {
          setState(() {
            _plans.insert(0, newPlan);
          });
        },
      ),
    );
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
    final url = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  void _confirmDelete(DietPlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Diet Plan'),
        content: Text('Are you sure you want to delete ${plan.title}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await DbService.deleteDietPlan(plan.id);
              setState(() {
                _plans.removeWhere((p) => p.id == plan.id);
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted ${plan.title}')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPlans,
              child: ListView.separated(
                padding: const EdgeInsets.all(16.0),
                itemCount: _plans.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final plan = _plans[index];
                  final isVeg = plan.type.toLowerCase() == 'veg';
                  final color = isVeg ? AppTheme.success : AppTheme.error;
                  final bgColor = isVeg ? AppTheme.successBg : AppTheme.errorBg;
                  final icon = isVeg ? Icons.eco_rounded : Icons.set_meal_rounded;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, color: color, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plan.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${isVeg ? "🥗 Veg" : "🍗 Non-Veg"} • ${plan.calories}',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
                                onPressed: () => _confirmDelete(plan),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          decoration: const BoxDecoration(color: AppTheme.surfaceAlt),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: plan.items
                                .map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Icon(Icons.circle, size: 5, color: color),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _copyPlan(plan),
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text('Copy'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _shareWhatsApp(plan),
                                  icon: const Icon(Icons.send, size: 16),
                                  label: const Text('WhatsApp'),
                                ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDietModal,
        icon: const Icon(Icons.add),
        label: const Text('New Diet'),
      ),
    );
  }
}

class _AddDietForm extends StatefulWidget {
  final Function(DietPlan) onPlanAdded;
  const _AddDietForm({required this.onPlanAdded});

  @override
  State<_AddDietForm> createState() => _AddDietFormState();
}

class _AddDietFormState extends State<_AddDietForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _breakfastController = TextEditingController();
  final _lunchController = TextEditingController();
  final _dinnerController = TextEditingController();
  String _selectedType = 'veg';
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _caloriesController.dispose();
    _breakfastController.dispose();
    _lunchController.dispose();
    _dinnerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final gymId = await AuthService.getGymId() ?? 'gym_demo';
      final now = DateTime.now();
      final items = <String>[];
      if (_breakfastController.text.trim().isNotEmpty) {
        items.add('Breakfast: ${_breakfastController.text.trim()}');
      }
      if (_lunchController.text.trim().isNotEmpty) {
        items.add('Lunch: ${_lunchController.text.trim()}');
      }
      if (_dinnerController.text.trim().isNotEmpty) {
        items.add('Dinner: ${_dinnerController.text.trim()}');
      }
      if (items.isEmpty) {
        items.add('Balanced High-Protein Meal Plan');
      }

      final plan = DietPlan(
        id: 'diet_${now.millisecondsSinceEpoch}',
        gymId: gymId,
        title: _titleController.text.trim(),
        type: _selectedType,
        calories: '${_caloriesController.text.trim()} kcal',
        items: items,
        createdAt: now,
      );

      final created = await DbService.addDietPlan(plan);
      widget.onPlanAdded(created);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      final now = DateTime.now();
      final fallback = DietPlan(
        id: 'diet_${now.millisecondsSinceEpoch}',
        gymId: 'gym_demo',
        title: _titleController.text.trim(),
        type: _selectedType,
        calories: '${_caloriesController.text.trim()} kcal',
        items: [
          if (_breakfastController.text.isNotEmpty) 'Breakfast: ${_breakfastController.text}',
          if (_lunchController.text.isNotEmpty) 'Lunch: ${_lunchController.text}',
          if (_dinnerController.text.isNotEmpty) 'Dinner: ${_dinnerController.text}',
        ],
        createdAt: now,
      );
      widget.onPlanAdded(fallback);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Diet Plan Template', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              TextFormField(
                controller: _titleController,
                validator: InputValidator.validateName,
                decoration: const InputDecoration(labelText: 'Plan Title *', hintText: 'e.g. Lean Muscle Gain'),
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Diet Type'),
                items: const [
                  DropdownMenuItem(value: 'veg', child: Text('Vegetarian 🥗')),
                  DropdownMenuItem(value: 'nonveg', child: Text('Non-Vegetarian 🍗')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: InputValidator.validateAmount,
                decoration: const InputDecoration(labelText: 'Target Calories (kcal) *', hintText: 'e.g. 2200'),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _breakfastController,
                decoration: const InputDecoration(labelText: 'Breakfast Menu', hintText: 'e.g. Oats + Egg whites + Almonds'),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _lunchController,
                decoration: const InputDecoration(labelText: 'Lunch Menu', hintText: 'e.g. Grilled Chicken / Paneer + Brown Rice'),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _dinnerController,
                decoration: const InputDecoration(labelText: 'Dinner Menu', hintText: 'e.g. Fish / Tofu + Green Salad + Soup'),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Diet Plan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
