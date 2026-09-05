import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/diet_plan.dart';
import '../../services/db_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/input_validator.dart';

class AddDietPlanScreen extends StatefulWidget {
  final DietPlan? planToEdit;
  const AddDietPlanScreen({super.key, this.planToEdit});

  @override
  State<AddDietPlanScreen> createState() => _AddDietPlanScreenState();
}

class _AddDietPlanScreenState extends State<AddDietPlanScreen> {
  final _formKey              = GlobalKey<FormState>();
  final _titleController      = TextEditingController();
  final _caloriesController   = TextEditingController(text: '2200');
  final _proteinController    = TextEditingController(text: '150');
  final _carbsController      = TextEditingController(text: '200');
  final _fatsController       = TextEditingController(text: '50');
  final _waterController      = TextEditingController(text: '3.5');
  final _notesController      = TextEditingController();

  // 7 Meal Slots
  final _earlyMorningCtrl     = TextEditingController();
  final _breakfastCtrl        = TextEditingController();
  final _midMorningCtrl       = TextEditingController();
  final _lunchCtrl            = TextEditingController();
  final _postWorkoutCtrl      = TextEditingController();
  final _dinnerCtrl           = TextEditingController();
  final _bedtimeCtrl          = TextEditingController();

  String _selectedCategory = 'veg';
  String _selectedGoal = 'Fat Loss';
  bool _isSaving = false;

