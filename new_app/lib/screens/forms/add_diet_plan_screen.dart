import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/diet_plan.dart';
import '../../services/db_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/input_validator.dart';

class AddDietPlanScreen extends StatefulWidget {
  const AddDietPlanScreen({super.key});

  @override
  State<AddDietPlanScreen> createState() => _AddDietPlanScreenState();
}

class _AddDietPlanScreenState extends State<AddDietPlanScreen> {
  final _formKey              = GlobalKey<FormState>();
  final _titleController      = TextEditingController();
  final _caloriesController   = TextEditingController(text: '2200');
  final _breakfastController  = TextEditingController();
  final _lunchController      = TextEditingController();
  final _dinnerController     = TextEditingController();
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
      final now   = DateTime.now();
      final items = <String>[];
      if (_breakfastController.text.trim().isNotEmpty) items.add('Breakfast: ${_breakfastController.text.trim()}');
      if (_lunchController.text.trim().isNotEmpty)     items.add('Lunch: ${_lunchController.text.trim()}');
      if (_dinnerController.text.trim().isNotEmpty)    items.add('Dinner: ${_dinnerController.text.trim()}');
      if (items.isEmpty) items.add('Balanced High-Protein Meal Plan');

      final plan = DietPlan(
        id: '',
        gymId: gymId,
        title: _titleController.text.trim(),
        type: _selectedType,
        calories: '${_caloriesController.text.trim()} kcal',
        items: items,
        createdAt: now,
      );
      final created = await DbService.addDietPlan(plan);
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save diet plan to database: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        title: Text('Create Diet Plan', style: TextStyle(color: txt, fontWeight: FontWeight.w700, fontSize: 17)),
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

                      // ── Section 1: Plan Overview ──
                      _sectionHeader(
                        icon: Icons.restaurant_menu_rounded,
                        iconBg: AppTheme.success.withValues(alpha: 0.12),
                        iconColor: AppTheme.success,
                        title: 'Plan Overview',
                        subtitle: 'Set the plan name, type and calorie target',
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
                          hint: 'e.g. Lean Muscle Gain Plan',
                          icon: Icons.edit_note_rounded,
                          iconColor: AppTheme.primary,
                          fillColor: inputFill, border: border, hintColor: muted,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Diet Type Chips ──
                      _label('Diet Category', muted),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _typeChip(
                          label: 'Vegetarian 🥗',
                          value: 'veg',
                          color: AppTheme.success,
                          isDark: isDark,
                          inputFill: inputFill, border: border, txt: txt, txt2: txt2,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _typeChip(
                          label: 'Non-Veg 🍗',
                          value: 'nonveg',
                          color: AppTheme.error,
                          isDark: isDark,
                          inputFill: inputFill, border: border, txt: txt, txt2: txt2,
                        )),
                      ]),

                      const SizedBox(height: 16),

                      _label('Target Calories (kcal) *', muted),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _caloriesController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: InputValidator.validateAmount,
                        style: TextStyle(color: txt, fontWeight: FontWeight.w500),
                        decoration: _fieldDec(
                          hint: 'e.g. 2200',
                          suffix: 'kcal',
                          icon: Icons.local_fire_department_rounded,
                          iconColor: AppTheme.warning,
                          fillColor: inputFill, border: border, hintColor: muted,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Section 2: Meal Schedule ──
                      _sectionHeader(
                        icon: Icons.flatware_rounded,
                        iconBg: AppTheme.accent.withValues(alpha: 0.12),
                        iconColor: AppTheme.accent,
                        title: 'Meal Schedule & Menu',
                        subtitle: 'Fill breakfast, lunch, dinner menus',
                        txt: txt, txt2: txt2,
                      ),
                      const SizedBox(height: 16),

                      _label('Breakfast Menu', muted),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _breakfastController,
                        maxLines: 2,
                        style: TextStyle(color: txt),
                        decoration: _fieldDec(
                          hint: 'e.g. Oats, Peanut Butter, 4 Egg Whites, Almonds',
                          icon: Icons.free_breakfast_rounded,
                          iconColor: AppTheme.warning,
                          fillColor: inputFill, border: border, hintColor: muted,
                        ),
                      ),

                      const SizedBox(height: 16),

                      _label('Lunch Menu', muted),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _lunchController,
                        maxLines: 2,
                        style: TextStyle(color: txt),
                        decoration: _fieldDec(
                          hint: 'e.g. 200g Grilled Chicken/Paneer, Brown Rice, Salad',
                          icon: Icons.lunch_dining_rounded,
                          iconColor: AppTheme.accent,
                          fillColor: inputFill, border: border, hintColor: muted,
                        ),
                      ),

                      const SizedBox(height: 16),

                      _label('Dinner Menu', muted),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _dinnerController,
                        maxLines: 2,
                        style: TextStyle(color: txt),
                        decoration: _fieldDec(
                          hint: 'e.g. Baked Fish/Tofu, Mixed Veggies, Clear Soup',
                          icon: Icons.dinner_dining_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          fillColor: inputFill, border: border, hintColor: muted,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: muted),
                        const SizedBox(width: 6),
                        Text('Plan will be available to assign to members', style: TextStyle(color: muted, fontSize: 12)),
                      ]),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // ── Sticky Bottom Button ──
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Save Diet Plan Template', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
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

  // Type chip (Veg / Non-Veg)
  Widget _typeChip({
    required String label, required String value, required Color color,
    required bool isDark, required Color inputFill, required Color border,
    required Color txt, required Color txt2,
  }) {
    final selected = _selectedType == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: isDark ? 0.2 : 0.1) : inputFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : border, width: selected ? 2 : 1),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : txt2,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
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
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.error, width: 2)),
    );
  }
}
