import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/subscription_plan.dart';
import '../../services/db_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/input_validator.dart';

class _DurationOption {
  final int days;
  final String title;
  final String subtitle;
  const _DurationOption(this.days, this.title, this.subtitle);
}

class AddPlanScreen extends StatefulWidget {
  const AddPlanScreen({super.key});

  @override
  State<AddPlanScreen> createState() => _AddPlanScreenState();
}

class _AddPlanScreenState extends State<AddPlanScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _nameController  = TextEditingController();
  final _priceController = TextEditingController();
  final _descController  = TextEditingController();
  bool _isSaving = false;

  final List<_DurationOption> _durations = const [
    _DurationOption(30,  '1 Month Plan',   'Valid for 30 days'),
    _DurationOption(60,  '2 Months Plan',  'Valid for 60 days'),
    _DurationOption(90,  '3 Months Plan',  'Valid for 90 days'),
    _DurationOption(180, '6 Months Plan',  'Valid for 180 days'),
    _DurationOption(210, '7 Months Plan',  'Valid for 210 days'),
    _DurationOption(365, '1 Year Plan',    'Valid for 365 days'),
  ];
  int _selectedDuration = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final gymId = await AuthService.getGymId() ?? 'gym_demo';
      final now   = DateTime.now();
      final plan  = SubscriptionPlan(
        id: '',
        gymId: gymId,
        name: _nameController.text.trim(),
        durationDays: _durations[_selectedDuration].days,
        price: double.parse(_priceController.text.trim()),
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        createdAt: now,
      );
      final created = await DbService.addPlan(plan);
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save plan to database: $e'),
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
        title: Text('Create Membership Plan', style: TextStyle(color: txt, fontWeight: FontWeight.w700, fontSize: 17)),
        iconTheme: IconThemeData(color: txt),
        centerTitle: false,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.card_membership_rounded, color: AppTheme.primary, size: 20),
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
                      // ── Section 1: Package Details ──
                      _sectionHeader(
                        icon: Icons.card_membership_rounded,
                        iconBg: AppTheme.primary.withValues(alpha: 0.12),
                        iconColor: AppTheme.primary,
                        title: 'Package Details',
                        subtitle: 'Set the plan name, price and validity',
                        txt: txt, txt2: txt2,
                      ),
                      const SizedBox(height: 16),

                      _label('Plan Name *', muted),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        validator: InputValidator.validateName,
                        style: TextStyle(color: txt, fontWeight: FontWeight.w500),
                        decoration: _fieldDec(hint: 'e.g. 6 Months Gold Package', icon: Icons.stars_rounded, iconColor: AppTheme.primary, fillColor: inputFill, border: border, hintColor: muted),
                      ),

                      const SizedBox(height: 16),

                      _label('Package Price (₹) *', muted),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: InputValidator.validateAmount,
                        style: TextStyle(color: txt, fontWeight: FontWeight.w600, fontSize: 16),
                        decoration: _fieldDec(hint: 'e.g. 7500', prefix: '₹ ', icon: Icons.sell_rounded, iconColor: AppTheme.success, fillColor: inputFill, border: border, hintColor: muted),
                      ),

                      const SizedBox(height: 16),

                      _label('Validity Period *', muted),
                      const SizedBox(height: 8),

                      // ── Custom Duration Picker ──
                      GestureDetector(
                        onTap: () => _showDurationPicker(context, isDark, barBg, border, txt, txt2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: inputFill,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.timer_rounded, color: AppTheme.accent, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(_durations[_selectedDuration].title, style: TextStyle(color: txt, fontWeight: FontWeight.w700, fontSize: 14)),
                                  Text(_durations[_selectedDuration].subtitle, style: TextStyle(color: txt2, fontSize: 12)),
                                ]),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded, color: txt2, size: 20),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Section 2: Description ──
                      _sectionHeader(
                        icon: Icons.description_rounded,
                        iconBg: AppTheme.accent.withValues(alpha: 0.12),
                        iconColor: AppTheme.accent,
                        title: 'Description & Features',
                        subtitle: 'Optional — describe what this plan includes',
                        txt: txt, txt2: txt2,
                      ),
                      const SizedBox(height: 16),

                      _label('Plan Description', muted),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descController,
                        maxLines: 3,
                        style: TextStyle(color: txt),
                        decoration: _fieldDec(
                          hint: 'e.g. Full access to weight floor, cardio zone, complimentary steam bath.',
                          icon: Icons.format_list_bulleted_rounded,
                          iconColor: AppTheme.primary,
                          fillColor: inputFill, border: border, hintColor: muted,
                        ),
                      ),

                      const SizedBox(height: 12),
                      Row(children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: muted),
                        const SizedBox(width: 6),
                        Text('Plan will be available when adding members', style: TextStyle(color: muted, fontSize: 12)),
                      ]),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(color: barBg, border: Border(top: BorderSide(color: border))),
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
                            Text('Save Membership Plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
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

  void _showDurationPicker(BuildContext context, bool isDark, Color selBg, Color border, Color txt, Color txt2) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(color: selBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2))),
            Text('Select Validity Period', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: txt)),
            const SizedBox(height: 16),
            ...List.generate(_durations.length, (i) {
              final d = _durations[i];
              final selected = _selectedDuration == i;
              return GestureDetector(
                onTap: () { setState(() => _selectedDuration = i); Navigator.pop(context); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? AppTheme.primary : border, width: selected ? 1.5 : 1),
                  ),
                  child: Row(children: [
                    Icon(Icons.timer_rounded, color: selected ? AppTheme.primary : txt2, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.title, style: TextStyle(color: selected ? AppTheme.primary : txt, fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(d.subtitle, style: TextStyle(color: txt2, fontSize: 12)),
                    ])),
                    if (selected) const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader({required IconData icon, required Color iconBg, required Color iconColor, required String title, required String subtitle, required Color txt, required Color txt2}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: 20)),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: txt, fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(color: txt2, fontSize: 12)),
      ]),
    ]);
  }

  Widget _label(String text, Color muted) => Text(text, style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3));

  InputDecoration _fieldDec({String? hint, String? prefix, IconData? icon, Color? iconColor, required Color fillColor, required Color border, required Color hintColor}) {
    return InputDecoration(
      hintText: hint, prefixText: prefix,
      hintStyle: TextStyle(color: hintColor, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: iconColor ?? AppTheme.primary, size: 20) : null,
      filled: true, fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.error, width: 2)),
    );
  }
}
