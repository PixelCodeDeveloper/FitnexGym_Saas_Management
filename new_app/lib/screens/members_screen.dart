import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/member.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';
import 'forms/add_member_screen.dart';
import 'forms/edit_member_screen.dart';
import 'forms/renew_member_screen.dart';
import 'member_detail_screen.dart';
import '../models/diet_plan.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  String _selectedFilter = 'All';
  String _searchQuery   = '';
  final _filters = ['All', 'Active', 'Expiring Soon', 'Expired'];
  bool _isLoading = true;
  List<Member> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
    DbService.membersRefreshNotifier.addListener(_onMembersChanged);
  }

  @override
  void dispose() {
    DbService.membersRefreshNotifier.removeListener(_onMembersChanged);
    super.dispose();
  }

  void _onMembersChanged() {
    if (mounted) _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      _members = await DbService.getMembers();
    } catch (_) {
      _members = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(MemberStatus s) {
    switch (s) {
      case MemberStatus.active:       return AppTheme.success;
      case MemberStatus.expiringSoon: return AppTheme.warning;
      case MemberStatus.expired:      return AppTheme.error;
    }
  }

  String _statusLabel(MemberStatus s) {
    switch (s) {
      case MemberStatus.active:       return 'Active';
      case MemberStatus.expiringSoon: return 'Expiring';
      case MemberStatus.expired:      return 'Expired';
    }
  }

  IconData _statusIcon(MemberStatus s) {
    switch (s) {
      case MemberStatus.active:       return Icons.check_circle_rounded;
      case MemberStatus.expiringSoon: return Icons.timer_outlined;
      case MemberStatus.expired:      return Icons.cancel_rounded;
    }
  }

  Future<void> _openAddMemberScreen() async {
    final newMember = await Navigator.push<Member>(
      context,
      MaterialPageRoute(builder: (_) => const AddMemberScreen()),
    );
    if (newMember != null) setState(() => _members.insert(0, newMember));
  }

  Future<void> _openEditMemberScreen(Member member) async {
    final updated = await Navigator.push<Member>(
      context,
      MaterialPageRoute(builder: (_) => EditMemberScreen(member: member)),
    );
    if (updated != null) {
      setState(() {
        final idx = _members.indexWhere((m) => m.id == member.id);
        if (idx != -1) _members[idx] = updated;
      });
    }
  }

  Future<void> _openMemberDetailScreen(Member member) async {
    final updated = await Navigator.push<Member>(
      context,
      MaterialPageRoute(builder: (_) => MemberDetailScreen(member: member)),
    );
    if (updated != null && mounted) {
      _loadMembers();
    }
  }

  Future<void> _openAssignDietFromList(Member member) async {
    final templates = await DbService.getDietPlans().catchError((_) => <DietPlan>[]);
    DietPlan? selectedTemplate = templates.isNotEmpty ? templates.first : null;
    final titleCtrl = TextEditingController(text: selectedTemplate != null ? '${selectedTemplate.title} (for ${member.name})' : 'Personalized Plan for ${member.name}');
    final caloriesCtrl = TextEditingController(text: selectedTemplate?.calories ?? '2100 kcal');
    final proteinCtrl = TextEditingController(text: selectedTemplate?.macros?['protein'] ?? '150g');
    int reviewDays = 30;
    bool isAssigning = false;

    if (!mounted) return;

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
                      Text('Assign Diet to ${member.name}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: txt)),
                    ]),
                    const SizedBox(height: 6),
                    Text('Select master template & customize macros for member', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF475569))),
                    const SizedBox(height: 16),

                    if (templates.isNotEmpty) ...[
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
                        items: templates.map((t) => DropdownMenuItem(value: t, child: Text('${t.title} (${t.CategoryBadge})'))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedTemplate = val;
                              titleCtrl.text = '${val.title} (for ${member.name})';
                              caloriesCtrl.text = val.calories;
                              proteinCtrl.text = val.macros?['protein'] ?? '150g';
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
                            labelText: 'Protein Target',
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
                                    'member_id': member.id,
                                    'template_id': selectedTemplate?.id.isNotEmpty == true ? selectedTemplate?.id : null,
                                    'custom_title': titleCtrl.text.trim(),
                                    'category': selectedTemplate?.category ?? 'veg',
                                    'goal_tag': selectedTemplate?.goalTag ?? 'Fat Loss',
                                    'calories': caloriesCtrl.text.trim(),
                                    'macros': {
                                      'protein': proteinCtrl.text.trim(),
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Assigned "${assigned.customTitle}" to ${member.name}! 🎉')),
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

  Future<void> _openRenewScreen(Member member) async {
    final updated = await Navigator.push<Member>(
      context,
      MaterialPageRoute(builder: (_) => RenewMemberScreen(member: member)),
    );
    if (updated != null) {
      setState(() {
        final idx = _members.indexWhere((m) => m.id == member.id);
        if (idx != -1) _members[idx] = updated;
      });
    }
  }

  Future<void> _launchWhatsApp(Member member) async {
    final phone = member.phone.replaceAll(RegExp(r'[^\d]'), '');
    final full  = phone.length == 10 ? '91$phone' : phone;
    final msg   = Uri.encodeComponent(
      'Hi ${member.name}, your Fitnex GYM membership expires on '
      '${DateFormat('dd MMM yyyy').format(member.subscriptionEnd)}. '
      'Please renew to keep enjoying your workout sessions!',
    );
    final url = Uri.parse('https://wa.me/$full?text=$msg');
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

  Future<void> _sendReceiptEmail(Member member) async {
    if (member.email == null || member.email!.isEmpty) {
      _promptMemberEmailAndSend(member, action: 'receipt');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF Receipt & Sending Email… 📄')));
    final ok = await DbService.sendMemberReceiptEmail(
      memberId: member.id,
      memberEmail: member.email!,
      amount: member.amountPaid,
      startDate: member.subscriptionStart,
      endDate: member.subscriptionEnd,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Receipt PDF sent to ${member.email}! 📧' : 'Failed to send receipt email'),
        backgroundColor: ok ? AppTheme.success : AppTheme.error,
      ));
    }
  }

  Future<void> _sendExpiryReminderEmail(Member member) async {
    if (member.email == null || member.email!.isEmpty) {
      _promptMemberEmailAndSend(member, action: 'expiry');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending Expiry Reminder Email… 📧')));
    final ok = await DbService.sendMemberExpiryReminderEmail(member.id, email: member.email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Expiry Reminder sent to ${member.email}! 🚀' : 'Failed to send expiry email'),
        backgroundColor: ok ? AppTheme.success : AppTheme.error,
      ));
    }
  }

  void _promptMemberEmailAndSend(Member member, {required String action}) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'receipt' ? 'Send Receipt Email' : 'Send Expiry Reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter email address for ${member.name}:'),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'member@email.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              if (action == 'receipt') {
                final ok = await DbService.sendMemberReceiptEmail(
                  memberId: member.id,
                  memberEmail: email,
                  amount: member.amountPaid,
                  startDate: member.subscriptionStart,
                  endDate: member.subscriptionEnd,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok ? 'Receipt PDF sent to $email! 📧' : 'Failed to send receipt email'),
                    backgroundColor: ok ? AppTheme.success : AppTheme.error,
                  ));
                }
              } else {
                final ok = await DbService.sendMemberExpiryReminderEmail(member.id, email: email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok ? 'Expiry Reminder sent to $email! 🚀' : 'Failed to send expiry email'),
                    backgroundColor: ok ? AppTheme.success : AppTheme.error,
                  ));
                }
              }
            },
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

  void _showEmailOptions(Member member) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final txt    = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final txt2   = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Email & PDF Options for ${member.name}', style: TextStyle(color: txt, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF0EA5E9), size: 22),
              ),
              title: Text('Send Payment Receipt PDF', style: TextStyle(color: txt, fontWeight: FontWeight.w600)),
              subtitle: Text('Email official PDF receipt & payment proof to member', style: TextStyle(color: txt2, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _sendReceiptEmail(member);
              },
            ),
            Divider(color: border, height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.mark_email_unread_rounded, color: AppTheme.warning, size: 22),
              ),
              title: Text('Send Expiry Reminder Email', style: TextStyle(color: txt, fontWeight: FontWeight.w600)),
              subtitle: Text('Send membership expiry notice email to member', style: TextStyle(color: txt2, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _sendExpiryReminderEmail(member);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Member member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Member'),
        content: Text('Remove ${member.name} permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await DbService.deleteMember(member.id);
              setState(() => _members.removeWhere((m) => m.id == member.id));
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('${member.name} removed')));
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
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bgColor   = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final barBg     = isDark ? const Color(0xFF08101C) : Colors.white;
    final border    = isDark ? const Color(0xFF162234) : const Color(0xFFE2E8F0);
    final txt       = isDark ? Colors.white : const Color(0xFF0F172A);
    final txt2      = isDark ? const Color(0xFF8896B3) : const Color(0xFF334155);
    final muted     = isDark ? const Color(0xFF64748B) : const Color(0xFF475569);
    final inputFill = isDark ? const Color(0xFF131D2D) : const Color(0xFFF1F5F9);
    const activeCyan= Color(0xFF00E5C0);

    final filtered = _members.where((m) {
      final q = _searchQuery.toLowerCase();
      if (!m.name.toLowerCase().contains(q) && !m.phone.contains(q)) return false;
      if (_selectedFilter == 'Active')       return m.status == MemberStatus.active;
      if (_selectedFilter == 'Expiring Soon') return m.status == MemberStatus.expiringSoon;
      if (_selectedFilter == 'Expired')      return m.status == MemberStatus.expired;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // ── Search + Filter bar ──
          Container(
            color: barBg,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: TextStyle(color: txt, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone…',
                    hintStyle: TextStyle(color: muted, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: muted),
                    filled: true,
                    fillColor: inputFill,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: activeCyan, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (context, i) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final f = _filters[i];
                      final sel = _selectedFilter == f;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? (isDark ? activeCyan : AppTheme.darkColor(activeCyan, isDark)) : inputFill,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? (isDark ? activeCyan : AppTheme.darkColor(activeCyan, isDark)) : border,
                            ),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              color: sel ? Colors.white : txt2,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Member count header ──
          if (!_isLoading)
            Container(
              color: bgColor,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Text('${filtered.length} members', style: TextStyle(color: txt2, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),

          // ── Flat Member List ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: activeCyan, strokeWidth: 2))
                : filtered.isEmpty
                    ? _emptyState(isDark, txt, muted)
                    : RefreshIndicator(
                        color: activeCyan,
                        onRefresh: _loadMembers,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: filtered.length,
                          separatorBuilder: (context, idx) => Divider(height: 1, color: border),
                          itemBuilder: (context, index) =>
                              _memberTile(filtered[index], isDark, border, txt, txt2, muted),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddMemberScreen,
        backgroundColor: activeCyan,
        foregroundColor: Colors.black,
        elevation: 0,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _memberTile(
    Member m, bool isDark,
    Color border,
    Color txt, Color txt2, Color muted,
  ) {
    final statusColor  = _statusColor(m.status);
    final statusLabel  = _statusLabel(m.status);
    final statusIcon   = _statusIcon(m.status);
    final initials     = m.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    final daysLeft     = m.subscriptionEnd.difference(DateTime.now()).inDays;
    final expStr       = DateFormat('dd MMM yyyy').format(m.subscriptionEnd);
    const activeCyan   = Color(0xFF00E5C0);

    return InkWell(
      onTap: () => _openMemberDetailScreen(m),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (isDark ? activeCyan : AppTheme.darkColor(activeCyan, isDark)).withValues(alpha: isDark ? 0.15 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials.isEmpty ? 'M' : initials,
                  style: TextStyle(color: isDark ? activeCyan : AppTheme.darkColor(activeCyan, isDark), fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Member Main Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          m.name,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: txt),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: isDark ? 0.15 : 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 10, color: AppTheme.darkColor(statusColor, isDark)),
                            const SizedBox(width: 3),
                            Text(statusLabel, style: TextStyle(color: AppTheme.darkColor(statusColor, isDark), fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('+91 ${m.phone}', style: TextStyle(color: txt2, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: muted, fontSize: 12)),
                      const SizedBox(width: 8),
                      Text('₹${m.amountPaid.toInt()}', style: TextStyle(color: AppTheme.darkColor(activeCyan, isDark), fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.how_to_reg_rounded, size: 11, color: AppTheme.darkColor(activeCyan, isDark)),
                      const SizedBox(width: 4),
                      Text('Joined: ${DateFormat('dd MMM yyyy, hh:mm a').format(m.createdAt)}', style: TextStyle(color: txt2, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 11, color: muted),
                      const SizedBox(width: 4),
                      Text('Exp: $expStr', style: TextStyle(color: txt2, fontSize: 11)),
                      if (daysLeft >= 0) ...[
                        const SizedBox(width: 6),
                        Text('($daysLeft days left)', style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // 3-Dot Popup Menu Button
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: txt2, size: 22),
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    _openMemberDetailScreen(m);
                    break;
                  case 'diet':
                    _openAssignDietFromList(m);
                    break;
                  case 'whatsapp':
                    _launchWhatsApp(m);
                    break;
                  case 'email':
                    _showEmailOptions(m);
                    break;
                  case 'renew':
                    _openRenewScreen(m);
                    break;
                  case 'edit':
                    _openEditMemberScreen(m);
                    break;
                  case 'delete':
                    _confirmDelete(m);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_rounded, size: 18, color: activeCyan),
                      const SizedBox(width: 12),
                      Text('View Details', style: TextStyle(color: txt, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'diet',
                  child: Row(
                    children: [
                      const Icon(Icons.restaurant_menu_rounded, size: 18, color: activeCyan),
                      const SizedBox(width: 12),
                      Text('Assign Diet', style: TextStyle(color: txt, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'whatsapp',
                  child: Row(
                    children: [
                      const Icon(Icons.chat_rounded, size: 18, color: Color(0xFF22C55E)),
                      const SizedBox(width: 12),
                      Text('WhatsApp Reminder', style: TextStyle(color: txt, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'email',
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xFF0EA5E9)),
                      const SizedBox(width: 12),
                      Text('PDF & Email Receipt', style: TextStyle(color: txt, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'renew',
                  child: Row(
                    children: [
                      const Icon(Icons.autorenew_rounded, size: 18, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 12),
                      Text('Renew Membership', style: TextStyle(color: txt, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, size: 18, color: txt2),
                      const SizedBox(width: 12),
                      Text('Edit Profile', style: TextStyle(color: txt, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                      const SizedBox(width: 12),
                      const Text('Delete Member', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
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
          child: const Icon(Icons.people_outline_rounded, size: 40, color: AppTheme.primary),
        ),
        const SizedBox(height: 16),
        Text('No members found', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: txt)),
        const SizedBox(height: 6),
        Text('Try a different filter or add a new member.', style: TextStyle(color: muted, fontSize: 13)),
      ],
    ),
  );
}
