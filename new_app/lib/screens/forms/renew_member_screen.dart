import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/member.dart';
import '../../models/payment.dart';
import '../../services/db_service.dart';
import '../../theme/app_theme.dart';

class RenewMemberScreen extends StatefulWidget {
  final Member member;
  const RenewMemberScreen({super.key, required this.member});

  @override
  State<RenewMemberScreen> createState() => _RenewMemberScreenState();
}

class _RenewMemberScreenState extends State<RenewMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  int _months = 1;
  final _amountController = TextEditingController(text: '1800');
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final amt       = double.tryParse(_amountController.text) ?? 1800.0;
      final baseStart = widget.member.subscriptionEnd.isBefore(DateTime.now())
          ? DateTime.now()
          : widget.member.subscriptionEnd;
      final newEnd    = DateTime(baseStart.year, baseStart.month + _months, baseStart.day);

      final updated = Member(
        id: widget.member.id,
        gymId: widget.member.gymId,
        name: widget.member.name,
        phone: widget.member.phone,
        planId: widget.member.planId,
        subscriptionStart: baseStart,
        subscriptionEnd: newEnd,
        amountPaid: widget.member.amountPaid + amt,
        createdAt: widget.member.createdAt,
      );

      await DbService.recordPayment(
        Payment(
          id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
          gymId: widget.member.gymId,
          memberId: widget.member.id,
          memberName: widget.member.name,
          amount: amt,
          planName: '$_months Month Renewal',
          paidAt: DateTime.now(),
        ),
      );

      if (mounted) Navigator.pop(context, updated);
    } catch (_) {
      final baseStart = widget.member.subscriptionEnd.isBefore(DateTime.now())
          ? DateTime.now()
          : widget.member.subscriptionEnd;
      final newEnd = DateTime(baseStart.year, baseStart.month + _months, baseStart.day);
      final fallback = Member(
        id: widget.member.id,
        gymId: widget.member.gymId,
        name: widget.member.name,
        phone: widget.member.phone,
        planId: widget.member.planId,
        subscriptionStart: baseStart,
        subscriptionEnd: newEnd,
        amountPaid: widget.member.amountPaid + 1800.0,
        createdAt: widget.member.createdAt,
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

    final isExpired    = widget.member.subscriptionEnd.isBefore(DateTime.now());
    final expFormatted = DateFormat('dd MMM yyyy').format(widget.member.subscriptionEnd);
    final initials     = widget.member.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: barBg,
        title: Text('Renew Membership', style: TextStyle(color: txt, fontWeight: FontWeight.w700)),
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
                      // ── Member Banner ──
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.25), blurRadius: 15, offset: const Offset(0, 8))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                              ),
                              child: Center(
                                child: Text(
                                  initials.isEmpty ? 'M' : initials,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.member.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text('+91 ${widget.member.phone}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isExpired ? AppTheme.error : Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isExpired ? '⚠️ EXPIRED on $expFormatted' : '✅ Expires $expFormatted',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Renewal Card ──
                      _sectionHeader('Renewal Extension', Icons.autorenew_rounded, txt),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: border),
                          boxShadow: isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))] : null,
                        ),
                        child: Column(children: [
                          DropdownButtonFormField<int>(
                            value: _months,
                            dropdownColor: cardBg,
                            style: TextStyle(color: txt, fontWeight: FontWeight.w500, fontSize: 14),
                            decoration: _fieldDec(
                              label: 'Renewal Duration',
                              icon: Icons.history_rounded,
                              iconColor: AppTheme.primary,
                              fillColor: inputFill,
                              hintColor: txt2,
                            ),
                            items: [
                              DropdownMenuItem(value: 1,  child: Text('1 Month Extension (₹1,800)',   style: TextStyle(color: txt))),
                              DropdownMenuItem(value: 2,  child: Text('2 Months Extension (₹3,600)',  style: TextStyle(color: txt))),
                              DropdownMenuItem(value: 3,  child: Text('3 Months Extension (₹5,400)',  style: TextStyle(color: txt))),
                              DropdownMenuItem(value: 6,  child: Text('6 Months Extension (₹10,800)', style: TextStyle(color: txt))),
                              DropdownMenuItem(value: 7,  child: Text('7 Months Extension (₹12,600)', style: TextStyle(color: txt))),
                              DropdownMenuItem(value: 12, child: Text('1 Year Extension (₹21,600)',   style: TextStyle(color: txt))),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _months = val;
                                  _amountController.text = (val * 1800).toString();
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: TextStyle(color: txt),
                            decoration: _fieldDec(
                              label: 'Renewal Fee Collected (₹)',
                              prefix: '₹ ',
                              icon: Icons.payments_rounded,
                              iconColor: AppTheme.success,
                              fillColor: inputFill,
                              hintColor: txt2,
                            ),
                          ),
                        ]),
                      ),
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
                      : const Text('Confirm Renewal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
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
    String? label, String? prefix,
    IconData? icon, Color? iconColor,
    required Color fillColor, required Color hintColor,
  }) {
    return InputDecoration(
      labelText: label,
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
