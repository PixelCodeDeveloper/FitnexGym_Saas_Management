class DietPlan {
  final String id;
  final String gymId;
  final String title;
  final String type; // 'veg', 'nonveg', 'egg', 'vegan'
  final String category; // 'veg', 'nonveg', 'egg', 'vegan'
  final String? goalTag; // 'Fat Loss', 'Muscle Gain', etc.
  final String calories;
  final Map<String, dynamic>? macros; // { 'protein': '150g', 'carbs': '200g', 'fats': '50g' }
  final String? waterIntake;
  final String? notes;
  final List<String> items;
  final Map<String, String> meals; // { 'early_morning': '...', 'breakfast': '...', 'mid_morning': '...', 'lunch': '...', 'post_workout': '...', 'dinner': '...', 'bedtime': '...' }
  final DateTime createdAt;

  DietPlan({
    required this.id,
    required this.gymId,
    required this.title,
    required this.type,
    required this.category,
    this.goalTag,
    required this.calories,
    this.macros,
    this.waterIntake,
    this.notes,
    required this.items,
    required this.meals,
    required this.createdAt,
  });

  factory DietPlan.fromJson(Map<String, dynamic> json) {
    final rawMeals = json['meals'] as Map<String, dynamic>? ?? {};
    final parsedMeals = <String, String>{};
    rawMeals.forEach((key, val) {
      if (val != null && val.toString().trim().isNotEmpty) {
        parsedMeals[key] = val.toString().trim();
      }
    });

    final rawType = (json['type'] ?? json['category'] ?? 'veg').toString().toLowerCase();

    return DietPlan(
      id: json['id'] ?? '',
      gymId: json['gym_id'] ?? '',
      title: json['title'] ?? '',
      type: rawType,
      category: json['category'] ?? rawType,
      goalTag: json['goal_tag'],
      calories: json['calories'] ?? '2000 kcal',
      macros: json['macros'] != null ? Map<String, dynamic>.from(json['macros']) : null,
      waterIntake: json['water_intake'],
      notes: json['notes'],
      items: List<String>.from(json['items'] ?? []),
      meals: parsedMeals,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'gym_id': gymId,
    'title': title,
    'type': type,
    'category': category,
    'goal_tag': goalTag,
    'calories': calories,
    'macros': macros,
    'water_intake': waterIntake,
    'notes': notes,
    'items': items,
    'meals': meals,
  };

  String get CategoryBadge {
    switch (category.toLowerCase()) {
      case 'veg':
        return '🥗 Pure Veg';
      case 'nonveg':
        return '🍗 Non-Veg';
      case 'egg':
        return '🥚 Eggetarian';
      case 'vegan':
        return '🌱 Vegan';
      default:
        return '🥗 Pure Veg';
    }
  }

  String toShareText() {
    final buf = StringBuffer();
    buf.writeln('🏋️ $title');
    buf.writeln('🏷️ Category: $CategoryBadge');
    if (goalTag != null && goalTag!.isNotEmpty) buf.writeln('🎯 Goal: $goalTag');
    buf.writeln('🔥 Calories: $calories');
    if (macros != null) {
      final p = macros!['protein'] ?? 'N/A';
      final c = macros!['carbs'] ?? 'N/A';
      final f = macros!['fats'] ?? 'N/A';
      buf.writeln('💪 Protein: $p | 🌾 Carbs: $c | 🥑 Fats: $f');
    }
    if (waterIntake != null && waterIntake!.isNotEmpty) buf.writeln('💧 Water: $waterIntake');
    buf.writeln('');

    if (meals.isNotEmpty) {
      if (meals.containsKey('early_morning')) buf.writeln('🌅 Early Morning: ${meals['early_morning']}');
      if (meals.containsKey('breakfast')) buf.writeln('🥣 Breakfast: ${meals['breakfast']}');
      if (meals.containsKey('mid_morning')) buf.writeln('🍏 Mid-Morning: ${meals['mid_morning']}');
      if (meals.containsKey('lunch')) buf.writeln('🥗 Lunch: ${meals['lunch']}');
      if (meals.containsKey('post_workout')) buf.writeln('⚡ Post-Workout: ${meals['post_workout']}');
      if (meals.containsKey('dinner')) buf.writeln('🍲 Dinner: ${meals['dinner']}');
      if (meals.containsKey('bedtime')) buf.writeln('🌙 Bedtime: ${meals['bedtime']}');
    } else {
      for (final item in items) {
        buf.writeln('• $item');
      }
    }

    if (notes != null && notes!.trim().isNotEmpty) {
      buf.writeln('');
      buf.writeln('📝 Instructions: $notes');
    }

    return buf.toString();
  }
}

class MemberDietPlan {
  final String id;
  final String gymId;
  final String memberId;
  final String? memberName;
  final String? memberEmail;
  final String? memberPhone;
  final String? templateId;
  final String customTitle;
  final String category;
  final String? goalTag;
  final String calories;
  final Map<String, dynamic>? macros;
  final String? waterIntake;
  final Map<String, String> meals;
  final String? notes;
  final DateTime startDate;
  final DateTime reviewDate;
  final String status; // 'active', 'archived'

  MemberDietPlan({
    required this.id,
    required this.gymId,
    required this.memberId,
    this.memberName,
    this.memberEmail,
    this.memberPhone,
    this.templateId,
    required this.customTitle,
    required this.category,
    this.goalTag,
    required this.calories,
    this.macros,
    this.waterIntake,
    required this.meals,
    this.notes,
    required this.startDate,
    required this.reviewDate,
    required this.status,
  });

  factory MemberDietPlan.fromJson(Map<String, dynamic> json) {
    final rawMeals = json['meals'] as Map<String, dynamic>? ?? {};
    final parsedMeals = <String, String>{};
    rawMeals.forEach((k, v) {
      if (v != null && v.toString().trim().isNotEmpty) parsedMeals[k] = v.toString().trim();
    });

    return MemberDietPlan(
      id: json['id'] ?? '',
      gymId: json['gym_id'] ?? '',
      memberId: json['member_id'] ?? '',
      memberName: json['member_name'],
      memberEmail: json['member_email'],
      memberPhone: json['member_phone'],
      templateId: json['template_id'],
      customTitle: json['custom_title'] ?? 'Custom Member Diet',
      category: json['category'] ?? 'veg',
      goalTag: json['goal_tag'],
      calories: json['calories'] ?? '2000 kcal',
      macros: json['macros'] != null ? Map<String, dynamic>.from(json['macros']) : null,
      waterIntake: json['water_intake'],
      meals: parsedMeals,
      notes: json['notes'],
      startDate: DateTime.parse(json['start_date']),
      reviewDate: DateTime.parse(json['review_date']),
      status: json['status'] ?? 'active',
    );
  }

  bool get isDueForReview {
    final diff = reviewDate.difference(DateTime.now()).inDays;
    return diff <= 7;
  }
}