  final List<String> _goals = [
    'Fat Loss',
    'Muscle Gain',
    'Lean Muscle',
    'Bulking',
    'Maintenance',
    'General Fitness',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.planToEdit != null) {
      final p = widget.planToEdit!;
      _titleController.text = p.title;
      _caloriesController.text = p.calories.replaceAll(RegExp(r'[^\d]'), '');
      _proteinController.text = (p.macros?['protein'] ?? '150').toString().replaceAll(RegExp(r'[^\d]'), '');
      _carbsController.text = (p.macros?['carbs'] ?? '200').toString().replaceAll(RegExp(r'[^\d]'), '');
      _fatsController.text = (p.macros?['fats'] ?? '50').toString().replaceAll(RegExp(r'[^\d]'), '');
      _waterController.text = (p.waterIntake ?? '3.5').replaceAll(RegExp(r'[^\d\.]'), '');
      _notesController.text = p.notes ?? '';

      _earlyMorningCtrl.text = p.meals['early_morning'] ?? '';
      _breakfastCtrl.text    = p.meals['breakfast'] ?? '';
      _midMorningCtrl.text   = p.meals['mid_morning'] ?? '';
      _lunchCtrl.text        = p.meals['lunch'] ?? '';
      _postWorkoutCtrl.text  = p.meals['post_workout'] ?? '';
      _dinnerCtrl.text       = p.meals['dinner'] ?? '';
      _bedtimeCtrl.text      = p.meals['bedtime'] ?? '';

      if (['veg', 'nonveg', 'egg', 'vegan'].contains(p.category.toLowerCase())) {
        _selectedCategory = p.category.toLowerCase();
      }
      if (p.goalTag != null && _goals.contains(p.goalTag)) {
        _selectedGoal = p.goalTag!;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    _waterController.dispose();
    _notesController.dispose();
    _earlyMorningCtrl.dispose();
    _breakfastCtrl.dispose();
    _midMorningCtrl.dispose();
    _lunchCtrl.dispose();
    _postWorkoutCtrl.dispose();
    _dinnerCtrl.dispose();
    _bedtimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final gymId = await AuthService.getGymId() ?? 'gym_demo';
      final now   = DateTime.now();

      final mealsMap = <String, String>{};
      if (_earlyMorningCtrl.text.trim().isNotEmpty) mealsMap['early_morning'] = _earlyMorningCtrl.text.trim();
      if (_breakfastCtrl.text.trim().isNotEmpty)    mealsMap['breakfast']     = _breakfastCtrl.text.trim();
      if (_midMorningCtrl.text.trim().isNotEmpty)   mealsMap['mid_morning']   = _midMorningCtrl.text.trim();
      if (_lunchCtrl.text.trim().isNotEmpty)        mealsMap['lunch']         = _lunchCtrl.text.trim();
      if (_postWorkoutCtrl.text.trim().isNotEmpty)  mealsMap['post_workout']  = _postWorkoutCtrl.text.trim();
      if (_dinnerCtrl.text.trim().isNotEmpty)       mealsMap['dinner']        = _dinnerCtrl.text.trim();
      if (_bedtimeCtrl.text.trim().isNotEmpty)      mealsMap['bedtime']       = _bedtimeCtrl.text.trim();

      if (mealsMap.isEmpty) {
        mealsMap['lunch'] = 'Balanced High-Protein Nutrition Meal';
      }

      final items = mealsMap.entries.map((e) => '${_formatMealLabel(e.key)}: ${e.value}').toList();

      final macrosMap = <String, dynamic>{
        if (_proteinController.text.trim().isNotEmpty) 'protein': '${_proteinController.text.trim()}g',
        if (_carbsController.text.trim().isNotEmpty)   'carbs': '${_carbsController.text.trim()}g',
        if (_fatsController.text.trim().isNotEmpty)    'fats': '${_fatsController.text.trim()}g',
      };

      final waterText = _waterController.text.trim().isNotEmpty
          ? '${_waterController.text.trim()} Liters/day'
          : '3.5 - 4.0 Liters/day';

      if (widget.planToEdit != null) {
        final updates = {
          'title': _titleController.text.trim(),
          'type': _selectedCategory,
          'category': _selectedCategory,
          'goal_tag': _selectedGoal,
          'calories': '${_caloriesController.text.trim()} kcal',
          'macros': macrosMap.isNotEmpty ? macrosMap : null,
          'water_intake': waterText,
          'notes': _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
          'items': items,
          'meals': mealsMap,
        };
        final updated = await DbService.updateDietPlan(widget.planToEdit!.id, updates);
        if (mounted) Navigator.pop(context, updated);
      } else {
        final plan = DietPlan(
          id: '',
          gymId: gymId,
          title: _titleController.text.trim(),
          type: _selectedCategory,
          category: _selectedCategory,
          goalTag: _selectedGoal,
          calories: '${_caloriesController.text.trim()} kcal',
          macros: macrosMap.isNotEmpty ? macrosMap : null,
          waterIntake: waterText,
          notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
          items: items,
          meals: mealsMap,
          createdAt: now,
        );

        final created = await DbService.addDietPlan(plan);
        if (mounted) Navigator.pop(context, created);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save diet plan: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatMealLabel(String key) {
    switch (key) {
      case 'early_morning': return 'Early Morning';
      case 'breakfast': return 'Breakfast';
      case 'mid_morning': return 'Mid-Morning Snack';
      case 'lunch': return 'Lunch';
      case 'post_workout': return 'Post-Workout / Evening';
      case 'dinner': return 'Dinner';
      case 'bedtime': return 'Bedtime';
      default: return 'Meal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bgColor   = isDark ? AppTheme.darkBg          : const Color(0xFFF8FAFC);
    final inputFill = isDark ? AppTheme.darkSurfaceAlt   : Colors.white;
    final border    = isDark ? AppTheme.darkBorder       : AppTheme.lightBorder;
    final txt       = isDark ? AppTheme.darkTextPrimary  : AppTheme.lightTextPrimary;
    final txt2      = isDark ? AppTheme.darkTextSecondary: AppTheme.lightTextSecondary;
    final muted     = isDark ? AppTheme.darkTextMuted    : AppTheme.lightTextMuted;
    final barBg     = isDark ? AppTheme.darkSurface      : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: barBg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.planToEdit != null ? 'Edit Diet Template' : 'Create Master Diet Template',
          style: TextStyle(color: txt, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        iconTheme: IconThemeData(color: txt),
        centerTitle: false,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.restaurant_menu_rounded, color: AppTheme.success, size: 20),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Section 1: Overview & Goal ──
                      _sectionHeader(
                        icon: Icons.restaurant_menu_rounded,
                        iconBg: AppTheme.success.withValues(alpha: 0.12),
                        iconColor: AppTheme.success,
                        title: 'Plan Overview & Goal',
                        subtitle: 'Plan title, dietary category & primary goal',
                        txt: txt, txt2: txt2,
                      ),
                      const SizedBox(height: 16),

                      _label('Plan Title *', muted),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleController,
                        validator: InputValidator.validateName,
                        style: TextStyle(color: txt, fontWeight: FontWeight.w500),
                        decoration: _fieldDec(
                          hint: 'e.g. 2100 kcal Lean Mass Plan',
                          icon: Icons.edit_note_rounded,
                          iconColor: AppTheme.primary,
                          fillColor: inputFill, border: border, hintColor: muted,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Dietary Category Selector ──
                      _label('Dietary Category *', muted),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          _catChip('🥗 Pure Veg', 'veg', AppTheme.success, isDark, inputFill, border),
                          _catChip('🥚 Eggetarian', 'egg', const Color(0xFFF59E0B), isDark, inputFill, border),
                          _catChip('🍗 Non-Veg', 'nonveg', AppTheme.error, isDark, inputFill, border),
                          _catChip('🌱 Vegan', 'vegan', const Color(0xFF10B981), isDark, inputFill, border),
                        ],
                      ),

                      const SizedBox(height: 16),

                      _label('Primary Goal Target', muted),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedGoal,
                        dropdownColor: barBg,
                        style: TextStyle(color: txt, fontWeight: FontWeight.w600),
                        decoration: _fieldDec(
                          icon: Icons.track_changes_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          fillColor: inputFill, border: border, hintColor: muted,
                        ),
                        items: _goals.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedGoal = val);
                        },
                      ),

                      const SizedBox(height: 28),

                      // ── Section 2: Macro & Calorie Targets ──
                      _sectionHeader(
                        icon: Icons.local_fire_department_rounded,
                        iconBg: AppTheme.warning.withValues(alpha: 0.12),
                        iconColor: AppTheme.warning,
                        title: 'Calorie & Macro Targets',
                        subtitle: 'Set daily calories, protein, carbs & fats',
                        txt: txt, txt2: txt2,
                      ),
                      const SizedBox(height: 16),

                      Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _label('Target Calories *', muted),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _caloriesController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: InputValidator.validateAmount,
                              style: TextStyle(color: txt, fontWeight: FontWeight.w500),
                              decoration: _fieldDec(
                                hint: '2200', suffix: 'kcal',
                                icon: Icons.local_fire_department_rounded,
                                iconColor: AppTheme.warning,
                                fillColor: inputFill, border: border, hintColor: muted,
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _label('Protein (g)', muted),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _proteinController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: TextStyle(color: txt, fontWeight: FontWeight.w500),
                              decoration: _fieldDec(
                                hint: '150', suffix: 'g',
                                icon: Icons.fitness_center_rounded,
                                iconColor: AppTheme.primary,
                                fillColor: inputFill, border: border, hintColor: muted,
                              ),
                            ),
                          ]),
                        ),
                      ]),

                      const SizedBox(height: 12),

                      Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _label('Carbohydrates (g)', muted),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _carbsController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: TextStyle(color: txt, fontWeight: FontWeight.w500),
                              decoration: _fieldDec(
                                hint: '200', suffix: 'g',
                                icon: Icons.grain_rounded,
                                iconColor: const Color(0xFF8B5CF6),
                                fillColor: inputFill, border: border, hintColor: muted,
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _label('Fats (g)', muted),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _fatsController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: TextStyle(color: txt, fontWeight: FontWeight.w500),
                              decoration: _fieldDec(
                                hint: '50', suffix: 'g',
                                icon: Icons.opacity_rounded,
                                iconColor: const Color(0xFFEC4899),
                                fillColor: inputFill, border: border, hintColor: muted,
                              ),
                            ),
                          ]),
                        ),
                      ]),

                      const SizedBox(height: 12),

                      _label('Daily Water Hydration Target', muted),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _waterController,
                        style: TextStyle(color: txt, fontWeight: FontWeight.w500),
                        decoration: _fieldDec(
                          hint: '3.5', suffix: 'L/day',
                          icon: Icons.water_drop_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          fillColor: inputFill, border: border, hintColor: muted,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Section 3: 7-Meal Timetable Schedule ──
                      _sectionHeader(
                        icon: Icons.schedule_rounded,
                        iconBg: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        iconColor: const Color(0xFF3B82F6),
                        title: '7-Meal Flexible Schedule',
                        subtitle: 'Fill optional meal slots (empty slots auto-omitted)',
                        txt: txt, txt2: txt2,
                      ),
                      const SizedBox(height: 16),

                      _mealField('🌅 1. Early Morning / Pre-Workout', _earlyMorningCtrl, 'Warm lemon water, Black Coffee, 4 Almonds', inputFill, border, muted, txt),
                      const SizedBox(height: 12),
                      _mealField('🥣 2. Breakfast Menu', _breakfastCtrl, 'Oats with Whey Protein, Peanut Butter, Banana', inputFill, border, muted, txt),
                      const SizedBox(height: 12),
                      _mealField('🍏 3. Mid-Morning Snack', _midMorningCtrl, 'Green Tea, Roasted Chana / Boiled Eggs', inputFill, border, muted, txt),
                      const SizedBox(height: 12),
                      _mealField('🥗 4. Lunch Menu', _lunchCtrl, '200g Paneer/Grilled Chicken, Brown Rice, Salad', inputFill, border, muted, txt),
                      const SizedBox(height: 12),
                      _mealField('⚡ 5. Post-Workout / Evening Snack', _postWorkoutCtrl, '1 Scoop Whey Protein, Sprouts Salad', inputFill, border, muted, txt),
                      const SizedBox(height: 12),
                      _mealField('🍲 6. Dinner Menu', _dinnerCtrl, 'Tofu/Fish Curry, Mixed Veggies, Clear Soup', inputFill, border, muted, txt),
                      const SizedBox(height: 12),
                      _mealField('🌙 7. Bedtime Recovery', _bedtimeCtrl, 'Warm Turmeric Milk, Casein Protein', inputFill, border, muted, txt),

                      const SizedBox(height: 28),

                      // ── Section 4: Trainer Guidelines ──
                      _sectionHeader(
                        icon: Icons.assignment_turned_in_rounded,
                        iconBg: const Color(0xFF10B981).withValues(alpha: 0.12),
                        iconColor: const Color(0xFF10B981),
                        title: 'Trainer Notes & Guidelines',
                        subtitle: 'Special instructions, allergy warnings & rules',
                        txt: txt, txt2: txt2,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        style: TextStyle(color: txt),
                        decoration: _fieldDec(
                          hint: 'e.g. Avoid refined sugar & deep-fried foods. Drink 500ml water 30 mins before lunch.',
                          icon: Icons.speaker_notes_rounded,
                          iconColor: const Color(0xFF10B981),
                          fillColor: inputFill, border: border, hintColor: muted,
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // ── Sticky Bottom Save Button ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: barBg,
                border: Border(top: BorderSide(color: border)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              widget.planToEdit != null ? 'Save Template Changes' : 'Save Master Diet Template',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _catChip(String label, String value, Color color, bool isDark, Color inputFill, Color border) {
    final selected = _selectedCategory == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: isDark ? 0.25 : 0.12) : inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : border, width: selected ? 2 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _mealField(String label, TextEditingController ctrl, String hint, Color fillColor, Color border, Color muted, Color txt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, muted),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          maxLines: 2,
          style: TextStyle(color: txt, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: muted, fontSize: 12),
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader({
    required IconData icon, required Color iconBg, required Color iconColor,
    required String title, required String subtitle,
    required Color txt, required Color txt2,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: txt, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: txt2, fontSize: 12)),
        ]),
      ],
    );
  }

  Widget _label(String text, Color muted) => Text(
    text,
    style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3),
  );

  InputDecoration _fieldDec({
    String? hint, String? suffix,
    IconData? icon, Color? iconColor,
    required Color fillColor, required Color border, required Color hintColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: hintColor, fontSize: 13),
      suffixText: suffix,
      prefixIcon: icon != null ? Icon(icon, color: iconColor ?? AppTheme.primary, size: 20) : null,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
    );
  }
}
