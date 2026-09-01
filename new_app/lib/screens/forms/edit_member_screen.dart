import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/member.dart';
import '../../services/db_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/input_validator.dart';

class EditMemberScreen extends StatefulWidget {
  final Member member;
  const EditMemberScreen({super.key, required this.member});

  @override
  State<EditMemberScreen> createState() => _EditMemberScreenState();
}

class _EditMemberScreenState extends State<EditMemberScreen> {
  final _formKey          = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _amountController;
  late DateTime _subscriptionEnd;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController   = TextEditingController(text: widget.member.name);
    _phoneController  = TextEditingController(text: widget.member.phone);
    _amountController = TextEditingController(text: widget.member.amountPaid.toStringAsFixed(0));
    _subscriptionEnd  = widget.member.subscriptionEnd;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectExpiryDate(BuildContext context, bool isDark) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _subscriptionEnd,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isDark
              ? const ColorScheme.dark(primary: AppTheme.primary)
              : const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _subscriptionEnd) {
      setState(() => _subscriptionEnd = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final updatedName = _nameController.text.trim();
    final updatedPhone = InputValidator.sanitizePhone(_phoneController.text);
    final updatedAmount = double.tryParse(_amountController.text.trim()) ?? widget.member.amountPaid;

    final updatedMember = Member(
      id: widget.member.id,
      gymId: widget.member.gymId,
      name: updatedName,
      phone: updatedPhone,
      planId: widget.member.planId,
      subscriptionStart: widget.member.subscriptionStart,
      subscriptionEnd: _subscriptionEnd,
      amountPaid: updatedAmount,
      createdAt: widget.member.createdAt,
    );

    try {
      await DbService.updateMember(widget.member.id, {
        'name': updatedName,
        'phone': updatedPhone,
        'subscription_end': _subscriptionEnd.toIso8601String(),
        'amount_paid': updatedAmount,
      });
      if (mounted) Navigator.pop(context, updatedMember);
    } catch (_) {
      if (mounted) Navigator.pop(context, updatedMember);
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
        title: Text('Edit Member Profile', style: TextStyle(color: txt, fontWeight: FontWeight.w700, fontSize: 17)),
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
            child: const Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 20),
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
                      // ── Section 1: Member Information ──
                      _sectionHeader(
                        icon: Icons.person_outline_rounded,
                        iconBg: AppTheme.primary.withValues(alpha: 0.12),
                        iconColor: AppTheme.primary,
                        title: 'Edit Personal Details',
                        subtitle: 'Update member name and contact number',
                        txt: txt, txt2: txt2,
                      ),
                      const SizedBox(height: 16),

                      _label('Full Name *', muted),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        validator: InputValidator.validateName,
                        style: TextStyle(color: txt, fontWeight: FontWeight.w500),
                        decoration: _fieldDec(
                          hint: 'e.g. Rahul Sharma',
                          icon: Icons.person_rounded,
                          iconColor: AppTheme.primary,
                          fillColor: inputFill,
                          border: border,
                          hintColor: muted,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _label('10-Digit Mobile Number *', muted),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: InputValidator.validatePhone,
                        style: TextStyle(color: txt, fontWeight: FontWeight.w500),
                        decoration: _fieldDec(
                          hint: 'Enter 10-digit mobile number',
                          icon: Icons.phone_android_rounded,
                          iconColor: AppTheme.primary,
                          fillColor: inputFill,
                          border: border,
                          hintColor: muted,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Section 2: Subscription & Billing ──
                      _sectionHeader(
                        icon: Icons.card_membership_rounded,
                        iconBg: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                        iconColor: const Color(0xFF0EA5E9),
                        title: 'Subscription & Expiry Date',
                        subtitle: 'Modify validity expiry date or recorded amount',
                        txt: txt, txt2: txt2,
                      ),
                      const SizedBox(height: 16),

                      _label('Membership Expiry Date *', muted),
                      const SizedBox(height: 6),

                      GestureDetector(
                        onTap: () => _selectExpiryDate(context, isDark),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: inputFill,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.event_rounded, color: AppTheme.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Expires on ${DateFormat('EEEE, dd MMM yyyy').format(_subscriptionEnd)}',
                                      style: TextStyle(color: txt, fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tap to change expiry date',
                                      style: TextStyle(color: txt2, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.calendar_month_rounded, color: txt2, size: 20),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      _label('Total Amount Collected (₹) *', muted),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: InputValidator.validateAmount,
                        style: TextStyle(color: txt, fontWeight: FontWeight.w600, fontSize: 16),
                        decoration: _fieldDec(
                          icon: Icons.currency_rupee_rounded,
                          iconColor: AppTheme.success,
                          fillColor: inputFill,
                          border: border,
                          hintColor: muted,
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Update Member Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: txt, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: txt2, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _label(String text, Color muted) => Text(
    text,
    style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3),
  );

  InputDecoration _fieldDec({
    String? hint, IconData? icon, Color? iconColor,
    required Color fillColor, required Color border, required Color hintColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: hintColor, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: iconColor ?? AppTheme.primary, size: 20) : null,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.error),
      ),
    );
  }
}
