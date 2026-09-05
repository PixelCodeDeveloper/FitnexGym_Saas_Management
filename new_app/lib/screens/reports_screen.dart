import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payment.dart';
import '../services/db_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = true;
  double _monthlyRevenue = 0.0;
  List<Payment> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final rev = await DbService.getMonthlyRevenue();
      final list = await DbService.getPayments();
      setState(() {
        _monthlyRevenue = rev;
        _payments = list;
      });
    } catch (_) {
      setState(() {
        _monthlyRevenue = 0.0;
        _payments = [];
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final bgColor  = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final border   = isDark ? const Color(0xFF162234) : const Color(0xFFE2E8F0);
    final txt      = isDark ? Colors.white : const Color(0xFF0F172A);
    final txt2     = isDark ? const Color(0xFF8896B3) : const Color(0xFF334155);
    final muted    = isDark ? const Color(0xFF64748B) : const Color(0xFF475569);
    const activeCyan = Color(0xFF00E5C0);

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: activeCyan, strokeWidth: 2))
          : RefreshIndicator(
              color: activeCyan,
              onRefresh: _loadReportData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Revenue Summary Header (Flat layout) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly Revenue',
                            style: TextStyle(color: txt2, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${_monthlyRevenue.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: activeCyan,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    Divider(height: 1, color: border),
                    const SizedBox(height: 20),

                    Text(
                      'Payment History',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: txt),
                    ),
                    const SizedBox(height: 12),

                    if (_payments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: txt2.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(Icons.receipt_long_outlined, size: 28, color: muted),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No payment records found',
                                style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Payments collected from members will appear here.',
                                style: TextStyle(color: muted, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _payments.length,
                        separatorBuilder: (_, idx) => Divider(height: 1, color: border),
                        itemBuilder: (context, i) {
                          final p = _payments[i];
                          return _paymentTile(
                            p.memberName ?? 'Member',
                            '₹${p.amount.toStringAsFixed(0)}',
                            p.planName ?? 'Subscription Payment',
                            DateFormat('dd MMM yyyy').format(p.paidAt),
                            txt, txt2, muted,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _paymentTile(String name, String amount, String plan, String time, Color txt, Color txt2, Color muted) {
    const activeCyan = Color(0xFF00E5C0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_downward_rounded,
              color: Color(0xFF22C55E),
              size: 16,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: txt,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  plan,
                  style: TextStyle(
                    color: txt2,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: activeCyan,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
