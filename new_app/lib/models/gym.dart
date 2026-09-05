class Gym {
  final String id;
  final String ownerId;
  final String name;
  final String? ownerName;
  final String? email;
  final String? address;
  final String? phone;
  final String currency;
  final DateTime createdAt;

  Gym({
    required this.id,
    required this.ownerId,
    required this.name,
    this.ownerName,
    this.email,
    this.address,
    this.phone,
    this.currency = 'INR',
    required this.createdAt,
  });

  factory Gym.fromJson(Map<String, dynamic> json) => Gym(
    id: json['id'],
    ownerId: json['owner_id'] ?? 'owner_default',
    name: json['name'],
    ownerName: json['owner_name'],
    email: json['email'],
    address: json['address'],
    phone: json['phone'],
    currency: json['currency'] ?? 'INR',
    createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'owner_id': ownerId,
    'name': name,
    'owner_name': ownerName,
    'email': email,
    'address': address,
    'phone': phone,
    'currency': currency,
  };
}
