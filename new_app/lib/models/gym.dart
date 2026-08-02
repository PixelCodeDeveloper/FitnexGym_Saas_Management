class Gym {
  final String id;
  final String ownerId;
  final String name;
  final String? address;
  final String? phone;
  final String currency;
  final DateTime createdAt;

  Gym({
    required this.id,
    required this.ownerId,
    required this.name,
    this.address,
    this.phone,
    this.currency = 'INR',
    required this.createdAt,
  });

  factory Gym.fromJson(Map<String, dynamic> json) => Gym(
    id: json['id'],
    ownerId: json['owner_id'],
    name: json['name'],
    address: json['address'],
    phone: json['phone'],
    currency: json['currency'] ?? 'INR',
    createdAt: DateTime.parse(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'owner_id': ownerId,
    'name': name,
    'address': address,
    'phone': phone,
    'currency': currency,
  };
}
