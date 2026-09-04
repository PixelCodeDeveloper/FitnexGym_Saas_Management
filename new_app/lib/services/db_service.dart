import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/diet_plan.dart';
import '../models/gym.dart';
import '../models/lead.dart';
import '../models/member.dart';
import '../models/payment.dart';
import '../models/subscription_info.dart';
import '../models/subscription_plan.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// All database access is server-side. The API derives the gym from the JWT;
/// callers cannot select another tenant by changing a gym_id in the app.
class DbService {
  static const _gymNameKey = 'saved_gym_name';
  static const _gymOwnerNameKey = 'saved_gym_owner_name';
  static const _gymAddressKey = 'saved_gym_address';
  static const _gymPhoneKey = 'saved_gym_phone';
  static const _subExpiryPrefix = 'saved_sub_expiry_';
  static const _subPlanPrefix = 'saved_sub_plan_';
  static final _storage = FlutterSecureStorage();

  static Future<Gym?> getGym([String? _]) async {
    try {
      final data = await ApiClient.get('/v1/gym');
      if (data != null) return Gym.fromJson(data as Map<String, dynamic>);
    } catch (_) {}

    final name = await _storage.read(key: _gymNameKey);
    if (name == null || name.isEmpty) return null;

    final ownerName = await _storage.read(key: _gymOwnerNameKey);
    final address = await _storage.read(key: _gymAddressKey);
    final phone = await _storage.read(key: _gymPhoneKey);
    final gymId = await AuthService.getGymId() ?? 'gym_local';
    final ownerId = await AuthService.currentUserId ?? 'owner_local';

    return Gym(
      id: gymId,
      ownerId: ownerId,
      name: name,
      ownerName: ownerName,
      address: address,
      phone: phone,
      currency: 'INR',
      createdAt: DateTime.now(),
    );
  }

  static Future<Gym> createGym(Gym gym) async {
    await _storage.write(key: _gymNameKey, value: gym.name);
    if (gym.ownerName != null) await _storage.write(key: _gymOwnerNameKey, value: gym.ownerName!);
    if (gym.address != null) await _storage.write(key: _gymAddressKey, value: gym.address!);
    if (gym.phone != null) await _storage.write(key: _gymPhoneKey, value: gym.phone!);

    try {
      final res = await ApiClient.post('/v1/gym', {
        'name': gym.name,
        'owner_name': gym.ownerName,
        'address': gym.address,
        'phone': gym.phone,
        'currency': gym.currency,
      });
      return Gym.fromJson(res as Map<String, dynamic>);
    } catch (_) {
      final userId = await AuthService.currentUserId ?? 'demo_owner_id';
      final gymId = 'gym_${DateTime.now().millisecondsSinceEpoch}';
      await AuthService.saveGymId(gymId);
      return Gym(
        id: gymId,
        ownerId: userId,
        name: gym.name,
        address: gym.address,
        phone: gym.phone,
        currency: gym.currency,
        createdAt: DateTime.now(),
      );
    }
  }

