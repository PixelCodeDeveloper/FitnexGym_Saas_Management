import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/gym.dart';
import '../../services/db_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/input_validator.dart';

class EditGymScreen extends StatefulWidget {
  final Gym currentGym;
  const EditGymScreen({super.key, required this.currentGym});

  @override
  State<EditGymScreen> createState() => _EditGymScreenState();
}

class _EditGymScreenState extends State<EditGymScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ownerNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.currentGym.name);
    _ownerNameCtrl = TextEditingController(text: widget.currentGym.ownerName ?? '');
    _emailCtrl = TextEditingController(text: widget.currentGym.email ?? '');
    _addressCtrl = TextEditingController(text: widget.currentGym.address ?? '');
    _phoneCtrl = TextEditingController(text: widget.currentGym.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
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
        email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        address: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
        phone: InputValidator.sanitizePhone(_phoneCtrl.text),
        currency: widget.currentGym.currency,
        createdAt: widget.currentGym.createdAt,
      );
      final saved = await DbService.createGym(updated);
      if (mounted) Navigator.pop(context, saved);
    } catch (_) {
      final updated = Gym(
        id: widget.currentGym.id,
        ownerId: widget.currentGym.ownerId,
        name: _nameCtrl.text.trim(),
        ownerName: _ownerNameCtrl.text.trim().isNotEmpty ? _ownerNameCtrl.text.trim() : null,
        email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        address: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
        phone: InputValidator.sanitizePhone(_phoneCtrl.text),
        currency: widget.currentGym.currency,
        createdAt: widget.currentGym.createdAt,
      );
      if (mounted) Navigator.pop(context, updated);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final txt = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Edit Gym Profile',
          style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: IconThemeData(color: txt),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCtrl,
                validator: InputValidator.validateName,
                style: TextStyle(color: txt),
                decoration: const InputDecoration(
                  labelText: 'Gym Name *',
                  prefixIcon: Icon(Icons.fitness_center_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ownerNameCtrl,
                validator: InputValidator.validateName,
                style: TextStyle(color: txt),
                decoration: const InputDecoration(
                  labelText: 'Owner Name *',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: InputValidator.validateEmail,
                style: TextStyle(color: txt),
                decoration: const InputDecoration(
                  labelText: 'Contact Email *',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressCtrl,
                style: TextStyle(color: txt),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: InputValidator.validatePhone,
                style: TextStyle(color: txt),
                decoration: const InputDecoration(
                  labelText: 'Contact Phone *',
                  prefixText: '+91 ',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primary,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Update Gym Profile',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
