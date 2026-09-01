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
    final bgColor  = isDark ? AppTheme.darkBg          : AppTheme.lightBg;
    final cardBg   = isDark ? AppTheme.darkCard         : AppTheme.lightSurface;
    final border   = isDark ? AppTheme.darkBorder       : AppTheme.lightBorder;
    final tile     = isDark ? AppTheme.darkSurfaceAlt   : AppTheme.lightSurfaceAlt;
    final txt      = isDark ? AppTheme.darkTextPrimary  : AppTheme.lightTextPrimary;
    final txt2     = isDark ? AppTheme.darkTextSecondary: AppTheme.lightTextSecondary;
    final muted    = isDark ? AppTheme.darkTextMuted    : AppTheme.lightTextMuted;

    final initials = _userEmail.isNotEmpty ? _userEmail[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2))
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _loadProfileData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  // ── Profile Card ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: isDark ? 0.3 : 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Signed-in Account', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(height: 3),
                              Text(
                                _userEmail,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.g_mobiledata_rounded, color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text('Google SSO Active', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Appearance ──
                  _sectionLabel('APPEARANCE', muted),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
                    child: ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeNotifier,
                      builder: (_, mode, __) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkSurfaceAlt : AppTheme.lightSurfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: isDark ? AppTheme.primary : AppTheme.warning,
                            size: 20,
                          ),
                        ),
                        title: Text('Dark Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: txt)),
                        subtitle: Text(
                          isDark ? 'Currently using dark theme' : 'Currently using light theme',
                          style: TextStyle(fontSize: 12, color: txt2),
                        ),
                        trailing: Switch(
                          value: mode == ThemeMode.dark,
                          activeThumbColor: AppTheme.primary,
                          onChanged: (_) => themeNotifier.toggle(),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Gym Profile ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionLabel('GYM PROFILE', muted),
                      TextButton.icon(
                        onPressed: _showEditGymModal,
                        icon: const Icon(Icons.edit_rounded, size: 15),
                        label: const Text('Edit', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
                    child: Column(
                      children: [
                        _tile(Icons.fitness_center_rounded, 'Gym Name',     _gym?.name ?? 'Not set',           isDark, cardBg, tile, txt, txt2, muted, onTap: _showEditGymModal),
                        Divider(height: 1, color: border, indent: 56),
                        _tile(Icons.location_on_outlined,   'Address',      _gym?.address ?? 'Not configured', isDark, cardBg, tile, txt, txt2, muted, onTap: _showEditGymModal),
                        Divider(height: 1, color: border, indent: 56),
                        _tile(Icons.phone_outlined,          'Phone',       _gym?.phone != null ? '+91 ${_gym!.phone}' : 'Not configured', isDark, cardBg, tile, txt, txt2, muted, onTap: _showEditGymModal),
                        Divider(height: 1, color: border, indent: 56),
                        _tile(Icons.currency_rupee_rounded,  'Currency',    _gym?.currency ?? 'INR (₹)',        isDark, cardBg, tile, txt, txt2, muted),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Logout ──
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text, Color muted) => Text(
    text,
    style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
  );

  Widget _tile(
    IconData icon, String title, String value,
    bool isDark, Color cardBg, Color tile, Color txt, Color txt2, Color muted, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceAlt : AppTheme.lightSurfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppTheme.primary),
      ),
      title: Text(title, style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w600)),
      subtitle: Text(value, style: TextStyle(fontSize: 14, color: txt, fontWeight: FontWeight.w600)),
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
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl    = TextEditingController(text: widget.currentGym.name);
    _addressCtrl = TextEditingController(text: widget.currentGym.address ?? '');
    _phoneCtrl   = TextEditingController(text: widget.currentGym.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
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