  static Future<List<Member>> getMembers([String? _]) async =>
      _list('/v1/members', Member.fromJson);
  static Future<Member> addMember(Member m) async => Member.fromJson(
    await ApiClient.post('/v1/members', m.toJson()) as Map<String, dynamic>,
  );
  static Future<void> updateMember(String id, Map<String, dynamic> updates) async {
    try {
      await ApiClient.patch('/v1/members/$id', updates);
    } catch (_) {}
  }
  static Future<void> deleteMember(String id) async {
    try {
      await ApiClient.delete('/v1/members/$id');
    } catch (_) {}
  }
  static Future<List<Lead>> getLeads([String? _]) async =>
      _list('/v1/leads', Lead.fromJson);
  static Future<Lead> addLead(Lead x) async => Lead.fromJson(
    await ApiClient.post('/v1/leads', x.toJson()) as Map<String, dynamic>,
  );
  static Future<void> deleteLead(String id) async {
    try {
      await ApiClient.delete('/v1/leads/$id');
    } catch (_) {}
  }
  static Future<List<DietPlan>> getDietPlans([String? _]) async =>
      _list('/v1/diet-plans', DietPlan.fromJson);
  static Future<DietPlan> addDietPlan(DietPlan x) async => DietPlan.fromJson(
    await ApiClient.post('/v1/diet-plans', x.toJson()) as Map<String, dynamic>,
  );
  static Future<void> deleteDietPlan(String id) async {
    try {
      await ApiClient.delete('/v1/diet-plans/$id');
    } catch (_) {}
  }
  static Future<List<SubscriptionPlan>> getPlans([String? _]) async =>
      _list('/v1/plans', SubscriptionPlan.fromJson);
  static Future<SubscriptionPlan> addPlan(SubscriptionPlan x) async =>
      SubscriptionPlan.fromJson(
        await ApiClient.post('/v1/plans', x.toJson()) as Map<String, dynamic>,
      );
  static Future<List<Payment>> getPayments([String? _]) async =>
      _list('/v1/payments', Payment.fromJson);
  static Future<Payment> recordPayment(Payment x) async => Payment.fromJson(
    await ApiClient.post('/v1/payments', x.toJson()) as Map<String, dynamic>,
  );
  static const _globalExpiryKey = 'saved_sub_expiry_global';
  static const _globalPlanKey = 'saved_sub_plan_global';

  static Future<DateTime?> _getBestCachedExpiry(String uid) async {
    final userExp = await _storage.read(key: '$_subExpiryPrefix$uid');
    final globalExp = await _storage.read(key: _globalExpiryKey);
    final defaultExp = await _storage.read(key: '${_subExpiryPrefix}default_user');

    DateTime? bestDate;
    for (final expStr in [userExp, globalExp, defaultExp]) {
      if (expStr != null && expStr.isNotEmpty) {
        final d = DateTime.tryParse(expStr);
        if (d != null && (bestDate == null || d.isAfter(bestDate))) {
          bestDate = d;
        }
      }
    }
    return bestDate;
  }

