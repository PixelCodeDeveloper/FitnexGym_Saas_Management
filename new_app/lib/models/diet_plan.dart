class DietPlan {
  final String id;
  final String gymId;
  final String title;
  final String type; // 'veg' or 'nonveg'
  final String calories;
  final List<String> items;
  final DateTime createdAt;

  DietPlan({
    required this.id,
    required this.gymId,
    required this.title,
    required this.type,
    required this.calories,
    required this.items,
    required this.createdAt,
  });

  factory DietPlan.fromJson(Map<String, dynamic> json) => DietPlan(
    id: json['id'],
    gymId: json['gym_id'],
    title: json['title'],
    type: json['type'],
    calories: json['calories'],
    items: List<String>.from(json['items'] ?? []),
    createdAt: DateTime.parse(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'gym_id': gymId,
    'title': title,
    'type': type,
    'calories': calories,
    'items': items,
  };

  String toShareText() {
    final buf = StringBuffer();
    buf.writeln('🏋️ $title');
    buf.writeln('📊 $calories');
    buf.writeln('');
    for (final item in items) {
      buf.writeln('• $item');
    }
    return buf.toString();
  }
}
