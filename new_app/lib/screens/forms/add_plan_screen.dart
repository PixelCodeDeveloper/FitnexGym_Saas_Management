import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/subscription_plan.dart';
import '../../services/db_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/input_validator.dart';

class AddPlanScreen extends StatefulWidget {
  const AddPlanScreen({super.key});

  @override
  State<AddPlanScreen> createState() => _AddPlanScreenState();
}

class _AddPlanScreenState extends State<AddPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  int _durationDays = 30;
  bool _isSaving = false;

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
      final now = DateTime.now();
      final plan = SubscriptionPlan(
        id: 'plan_${now.millisecondsSinceEpoch}',
        gymId: gymId,
        name: _nameController.text.trim(),
        durationDays: _durationDays,
        price: double.parse(_priceController.text.trim()),
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        createdAt: now,
      );

      final created = await DbService.addPlan(plan);
      if (mounted) Navigator.pop(context, created);
    } catch (_) {
      final now = DateTime.now();
      final fallback = SubscriptionPlan(
        id: 'plan_${now.millisecondsSinceEpoch}',
        gymId: 'gym_demo',
        name: _nameController.text.trim(),
        durationDays: _durationDays,
        price: double.tryParse(_priceController.text.trim()) ?? 1500.0,
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        createdAt: now,
      );
      if (mounted) Navigator.pop(context, fallback);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Create Membership Package'),
        centerTitle: false,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Card 1: Package Specifications ──
                      _buildSectionHeader('Package Details', Icons.card_membership_rounded),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              validator: InputValidator.validateName,
                              decoration: InputDecoration(
                                labelText: 'Plan Name *',
                                hintText: 'e.g. 6 Months Gold Package',
                                prefixIcon: const Icon(Icons.stars_rounded, color: AppTheme.primary),
                                filled: true,
                                fillColor: AppTheme.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: InputValidator.validateAmount,
                              decoration: InputDecoration(
                                labelText: 'Package Price (₹) *',
                                prefixText: '₹ ',
                                hintText: 'e.g. 7500',
                                prefixIcon: const Icon(Icons.sell_rounded, color: AppTheme.success),
                                filled: true,
                                fillColor: AppTheme.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<int>(
                              value: _durationDays,
                              decoration: InputDecoration(
                                labelText: 'Validity Period',
                                prefixIcon: const Icon(Icons.timer_rounded, color: AppTheme.accent),
                                filled: true,
                                fillColor: AppTheme.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 30, child: Text('30 Days (1 Month)')),
                                DropdownMenuItem(value: 90, child: Text('90 Days (3 Months)')),
                                DropdownMenuItem(value: 180, child: Text('180 Days (6 Months)')),
                                DropdownMenuItem(value: 365, child: Text('365 Days (1 Year)')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _durationDays = val);
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Card 2: Features / Description ──
                      _buildSectionHeader('Description & Features', Icons.description_rounded),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: TextFormField(
                          controller: _descController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'e.g. Full access to weight floor, cardio zone, and complimentary steam bath.',
                            prefixIcon: const Icon(Icons.format_list_bulleted_rounded, color: AppTheme.primary),
                            filled: true,
                            fillColor: AppTheme.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Sticky Bottom Action Bar ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Save Membership Plan',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
