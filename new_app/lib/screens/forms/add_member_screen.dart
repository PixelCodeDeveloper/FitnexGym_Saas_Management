import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/member.dart';
import '../../models/subscription_plan.dart';
import '../../services/db_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/input_validator.dart';
import 'add_plan_screen.dart';

class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey          = GlobalKey<FormState>();
  final _nameController   = TextEditingController();
  final _phoneController  = TextEditingController();
  final _emailController  = TextEditingController();
  final _amountController = TextEditingController(text: '1800');

  bool _isSaving = false;

  List<SubscriptionPlan> _dbPlans = [];
  SubscriptionPlan? _selectedPlan;
  bool _isCustomPlan = false;
  int _customMonths = 1;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      _dbPlans = await DbService.getPlans();
      if (_dbPlans.isNotEmpty) {
        _selectedPlan = _dbPlans[0];
        _isCustomPlan = false;
        _amountController.text = _dbPlans[0].price.toStringAsFixed(0);
      } else {
        _isCustomPlan = true;
        _customMonths = 1;
        _amountController.text = '1800';
      }
    } catch (_) {
      _isCustomPlan = true;
      _customMonths = 1;
      _amountController.text = '1800';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  DateTime _calculateExpiryDate() {
    final now = DateTime.now();
    if (!_isCustomPlan && _selectedPlan != null) {
      return now.add(Duration(days: _selectedPlan!.durationDays));
    } else {
      return DateTime(now.year, now.month + _customMonths, now.day);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final gymId = await AuthService.getGymId() ?? 'gym_demo';
      final now   = DateTime.now();
      final expiryDate = _calculateExpiryDate();

      final member = Member(
        id: '',
        gymId: gymId,
        name: _nameController.text.trim(),
        phone: InputValidator.sanitizePhone(_phoneController.text),
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        planId: !_isCustomPlan && _selectedPlan != null ? _selectedPlan!.id : null,
        subscriptionStart: now,
        subscriptionEnd: expiryDate,
        amountPaid: double.tryParse(_amountController.text.trim()) ?? 1800.0,
        createdAt: now,
      );
      final created = await DbService.addMember(member);
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save member to database: $e'),
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
    final selBg     = isDark ? AppTheme.darkCard         : Colors.white;

    final expiryDateStr = DateFormat('dd MMM yyyy').format(_calculateExpiryDate());

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: barBg,
        surfaceTintColor: Colors.transparent,
        title: Text('Add New Member', style: TextStyle(color: txt, fontWeight: FontWeight.w700, fontSize: 17)),
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
            child: const Icon(Icons.person_add_rounded, color: AppTheme.primary, size: 20),
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
                      _sectionHeader(
                        icon: Icons.person_outline_rounded,
                        iconBg: AppTheme.primary.withValues(alpha: 0.12),
                        iconColor: AppTheme.primary,
                        title: 'Personal Information',
                        subtitle: "Enter member's basic details",
                        txt: txt, txt2: txt2,
                      ),
                      const SizedBox(height: 16),
                      _label('Full Name *', muted),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        validator: InputValidator.validateName,
                        style: TextStyle(color: txt, fontWeight: FontWeight.w500),
                        decoration: _fieldDec(hint: 'e.g. Rahul Sharma', icon: Icons.person_rounded, iconColor: AppTheme.primary, fillColor: inputFill, border: border, hintColor: muted),
                      ),
                      const SizedBox(height: 16),
                      _label('10-Digit Mobile Number *', muted),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                        validator: InputValidator.validatePhone,
                        style: TextStyle(color: txt, fontWeight: FontWeight.w500),
                        decoration: _fieldDec(hint: 'Enter 10-digit mobile number', icon: Icons.phone_android_rounded, iconColor: AppTheme.primary, fillColor: inputFill, border: border, hintColor: muted),
                      ),
                      const SizedBox(height: 16),
                      _label('Email Address (Optional)', muted),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) => (val != null && val.trim().isNotEmpty) ? InputValidator.validateEmail(val.trim()) : null,
                        style: TextStyle(color: txt, fontWeight: FontWeight.w500),
                        decoration: _fieldDec(hint: 'e.g. member@email.com', icon: Icons.email_outlined, iconColor: AppTheme.primary, fillColor: inputFill, border: border, hintColor: muted),
                      ),
                      const SizedBox(height: 28),
                      _sectionHeader(
                        icon: Icons.card_membership_rounded,
                        iconBg: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                        iconColor: const Color(0xFF0EA5E9),
                        title: 'Membership & Payment',
                        subtitle: 'Select membership plan or customize duration',
                        txt: txt, txt2: txt2,
                      ),
                      const SizedBox(height: 16),
                      _label('Membership Package *', muted),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _showPlanPicker(context, isDark, selBg, border, txt, txt2),
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
                                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                child: Icon(_isCustomPlan ? Icons.edit_calendar_rounded : Icons.emoji_events_rounded, color: AppTheme.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isCustomPlan
                                          ? '⚡ Custom Flexible Plan ($_customMonths ${_customMonths == 1 ? 'Month' : 'Months'})'
                                          : (_selectedPlan?.name ?? 'Select Membership Plan'),
                                      style: TextStyle(color: txt, fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _isCustomPlan
                                          ? 'Valid until $expiryDateStr'
                                          : '${_selectedPlan?.durationDays ?? 30} Days Validity',
                                      style: TextStyle(color: txt2, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              if (!_isCustomPlan && _selectedPlan != null)
                                Text('₹${_selectedPlan!.price.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 15)),
                              const SizedBox(width: 6),
                              Icon(Icons.keyboard_arrow_down_rounded, color: txt2, size: 20),
                            ],
                          ),
                        ),
                      ),
                      if (_isCustomPlan) ...[
                        const SizedBox(height: 16),
                        _label('Custom Duration (Months) *', muted),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [1, 2, 3, 5, 6, 7, 9, 12].map((m) {
                              final sel = _customMonths == m;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text('$m ${m == 1 ? 'Month' : 'Months'}', style: TextStyle(color: sel ? Colors.white : txt, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                                  selected: sel,
                                  selectedColor: AppTheme.primary,
                                  backgroundColor: inputFill,
                                  onSelected: (_) {
                                    setState(() {
                                      _customMonths = m;
                                      _amountController.text = (m * 1800).toString();
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Text('Custom expiry calculated: ', style: TextStyle(color: txt2, fontSize: 12)),
                            Text(expiryDateStr, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      _label('Amount Collected (₹) *', muted),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: InputValidator.validateAmount,
                        style: TextStyle(color: txt, fontWeight: FontWeight.w600, fontSize: 16),
                        decoration: _fieldDec(icon: Icons.currency_rupee_rounded, iconColor: AppTheme.success, fillColor: inputFill, border: border, hintColor: muted),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.verified_user_outlined, size: 14, color: muted),
                          const SizedBox(width: 6),
                          Text('Payment will be saved to financial reports', style: TextStyle(color: muted, fontSize: 12)),
                        ],
                      ),
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
                            Text('Save & Add Member', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
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

  void _showPlanPicker(BuildContext context, bool isDark, Color selBg, Color border, Color txt, Color txt2) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: BoxDecoration(color: selBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2))),
            Text('Select Membership Package', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: txt)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isCustomPlan = true;
                        _selectedPlan = null;
                        _amountController.text = (_customMonths * 1800).toString();
                      });
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _isCustomPlan ? AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _isCustomPlan ? AppTheme.primary : border, width: _isCustomPlan ? 1.5 : 1),
                      ),
                      child: Row(
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.edit_calendar_rounded, size: 20, color: AppTheme.primary)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('⚡ Custom Flexible Plan', style: TextStyle(color: _isCustomPlan ? AppTheme.primary : txt, fontWeight: FontWeight.w700, fontSize: 14)),
                                Text('Choose custom months & amount', style: TextStyle(color: txt2, fontSize: 12)),
                              ],
                            ),
                          ),
                          if (_isCustomPlan) const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 20),
                  if (_dbPlans.isEmpty)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('No saved plans yet.', style: TextStyle(color: txt2, fontSize: 13), textAlign: TextAlign.center))
                  else
                    ..._dbPlans.map((p) {
                      final selected = !_isCustomPlan && _selectedPlan?.id == p.id;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _isCustomPlan = false;
                            _selectedPlan = p;
                            _amountController.text = p.price.toStringAsFixed(0);
                          });
                          Navigator.pop(context);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.08) : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: selected ? AppTheme.primary : border, width: selected ? 1.5 : 1),
                          ),
                          child: Row(
                            children: [
                              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: selected ? AppTheme.primary.withValues(alpha: 0.15) : (isDark ? AppTheme.darkSurfaceAlt : AppTheme.lightSurfaceAlt), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.card_membership_rounded, size: 18, color: selected ? AppTheme.primary : txt2)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(p.name, style: TextStyle(color: selected ? AppTheme.primary : txt, fontWeight: FontWeight.w700, fontSize: 14)),
                                  Text('${p.durationDays} Days Validity', style: TextStyle(color: txt2, fontSize: 12)),
                                ]),
                              ),
                              Text('₹${p.price.toStringAsFixed(0)}', style: TextStyle(color: selected ? AppTheme.primary : txt, fontWeight: FontWeight.w800, fontSize: 15)),
                              if (selected) ...[const SizedBox(width: 8), const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18)],
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPlanScreen()));
                      _loadPlans();
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary, side: const BorderSide(color: AppTheme.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create New Reusable Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader({required IconData icon, required Color iconBg, required Color iconColor, required String title, required String subtitle, required Color txt, required Color txt2}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: 20)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: txt, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: txt2, fontSize: 12)),
        ]),
      ],
    );
  }

  Widget _label(String text, Color muted) => Text(text, style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3));

  InputDecoration _fieldDec({String? hint, IconData? icon, Color? iconColor, required Color fillColor, required Color border, required Color hintColor}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: hintColor, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: iconColor ?? AppTheme.primary, size: 20) : null,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.error, width: 2)),
    );
  }
}
