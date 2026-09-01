enum MemberStatus { active, expiringSoon, expired }

class Member {
  final String id;
  final String gymId;
  final String name;
  final String phone;
  final String? planId;
  final DateTime subscriptionStart;
  final DateTime subscriptionEnd;
  final double amountPaid;
  final DateTime createdAt;

  Member({
    required this.id,
    required this.gymId,
    required this.name,
    required this.phone,
    this.planId,
    required this.subscriptionStart,
    required this.subscriptionEnd,
    required this.amountPaid,
    required this.createdAt,
  });

  MemberStatus get status {
    final now = DateTime.now();
    if (subscriptionEnd.isBefore(now)) return MemberStatus.expired;
    if (subscriptionEnd.difference(now).inDays <= 7)
      return MemberStatus.expiringSoon;
    return MemberStatus.active;
  }

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    id: json['id'],
    gymId: json['gym_id'],
    name: json['name'],
    phone: json['phone'],
    planId: json['plan_id'],
    subscriptionStart: DateTime.parse(json['subscription_start']),
    subscriptionEnd: DateTime.parse(json['subscription_end']),
    amountPaid: double.tryParse(json['amount_paid']?.toString() ?? '') ?? 0.0,
    createdAt: DateTime.parse(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'plan_id': (planId != null && planId!.isNotEmpty && planId!.contains('-')) ? planId : null,
    'subscription_start': subscriptionStart.toUtc().toIso8601String(),
    'subscription_end': subscriptionEnd.toUtc().toIso8601String(),
    'amount_paid': amountPaid,
  };
}
