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
    final bgColor = isDark ? AppTheme.darkBg          : AppTheme.lightBg;
    final cardBg  = isDark ? AppTheme.darkCard         : AppTheme.lightSurface;
    final border  = isDark ? AppTheme.darkBorder       : AppTheme.lightBorder;
    final footBg  = isDark ? AppTheme.darkSurfaceAlt   : AppTheme.lightSurfaceAlt;
    final txt     = isDark ? AppTheme.darkTextPrimary  : AppTheme.lightTextPrimary;
    final txt2    = isDark ? AppTheme.darkTextSecondary: AppTheme.lightTextSecondary;
    final muted   = isDark ? AppTheme.darkTextMuted    : AppTheme.lightTextMuted;

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2))
          : _leads.isEmpty
              ? _emptyState(isDark, txt, muted)
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _loadLeads,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _leads.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _leadCard(_leads[i], isDark, cardBg, border, footBg, txt, txt2, muted),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddLeadScreen,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('New Lead', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _leadCard(
    Lead lead, bool isDark,
    Color cardBg, Color border, Color footBg,
    Color txt, Color txt2, Color muted,
  ) {
    final sc       = _statusColor(lead.status);
    final sl       = _statusLabel(lead.status);
    final initials = lead.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    final followUp = DateFormat('dd MMM yyyy').format(lead.followUpDate);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: sc.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(
                      initials.isEmpty ? 'L' : initials,
                      style: TextStyle(color: sc, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lead.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: txt)),
                      const SizedBox(height: 3),
                      Text('+91 ${lead.phone}', style: TextStyle(color: txt2, fontSize: 12)),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sc.withValues(alpha: 0.3)),
                  ),
                  child: Text(sl, style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.error.withValues(alpha: 0.7)),
                  onPressed: () => _confirmDelete(lead),
                ),
              ],
            ),
          ),

          // ── Note ──
          if (lead.note != null && lead.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: isDark ? 0.08 : 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.sticky_note_2_rounded, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(lead.note!, style: TextStyle(color: txt2, fontSize: 12, fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ),
            ),

          // ── Follow-up ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_rounded, size: 13, color: AppTheme.primary),
                      const SizedBox(width: 5),
                      Text('Follow-up: $followUp', style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Actions ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: footBg,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _makeCall(lead),
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: const Text('Call', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _convertToMember(lead),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text('Convert', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
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
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.contacts_rounded, size: 40, color: AppTheme.primary),
        ),
        const SizedBox(height: 16),
        Text('No leads yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: txt)),
        const SizedBox(height: 6),
        Text('Add leads to start tracking potential members.', style: TextStyle(color: muted, fontSize: 13)),
      ],
    ),
  );
}
