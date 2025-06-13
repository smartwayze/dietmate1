import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Simple health profile data model
class UserHealthProfile {
  int? age;
  double? weight;
  double? height;
  List<String> medicalConditions;
  String? dietRecommendation;

  UserHealthProfile({
    this.age,
    this.weight,
    this.height,
    this.medicalConditions = const [],
    this.dietRecommendation,
  });
}

class HealthIntegrationScreen extends StatefulWidget {
  const HealthIntegrationScreen({Key? key}) : super(key: key);

  @override
  State<HealthIntegrationScreen> createState() => _HealthIntegrationScreenState();
}

class _HealthIntegrationScreenState extends State<HealthIntegrationScreen> {
  final Health health = Health(); // ✅ Correct instantiation for health 13.x
  List<HealthDataPoint> _healthData = [];
  bool _isLoading = false;
  bool _hasPermissions = false;
  UserHealthProfile _userProfile = UserHealthProfile();

  @override
  void initState() {
    super.initState();
    _loadSavedProfile();
    _checkPermissions();
  }

  Future<void> _loadSavedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userProfile = UserHealthProfile(
        age: prefs.getInt('user_age'),
        weight: prefs.getDouble('user_weight'),
        height: prefs.getDouble('user_height'),
        medicalConditions: prefs.getStringList('user_conditions') ?? [],
      );
    });
  }

  Future<void> _saveProfile(UserHealthProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    if (profile.age != null) prefs.setInt('user_age', profile.age!);
    if (profile.weight != null) prefs.setDouble('user_weight', profile.weight!);
    if (profile.height != null) prefs.setDouble('user_height', profile.height!);
    prefs.setStringList('user_conditions', profile.medicalConditions);
  }

  Future<void> _checkPermissions() async {
    final types = [
      HealthDataType.WEIGHT,
      HealthDataType.HEIGHT,
      HealthDataType.STEPS,
      HealthDataType.HEART_RATE,
    ];

    final hasPermissions = await health.hasPermissions(types);
    setState(() => _hasPermissions = hasPermissions ?? false);
  }

  Future<void> _requestPermissions() async {
    final types = [
      HealthDataType.WEIGHT,
      HealthDataType.HEIGHT,
      HealthDataType.STEPS,
      HealthDataType.HEART_RATE,
    ];

    final success = await health.requestAuthorization(types);
    setState(() => _hasPermissions = success);

    if (!success) {
      _showSnackBar('Permission denied', isError: true);
    }
  }

  Future<void> _fetchHealthData() async {
    if (!_hasPermissions) {
      await _requestPermissions();
      if (!_hasPermissions) return;
    }

    setState(() => _isLoading = true);

    final now = DateTime.now();
    final lastWeek = now.subtract(const Duration(days: 7));

    try {
      final healthData = await health.getHealthDataFromTypes(
        startTime: lastWeek,
        endTime: now,
        types: [
          HealthDataType.WEIGHT,
          HealthDataType.HEIGHT,
          HealthDataType.STEPS,
          HealthDataType.HEART_RATE,
        ],
      );

      setState(() {
        _healthData = healthData;
      });

      _showSnackBar('Synced successfully');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final color = isError ? Colors.red : Colors.green;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Integration')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _fetchHealthData,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Fetch Health Data"),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _healthData.length,
                itemBuilder: (context, index) {
                  final point = _healthData[index];
                  return ListTile(
                    title: Text(point.type.toString().split('.').last),
                    subtitle: Text('${point.value}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
