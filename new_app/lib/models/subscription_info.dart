class SubscriptionInfo {
  final bool active;
  final DateTime? expiresAt;
  final int daysRemaining;
  final String planName;
  final bool isTrial;
  final bool isFirstTime;

  const SubscriptionInfo({
    required this.active,
    this.expiresAt,
    required this.daysRemaining,
    required this.planName,
    this.isTrial = false,
    this.isFirstTime = false,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    final expiresStr = json['expires_at'] ?? json['expiresAt'];
    final parsedExpires = expiresStr != null ? DateTime.tryParse(expiresStr.toString()) : null;
    final now = DateTime.now();

    final isAct = parsedExpires != null
        ? parsedExpires.isAfter(now)
        : (json['active'] == true);

    final remaining = parsedExpires != null && parsedExpires.isAfter(now)
        ? parsedExpires.difference(now).inDays + 1
        : (json['days_remaining'] as int? ?? (json['daysRemaining'] as int? ?? 0));

    final isTrialVal = json['is_trial'] == true || json['isTrial'] == true || (isAct && remaining <= 14);
    final isFirstTimeVal = json['is_first_time'] == true || json['isFirstTime'] == true || (!isAct && parsedExpires == null);

    return SubscriptionInfo(
      active: isAct,
      expiresAt: parsedExpires,
      daysRemaining: isAct ? _mathMax(1, remaining) : 0,
      planName: (json['plan_name'] ?? json['planName'] ?? (isAct ? (isTrialVal ? '14-Day Free Trial' : 'Pro Monthly') : 'Expired')).toString(),
      isTrial: isTrialVal,
      isFirstTime: isFirstTimeVal,
    );
  }

  static int _mathMax(int a, int b) => a > b ? a : b;

  Map<String, dynamic> toJson() => {
        'active': active,
        'expires_at': expiresAt?.toIso8601String(),
        'days_remaining': daysRemaining,
        'plan_name': planName,
        'is_trial': isTrial,
        'is_first_time': isFirstTime,
      };

  factory SubscriptionInfo.fallbackActive({int days = 30}) {
    final exp = DateTime.now().add(Duration(days: days));
    return SubscriptionInfo(
      active: true,
      expiresAt: exp,
      daysRemaining: days,
      planName: 'Pro Monthly (Offline)',
      isTrial: false,
      isFirstTime: false,
    );
  }
}

