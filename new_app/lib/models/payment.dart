class Payment {
  final String id;
  final String gymId;
  final String memberId;
  final String? memberName;
  final double amount;
  final String? planName;
  final DateTime paidAt;

  Payment({
    required this.id,
    required this.gymId,
    required this.memberId,
    this.memberName,
    required this.amount,
    this.planName,
    required this.paidAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id'],
    gymId: json['gym_id'],
    memberId: json['member_id'],
    memberName: json['member_name'],
    amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0.0,
    planName: json['plan_name'],
    paidAt: DateTime.parse(json['paid_at']),
  );

  Map<String, dynamic> toJson() => {
    'member_id': memberId,
    'member_name': memberName,
    'amount': amount,
    'plan_name': planName,
    'paid_at': paidAt.toUtc().toIso8601String(),
  };
}
