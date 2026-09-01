enum LeadStatus { hot, warm, cold }

class Lead {
  final String id;
  final String gymId;
  final String name;
  final String phone;
  final String? note;
  final LeadStatus status;
  final DateTime followUpDate;
  final DateTime createdAt;

  Lead({
    required this.id,
    required this.gymId,
    required this.name,
    required this.phone,
    this.note,
    required this.status,
    required this.followUpDate,
    required this.createdAt,
  });

  factory Lead.fromJson(Map<String, dynamic> json) => Lead(
    id: json['id'],
    gymId: json['gym_id'],
    name: json['name'],
    phone: json['phone'],
    note: json['note'],
    status: LeadStatus.values.firstWhere((e) => e.name == json['status']),
    followUpDate: DateTime.parse(json['follow_up_date']),
    createdAt: DateTime.parse(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'note': (note != null && note!.isNotEmpty) ? note : null,
    'status': status.name,
    'follow_up_date': followUpDate.toUtc().toIso8601String(),
  };
}
