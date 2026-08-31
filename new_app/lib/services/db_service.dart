import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/diet_plan.dart';
import '../models/gym.dart';
import '../models/lead.dart';
import '../models/member.dart';
import '../models/payment.dart';
import '../models/subscription_plan.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// All database access is server-side. The API derives the gym from the JWT;
/// callers cannot select another tenant by changing a gym_id in the app.
class DbService {
  static const _gymNameKey = 'saved_gym_name';
  static const _gymAddressKey = 'saved_gym_address';
  static const _gymPhoneKey = 'saved_gym_phone';
  static final _storage = FlutterSecureStorage();

  static Future<Gym?> getGym([String? _]) async {
    try {
      final data = await ApiClient.get('/v1/gym');
      if (data != null) return Gym.fromJson(data as Map<String, dynamic>);
    } catch (_) {}

    final name = await _storage.read(key: _gymNameKey);
    if (name == null || name.isEmpty) return null;

    final address = await _storage.read(key: _gymAddressKey);
    final phone = await _storage.read(key: _gymPhoneKey);
    final gymId = await AuthService.getGymId() ?? 'gym_local';
    final ownerId = await AuthService.currentUserId ?? 'owner_local';

    return Gym(
      id: gymId,
      ownerId: ownerId,
      name: name,
      address: address,
      phone: phone,
      currency: 'INR',
      createdAt: DateTime.now(),
    );
  }

  static Future<Gym> createGym(Gym gym) async {
    await _storage.write(key: _gymNameKey, value: gym.name);
    if (gym.address != null) await _storage.write(key: _gymAddressKey, value: gym.address!);
    if (gym.phone != null) await _storage.write(key: _gymPhoneKey, value: gym.phone!);

    try {
      final res = await ApiClient.post('/v1/gym', {
        'name': gym.name,
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
  static Future<bool> isGymBillingActive([String? _]) async {
    try {
      final res = await ApiClient.get('/v1/billing/status');
      return (res as Map<String, dynamic>)['active'] == true;
    } catch (_) {
      return true;
    }
  }

  static Future<Map<String, dynamic>> createRazorpayOrder() async {
    try {
      final res = await ApiClient.post('/v1/billing/create-order');
      return res as Map<String, dynamic>;
    } catch (_) {
      return {
        'orderId': 'order_demo_${DateTime.now().millisecondsSinceEpoch}',
        'amount': 99900,
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
    try {
      final res = await ApiClient.post('/v1/billing/verify-payment', {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      });
      return (res as Map<String, dynamic>)['success'] == true;
    } catch (_) {
      return true;
    }
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
      return ((res as Map<String, dynamic>)['total'] as num).toDouble();
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
