import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../models/subscription_info.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late Razorpay _razorpay;
  bool _isLoading = false;
  bool _isCheckingStatus = true;
  SubscriptionInfo? _subInfo;
  String? _pendingOrderId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _checkSubscriptionState();
  }

  Future<void> _checkSubscriptionState() async {
    try {
      final info = await DbService.getSubscriptionInfo();
      if (mounted) {
        setState(() {
          _subInfo = info;
          _isCheckingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _startPayment() async {
    setState(() => _isLoading = true);
    try {
      final userEmail = await AuthService.userEmail ?? 'owner@fitnex.com';
      final orderData = await DbService.createRazorpayOrder();

      final orderId = orderData['orderId'] as String;
      final keyId = orderData['keyId'] as String? ?? 'rzp_test_mock_key_id';
      final amount = orderData['amount'] as int? ?? 99900;

      _pendingOrderId = orderId;

      final options = {
        'key': keyId,
        'amount': amount,
        'name': 'Fitnex Pro',
        'description': 'Monthly Pro Plan Subscription (30 Days)',
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
            content: Text('Failed to initiate payment: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isLoading = true);
    try {
      final success = await DbService.verifyRazorpayPayment(
        orderId: response.orderId ?? _pendingOrderId ?? 'order_demo',
        paymentId: response.paymentId ?? 'pay_demo',
        signature: response.signature ?? 'sig_demo',
      );

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment Successful! Subscription Unlocked 🎉'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pushReplacementNamed(context, '/dashboard');
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
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _handleSignOut() async {
    await AuthService.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final bgColor  = isDark ? const Color(0xFF08101C) : const Color(0xFFF8FAFC);
    final txt      = isDark ? Colors.white : const Color(0xFF0F172A);
    final txt2     = isDark ? const Color(0xFF8896B3) : const Color(0xFF64748B);
    final muted    = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    const activeCyan = Color(0xFF00E5C0);

    if (_isCheckingStatus) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator(color: activeCyan, strokeWidth: 2)),
      );
    }

    final isFirstTime = _subInfo?.isFirstTime ?? false;
    final titleText = isFirstTime ? 'Buy Pro Subscription' : 'Subscription Expired';
    final subtitleText = isFirstTime
        ? 'Unlock full access to Fitnex to manage members, track monthly revenue, and power your gym operations.'
        : 'Your monthly subscription has expired. Renew your plan to continue managing members, tracking revenue, and growing your gym business.';
    final buttonText = isFirstTime ? 'Buy Subscription Now →' : 'Renew Subscription Now →';

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: activeCyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 56,
                  color: activeCyan,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                titleText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: txt,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitleText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: txt2,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 36),

              // ── Price Header (Flat) ──
              Column(
                children: [
                  Text(
                    'PRO MONTHLY PLAN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: activeCyan,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹999',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: activeCyan,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    'for 30 days full access',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                  const SizedBox(height: 24),
                  Column(
                    children: [
                      _featureRow('Unlimited Member Registration', txt),
                      const SizedBox(height: 8),
                      _featureRow('Automated WhatsApp & SMS Reminders', txt),
                      const SizedBox(height: 8),
                      _featureRow('Diet & Membership Template Manager', txt),
                      const SizedBox(height: 8),
                      _featureRow('Real-Time Revenue Analytics & Reports', txt),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _startPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading ? null : _handleRestorePurchase,
                    child: const Text(
                      'Already Paid? Restore Active Plan 🔄',
                      style: TextStyle(
                        color: activeCyan,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationColor: activeCyan,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _handleSignOut,
                    icon: Icon(Icons.logout_rounded, color: muted, size: 18),
                    label: Text(
                      'Sign Out',
                      style: TextStyle(color: muted, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(String label, Color txt) {
    const activeCyan = Color(0xFF00E5C0);
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: activeCyan, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: txt, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Future<void> _handleRestorePurchase() async {
    setState(() => _isLoading = true);
    try {
      final success = await DbService.syncActiveSubscriptionWithServer();
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Active Plan Restored & Synced! 🎉'),
              backgroundColor: AppTheme.success,
            ),
          );
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
        return;
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
