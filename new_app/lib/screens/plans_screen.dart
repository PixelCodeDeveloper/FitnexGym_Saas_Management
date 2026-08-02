import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/subscription_plan.dart';
import '../services/db_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/input_validator.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  bool _isLoading = true;
  List<SubscriptionPlan> _plans = [];

  final List<SubscriptionPlan> _fallbackPlans = [
    SubscriptionPlan(
      id: 'p1',
      gymId: 'g1',
      name: '1 Month Basic Plan',
      durationDays: 30,
      price: 1500.0,
      description: 'Basic gym floor access.',
      createdAt: DateTime.now(),
    ),
    SubscriptionPlan(
      id: 'p2',
      gymId: 'g1',
      name: '3 Months Standard Plan',
      durationDays: 90,
      price: 4000.0,
      description: 'Save ₹500. Most Popular.',
      createdAt: DateTime.now(),
    ),
    SubscriptionPlan(
      id: 'p3',
      gymId: 'g1',
      name: '1 Year Pro Annual',
      durationDays: 365,
      price: 12000.0,
      description: '1 Month Free + Personal Trainer guidance.',
      createdAt: DateTime.now(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final list = await DbService.getPlans();
      setState(() {
        _plans = list.isEmpty ? _fallbackPlans : list;
      });
    } catch (_) {
      setState(() {
        _plans = _fallbackPlans;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddPlanModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddPlanForm(
        onPlanAdded: (newPlan) {
          setState(() {
            _plans.insert(0, newPlan);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPlans,
              child: ListView.separated(
                padding: const EdgeInsets.all(16.0),
                itemCount: _plans.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final plan = _plans[index];
                  final isPopular = plan.durationDays == 90;
                  final highlightColor = isPopular ? AppTheme.primary : AppTheme.textSecondary;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPopular ? AppTheme.primary : AppTheme.divider,
                        width: isPopular ? 2 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: highlightColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.card_membership,
                                  color: highlightColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plan.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 17,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      plan.description ?? '${plan.durationDays} Days membership',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${plan.price.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: highlightColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${plan.durationDays} Days',
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isPopular)
                          Positioned(
                            top: 0,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'POPULAR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPlanModal,
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
      ),
    );
  }
}

class _AddPlanForm extends StatefulWidget {
  final Function(SubscriptionPlan) onPlanAdded;
  const _AddPlanForm({required this.onPlanAdded});

  @override
  State<_AddPlanForm> createState() => _AddPlanFormState();
}

class _AddPlanFormState extends State<_AddPlanForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  int _durationDays = 30;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final gymId = await AuthService.getGymId() ?? 'gym_demo';
      final now = DateTime.now();
      final plan = SubscriptionPlan(
        id: 'plan_${now.millisecondsSinceEpoch}',
        gymId: gymId,
        name: _nameController.text.trim(),
        durationDays: _durationDays,
        price: double.parse(_priceController.text.trim()),
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        createdAt: now,
      );

      final created = await DbService.addPlan(plan);
      widget.onPlanAdded(created);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      final now = DateTime.now();
      final fallback = SubscriptionPlan(
        id: 'plan_${now.millisecondsSinceEpoch}',
        gymId: 'gym_demo',
        name: _nameController.text.trim(),
        durationDays: _durationDays,
        price: double.tryParse(_priceController.text.trim()) ?? 1500.0,
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        createdAt: now,
      );
      widget.onPlanAdded(fallback);
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
              const Text('Add Subscription Plan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Title
              TextFormField(
                controller: _nameController,
                validator: InputValidator.validateName,
                decoration: const InputDecoration(labelText: 'Plan Name *', hintText: 'e.g. 6 Months Gold Package'),
              ),
              const SizedBox(height: 14),

              // Price
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: InputValidator.validateAmount,
                decoration: const InputDecoration(labelText: 'Plan Price (₹) *', prefixText: '₹ ', hintText: 'e.g. 7500'),
              ),
              const SizedBox(height: 14),

              // Duration
              DropdownButtonFormField<int>(
                value: _durationDays,
                decoration: const InputDecoration(labelText: 'Duration'),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30 Days (1 Month)')),
                  DropdownMenuItem(value: 90, child: Text('90 Days (3 Months)')),
                  DropdownMenuItem(value: 180, child: Text('180 Days (6 Months)')),
                  DropdownMenuItem(value: 365, child: Text('365 Days (1 Year)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _durationDays = val);
                },
              ),
              const SizedBox(height: 14),

              // Description
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Plan Description',
                  hintText: 'e.g. Full access + free steam bath',
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
                      : const Text('Save Plan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
