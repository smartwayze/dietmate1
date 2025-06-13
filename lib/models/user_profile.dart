// models/user_profile.dart
class UserProfile {
  final String uid;
  final String email;
  final String? name;
  final int age;
  final String gender;
  final double height; // in cm
  final double weight; // in kg
  final String activityLevel;
  final String healthGoal;
  final double? targetWeight;
  final int? dailyCalorieTarget;
  final Map<String, int>? macronutrientGoals; // {carbs, protein, fat} in grams
  final List<String> healthConditions;
  final List<String> dietaryRestrictions;
  final List<String> foodPreferences;
  final List<String> mealPreferences;
  final String? specificDiet;
  final DateTime? goalDeadline;

  UserProfile({
    required this.uid,
    required this.email,
    this.name,
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.activityLevel,
    required this.healthGoal,
    this.targetWeight,
    this.dailyCalorieTarget,
    this.macronutrientGoals,
    this.healthConditions = const [],
    this.dietaryRestrictions = const [],
    this.foodPreferences = const [],
    this.mealPreferences = const [],
    this.specificDiet,
    this.goalDeadline,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'age': age,
      'gender': gender,
      'height': height,
      'weight': weight,
      'activityLevel': activityLevel,
      'healthGoal': healthGoal,
      'targetWeight': targetWeight,
      'dailyCalorieTarget': dailyCalorieTarget,
      'macronutrientGoals': macronutrientGoals,
      'healthConditions': healthConditions,
      'dietaryRestrictions': dietaryRestrictions,
      'foodPreferences': foodPreferences,
      'mealPreferences': mealPreferences,
      'specificDiet': specificDiet,
      'goalDeadline': goalDeadline?.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'],
      email: map['email'],
      name: map['name'],
      age: map['age'],
      gender: map['gender'],
      height: map['height'],
      weight: map['weight'],
      activityLevel: map['activityLevel'],
      healthGoal: map['healthGoal'],
      targetWeight: map['targetWeight'],
      dailyCalorieTarget: map['dailyCalorieTarget'],
      macronutrientGoals: map['macronutrientGoals'] != null
          ? Map<String, int>.from(map['macronutrientGoals'])
          : null,
      healthConditions: List<String>.from(map['healthConditions']),
      dietaryRestrictions: List<String>.from(map['dietaryRestrictions']),
      foodPreferences: List<String>.from(map['foodPreferences']),
      mealPreferences: List<String>.from(map['mealPreferences']),
      specificDiet: map['specificDiet'],
      goalDeadline: map['goalDeadline'] != null
          ? DateTime.parse(map['goalDeadline'])
          : null,
    );
  }
}