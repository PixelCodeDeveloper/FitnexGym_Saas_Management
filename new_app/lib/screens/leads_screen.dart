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
    final gymId = await AuthService.getGymId() ?? 'gym_demo';
    final now   = DateTime.now();
    final mem   = Member(
      id: 'mem_${now.millisecondsSinceEpoch}',
      gymId: gymId,
      name: lead.name,
      phone: lead.phone,
      subscriptionStart: now,
      subscriptionEnd: DateTime(now.year, now.month + 1, now.day),
      amountPaid: 1800.0,
      createdAt: now,
    );
    await DbService.addMember(mem);
    await DbService.deleteLead(lead.id);
    setState(() => _leads.removeWhere((l) => l.id == lead.id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${lead.name} converted to Member! 🎉'), backgroundColor: AppTheme.success),
      );
    }
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
    final txt2    = isDark ? const Color(0xFF8896B3) : const Color(0xFF64748B);
    final muted   = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
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
    final sc       = _statusColor(lead.status);
    final sl       = _statusLabel(lead.status);
    final initials = lead.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    final followUp = DateFormat('dd MMM yyyy').format(lead.followUpDate);
    const activeCyan = Color(0xFF00E5C0);

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
                  color: sc.withValues(alpha: 0.15),
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
                  color: sc.withValues(alpha: 0.15),
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
                  color: activeCyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2_rounded, size: 14, color: activeCyan),
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
                  color: activeCyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_rounded, size: 13, color: activeCyan),
                    const SizedBox(width: 4),
                    Text('Follow-up: $followUp', style: const TextStyle(color: activeCyan, fontSize: 11, fontWeight: FontWeight.bold)),
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
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.call_rounded, size: 13, color: Color(0xFF3B82F6)),
                      SizedBox(width: 4),
                      Text('Call', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.bold)),
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
                    color: activeCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.person_add_alt_1_rounded, size: 13, color: activeCyan),
                      SizedBox(width: 4),
                      Text('Convert', style: TextStyle(color: activeCyan, fontSize: 11, fontWeight: FontWeight.bold)),
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
