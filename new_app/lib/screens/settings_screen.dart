import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/gym.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';
import '../utils/input_validator.dart';

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
      final gym = await DbService.getGym();

      setState(() {
        _userEmail = email;
        _gym = gym;
      });
    } catch (_) {
      final email = await AuthService.userEmail ?? 'Signed-In User';
      final gym = await DbService.getGym();
      setState(() {
        _userEmail = email;
        _gym = gym;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditGymModal() {
    if (_gym == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _EditGymForm(
        currentGym: _gym!,
        onGymUpdated: (updatedGym) {
          setState(() {
            _gym = updatedGym;
          });
        },
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
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
          : RefreshIndicator(
              onRefresh: _loadProfileData,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // ── Account / Google Profile Card ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Signed-in Account',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _userEmail,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.g_mobiledata_rounded, color: Colors.white, size: 18),
                                    Text(
                                      'Google SSO Active',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
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

                  // ── Gym Profile Details ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionLabel('GYM PROFILE DETAILS'),
                      TextButton.icon(
                        onPressed: _showEditGymModal,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                      children: [
                        _settingsTile(
                          Icons.fitness_center_rounded,
                          'Gym Name',
                          _gym?.name ?? 'Tap Edit to set Gym Name',
                          true,
                          onTap: _showEditGymModal,
                        ),
                        const Divider(height: 1, indent: 56),
                        _settingsTile(
                          Icons.location_on_outlined,
                          'Address',
                          _gym?.address ?? 'Not configured',
                          true,
                          onTap: _showEditGymModal,
                        ),
                        const Divider(height: 1, indent: 56),
                        _settingsTile(
                          Icons.phone_outlined,
                          'Contact Phone',
                          _gym?.phone != null ? '+91 ${_gym!.phone}' : 'Not configured',
                          true,
                          onTap: _showEditGymModal,
                        ),
                        const Divider(height: 1, indent: 56),
                        _settingsTile(
                          Icons.currency_rupee_rounded,
                          'Currency',
                          _gym?.currency ?? 'INR (₹)',
                          false,
                        ),
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
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Log Out'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _settingsTile(
    IconData icon,
    String title,
    String value,
    bool editable, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.textSecondary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.textMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: editable
          ? const Icon(Icons.chevron_right, color: AppTheme.textMuted)
          : null,
      onTap: onTap,
    );
  }
}

class _EditGymForm extends StatefulWidget {
  final Gym currentGym;
  final Function(Gym) onGymUpdated;
  const _EditGymForm({required this.currentGym, required this.onGymUpdated});

  @override
  State<_EditGymForm> createState() => _EditGymFormState();
}

class _EditGymFormState extends State<_EditGymForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentGym.name);
    _addressController = TextEditingController(text: widget.currentGym.address ?? '');
    _phoneController = TextEditingController(text: widget.currentGym.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final updated = Gym(
        id: widget.currentGym.id,
        ownerId: widget.currentGym.ownerId,
        name: _nameController.text.trim(),
        address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
        phone: InputValidator.sanitizePhone(_phoneController.text),
        currency: widget.currentGym.currency,
        createdAt: widget.currentGym.createdAt,
      );

      final saved = await DbService.createGym(updated);
      widget.onGymUpdated(saved);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      final updated = Gym(
        id: widget.currentGym.id,
        ownerId: widget.currentGym.ownerId,
        name: _nameController.text.trim(),
        address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
        phone: InputValidator.sanitizePhone(_phoneController.text),
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
              const Text('Edit Gym Profile Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameController,
                validator: InputValidator.validateName,
                decoration: const InputDecoration(labelText: 'Gym Name *'),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Gym Address'),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: InputValidator.validatePhone,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone Number (10 Digits) *',
                  prefixText: '+91 ',
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Update Gym Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }
}
