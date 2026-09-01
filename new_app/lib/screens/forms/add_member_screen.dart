import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/member.dart';
import '../../services/db_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/input_validator.dart';

class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController(text: '1800');
  int _selectedDurationMonths = 1;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final gymId = await AuthService.getGymId() ?? 'gym_demo';
      final now = DateTime.now();
      final member = Member(
        id: 'mem_${now.millisecondsSinceEpoch}',
        gymId: gymId,
        name: _nameController.text.trim(),
        phone: InputValidator.sanitizePhone(_phoneController.text),
        subscriptionStart: now,
        subscriptionEnd: DateTime(now.year, now.month + _selectedDurationMonths, now.day),
        amountPaid: double.tryParse(_amountController.text.trim()) ?? 1800.0,
        createdAt: now,
      );

      final created = await DbService.addMember(member);
      if (mounted) Navigator.pop(context, created);
    } catch (_) {
      final now = DateTime.now();
      final fallbackMember = Member(
        id: 'mem_${now.millisecondsSinceEpoch}',
        gymId: 'gym_demo',
        name: _nameController.text.trim(),
        phone: InputValidator.sanitizePhone(_phoneController.text),
        subscriptionStart: now,
        subscriptionEnd: DateTime(now.year, now.month + _selectedDurationMonths, now.day),
        amountPaid: double.tryParse(_amountController.text.trim()) ?? 1800.0,
        createdAt: now,
      );
      if (mounted) Navigator.pop(context, fallbackMember);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Add New Member'),
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
                      // ── Card 1: Personal Details ──
                      _buildSectionHeader('Personal Information', Icons.person_outline_rounded),
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
                                labelText: 'Full Name *',
                                hintText: 'e.g. Rahul Sharma',
                                prefixIcon: const Icon(Icons.person_rounded, color: AppTheme.primary),
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
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: InputValidator.validatePhone,
                              decoration: InputDecoration(
                                labelText: '10-Digit Mobile Number *',
                                hintText: 'e.g. 9876543210',
                                prefixText: '+91 ',
                                prefixIcon: const Icon(Icons.phone_android_rounded, color: AppTheme.primary),
                                filled: true,
                                fillColor: AppTheme.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Card 2: Package & Billing ──
                      _buildSectionHeader('Membership & Payment', Icons.card_membership_rounded),
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
                            DropdownButtonFormField<int>(
                              value: _selectedDurationMonths,
                              decoration: InputDecoration(
                                labelText: 'Membership Duration',
                                prefixIcon: const Icon(Icons.timelapse_rounded, color: AppTheme.accent),
                                filled: true,
                                fillColor: AppTheme.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('1 Month Package (₹1,800)')),
                                DropdownMenuItem(value: 3, child: Text('3 Months Package (₹5,400)')),
                                DropdownMenuItem(value: 6, child: Text('6 Months Package (₹10,800)')),
                                DropdownMenuItem(value: 12, child: Text('1 Year Package (₹21,600)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedDurationMonths = val;
                                    _amountController.text = (val * 1800).toString();
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: InputValidator.validateAmount,
                              decoration: InputDecoration(
                                labelText: 'Amount Collected (₹) *',
                                prefixText: '₹ ',
                                prefixIcon: const Icon(Icons.payments_rounded, color: AppTheme.success),
                                filled: true,
                                fillColor: AppTheme.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
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
                          'Save & Add Member',
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
