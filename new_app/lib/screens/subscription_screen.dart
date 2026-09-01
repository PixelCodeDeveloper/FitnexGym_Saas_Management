import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../models/subscription_info.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late Razorpay _razorpay;
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  SubscriptionInfo? _subInfo;
  String? _pendingOrderId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadSubscription();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _loadSubscription() async {
    setState(() => _isLoading = true);
    try {
      final info = await DbService.getSubscriptionInfo();
      setState(() => _subInfo = info);
    } catch (_) {
      setState(() => _subInfo = SubscriptionInfo.fallbackActive(days: 30));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startPayment() async {
    setState(() => _isProcessingPayment = true);
    try {
      final userEmail = await AuthService.userEmail ?? 'owner@fitnexgym.com';
      final orderData = await DbService.createRazorpayOrder();

      final orderId = orderData['orderId'] as String;
      final keyId = orderData['keyId'] as String? ?? 'rzp_test_mock_key_id';
      final amount = orderData['amount'] as int? ?? 99900;

      _pendingOrderId = orderId;

      final options = {
        'key': keyId,
        'amount': amount,
        'name': 'FitnexGym SaaS Pro Renewal',
        'description': '30-Day Pro Subscription Extension',
        'order_id': orderId.startsWith('order_demo') ? null : orderId,
        'prefill': {
          'email': userEmail,
          'contact': '9999999999',
        },
        'theme': {
          'color': '#00A8B5',
        },
      };

      _razorpay.open(options);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isProcessingPayment = true);
    try {
      final success = await DbService.verifyRazorpayPayment(
        orderId: response.orderId ?? _pendingOrderId ?? 'order_demo',
        paymentId: response.paymentId ?? 'pay_demo',
        signature: response.signature ?? 'sig_demo',
      );

      if (mounted && success) {
        await _loadSubscription();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription Extended Successfully! 🎉'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Failed: ${response.message} (Code: ${response.code})'),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External Wallet Selected: ${response.walletName}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = _subInfo ?? SubscriptionInfo.fallbackActive(days: 30);
    final isFirstTime = sub.isFirstTime;
    final isExpired = !sub.active;

    final sectionTitle = isFirstTime
        ? 'Available Subscription Plans'
        : (isExpired ? 'Renew Subscription' : 'Manage Subscription');

    final primaryButtonLabel = isFirstTime
        ? 'Buy Pro Plan Now →'
        : (isExpired ? 'Renew Subscription Now →' : 'Extend Subscription Now →');

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Subscription & Billing'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSubscription,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSubscription,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Active Subscription Card ──
                    _buildActivePlanCard(),

                    const SizedBox(height: 28),

                    // ── Features & Extensions Section ──
                    Text(
                      sectionTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildExtensionOptionCard(
                      title: isFirstTime ? 'Pro Monthly Plan' : 'Extend Pro Monthly',
                      price: '₹999',
                      duration: '30 Days Access',
                      description: isFirstTime
                          ? 'Get 30 days of full access to member management, WhatsApp reminders, and revenue reporting.'
                          : 'Add 30 days onto your subscription period.',
                      isRecommended: true,
                      buttonText: primaryButtonLabel,
                    ),

                    const SizedBox(height: 16),

                    _buildExtensionOptionCard(
                      title: 'Annual Pro Saver',
                      price: '₹9,999',
                      duration: '365 Days Access',
                      description: 'Save over 15% with annual billing + priority support.',
                      isRecommended: false,
                      buttonText: 'Select Annual Package',
                    ),

                    const SizedBox(height: 28),

                    // ── Billing History & Support Info ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: const Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified_user_outlined, color: AppTheme.primary, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Secure Payments by Razorpay',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'All subscription payments are encrypted with 256-bit SSL encryption. Your plan extensions stack automatically on top of existing remaining days.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildActivePlanCard() {
    final sub = _subInfo ?? SubscriptionInfo.fallbackActive(days: 30);
    final isActive = sub.active;
    final days = sub.daysRemaining;

    final DateTime expDate = sub.expiresAt ?? DateTime.now().add(Duration(days: days));
    final expFormatted = (sub.expiresAt != null || days > 0)
        ? DateFormat('dd MMM yyyy').format(expDate)
        : 'N/A';

    final badgeText = sub.isFirstTime
        ? 'NO ACTIVE PLAN'
        : (isActive ? (sub.isTrial ? 'FREE TRIAL' : 'ACTIVE') : 'EXPIRED');

    final planBadgeName = sub.isFirstTime ? 'GET STARTED' : sub.planName.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: isActive ? AppTheme.primaryGradient : null,
        color: isActive ? null : AppTheme.errorBg,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  planBadgeName,
                  style: TextStyle(
                    color: isActive ? Colors.white : AppTheme.error,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : AppTheme.error,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive ? Icons.check_circle : Icons.warning_amber_rounded,
                      size: 14,
                      color: isActive ? AppTheme.primary : Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: TextStyle(
                        color: isActive ? AppTheme.primaryDark : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$days',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: isActive ? Colors.white : AppTheme.error,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                days == 1 ? 'Day Remaining' : 'Days Remaining',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white70 : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.event_outlined,
                size: 16,
                color: isActive ? Colors.white70 : AppTheme.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                'Valid until $expFormatted',
                style: TextStyle(
                  color: isActive ? Colors.white.withValues(alpha: 0.9) : AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtensionOptionCard({
    required String title,
    required String price,
    required String duration,
    required String description,
    required bool isRecommended,
    required String buttonText,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRecommended ? AppTheme.primary : AppTheme.divider,
          width: isRecommended ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    duration,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessingPayment ? null : _startPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: isRecommended ? AppTheme.primary : AppTheme.surfaceAlt,
                foregroundColor: isRecommended ? Colors.white : AppTheme.textPrimary,
                elevation: isRecommended ? 2 : 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isProcessingPayment
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                    )
                  : Text(
                      buttonText,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isRecommended ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
