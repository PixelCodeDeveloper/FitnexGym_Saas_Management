import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/member.dart';
import '../models/diet_plan.dart';
import '../models/payment.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';
import 'forms/edit_member_screen.dart';

class MemberDetailScreen extends StatefulWidget {
  final Member member;

  const MemberDetailScreen({super.key, required this.member});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  late Member _member;
  bool _isLoading = true;

  MemberDietPlan? _activeDiet;
  List<DietPlan> _dietTemplates = [];
  List<Payment> _paymentHistory = [];

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _loadMemberDetails();
  }

  Future<void> _loadMemberDetails() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        DbService.getMemberDietPlan(_member.id).catchError((_) => null),
        DbService.getDietPlans().catchError((_) => <DietPlan>[]),
        DbService.getPayments().catchError((_) => <Payment>[]),
      ]);
      _activeDiet = results[0] as MemberDietPlan?;
      _dietTemplates = results[1] as List<DietPlan>;
      final allPayments = results[2] as List<Payment>;
      _paymentHistory = allPayments.where((p) => p.memberId == _member.id).toList();
      if (_paymentHistory.isEmpty && _member.amountPaid > 0) {
        _paymentHistory = [
          Payment(
            id: 'initial_${_member.id}',
            gymId: _member.gymId,
            memberId: _member.id,
            memberName: _member.name,
            amount: _member.amountPaid,
            planName: 'Initial Membership Joining Fee',
            paidAt: _member.subscriptionStart,
          ),
        ];
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openEditMember() async {
    final updated = await Navigator.push<Member>(
      context,
      MaterialPageRoute(builder: (_) => EditMemberScreen(member: _member)),
    );
    if (updated != null && mounted) {
      setState(() => _member = updated);
      Navigator.pop(context, updated); // return updated member to list
    }
  }

  Future<void> _shareWhatsApp() async {
    final text = Uri.encodeComponent(
      'Hello ${_member.name} 👋,\n\nThis is a reminder from Fitnex Gym.\nYour membership (${_member.statusText}) expires on ${DateFormat('dd MMM yyyy').format(_member.subscriptionEnd)}.\n\nThank you for choosing us for your fitness journey! 💪',
    );
    final url = Uri.parse('https://wa.me/${_member.phone.replaceAll(RegExp(r'[^\d+]'), '')}?text=$text');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch WhatsApp')));
    }
  }

  Future<void> _sendReceiptEmail() async {
    if (_member.email == null || _member.email!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member does not have an email address recorded.')),
      );
      return;
    }
    try {
      final success = await DbService.sendMemberReceiptEmail(
        memberId: _member.id,
        memberEmail: _member.email!,
        amount: _member.amountPaid,
        startDate: _member.subscriptionStart,
        endDate: _member.subscriptionEnd,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Payment Receipt PDF emailed to ${_member.email}! 📧'
                  : 'Failed to send payment receipt.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending receipt: $e')));
    }
  }

  Future<void> _openAssignDietDialog() async {
    if (_dietTemplates.isEmpty) {
      _dietTemplates = await DbService.getDietPlans().catchError((_) => <DietPlan>[]);
    }

    DietPlan? selectedTemplate = _dietTemplates.isNotEmpty ? _dietTemplates.first : null;
    final titleCtrl = TextEditingController(text: selectedTemplate != null ? '${selectedTemplate.title} (for ${_member.name})' : 'Personalized Plan for ${_member.name}');
    final caloriesCtrl = TextEditingController(text: selectedTemplate?.calories ?? '2100 kcal');
    final proteinCtrl = TextEditingController(text: selectedTemplate?.macros?['protein'] ?? '150g');
    final carbsCtrl = TextEditingController(text: selectedTemplate?.macros?['carbs'] ?? '200g');
    final fatsCtrl = TextEditingController(text: selectedTemplate?.macros?['fats'] ?? '50g');
    int reviewDays = 30;
    bool isAssigning = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
            final txt = isDark ? Colors.white : Colors.black;

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
                    Row(children: [
                      const Icon(Icons.restaurant_menu_rounded, color: AppTheme.primary, size: 24),
                      const SizedBox(width: 10),
                      Text('Assign Diet to ${_member.name}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: txt)),
                    ]),
                    const SizedBox(height: 6),
                    Text('Select master template or customize macros & review date', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                    const SizedBox(height: 16),

                    if (_dietTemplates.isNotEmpty) ...[
                      Text('Master Template', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: txt)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<DietPlan>(
                        value: selectedTemplate,
                        dropdownColor: bg,
                        style: TextStyle(color: txt, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.description_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: _dietTemplates.map((t) => DropdownMenuItem(value: t, child: Text('${t.title} (${t.CategoryBadge})'))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedTemplate = val;
                              titleCtrl.text = '${val.title} (for ${_member.name})';
                              caloriesCtrl.text = val.calories;
                              proteinCtrl.text = val.macros?['protein'] ?? '150g';
                              carbsCtrl.text = val.macros?['carbs'] ?? '200g';
                              fatsCtrl.text = val.macros?['fats'] ?? '50g';
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Assigned Title',
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: caloriesCtrl,
                          decoration: InputDecoration(
                            labelText: 'Calories Target',
                            prefixIcon: const Icon(Icons.local_fire_department_rounded, color: AppTheme.warning),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: proteinCtrl,
                          decoration: InputDecoration(
                            labelText: 'Protein (g)',
                            prefixIcon: const Icon(Icons.fitness_center_rounded, color: AppTheme.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 14),

                    Row(children: [
                      Text('Review Period: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: txt)),
                      const Spacer(),
                      ChoiceChip(
                        label: const Text('14 Days'),
                        selected: reviewDays == 14,
                        onSelected: (_) => setModalState(() => reviewDays = 14),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('30 Days'),
                        selected: reviewDays == 30,
                        onSelected: (_) => setModalState(() => reviewDays = 30),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isAssigning
                            ? null
                            : () async {
                                setModalState(() => isAssigning = true);
                                try {
                                  final payload = {
                                    'member_id': _member.id,
                                    'template_id': selectedTemplate?.id.isNotEmpty == true ? selectedTemplate?.id : null,
                                    'custom_title': titleCtrl.text.trim(),
                                    'category': selectedTemplate?.category ?? 'veg',
                                    'goal_tag': selectedTemplate?.goalTag ?? 'Fat Loss',
                                    'calories': caloriesCtrl.text.trim(),
                                    'macros': {
                                      'protein': proteinCtrl.text.trim(),
                                      'carbs': carbsCtrl.text.trim(),
                                      'fats': fatsCtrl.text.trim(),
                                    },
                                    'water_intake': selectedTemplate?.waterIntake ?? '3.5 L/day',
                                    'meals': selectedTemplate?.meals ?? {},
                                    'notes': selectedTemplate?.notes,
                                    'start_date': DateTime.now().toIso8601String(),
                                    'review_date': DateTime.now().add(Duration(days: reviewDays)).toIso8601String(),
                                  };
                                  final assigned = await DbService.assignDietPlanToMember(payload);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted && assigned != null) {
                                    setState(() => _activeDiet = assigned);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Assigned "${assigned.customTitle}" to ${_member.name}! 🎉')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to assign diet: $e')));
                                } finally {
                                  if (ctx.mounted) setModalState(() => isAssigning = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: isAssigning
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_rounded),
                        label: Text(isAssigning ? 'Assigning...' : 'Confirm Diet Assignment', style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Future<void> _openAddPaymentDialog() async {
    final amountCtrl = TextEditingController(text: '1800');
    final descCtrl = TextEditingController(text: 'Membership Fee Renewal');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
            final txt = isDark ? Colors.white : Colors.black;

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
                    Row(children: [
                      const Icon(Icons.add_card_rounded, color: AppTheme.success, size: 24),
                      const SizedBox(width: 10),
                      Text('Record Payment Entry', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: txt)),
                    ]),
                    const SizedBox(height: 6),
                    Text('Log a payment transaction for ${_member.name}', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                    const SizedBox(height: 16),

                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Payment Amount (₹) *',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppTheme.success),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: descCtrl,
                      decoration: InputDecoration(
                        labelText: 'Description / Plan Name',
                        prefixIcon: const Icon(Icons.description_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                                if (amt <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid payment amount.')));
                                  return;
                                }
                                setModalState(() => saving = true);
                                try {
                                  final p = Payment(
                                    id: '',
                                    gymId: _member.gymId,
                                    memberId: _member.id,
                                    memberName: _member.name,
                                    amount: amt,
                                    planName: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : 'Membership Fee',
                                    paidAt: DateTime.now(),
                                  );
                                  final created = await DbService.addPayment(p);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    setState(() {
                                      _paymentHistory.insert(0, created);
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Logged payment of ₹${amt.toInt()} for ${_member.name}! 💰')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to log payment: $e')));
                                } finally {
                                  if (ctx.mounted) setModalState(() => saving = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_rounded),
                        label: Text(saving ? 'Saving Entry...' : 'Save Payment Entry', style: const TextStyle(fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bgColor   = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final cardBg    = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border    = isDark ? const Color(0xFF162234) : const Color(0xFFE2E8F0);
    final txt       = isDark ? Colors.white : const Color(0xFF0F172A);
    final txt2      = isDark ? const Color(0xFF8896B3) : const Color(0xFF64748B);
    final muted     = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    const activeCyan = Color(0xFF00E5C0);

    final statusColor = _member.isExpired
        ? AppTheme.error
        : (_member.isExpiringSoon ? AppTheme.warning : AppTheme.success);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(_member.name, style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 18)),
        iconTheme: IconThemeData(color: txt),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppTheme.primary, size: 22),
            onPressed: _openEditMember,
            tooltip: 'Edit Member Profile',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: activeCyan, strokeWidth: 2))
          : RefreshIndicator(
              color: activeCyan,
              onRefresh: _loadMemberDetails,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── 1. Hero Profile Overview Card ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: activeCyan.withValues(alpha: 0.15),
                                child: Text(
                                  _member.avatarInitials,
                                  style: const TextStyle(color: activeCyan, fontWeight: FontWeight.bold, fontSize: 20),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _member.name,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: txt),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            _member.statusText,
                                            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.phone_outlined, size: 14, color: muted),
                                        const SizedBox(width: 6),
                                        Text(_member.phone, style: TextStyle(color: txt2, fontSize: 13, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                    if (_member.email != null && _member.email!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.email_outlined, size: 14, color: muted),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(_member.email!, style: TextStyle(color: txt2, fontSize: 13), overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.how_to_reg_rounded, size: 14, color: activeCyan),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Joined App: ${DateFormat('dd MMM yyyy, hh:mm a').format(_member.createdAt)}',
                                            style: const TextStyle(color: activeCyan, fontSize: 12, fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── 2. Quick Action Toolbar ──
                    Row(
                      children: [
                        Expanded(
                          child: _actionTile(
                            icon: Icons.restaurant_menu_rounded,
                            label: 'Assign Diet',
                            color: activeCyan,
                            isDark: isDark,
                            onTap: _openAssignDietDialog,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _actionTile(
                            icon: Icons.receipt_long_rounded,
                            label: 'Email Receipt',
                            color: const Color(0xFF3B82F6),
                            isDark: isDark,
                            onTap: _sendReceiptEmail,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _actionTile(
                            icon: Icons.send_rounded,
                            label: 'WhatsApp',
                            color: const Color(0xFF22C55E),
                            isDark: isDark,
                            onTap: _shareWhatsApp,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── 3. Active Subscription Details ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                const Icon(Icons.card_membership_rounded, color: AppTheme.primary, size: 20),
                                const SizedBox(width: 8),
                                Text('Membership Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: txt)),
                              ]),
                              Text('₹${_member.amountPaid.toInt()}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('JOINED ON', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(DateFormat('dd MMM yyyy').format(_member.createdAt), style: TextStyle(color: txt, fontWeight: FontWeight.w600, fontSize: 12)),
                              ]),
                              Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                                Text('START DATE', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(DateFormat('dd MMM yyyy').format(_member.subscriptionStart), style: TextStyle(color: txt, fontWeight: FontWeight.w600, fontSize: 12)),
                              ]),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('EXPIRY DATE', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(DateFormat('dd MMM yyyy').format(_member.subscriptionEnd), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                              ]),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Days Left Progress
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _calculatePlanProgress(_member.subscriptionStart, _member.subscriptionEnd),
                              backgroundColor: border,
                              color: statusColor,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${_member.daysRemaining} days remaining', style: TextStyle(color: txt2, fontSize: 12, fontWeight: FontWeight.w500)),
                              Text(_member.isExpired ? 'Expired' : 'Active', style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── 4. Active Assigned Diet Plan Card ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.restaurant_rounded, color: activeCyan, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Active Assigned Diet',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: txt),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: _openAssignDietDialog,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: activeCyan.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(_activeDiet == null ? '+ Assign Diet' : 'Change Diet', style: const TextStyle(color: activeCyan, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          if (_activeDiet == null) ...[
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Column(
                                  children: [
                                    Icon(Icons.no_meals_rounded, size: 32, color: muted),
                                    const SizedBox(height: 8),
                                    Text('No active diet plan assigned yet', style: TextStyle(color: txt2, fontSize: 13)),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      onPressed: _openAssignDietDialog,
                                      style: ElevatedButton.styleFrom(backgroundColor: activeCyan, foregroundColor: Colors.black, elevation: 0),
                                      icon: const Icon(Icons.add_rounded, size: 16),
                                      label: const Text('Assign Diet Plan Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            Text(_activeDiet!.customTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: txt)),
                            const SizedBox(height: 6),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                child: Text(_formatDietCategory(_activeDiet!.category), style: const TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                child: Text('🔥 ${_activeDiet!.calories}', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ]),

                            if (_activeDiet!.macros != null && _activeDiet!.macros!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _macroBadge('💪 Protein', _activeDiet!.macros!['protein'] ?? 'N/A', activeCyan),
                                    _macroBadge('🌾 Carbs', _activeDiet!.macros!['carbs'] ?? 'N/A', const Color(0xFF8B5CF6)),
                                    _macroBadge('🥑 Fats', _activeDiet!.macros!['fats'] ?? 'N/A', const Color(0xFFEC4899)),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),
                            Row(children: [
                              Icon(Icons.event_repeat_rounded, size: 14, color: muted),
                              const SizedBox(width: 6),
                              Text('30-Day Review Date: ${DateFormat('dd MMM yyyy').format(_activeDiet!.reviewDate)}', style: TextStyle(color: txt2, fontSize: 12)),
                            ]),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── 5. Payment History Ledger ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.history_rounded, color: AppTheme.accent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Payment History',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: txt),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: _openAddPaymentDialog,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_rounded, size: 14, color: AppTheme.success),
                                      SizedBox(width: 3),
                                      Text('Record Payment', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_paymentHistory.isEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text('No recorded payment ledger entries yet.', style: TextStyle(color: muted, fontSize: 12)),
                            ),
                          ] else ...[
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _paymentHistory.length,
                              separatorBuilder: (_, i) => Divider(height: 1, color: border),
                              itemBuilder: (context, idx) {
                                final p = _paymentHistory[idx];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.planName ?? 'Membership Fee',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: txt),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              DateFormat('dd MMM yyyy, hh:mm a').format(p.paidAt),
                                              style: TextStyle(color: muted, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '+₹${p.amount.toInt()}',
                                        style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  double _calculatePlanProgress(DateTime start, DateTime end) {
    final totalDays = end.difference(start).inDays;
    if (totalDays <= 0) return 1.0;
    final elapsedDays = DateTime.now().difference(start).inDays;
    if (elapsedDays <= 0) return 0.0;
    if (elapsedDays >= totalDays) return 1.0;
    return elapsedDays / totalDays;
  }

  String _formatDietCategory(String cat) {
    switch (cat.toLowerCase()) {
      case 'veg': return '🥗 Pure Veg';
      case 'nonveg': return '🍗 Non-Veg';
      case 'egg': return '🥚 Eggetarian';
      case 'vegan': return '🌱 Vegan';
      default: return '🥗 Pure Veg';
    }
  }

  Widget _macroBadge(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _actionTile({required IconData icon, required String label, required Color color, required bool isDark, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
