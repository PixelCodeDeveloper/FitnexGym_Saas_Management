enum MemberStatus { active, expiringSoon, expired }

class Member {
  final String id;
  final String gymId;
  final String name;
  final String phone;
  final String? email;
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
    this.email,
    this.planId,
    required this.subscriptionStart,
    required this.subscriptionEnd,
    required this.amountPaid,
    required this.createdAt,
  });

  MemberStatus get status {
    final now = DateTime.now();
    if (subscriptionEnd.isBefore(now)) return MemberStatus.expired;
    if (subscriptionEnd.difference(now).inDays <= 7) return MemberStatus.expiringSoon;
    return MemberStatus.active;
  }

  bool get isExpired => status == MemberStatus.expired;
  bool get isExpiringSoon => status == MemberStatus.expiringSoon;
  bool get isActive => status == MemberStatus.active;

  int get daysRemaining {
    final diff = subscriptionEnd.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  String get statusText {
    switch (status) {
      case MemberStatus.active:
        return 'Active';
      case MemberStatus.expiringSoon:
        return 'Expiring Soon';
      case MemberStatus.expired:
        return 'Expired';
    }
  }

  String get avatarInitials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'M';
  }

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    id: json['id'],
    gymId: json['gym_id'],
    name: json['name'],
    phone: json['phone'],
    email: json['email'],
    planId: json['plan_id'],
    subscriptionStart: DateTime.parse(json['subscription_start']),
    subscriptionEnd: DateTime.parse(json['subscription_end']),
    amountPaid: double.tryParse(json['amount_paid']?.toString() ?? '') ?? 0.0,
    createdAt: DateTime.parse(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'email': (email != null && email!.trim().isNotEmpty) ? email!.trim() : null,
    'plan_id': (planId != null && planId!.isNotEmpty && planId!.contains('-')) ? planId : null,
    'subscription_start': subscriptionStart.toUtc().toIso8601String(),
    'subscription_end': subscriptionEnd.toUtc().toIso8601String(),
    'amount_paid': amountPaid,
  };
}
