import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/lead.dart';
import '../../services/db_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/input_validator.dart';

class AddLeadScreen extends StatefulWidget {
  const AddLeadScreen({super.key});

  @override
  State<AddLeadScreen> createState() => _AddLeadScreenState();
}

class _AddLeadScreenState extends State<AddLeadScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _nameController  = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController  = TextEditingController();
  LeadStatus _selectedStatus = LeadStatus.hot;
  DateTime _followUpDate     = DateTime.now().add(const Duration(days: 2));
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isDark) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _followUpDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isDark
              ? const ColorScheme.dark(primary: AppTheme.primary)
              : const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _followUpDate) {
      setState(() => _followUpDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final gymId = await AuthService.getGymId() ?? 'gym_demo';
      final now   = DateTime.now();
      final lead  = Lead(
        id: 'lead_${now.millisecondsSinceEpoch}',
        gymId: gymId,
        name: _nameController.text.trim(),
        phone: InputValidator.sanitizePhone(_phoneController.text),
        note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
        status: _selectedStatus,
        followUpDate: _followUpDate,
        createdAt: now,
      );
      final created = await DbService.addLead(lead);
      if (mounted) Navigator.pop(context, created);
    } catch (_) {
      final now      = DateTime.now();
      final fallback = Lead(
        id: 'lead_${now.millisecondsSinceEpoch}',
        gymId: 'gym_demo',
        name: _nameController.text.trim(),
        phone: InputValidator.sanitizePhone(_phoneController.text),
        note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
        status: _selectedStatus,
        followUpDate: _followUpDate,
        createdAt: now,
      );
      if (mounted) Navigator.pop(context, fallback);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bgColor   = isDark ? AppTheme.darkBg          : AppTheme.lightBg;
    final cardBg    = isDark ? AppTheme.darkCard         : AppTheme.lightSurface;
    final inputFill = isDark ? AppTheme.darkSurfaceAlt   : AppTheme.lightSurfaceAlt;
    final border    = isDark ? AppTheme.darkBorder       : AppTheme.lightBorder;
    final txt       = isDark ? AppTheme.darkTextPrimary  : AppTheme.lightTextPrimary;
    final txt2      = isDark ? AppTheme.darkTextSecondary: AppTheme.lightTextSecondary;
    final barBg     = isDark ? AppTheme.darkSurface      : AppTheme.lightSurface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: barBg,
        title: Text('Add Sales Lead', style: TextStyle(color: txt, fontWeight: FontWeight.w700)),
        iconTheme: IconThemeData(color: txt),
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
                      // ── Card 1: Contact Info ──
                      _sectionHeader('Contact Information', Icons.person_add_rounded, txt),
                      const SizedBox(height: 10),
                      _card(isDark: isDark, cardBg: cardBg, border: border, child: Column(children: [
                        TextFormField(
                          controller: _nameController,
                          validator: InputValidator.validateName,
                          style: TextStyle(color: txt),
                          decoration: _fieldDec(
                            label: 'Lead Name *', hint: 'e.g. Sanjay Yadav',
                            icon: Icons.person_rounded, iconColor: AppTheme.primary,
                            fillColor: inputFill, hintColor: txt2,
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
                          style: TextStyle(color: txt),
                          decoration: _fieldDec(
                            label: '10-Digit Mobile *', hint: 'e.g. 9123456780',
                            prefix: '+91 ',
                            icon: Icons.phone_android_rounded, iconColor: AppTheme.primary,
                            fillColor: inputFill, hintColor: txt2,
                          ),
                        ),
                      ])),

                      const SizedBox(height: 24),

                      // ── Card 2: Priority & Follow-Up ──
                      _sectionHeader('Lead Priority & Follow-Up', Icons.tune_rounded, txt),
                      const SizedBox(height: 10),
                      _card(isDark: isDark, cardBg: cardBg, border: border, child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select Priority Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: txt2)),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: _statusChip('Hot 🔥',  LeadStatus.hot,  AppTheme.error,   isDark, inputFill, border)),
                            const SizedBox(width: 8),
                            Expanded(child: _statusChip('Warm ☀️', LeadStatus.warm, AppTheme.warning,  isDark, inputFill, border)),
                            const SizedBox(width: 8),
                            Expanded(child: _statusChip('Cold ❄️', LeadStatus.cold, AppTheme.primary,  isDark, inputFill, border)),
                          ]),
                          const SizedBox(height: 18),
                          // Follow-up date picker
                          InkWell(
                            onTap: () => _selectDate(context, isDark),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: inputFill,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: border),
                              ),
                              child: Row(children: [
                                const Icon(Icons.event_rounded, color: AppTheme.primary),
                                const SizedBox(width: 12),
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Follow-Up Date', style: TextStyle(fontSize: 12, color: txt2)),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('EEEE, dd MMM yyyy').format(_followUpDate),
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: txt),
                                  ),
                                ]),
                                const Spacer(),
                                Icon(Icons.arrow_drop_down_rounded, color: txt2),
                              ]),
                            ),
                          ),
                        ],
                      )),

                      const SizedBox(height: 24),

                      // ── Card 3: Notes ──
                      _sectionHeader('Inquiry Notes', Icons.sticky_note_2_rounded, txt),
                      const SizedBox(height: 10),
                      _card(isDark: isDark, cardBg: cardBg, border: border, child: TextFormField(
                        controller: _noteController,
                        maxLines: 3,
                        style: TextStyle(color: txt),
                        decoration: _fieldDec(
                          hint: 'e.g. Visited gym at 8 AM. Interested in annual plan.',
                          icon: Icons.note_alt_rounded, iconColor: AppTheme.primary,
                          fillColor: inputFill, hintColor: txt2,
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ),

            // ── Sticky Bottom Bar ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: barBg,
                border: Border(top: BorderSide(color: border)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06), blurRadius: 10, offset: const Offset(0, -4))],
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
                      : const Text('Save Sales Lead', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, LeadStatus status, Color color, bool isDark, Color inputFill, Color border) {
    final sel = _selectedStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: isDark ? 0.2 : 0.12) : inputFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? color : border, width: sel ? 2 : 1),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: sel ? color : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _card({required bool isDark, required Color cardBg, required Color border, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))] : null,
      ),
      child: child,
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color txt) => Row(
    children: [
      Icon(icon, size: 20, color: AppTheme.primary),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: txt)),
    ],
  );

  InputDecoration _fieldDec({
    String? label, String? hint, String? prefix,
    IconData? icon, Color? iconColor,
    required Color fillColor, required Color hintColor,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix,
      prefixIcon: icon != null ? Icon(icon, color: iconColor ?? AppTheme.primary) : null,
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.error)),
    );
  }
}
