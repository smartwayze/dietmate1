import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RealTimeRecipeGenerator extends StatefulWidget {
  final String userId;

  const RealTimeRecipeGenerator({Key? key, required this.userId}) : super(key: key);

  @override
  _RealTimeRecipeGeneratorState createState() => _RealTimeRecipeGeneratorState();
}

class _RealTimeRecipeGeneratorState extends State<RealTimeRecipeGenerator> {
  // App state
  List<Map<String, dynamic>> recipes = [];
  bool isLoading = false;
  String? errorMessage;
  String? apiKey;
  late UserProfile userProfile;
  final _storage = const FlutterSecureStorage();

  // API rate limiting protection
  int _apiCallCount = 0;
  DateTime? _lastApiCallTime;
  static const _maxDailyCalls = 50;
  static const _minRequestInterval = Duration(seconds: 30);

  // Generation control
  bool _isGenerating = false;
  bool _cancelRequested = false;
  double _generationProgress = 0.0;
  String _generationStatus = 'Ready';
  int _totalRetries = 0;
  int _rateLimitHits = 0;

  // Recipe parameters
  String _currentMealType = 'any';
  String _currentCuisine = 'any';
  List<String> _availableIngredients = [];
  List<String> _excludedIngredients = [];

  // Constants
  static const _maxRetries = 3;
  static const _initialDelay = Duration(seconds: 2);
  static const _rateLimitDelay = Duration(seconds: 20);
  static const _overallTimeout = Duration(minutes: 2);
  final List<String> _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack', 'any'];
  final List<String> _cuisineTypes = [
    'italian', 'mexican', 'indian', 'chinese',
    'mediterranean', 'american', 'japanese', 'any'
  ];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await dotenv.load(fileName: ".env");
      apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey!.isEmpty) {
        throw Exception('API key not configured');
      }
      await _loadApiUsageFromCache();
      await _loadUserProfile();
      await _tryLoadCachedRecipes();
    } catch (e) {
      _handleError('Initialization error: ${e.toString()}');
    }
  }

  Future<void> _loadApiUsageFromCache() async {
    try {
      final lastCall = await _storage.read(key: 'last_api_call');
      final count = await _storage.read(key: 'api_call_count');
      if (lastCall != null && lastCall.isNotEmpty) {
        _lastApiCallTime = DateTime.parse(lastCall);
      }
      if (count != null && count.isNotEmpty) {
        _apiCallCount = int.parse(count);
      }
    } catch (e) {
      debugPrint('Error loading API usage: $e');
    }
  }

  Future<void> _saveApiUsageToCache() async {
    try {
      await _storage.write(
        key: 'last_api_call',
        value: _lastApiCallTime?.toIso8601String() ?? '',
      );
      await _storage.write(
        key: 'api_call_count',
        value: _apiCallCount.toString(),
      );
    } catch (e) {
      debugPrint('Error saving API usage: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final data = userDoc.data()!;
      userProfile = UserProfile.fromMap(data);

      setState(() {
        _currentMealType = data['preferredMealType'] ?? 'any';
        _currentCuisine = data['preferredCuisine'] ?? 'any';
        _availableIngredients = List<String>.from(data['availableIngredients'] ?? []);
        _excludedIngredients = List<String>.from(data['excludedIngredients'] ?? []);
      });
    } catch (e) {
      throw Exception('Failed to load profile: $e');
    }
  }

  Future<void> _tryLoadCachedRecipes() async {
    try {
      final cachedRecipes = await _storage.read(key: 'cached_recipes_${widget.userId}');
      if (cachedRecipes != null && cachedRecipes.isNotEmpty) {
        final parsed = jsonDecode(cachedRecipes);
        if (parsed is List) {
          setState(() {
            recipes = parsed.map((r) => r as Map<String, dynamic>).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Cache load error: $e');
    }
  }

  Future<void> _generateRecipes() async {
    if (_isGenerating) return;

    try {
      await Future.any([
        _actuallyGenerateRecipes(),
        Future.delayed(_overallTimeout).then((_) => throw TimeoutException('Overall timeout reached')),
      ]);
    } on TimeoutException {
      _handleError('Request timed out after ${_overallTimeout.inMinutes} minutes');
    } catch (e) {
      _handleError(e.toString());
    }
  }

  Future<void> _actuallyGenerateRecipes() async {
    await _checkApiLimits();

    setState(() {
      _cancelRequested = false;
      _isGenerating = true;
      isLoading = true;
      errorMessage = null;
      _generationProgress = 0.0;
      _generationStatus = 'Preparing recipe...';
    });

    _lastApiCallTime = DateTime.now();
    _apiCallCount++;
    await _saveApiUsageToCache();

    final prompt = _buildRecipePrompt();

    await _simulateGenerationProgress();

    try {
      final response = await _makeApiRequest(prompt);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        final parsed = jsonDecode(content);

        setState(() {
          recipes = parsed.map((r) => r as Map<String, dynamic>).toList();
        });

        await _storage.write(
          key: 'cached_recipes_${widget.userId}',
          value: jsonEncode(recipes),
        );

        _updateGenerationProgress(1.0, 'Done!');
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        throw Exception('API request failed with status ${response.statusCode}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          isLoading = false;
          _generationProgress = 0.0;
        });
      }
    }
  }

  Future<void> _simulateGenerationProgress() async {
    _updateGenerationProgress(0.2, 'Analyzing preferences...');
    await Future.delayed(const Duration(milliseconds: 500));
    if (_cancelRequested) throw Exception('Generation cancelled');

    _updateGenerationProgress(0.4, 'Finding ingredients...');
    await Future.delayed(const Duration(milliseconds: 500));
    if (_cancelRequested) throw Exception('Generation cancelled');

    _updateGenerationProgress(0.6, 'Creating recipe...');
  }

  Future<void> _checkApiLimits() async {
    final now = DateTime.now();
    if (_lastApiCallTime != null &&
        now.difference(_lastApiCallTime!) < _minRequestInterval) {
      throw Exception('Please wait ${_minRequestInterval.inSeconds} seconds between requests');
    }

    if (_apiCallCount >= _maxDailyCalls) {
      throw Exception('Daily API limit reached ($_maxDailyCalls calls)');
    }
  }

  Future<http.Response> _makeApiRequest(String prompt, {int retryCount = 0}) async {
    if (_cancelRequested) throw Exception('Generation cancelled');

    try {
      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');

      _updateGenerationProgress(0.7, retryCount > 0
          ? 'Retrying... (${retryCount + 1}/$_maxRetries)'
          : 'Contacting API...');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [{'role': 'user', 'content': prompt}],
          'temperature': 0.7,
          'max_tokens': 1500,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response;
      }

      if (response.statusCode == 429) {
        setState(() => _rateLimitHits++);
        if (retryCount < _maxRetries) {
          final retryAfter = _parseRetryAfter(response.headers) ?? _rateLimitDelay;
          _updateGenerationProgress(0.7, 'Rate limited. Retrying in ${retryAfter.inSeconds}s...');

          // Countdown with cancellation check
          for (var i = retryAfter.inSeconds; i > 0; i--) {
            if (!mounted || _cancelRequested) break;
            await Future.delayed(const Duration(seconds: 1));
            _updateGenerationProgress(0.7, 'Rate limited. Retrying in ${i}s...');
          }

          if (_cancelRequested) {
            throw Exception('Generation cancelled');
          }

          setState(() => _totalRetries++);
          return _makeApiRequest(prompt, retryCount: retryCount + 1);
        }
        throw Exception('Max retries ($_maxRetries) reached for rate limiting');
      }

      throw Exception('API request failed with status ${response.statusCode}');
    } on TimeoutException {
      if (retryCount < _maxRetries) {
        await Future.delayed(_initialDelay * (retryCount + 1));
        return _makeApiRequest(prompt, retryCount: retryCount + 1);
      }
      throw Exception('Request timed out after $_maxRetries retries');
    } catch (e) {
      if (retryCount < _maxRetries) {
        await Future.delayed(_initialDelay * (retryCount + 1));
        return _makeApiRequest(prompt, retryCount: retryCount + 1);
      }
      rethrow;
    }
  }

  Duration? _parseRetryAfter(Map<String, String> headers) {
    final retryAfter = headers['retry-after'];
    if (retryAfter != null) {
      try {
        final seconds = int.tryParse(retryAfter);
        if (seconds != null) return Duration(seconds: seconds);
      } catch (_) {}
    }
    return null;
  }

  void _updateGenerationProgress(double progress, String status) {
    if (mounted && !_cancelRequested) {
      setState(() {
        _generationProgress = progress;
        _generationStatus = status;
      });
    }
  }

  void _cancelGeneration() {
    if (mounted) {
      setState(() {
        _cancelRequested = true;
        _isGenerating = false;
        isLoading = false;
        errorMessage = 'Request cancelled by user';
      });
    }
  }

  String _buildRecipePrompt() {
    return '''
      Generate 3 personalized recipes in JSON format for a user with:
      - Dietary needs: ${userProfile.diets.join(', ')}
      - Health conditions: ${userProfile.conditions.join(', ')}
      - Goals: ${userProfile.goals.join(', ')}
      - Meal type: $_currentMealType
      - Cuisine: $_currentCuisine
      ${_availableIngredients.isNotEmpty ? '- Available ingredients: ${_availableIngredients.join(', ')}' : ''}
      ${_excludedIngredients.isNotEmpty ? '- Excluded ingredients: ${_excludedIngredients.join(', ')}' : ''}

      For each recipe provide:
      - name (string)
      - ingredients (array with quantities)
      - steps (array)
      - nutrition (string with calories, protein, carbs, fat)
      - dietaryInfo (string)
      - mealType (string)
      - cuisine (string)
      - prepTime (number in minutes)
      - cookTime (number in minutes)
      - servingSize (string)

      Return ONLY valid JSON like this:
      [
        {
          "name": "Recipe Name",
          "ingredients": ["1 cup flour", "2 tbsp oil"],
          "steps": ["Mix ingredients", "Cook for 10 minutes"],
          "nutrition": "300 cal, 10g protein, 40g carbs, 12g fat",
          "dietaryInfo": "Vegetarian, Low-carb",
          "mealType": "dinner",
          "cuisine": "italian",
          "prepTime": 10,
          "cookTime": 20,
          "servingSize": "2 servings"
        }
      ]
    ''';
  }

  void _handleError(String message) {
    String userFriendlyMessage = message;

    if (message.contains('rate') || message.contains('429')) {
      userFriendlyMessage = 'Server busy. Please wait a moment and try again.';
    } else if (message.contains('Daily API limit')) {
      userFriendlyMessage = 'Daily recipe limit reached. Try again tomorrow.';
    } else if (message.contains('timed out')) {
      userFriendlyMessage = 'Request took too long. Please try again.';
    } else if (message.contains('cancelled')) {
      userFriendlyMessage = 'Request cancelled';
    }

    if (mounted) {
      setState(() {
        errorMessage = userFriendlyMessage;
        isLoading = false;
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time Recipe Generator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _isGenerating ? null : _showFiltersDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isGenerating ? null : _generateRecipes,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _isGenerating
          ? FloatingActionButton(
        onPressed: _cancelGeneration,
        child: const Icon(Icons.close),
        backgroundColor: Colors.red,
        tooltip: 'Cancel',
      )
          : FloatingActionButton(
        onPressed: _generateRecipes,
        child: const Icon(Icons.auto_awesome),
        tooltip: 'Generate Recipes',
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) return _buildLoadingView();
    if (errorMessage != null) return _buildErrorView();
    if (recipes.isEmpty) return _buildEmptyView();
    return _buildRecipeList();
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              children: [
                CircularProgressIndicator(
                  value: _generationProgress,
                  strokeWidth: 6,
                  color: Colors.blue,
                ),
                if (_generationProgress > 0)
                  Center(
                    child: Text(
                      '${(_generationProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _generationStatus,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 50),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _generateRecipes,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Try Again', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.restaurant_menu, size: 50, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            'No recipes generated yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _generateRecipes,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Generate Recipes',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeList() {
    return Column(
      children: [
        if (_currentMealType != 'any' || _currentCuisine != 'any')
          _buildActiveFiltersChip(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _generateRecipes,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: recipes.length,
              itemBuilder: (context, index) => _buildRecipeCard(recipes[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFiltersChip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          if (_currentMealType != 'any')
            Chip(
              label: Text('Meal: ${_currentMealType.capitalize()}'),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () {
                setState(() => _currentMealType = 'any');
                _generateRecipes();
              },
            ),
          if (_currentCuisine != 'any')
            Chip(
              label: Text('Cuisine: ${_currentCuisine.capitalize()}'),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () {
                setState(() => _currentCuisine = 'any');
                _generateRecipes();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    final prepTime = recipe['prepTime'] ?? 0;
    final cookTime = recipe['cookTime'] ?? 0;
    final totalTime = prepTime + cookTime;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    recipe['name'],
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(recipe['mealType']?.toString().capitalize() ?? ''),
                  backgroundColor: Colors.blue[50],
                  labelStyle: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${recipe['cuisine']?.toString().capitalize() ?? ''} cuisine',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTimeChip(Icons.timer, 'Prep: ${prepTime}min'),
                const SizedBox(width: 8),
                _buildTimeChip(Icons.restaurant, 'Cook: ${cookTime}min'),
                const SizedBox(width: 8),
                _buildTimeChip(Icons.schedule, 'Total: ${totalTime}min'),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection('Ingredients:', recipe['ingredients']),
            const SizedBox(height: 16),
            _buildSection('Instructions:', recipe['steps']),
            const SizedBox(height: 16),
            _buildNutritionInfo(recipe),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 18, color: Colors.blue),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.grey[100],
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildSection(String title, List<dynamic> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 8, top: 4),
          child: Text(
            '• $item',
            style: const TextStyle(fontSize: 14),
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildNutritionInfo(Map<String, dynamic> recipe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nutrition:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          recipe['nutrition'] ?? 'Not available',
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 8),
        const Text(
          'Dietary Info:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          recipe['dietaryInfo'] ?? 'Not specified',
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Future<void> _showFiltersDialog() async {
    String? selectedMealType = _currentMealType;
    String? selectedCuisine = _currentCuisine;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recipe Filters'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Meal Type:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ..._mealTypes.map((type) => RadioListTile<String>(
                title: Text(type.capitalize()),
                value: type,
                groupValue: selectedMealType,
                onChanged: (value) => setState(() => selectedMealType = value),
              )).toList(),
              const SizedBox(height: 16),
              const Text(
                'Cuisine:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ..._cuisineTypes.map((type) => RadioListTile<String>(
                title: Text(type.capitalize()),
                value: type,
                groupValue: selectedCuisine,
                onChanged: (value) => setState(() => selectedCuisine = value),
              )).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _currentMealType = selectedMealType ?? 'any';
                _currentCuisine = selectedCuisine ?? 'any';
              });
              Navigator.pop(context);
              _generateRecipes();
            },
            child: const Text('Apply Filters'),
          ),
        ],
      ),
    );
  }
}

class UserProfile {
  final String name;
  final int age;
  final List<String> diets;
  final List<String> conditions;
  final List<String> goals;

  UserProfile({
    required this.name,
    required this.age,
    required this.diets,
    required this.conditions,
    required this.goals,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] ?? 'User',
      age: map['age'] ?? 30,
      diets: List<String>.from(map['dietaryPreferences'] ?? []),
      conditions: List<String>.from(map['healthConditions'] ?? []),
      goals: List<String>.from(map['goals'] ?? []),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}