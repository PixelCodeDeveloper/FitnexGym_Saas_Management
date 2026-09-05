import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead.dart';
import '../models/member.dart';
import '../models/subscription_plan.dart';
import '../models/payment.dart';
import '../services/db_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'forms/add_lead_screen.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  bool _isLoading = true;
  List<Lead> _leads = [];

  @override
  void initState() {
    super.initState();
    _loadLeads();
  }

  Future<void> _loadLeads() async {
    setState(() => _isLoading = true);
    try {
      _leads = await DbService.getLeads();
    } catch (_) {
      _leads = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(LeadStatus s) {
    switch (s) {
      case LeadStatus.hot:  return AppTheme.error;
      case LeadStatus.warm: return AppTheme.warning;
      case LeadStatus.cold: return AppTheme.primary;
    }
  }

  String _statusLabel(LeadStatus s) {
    switch (s) {
      case LeadStatus.hot:  return '🔥 Hot';
      case LeadStatus.warm: return '☀️ Warm';
      case LeadStatus.cold: return '❄️ Cold';
    }
  }

  Future<void> _openAddLeadScreen() async {
    final newLead = await Navigator.push<Lead>(
      context,
      MaterialPageRoute(builder: (_) => const AddLeadScreen()),
    );
    if (newLead != null) setState(() => _leads.insert(0, newLead));
  }

  Future<void> _makeCall(Lead lead) async {
    final url = Uri.parse('tel:+91${lead.phone}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not place call')));
    }
  }

  Future<void> _convertToMember(Lead lead) async {
    List<SubscriptionPlan> dbPlans = [];
    try {
      dbPlans = await DbService.getPlans();
    } catch (_) {}

    SubscriptionPlan? selectedPlan = dbPlans.isNotEmpty ? dbPlans.first : null;
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: lead.phone);
    final nameCtrl  = TextEditingController(text: lead.name);
    final priceCtrl = TextEditingController(text: selectedPlan != null ? selectedPlan.price.toInt().toString() : '1800');

    DateTime startDate = DateTime.now();
    DateTime endDate   = selectedPlan != null
        ? startDate.add(Duration(days: selectedPlan.durationDays))
        : DateTime(startDate.year, startDate.month + 1, startDate.day);

    bool converting = false;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bg     = isDark ? const Color(0xFF0F172A) : Colors.white;
            final txt    = isDark ? Colors.white : const Color(0xFF0F172A);
            final txt2   = isDark ? const Color(0xFF8896B3) : const Color(0xFF334155);
            const activeCyan = Color(0xFF00E5C0);

            return Container(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36, height: 4,
                        decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: activeCyan.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: const Icon(Icons.person_add_alt_1_rounded, color: activeCyan, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Convert Lead to Member', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: txt)),
                            const SizedBox(height: 2),
                            Text('Assign plan, record fee & register ${lead.name}', style: TextStyle(fontSize: 12, color: txt2)),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Member Name
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Member Full Name *',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Phone Number (Full Width)
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone Number *',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Email Address (Full Width)
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address (For PDF Receipts)',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Plan Selector
                    if (dbPlans.isNotEmpty) ...[
                      Text('Select Membership Plan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: txt)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<SubscriptionPlan>(
                        value: selectedPlan,
                        dropdownColor: bg,
                        style: TextStyle(color: txt, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.card_membership_rounded, color: AppTheme.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: dbPlans.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (₹${p.price.toInt()} / ${p.durationDays}d)'))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedPlan = val;
                              priceCtrl.text = val.price.toInt().toString();
                              endDate = startDate.add(Duration(days: val.durationDays));
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Payment Amount
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Collected Fee Amount (₹) *',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppTheme.success),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Dates
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  startDate = picked;
                                  if (selectedPlan != null) {
                                    endDate = startDate.add(Duration(days: selectedPlan!.durationDays));
                                  }
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Start Date',
                                prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(DateFormat('dd MMM yyyy').format(startDate), style: TextStyle(color: txt, fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setModalState(() => endDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Expiry Date',
                                prefixIcon: const Icon(Icons.event_repeat_rounded, size: 18, color: AppTheme.warning),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(DateFormat('dd MMM yyyy').format(endDate), style: TextStyle(color: txt, fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: converting
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                final phone = phoneCtrl.text.trim();
                                final email = emailCtrl.text.trim();
                                final amount = double.tryParse(priceCtrl.text.trim()) ?? 0.0;

                                if (name.isEmpty || phone.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in Member Name and Phone Number.')));
                                  return;
                                }

                                setModalState(() => converting = true);
                                try {
                                  final gymId = await AuthService.getGymId() ?? 'gym_demo';
                                  final now   = DateTime.now();

                                  final newMember = Member(
                                    id: 'mem_${now.millisecondsSinceEpoch}',
                                    gymId: gymId,
                                    name: name,
                                    phone: phone,
                                    email: email.isNotEmpty ? email : null,
                                    planId: selectedPlan?.id,
                                    subscriptionStart: startDate,
                                    subscriptionEnd: endDate,
                                    amountPaid: amount,
                                    createdAt: now,
                                  );

                                  final createdMember = await DbService.addMember(newMember);

                                  // Also log payment transaction
                                  if (amount > 0) {
                                    await DbService.recordPayment(Payment(
                                      id: '',
                                      gymId: gymId,
                                      memberId: createdMember.id,
                                      memberName: name,
                                      amount: amount,
                                      planName: selectedPlan?.name ?? 'Initial Joining Fee',
                                      paidAt: now,
                                    )).catchError((_) => Payment(id: '', gymId: gymId, memberId: createdMember.id, amount: amount, paidAt: now));
                                  }

                                  // Remove lead
                                  await DbService.deleteLead(lead.id).catchError((_) {});

                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    setState(() => _leads.removeWhere((l) => l.id == lead.id));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Converted ${name} to Member! ₹${amount.toInt()} payment recorded. 🎉'),
                                        backgroundColor: AppTheme.success,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Conversion failed: $e')));
                                } finally {
                                  if (ctx.mounted) setModalState(() => converting = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: converting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : const Icon(Icons.check_circle_rounded),
                        label: Text(converting ? 'Converting...' : 'Confirm Conversion & Record Fee', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(Lead lead) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lead'),
        content: Text('Remove ${lead.name} permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await DbService.deleteLead(lead.id);
              setState(() => _leads.removeWhere((l) => l.id == lead.id));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final border  = isDark ? const Color(0xFF162234) : const Color(0xFFE2E8F0);
    final txt     = isDark ? Colors.white : const Color(0xFF0F172A);
    final txt2    = isDark ? const Color(0xFF8896B3) : const Color(0xFF334155);
    final muted   = isDark ? const Color(0xFF64748B) : const Color(0xFF475569);
    const activeCyan = Color(0xFF00E5C0);

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: activeCyan, strokeWidth: 2))
          : _leads.isEmpty
              ? _emptyState(isDark, txt, muted)
              : RefreshIndicator(
                  color: activeCyan,
                  onRefresh: _loadLeads,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _leads.length,
                    separatorBuilder: (_, idx) => Divider(height: 1, color: border),
                    itemBuilder: (_, i) => _leadTile(_leads[i], isDark, border, txt, txt2, muted),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddLeadScreen,
        backgroundColor: activeCyan,
        foregroundColor: Colors.black,
        elevation: 0,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('New Lead', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _leadTile(
    Lead lead, bool isDark,
    Color border,
    Color txt, Color txt2, Color muted,
  ) {
    final rawSc    = _statusColor(lead.status);
    final sc       = AppTheme.darkColor(rawSc, isDark);
    final sl       = _statusLabel(lead.status);
    final initials = lead.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    final followUp = DateFormat('dd MMM yyyy').format(lead.followUpDate);
    const activeCyan = Color(0xFF00E5C0);
    final cyanFg     = AppTheme.darkColor(activeCyan, isDark);
    final blueFg     = AppTheme.darkColor(const Color(0xFF3B82F6), isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: rawSc.withValues(alpha: isDark ? 0.15 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials.isEmpty ? 'L' : initials,
                    style: TextStyle(color: sc, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lead.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: txt)),
                    const SizedBox(height: 3),
                    Text('+91 ${lead.phone}', style: TextStyle(color: txt2, fontSize: 12)),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: rawSc.withValues(alpha: isDark ? 0.15 : 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(sl, style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 20, color: const Color(0xFFEF4444).withValues(alpha: 0.8)),
                onPressed: () => _confirmDelete(lead),
              ),
            ],
          ),

          // ── Note ──
          if (lead.note != null && lead.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: activeCyan.withValues(alpha: isDark ? 0.08 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.sticky_note_2_rounded, size: 14, color: cyanFg),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(lead.note!, style: TextStyle(color: txt2, fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ),
            ),

          // ── Follow-up & Actions ──
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: activeCyan.withValues(alpha: isDark ? 0.1 : 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_rounded, size: 13, color: cyanFg),
                    const SizedBox(width: 4),
                    Text('Follow-up: $followUp', style: TextStyle(color: cyanFg, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _makeCall(lead),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.12 : 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.call_rounded, size: 13, color: blueFg),
                      const SizedBox(width: 4),
                      Text('Call', style: TextStyle(color: blueFg, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _convertToMember(lead),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: activeCyan.withValues(alpha: isDark ? 0.15 : 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_add_alt_1_rounded, size: 13, color: cyanFg),
                      const SizedBox(width: 4),
                      Text('Convert', style: TextStyle(color: cyanFg, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(bool isDark, Color txt, Color muted) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5C0).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.contacts_rounded, size: 40, color: Color(0xFF00E5C0)),
        ),
        const SizedBox(height: 16),
        Text('No leads yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: txt)),
        const SizedBox(height: 6),
        Text('Add leads to start tracking potential members.', style: TextStyle(color: muted, fontSize: 13)),
      ],
    ),
  );
}
