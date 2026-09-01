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
      final amt = double.tryParse(_amountController.text) ?? 1800.0;
      final baseStart = widget.member.subscriptionEnd.isBefore(DateTime.now())
          ? DateTime.now()
          : widget.member.subscriptionEnd;
      final newEnd = DateTime(baseStart.year, baseStart.month + _months, baseStart.day);

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
    final isExpired = widget.member.subscriptionEnd.isBefore(DateTime.now());
    final expFormatted = DateFormat('dd MMM yyyy').format(widget.member.subscriptionEnd);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Renew Membership'),
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
                      // ── Member Overview Banner Card ──
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.25),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white,
                              child: Text(
                                widget.member.name.isNotEmpty
                                    ? widget.member.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
                                    : 'M',
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.member.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '+91 ${widget.member.phone}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isExpired ? AppTheme.error : Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isExpired ? 'EXPIRED on $expFormatted' : 'Expires on $expFormatted',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Renewal Options Card ──
                      _buildSectionHeader('Renewal Extension', Icons.autorenew_rounded),
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
                              value: _months,
                              decoration: InputDecoration(
                                labelText: 'Renewal Duration',
                                prefixIcon: const Icon(Icons.history_rounded, color: AppTheme.primary),
                                filled: true,
                                fillColor: AppTheme.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('1 Month Extension (₹1,800)')),
                                DropdownMenuItem(value: 3, child: Text('3 Months Extension (₹5,400)')),
                                DropdownMenuItem(value: 6, child: Text('6 Months Extension (₹10,800)')),
                                DropdownMenuItem(value: 12, child: Text('1 Year Extension (₹21,600)')),
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
                              decoration: InputDecoration(
                                labelText: 'Renewal Fee Collected (₹)',
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
                          'Confirm Membership Renewal',
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
