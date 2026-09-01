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
      final userEmail = await AuthService.userEmail ?? 'owner@fitnexgym.com';
      final orderData = await DbService.createRazorpayOrder();

      final orderId = orderData['orderId'] as String;
      final keyId = orderData['keyId'] as String? ?? 'rzp_test_mock_key_id';
      final amount = orderData['amount'] as int? ?? 99900;

      _pendingOrderId = orderId;

      final options = {
        'key': keyId,
        'amount': amount,
        'name': 'FitnexGym SaaS Pro',
        'description': 'Monthly Pro Plan Subscription (30 Days)',
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
    if (_isCheckingStatus) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final isFirstTime = _subInfo?.isFirstTime ?? false;
    final titleText = isFirstTime ? 'Buy Pro Subscription' : 'Subscription Expired';
    final subtitleText = isFirstTime
        ? 'Unlock full access to FitnexGym SaaS to manage members, track monthly revenue, and power your gym operations.'
        : 'Your monthly subscription has expired. Renew your plan to continue managing members, tracking revenue, and growing your gym business.';
    final buttonText = isFirstTime ? 'Buy Subscription Now →' : 'Renew Subscription Now →';
    final iconBgColor = isFirstTime ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.errorBg;
    final iconColor = isFirstTime ? AppTheme.primary : AppTheme.error;
    final headerIcon = isFirstTime ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  headerIcon,
                  size: 56,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                titleText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitleText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 36),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: AppTheme.primaryGradient,
                ),
                child: Column(
                  children: [
                    const Text(
                      'Pro Plan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '₹999',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    const Text(
                      '/month',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        children: [
                          _FeatureRow('Unlimited Members'),
                          SizedBox(height: 6),
                          _FeatureRow('Revenue Analytics'),
                          SizedBox(height: 6),
                          _FeatureRow('WhatsApp Integration'),
                          SizedBox(height: 6),
                          _FeatureRow('Diet Plan Module'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _startPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primary,
                                ),
                              )
                            : Text(buttonText),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isLoading ? null : _handleRestorePurchase,
                      child: const Text(
                        'Already Paid? Restore Active Plan 🔄',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _handleSignOut,
                child: const Text(
                  'Sign Out',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
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
          Navigator.pushReplacementNamed(context, '/main');
        }
        return;
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  const _FeatureRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }
}
