import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead.dart';
import '../models/member.dart';
import '../services/db_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/input_validator.dart';

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
      final list = await DbService.getLeads();
      setState(() {
        _leads = list;
      });
    } catch (_) {
      setState(() {
        _leads = [];
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(LeadStatus status) {
    switch (status) {
      case LeadStatus.hot:
        return AppTheme.error;
      case LeadStatus.warm:
        return AppTheme.warning;
      case LeadStatus.cold:
        return AppTheme.textMuted;
    }
  }

  String _statusLabel(LeadStatus status) {
    switch (status) {
      case LeadStatus.hot:
        return 'Hot 🔥';
      case LeadStatus.warm:
        return 'Warm ☀️';
      case LeadStatus.cold:
        return 'Cold ❄️';
    }
  }

  void _showAddLeadModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddLeadForm(
        onLeadAdded: (newLead) {
          setState(() {
            _leads.insert(0, newLead);
          });
        },
      ),
    );
  }

  Future<void> _makeCall(Lead lead) async {
    final url = Uri.parse('tel:+91${lead.phone}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not place phone call')),
        );
      }
    }
  }

  Future<void> _convertToMember(Lead lead) async {
    final gymId = await AuthService.getGymId() ?? 'gym_demo';
    final now = DateTime.now();
    final newMember = Member(
      id: 'mem_${now.millisecondsSinceEpoch}',
      gymId: gymId,
      name: lead.name,
      phone: lead.phone,
      subscriptionStart: now,
      subscriptionEnd: DateTime(now.year, now.month + 1, now.day),
      amountPaid: 1800.0,
      createdAt: now,
    );

    await DbService.addMember(newMember);
    await DbService.deleteLead(lead.id);
    setState(() {
      _leads.removeWhere((l) => l.id == lead.id);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Converted ${lead.name} to Member! 🎉')),
      );
    }
  }

  void _confirmDelete(Lead lead) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lead'),
        content: Text('Are you sure you want to delete lead ${lead.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await DbService.deleteLead(lead.id);
              setState(() {
                _leads.removeWhere((l) => l.id == lead.id);
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted lead ${lead.name}')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _leads.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.contacts_outlined, size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      Text('No leads found', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadLeads,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _leads.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final lead = _leads[index];
                      final Color badgeColor = _statusColor(lead.status);

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: badgeColor.withOpacity(0.1),
                                        child: Text(
                                          lead.name.isNotEmpty
                                              ? lead.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
                                              : 'L',
                                          style: TextStyle(
                                            color: badgeColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              lead.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '+91 ${lead.phone}',
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
                                          color: badgeColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          _statusLabel(lead.status),
                                          style: TextStyle(
                                            color: badgeColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
                                        onPressed: () => _confirmDelete(lead),
                                      ),
                                    ],
                                  ),
                                  if (lead.note != null && lead.note!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceAlt,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.sticky_note_2_outlined, size: 16, color: AppTheme.textMuted),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              lead.note!,
                                              style: const TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 13,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(Icons.event, size: 14, color: AppTheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Follow-up: ${DateFormat('dd MMM yyyy').format(lead.followUpDate)}',
                                        style: const TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: const BoxDecoration(
                                color: AppTheme.surfaceAlt,
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _makeCall(lead),
                                      icon: const Icon(Icons.call_outlined, size: 18),
                                      label: const Text('Call'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _convertToMember(lead),
                                      icon: const Icon(Icons.person_add, size: 18),
                                      label: const Text('Convert'),
                                    ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLeadModal,
        icon: const Icon(Icons.add),
        label: const Text('New Lead'),
      ),
    );
  }
}

class _AddLeadForm extends StatefulWidget {
  final Function(Lead) onLeadAdded;
  const _AddLeadForm({required this.onLeadAdded});

  @override
  State<_AddLeadForm> createState() => _AddLeadFormState();
}

class _AddLeadFormState extends State<_AddLeadForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  LeadStatus _selectedStatus = LeadStatus.hot;
  DateTime _followUpDate = DateTime.now().add(const Duration(days: 2));
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final gymId = await AuthService.getGymId() ?? 'gym_demo';
      final now = DateTime.now();
      final lead = Lead(
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
      widget.onLeadAdded(created);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      final now = DateTime.now();
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
      widget.onLeadAdded(fallback);
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
              const Text('Add New Lead', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Name
              TextFormField(
                controller: _nameController,
                validator: InputValidator.validateName,
                decoration: const InputDecoration(labelText: 'Lead Name *', hintText: 'e.g. Sanjay Yadav'),
              ),
              const SizedBox(height: 14),

              // Phone (10 Digits)
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
                  hintText: 'e.g. 9123456780',
                  prefixText: '+91 ',
                ),
              ),
              const SizedBox(height: 14),

              // Status
              DropdownButtonFormField<LeadStatus>(
                value: _selectedStatus,
                decoration: const InputDecoration(labelText: 'Lead Status'),
                items: const [
                  DropdownMenuItem(value: LeadStatus.hot, child: Text('Hot 🔥 (High Interest)')),
                  DropdownMenuItem(value: LeadStatus.warm, child: Text('Warm ☀️ (Moderate Interest)')),
                  DropdownMenuItem(value: LeadStatus.cold, child: Text('Cold ❄️ (Low Interest)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStatus = val);
                },
              ),
              const SizedBox(height: 14),

              // Notes
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Inquiry Notes',
                  hintText: 'e.g. Interested in morning slot',
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Lead'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
