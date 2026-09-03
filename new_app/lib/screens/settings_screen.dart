import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/gym.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';
import '../utils/input_validator.dart';
import '../../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  String _userEmail = 'Loading...';
  Gym? _gym;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final email = await AuthService.userEmail ?? 'Signed-In User';
      final gym   = await DbService.getGym();
      setState(() {
        _userEmail = email;
        _gym = gym;
      });
    } catch (_) {
      final email = await AuthService.userEmail ?? 'Signed-In User';
      setState(() => _userEmail = email);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditGymModal() {
    if (_gym == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditGymForm(
        currentGym: _gym!,
        onGymUpdated: (g) => setState(() => _gym = g),
      ),
    );
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.signOut();
              if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final bgColor  = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final border   = isDark ? const Color(0xFF162234) : const Color(0xFFE2E8F0);
    final txt      = isDark ? Colors.white : const Color(0xFF0F172A);
    final txt2     = isDark ? const Color(0xFF8896B3) : const Color(0xFF64748B);
    final muted    = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    const activeCyan = Color(0xFF00E5C0);

    final initials = _userEmail.isNotEmpty ? _userEmail[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: activeCyan, strokeWidth: 2))
          : RefreshIndicator(
              color: activeCyan,
              onRefresh: _loadProfileData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  // ── Profile Header (Flat layout) ──
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: activeCyan,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Signed-in Account', style: TextStyle(color: txt2, fontSize: 11)),
                              const SizedBox(height: 3),
                              Text(
                                _userEmail,
                                style: TextStyle(color: txt, fontSize: 15, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Divider(height: 1, color: border),
                  const SizedBox(height: 20),

                  // ── Appearance ──
                  _sectionLabel('APPEARANCE', muted),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (context, mode, child) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131D2D) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: isDark ? activeCyan : const Color(0xFFF59E0B),
                          size: 20,
                        ),
                      ),
                      title: Text('Dark Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: txt)),
                      subtitle: Text(
                        isDark ? 'Currently using dark theme' : 'Currently using light theme',
                        style: TextStyle(fontSize: 12, color: txt2),
                      ),
                      trailing: Switch(
                        value: mode == ThemeMode.dark,
                        activeThumbColor: activeCyan,
                        activeTrackColor: activeCyan.withValues(alpha: 0.3),
                        onChanged: (_) => themeNotifier.toggle(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Divider(height: 1, color: border),
                  const SizedBox(height: 20),

                  // ── Gym Profile ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionLabel('GYM PROFILE', muted),
                      GestureDetector(
                        onTap: _showEditGymModal,
                        child: const Text('Edit', style: TextStyle(fontSize: 13, color: activeCyan, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      _tile(Icons.fitness_center_rounded, 'Gym Name',     _gym?.name ?? 'Not set',           isDark, txt, txt2, muted, onTap: _showEditGymModal),
                      Divider(height: 1, color: border),
                      _tile(Icons.person_outline_rounded,  'Owner Name',    _gym?.ownerName ?? 'Not configured', isDark, txt, txt2, muted, onTap: _showEditGymModal),
                      Divider(height: 1, color: border),
                      _tile(Icons.location_on_outlined,   'Address',      _gym?.address ?? 'Not configured', isDark, txt, txt2, muted, onTap: _showEditGymModal),
                      Divider(height: 1, color: border),
                      _tile(Icons.phone_outlined,          'Phone',       _gym?.phone != null ? '+91 ${_gym!.phone}' : 'Not configured', isDark, txt, txt2, muted, onTap: _showEditGymModal),
                      Divider(height: 1, color: border),
                      _tile(Icons.currency_rupee_rounded,  'Currency',    _gym?.currency ?? 'INR (₹)',        isDark, txt, txt2, muted),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ── Logout ──
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text, Color muted) => Text(
    text,
    style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
  );

  Widget _tile(
    IconData icon, String title, String value,
    bool isDark, Color txt, Color txt2, Color muted, {
    VoidCallback? onTap,
  }) {
    const activeCyan = Color(0xFF00E5C0);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D2D) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: activeCyan),
      ),
      title: Text(title, style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w600)),
      subtitle: Text(value, style: TextStyle(fontSize: 14, color: txt, fontWeight: FontWeight.bold)),
      trailing: onTap != null
          ? Icon(Icons.chevron_right_rounded, color: muted, size: 20)
          : null,
    );
  }
}

// ─────────── Edit Gym Bottom Sheet ───────────

class _EditGymForm extends StatefulWidget {
  final Gym currentGym;
  final Function(Gym) onGymUpdated;
  const _EditGymForm({required this.currentGym, required this.onGymUpdated});

  @override
  State<_EditGymForm> createState() => _EditGymFormState();
}

class _EditGymFormState extends State<_EditGymForm> {
  final _formKey    = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ownerNameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl      = TextEditingController(text: widget.currentGym.name);
    _ownerNameCtrl = TextEditingController(text: widget.currentGym.ownerName ?? '');
    _addressCtrl   = TextEditingController(text: widget.currentGym.address ?? '');
    _phoneCtrl     = TextEditingController(text: widget.currentGym.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final updated = Gym(
        id: widget.currentGym.id,
        ownerId: widget.currentGym.ownerId,
        name: _nameCtrl.text.trim(),
        ownerName: _ownerNameCtrl.text.trim().isNotEmpty ? _ownerNameCtrl.text.trim() : null,
        address: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
        phone: InputValidator.sanitizePhone(_phoneCtrl.text),
        currency: widget.currentGym.currency,
        createdAt: widget.currentGym.createdAt,
      );
      final saved = await DbService.createGym(updated);
      widget.onGymUpdated(saved);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      // Optimistic update
      final updated = Gym(
        id: widget.currentGym.id,
        ownerId: widget.currentGym.ownerId,
        name: _nameCtrl.text.trim(),
        ownerName: _ownerNameCtrl.text.trim().isNotEmpty ? _ownerNameCtrl.text.trim() : null,
        address: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
        phone: InputValidator.sanitizePhone(_phoneCtrl.text),
        currency: widget.currentGym.currency,
        createdAt: widget.currentGym.createdAt,
      );
      widget.onGymUpdated(updated);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 20,
        right: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Edit Gym Profile', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                validator: InputValidator.validateName,
                decoration: const InputDecoration(
                  labelText: 'Gym Name *',
                  prefixIcon: Icon(Icons.fitness_center_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ownerNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Owner Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: InputValidator.validatePhone,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone *',
                  prefixText: '+91 ',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Update Gym Profile', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
