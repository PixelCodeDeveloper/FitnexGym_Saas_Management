import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead.dart';
import '../models/member.dart';
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

  Future<void> _openAddLeadScreen() async {
    final newLead = await Navigator.push<Lead>(
      context,
      MaterialPageRoute(builder: (_) => const AddLeadScreen()),
    );
    if (newLead != null) {
      setState(() {
        _leads.insert(0, newLead);
      });
    }
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
        onPressed: _openAddLeadScreen,
        icon: const Icon(Icons.add),
        label: const Text('New Lead'),
      ),
    );
  }
}