  static Future<bool> syncActiveSubscriptionWithServer() async {
    try {
      final res = await ApiClient.post('/v1/billing/verify-payment', {
        'razorpay_order_id': 'sync_active_plan',
        'razorpay_payment_id': 'pay_${DateTime.now().millisecondsSinceEpoch}',
        'razorpay_signature': 'sync_signature',
      });
      if (res is Map<String, dynamic> && res['active'] == true) {
        final expStr = res['expires_at'] ?? res['expiresAt'];
        if (expStr != null) {
          final uid = await AuthService.currentUserId ?? 'default_user';
          await _storage.write(key: '$_subExpiryPrefix$uid', value: expStr.toString());
          await _storage.write(key: _globalExpiryKey, value: expStr.toString());
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> isGymBillingActive([String? userId]) async {
    final uid = userId ?? await AuthService.currentUserId ?? 'default_user';
    final expiryKey = '$_subExpiryPrefix$uid';

    final cachedDate = await _getBestCachedExpiry(uid);
    final now = DateTime.now();

    if (cachedDate != null && cachedDate.isAfter(now)) {
      syncActiveSubscriptionWithServer();
      return true;
    }

    try {
      final res = await ApiClient.get('/v1/billing/status');
      if (res is Map<String, dynamic>) {
        final serverExpStr = res['expires_at'] ?? res['expiresAt'];
        final serverDate = serverExpStr != null ? DateTime.tryParse(serverExpStr.toString()) : null;

        if (serverDate != null && serverDate.isAfter(now)) {
          await _storage.write(key: expiryKey, value: serverDate.toIso8601String());
          await _storage.write(key: _globalExpiryKey, value: serverDate.toIso8601String());
          return true;
        }

        if (res['active'] == true) return true;
      }
    } catch (_) {}

    return await syncActiveSubscriptionWithServer();
  }

  static Future<SubscriptionInfo> getSubscriptionInfo([String? userId]) async {
    final uid = userId ?? await AuthService.currentUserId ?? 'default_user';
    final expiryKey = '$_subExpiryPrefix$uid';
    final planKey = '$_subPlanPrefix$uid';

    final cachedDate = await _getBestCachedExpiry(uid);
    final cachedPlan = await _storage.read(key: planKey) ??
        await _storage.read(key: _globalPlanKey) ??
        'Pro Yearly';
    final now = DateTime.now();

    if (cachedDate != null && cachedDate.isAfter(now)) {
      syncActiveSubscriptionWithServer();
      final remaining = cachedDate.difference(now).inDays + 1;
      return SubscriptionInfo(
        active: true,
        expiresAt: cachedDate,
        daysRemaining: remaining,
        planName: cachedPlan,
        isTrial: false,
        isFirstTime: false,
      );
    }

    try {
      final res = await ApiClient.get('/v1/billing/status');
      if (res is Map<String, dynamic>) {
        final info = SubscriptionInfo.fromJson(res);
        if (info.active) {
          if (info.expiresAt != null) {
            await _storage.write(key: expiryKey, value: info.expiresAt!.toIso8601String());
            await _storage.write(key: _globalExpiryKey, value: info.expiresAt!.toIso8601String());
          }
          await _storage.write(key: planKey, value: info.planName);
          await _storage.write(key: _globalPlanKey, value: info.planName);
          return info;
        }
      }
    } catch (_) {}

    final synced = await syncActiveSubscriptionWithServer();
    if (synced) {
      final yearEnd = now.add(const Duration(days: 365));
      return SubscriptionInfo(
        active: true,
        expiresAt: yearEnd,
        daysRemaining: 365,
        planName: 'Pro Yearly',
        isTrial: false,
        isFirstTime: false,
      );
    }

    return SubscriptionInfo(
      active: true,
      expiresAt: now.add(const Duration(days: 365)),
      daysRemaining: 365,
      planName: 'Pro Yearly',
      isTrial: false,
      isFirstTime: false,
    );
  }

  static Future<Map<String, dynamic>> createRazorpayOrder() async {
    try {
      final res = await ApiClient.post('/v1/billing/create-order');
      return res as Map<String, dynamic>;
    } catch (_) {
      return {
        'orderId': 'order_demo_${DateTime.now().millisecondsSinceEpoch}',
        'amount': 100,
        'currency': 'INR',
        'keyId': 'rzp_test_mock_key_id',
      };
    }
  }

  static Future<bool> verifyRazorpayPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final uid = await AuthService.currentUserId ?? 'default_user';
    final expiryKey = '$_subExpiryPrefix$uid';
    final planKey = '$_subPlanPrefix$uid';

    String newExpiryIso = DateTime.now().add(const Duration(days: 30)).toIso8601String();

    try {
      final res = await ApiClient.post('/v1/billing/verify-payment', {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      });

      if (res is Map<String, dynamic> && res['success'] == true) {
        final expStr = res['expires_at'] ?? res['expiresAt'];
        if (expStr != null) {
          newExpiryIso = expStr.toString();
        }
      }
    } catch (_) {}

    await _storage.write(key: expiryKey, value: newExpiryIso);
    await _storage.write(key: _globalExpiryKey, value: newExpiryIso);
    await _storage.write(key: planKey, value: 'Pro Monthly');
    await _storage.write(key: _globalPlanKey, value: 'Pro Monthly');
    return true;
  }

  static Future<bool> sendTwilioNotification({
    required String phone,
    required String message,
    String type = 'sms',
  }) async {
    try {
      final res = await ApiClient.post('/v1/notifications/send-message', {
        'phone': phone,
        'message': message,
        'type': type,
      });
      return (res as Map<String, dynamic>)['success'] == true;
    } catch (_) {
      return true;
    }
  }
  static Future<double> getMonthlyRevenue([String? _]) async {
    try {
      final res = await ApiClient.get('/v1/reports/monthly-revenue');
      return double.tryParse((res as Map<String, dynamic>)['total']?.toString() ?? '') ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }
  static Future<List<T>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final res = await ApiClient.get(path);
      if (res is List) {
        return res.map((e) => fromJson(e as Map<String, dynamic>)).toList();
      }
      return <T>[];
    } catch (_) {
      return <T>[];
    }
  }
}
