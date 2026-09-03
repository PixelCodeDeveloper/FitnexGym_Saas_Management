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
      final userEmail = await AuthService.userEmail ?? 'owner@fitnex.com';
      final orderData = await DbService.createRazorpayOrder();

      final orderId = orderData['orderId'] as String;
      final keyId   = orderData['keyId'] as String? ?? 'rzp_test_mock_key_id';
      final amount  = orderData['amount'] as int? ?? 99900;

      _pendingOrderId = orderId;

      final options = {
        'key': keyId,
        'amount': amount,
        'name': 'Fitnex Pro Renewal',
        'description': '30-Day Pro Subscription Extension',
        'order_id': orderId.startsWith('order_demo') ? null : orderId,
        'prefill': {
          'email': userEmail,
          'contact': '9999999999',
        },
        'theme': {
          'color': '#00C4A0',
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
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final bgColor  = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final border   = isDark ? const Color(0xFF162234) : const Color(0xFFE2E8F0);
    final txt      = isDark ? Colors.white : const Color(0xFF0F172A);
    final txt2     = isDark ? const Color(0xFF8896B3) : const Color(0xFF64748B);
    final muted    = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    const activeCyan = Color(0xFF00E5C0);

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
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        title: Text('Subscription & Billing', style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 20)),
        iconTheme: IconThemeData(color: txt),
        titleSpacing: 0,
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: txt),
            onPressed: _loadSubscription,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: activeCyan, strokeWidth: 2))
          : RefreshIndicator(
              color: activeCyan,
              onRefresh: _loadSubscription,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Active Subscription Header (Flat) ──
                    _buildActivePlanCard(isDark, txt2, muted),

                    const SizedBox(height: 28),
                    Divider(height: 1, color: border),
                    const SizedBox(height: 20),

                    // ── Features & Extensions Section ──
                    Text(
                      sectionTitle,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: txt,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildExtensionOptionCard(
                      title: isFirstTime ? 'Pro Monthly Plan' : 'Extend Pro Monthly',
                      price: '₹999',
                      duration: '30 Days Access',
                      description: isFirstTime
                          ? 'Get 30 days of full access to member management, WhatsApp reminders, and revenue reporting.'
                          : 'Add 30 days onto your subscription period.',
                      isRecommended: true,
                      buttonText: primaryButtonLabel,
                      isDark: isDark,
                      cardBg: Colors.transparent,
                      border: border,
                      txt: txt,
                      txt2: txt2,
                      fillBg: isDark ? const Color(0xFF131D2D) : const Color(0xFFF1F5F9),
                    ),

                    const SizedBox(height: 20),
                    Divider(height: 1, color: border),
                    const SizedBox(height: 20),

                    _buildExtensionOptionCard(
                      title: 'Annual Pro Saver',
                      price: '₹9,999',
                      duration: '365 Days Access',
                      description: 'Save over 15% with annual billing + priority support.',
                      isRecommended: false,
                      buttonText: 'Select Annual Package',
                      isDark: isDark,
                      cardBg: Colors.transparent,
                      border: border,
                      txt: txt,
                      txt2: txt2,
                      fillBg: isDark ? const Color(0xFF131D2D) : const Color(0xFFF1F5F9),
                    ),

                    const SizedBox(height: 28),
                    Divider(height: 1, color: border),
                    const SizedBox(height: 20),

                    // ── Billing Support Info ──
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: activeCyan.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.shield_outlined, color: activeCyan, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Secure SSL Payments', style: TextStyle(color: txt, fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('Processed via Razorpay gateway with instant renewal', style: TextStyle(color: txt2, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
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

  Widget _buildActivePlanCard(bool isDark, Color txt2, Color muted) {
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

    final errorBgColor = isDark ? const Color(0xFF3F1717) : AppTheme.errorBg;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: isActive ? AppTheme.primaryGradient : null,
        color: isActive ? null : errorBgColor,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: isDark ? 0.35 : 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
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
                  color: isActive ? Colors.white70 : txt2,
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
                color: isActive ? Colors.white70 : muted,
              ),
              const SizedBox(width: 6),
              Text(
                'Valid until $expFormatted',
                style: TextStyle(
                  color: isActive ? Colors.white.withValues(alpha: 0.9) : txt2,
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
    required bool isDark,
    required Color cardBg,
    required Color border,
    required Color txt,
    required Color txt2,
    required Color fillBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRecommended ? AppTheme.primary : border,
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: txt,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    duration,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                price,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: txt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(color: txt2, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessingPayment ? null : _startPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: isRecommended ? AppTheme.primary : fillBg,
                foregroundColor: isRecommended ? Colors.white : txt,
                elevation: isRecommended ? 0 : 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isProcessingPayment
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      buttonText,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isRecommended ? Colors.white : txt,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
