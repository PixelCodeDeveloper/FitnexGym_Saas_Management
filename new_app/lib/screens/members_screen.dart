import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/member.dart';
import '../models/payment.dart';
import '../services/db_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/input_validator.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final filters = ['All', 'Active', 'Expiring Soon', 'Expired'];
  bool _isLoading = true;
  List<Member> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final list = await DbService.getMembers();
      setState(() {
        _members = list;
      });
    } catch (_) {
      setState(() {
        _members = [];
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(MemberStatus status) {
    switch (status) {
      case MemberStatus.active:
        return AppTheme.success;
      case MemberStatus.expiringSoon:
        return AppTheme.warning;
      case MemberStatus.expired:
        return AppTheme.error;
    }
  }

  String _statusLabel(MemberStatus status) {
    switch (status) {
      case MemberStatus.active:
        return 'Active';
      case MemberStatus.expiringSoon:
        return 'Expiring Soon';
      case MemberStatus.expired:
        return 'Expired';
    }
  }

  void _showAddMemberModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddMemberForm(
        onMemberAdded: (newMember) {
          setState(() {
            _members.insert(0, newMember);
          });
        },
      ),
    );
  }

  void _showRenewModal(Member member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _RenewMemberForm(
        member: member,
        onRenewed: (updatedMember) {
          setState(() {
            final idx = _members.indexWhere((m) => m.id == member.id);
            if (idx != -1) _members[idx] = updatedMember;
          });
        },
      ),
    );
  }

  Future<void> _launchWhatsApp(Member member) async {
    final phone = member.phone.replaceAll(RegExp(r'[^\d]'), '');
    final fullPhone = phone.length == 10 ? '91$phone' : phone;
    final message = Uri.encodeComponent(
      'Hi ${member.name}, your Fitnex GYM membership expires on ${DateFormat('dd MMM yyyy').format(member.subscriptionEnd)}. Please renew to keep enjoying your workout sessions!',
    );
    final url = Uri.parse('https://wa.me/$fullPhone?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    }
  }

  void _confirmDelete(Member member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Member'),
        content: Text('Are you sure you want to delete ${member.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await DbService.deleteMember(member.id);
              setState(() {
                _members.removeWhere((m) => m.id == member.id);
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${member.name} deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
  Future<void> _sendTwilioSMS(Member member) async {
    final msg = 'Hi ${member.name}, your Fitnex GYM membership expires on ${DateFormat('dd MMM yyyy').format(member.subscriptionEnd)}. Please renew to continue workout!';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sending Twilio SMS... 📲')),
    );
    final success = await DbService.sendTwilioNotification(
      phone: member.phone,
      message: msg,
      type: 'sms',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Twilio SMS Sent to ${member.name}! 🚀' : 'SMS Delivery Failed'),
          backgroundColor: success ? AppTheme.success : AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _members.where((m) {
      final matchesSearch = m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.phone.contains(_searchQuery);
      if (!matchesSearch) return false;
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Active') return m.status == MemberStatus.active;
      if (_selectedFilter == 'Expiring Soon') return m.status == MemberStatus.expiringSoon;
      if (_selectedFilter == 'Expired') return m.status == MemberStatus.expired;
      return true;
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          // ── Search + Filter Bar ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone…',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.background,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final f = filters[i];
                      final selected = _selectedFilter == f;
                      return ChoiceChip(
                        label: Text(f),
                        selected: selected,
                        selectedColor: AppTheme.primary.withOpacity(0.15),
                        backgroundColor: AppTheme.surfaceAlt,
                        labelStyle: TextStyle(
                          color: selected ? AppTheme.primaryDark : AppTheme.textSecondary,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: selected ? AppTheme.primary.withOpacity(0.3) : AppTheme.divider,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onSelected: (_) => setState(() => _selectedFilter = f),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Members List ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off, size: 48, color: AppTheme.textMuted),
                            const SizedBox(height: 12),
                            Text('No members found', style: TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadMembers,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final m = filtered[index];
                            final statusColor = _statusColor(m.status);
                            final statusText = _statusLabel(m.status);
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                                          child: Text(
                                            m.name.isNotEmpty
                                                ? m.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
                                                : 'M',
                                            style: const TextStyle(
                                              color: AppTheme.primaryDark,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                m.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '+91 ${m.phone} • ₹${m.amountPaid.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            statusText,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
                                          onPressed: () => _confirmDelete(m),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.surfaceAlt,
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(16),
                                        bottomRight: Radius.circular(16),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textMuted),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Exp: ${DateFormat('dd MMM yyyy').format(m.subscriptionEnd)}',
                                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                        ),
                                        const Spacer(),
                                        _ActionChip(
                                          icon: Icons.sms_outlined,
                                          label: 'Twilio SMS',
                                          color: AppTheme.accent,
                                          onTap: () => _sendTwilioSMS(m),
                                        ),
                                        const SizedBox(width: 8),
                                        _ActionChip(
                                          icon: Icons.chat_bubble_outline,
                                          label: 'WhatsApp',
                                          color: AppTheme.success,
                                          onTap: () => _launchWhatsApp(m),
                                        ),
                                        const SizedBox(width: 8),
                                        _ActionChip(
                                          icon: Icons.refresh,
                                          label: 'Renew',
                                          color: AppTheme.primary,
                                          onTap: () => _showRenewModal(m),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMemberModal,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Member'),
      ),
    );
  }
}

class _AddMemberForm extends StatefulWidget {
  final Function(Member) onMemberAdded;
  const _AddMemberForm({required this.onMemberAdded});

  @override
  State<_AddMemberForm> createState() => _AddMemberFormState();
}

class _AddMemberFormState extends State<_AddMemberForm> {
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
      widget.onMemberAdded(created);
      if (mounted) Navigator.pop(context);
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
      widget.onMemberAdded(fallbackMember);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add New Gym Member', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Name
              TextFormField(
                controller: _nameController,
                validator: InputValidator.validateName,
                decoration: const InputDecoration(labelText: 'Full Name *', hintText: 'e.g. Rahul Sharma'),
              ),
              const SizedBox(height: 14),

              // Phone (Strict 10 digits)
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: InputValidator.validatePhone,
                decoration: const InputDecoration(
                  labelText: '10-Digit Mobile Number *',
                  hintText: 'e.g. 9876543210',
                  prefixText: '+91 ',
                ),
              ),
              const SizedBox(height: 14),

              // Duration
              DropdownButtonFormField<int>(
                value: _selectedDurationMonths,
                decoration: const InputDecoration(labelText: 'Membership Package'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 Month Package')),
                  DropdownMenuItem(value: 3, child: Text('3 Months Package')),
                  DropdownMenuItem(value: 6, child: Text('6 Months Package')),
                  DropdownMenuItem(value: 12, child: Text('1 Year Package')),
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

              // Amount Paid
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: InputValidator.validateAmount,
                decoration: const InputDecoration(labelText: 'Amount Paid (₹) *', prefixText: '₹ '),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Member'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RenewMemberForm extends StatefulWidget {
  final Member member;
  final Function(Member) onRenewed;
  const _RenewMemberForm({required this.member, required this.onRenewed});

  @override
  State<_RenewMemberForm> createState() => _RenewMemberFormState();
}

class _RenewMemberFormState extends State<_RenewMemberForm> {
  int _months = 1;
  final _amountController = TextEditingController(text: '1800');
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Renew Membership - ${widget.member.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _months,
            decoration: const InputDecoration(labelText: 'Renewal Duration'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 Month Extension')),
              DropdownMenuItem(value: 3, child: Text('3 Months Extension')),
              DropdownMenuItem(value: 6, child: Text('6 Months Extension')),
              DropdownMenuItem(value: 12, child: Text('1 Year Extension')),
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
          const SizedBox(height: 14),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Renewal Fee Collected (₹)', prefixText: '₹ '),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : () async {
                      setState(() => _isSaving = true);
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

                      widget.onRenewed(updated);
                      if (mounted) Navigator.pop(context);
                    },
              child: const Text('Confirm Renewal'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
