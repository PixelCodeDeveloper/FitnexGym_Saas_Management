class SubscriptionPlan {
  final String id;
  final String gymId;
  final String name;
  final int durationDays;
  final double price;
  final String? description;
  final DateTime createdAt;

  SubscriptionPlan({
    required this.id,
    required this.gymId,
    required this.name,
    required this.durationDays,
    required this.price,
    this.description,
    required this.createdAt,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlan(
        id: json['id'],
        gymId: json['gym_id'],
        name: json['name'],
        durationDays: int.tryParse(json['duration_days']?.toString() ?? '') ?? 30,
        price: double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
        description: json['description'],
        createdAt: DateTime.parse(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
    'gym_id': gymId,
    'name': name,
    'duration_days': durationDays,
    'price': price,
    'description': description,
  };
}
