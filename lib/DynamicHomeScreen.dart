import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'ProfileCompletionScreen.dart';
import 'RecipeSuggestionsScreen.dart';
import 'AI-Based Recipe Rating System.dart';

class DynamicHomeScreen extends StatefulWidget {
  const DynamicHomeScreen({super.key});

  @override
  State<DynamicHomeScreen> createState() => _DynamicHomeScreenState();
}

class _DynamicHomeScreenState extends State<DynamicHomeScreen> {
  int _currentIndex = 0;
  final CarouselController _carouselController = CarouselController();
  late Stream<QuerySnapshot> _completedActivitiesStream;
  late Stream<QuerySnapshot> _completedMealsStream;
  late Stream<QuerySnapshot> _favoriteRecipesStream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _completedActivitiesStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('completedActivities')
          .orderBy('completedAt', descending: true)
          .snapshots();

      _completedMealsStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('completedMeals')
          .orderBy('completedAt', descending: true)
          .snapshots();

      _favoriteRecipesStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favoriteRecipes')
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your profile')),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('No profile data found')),
          );
        }

        final userProfile = UserProfile.fromMap(
            snapshot.data!.data()! as Map<String, dynamic>);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Welcome, ${userProfile.name}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green.shade300,
            iconTheme: const IconThemeData(color: Colors.white),
            automaticallyImplyLeading: false,
            actions: [
              if (_currentIndex == 1) // Recipes tab
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _showRecipeSearch(userProfile),
                ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: [
              // Home Tab
              _buildHomeTab(userProfile, user),

              // Recipes Tab
              _buildRecipesTab(userProfile),

              // Progress Tab
              _buildProgressTab(userProfile),

              // Settings Tab
              _buildSettingsTab(userProfile),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: Colors.green.shade300,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.restaurant),
                label: 'Recipes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.assessment),
                label: 'Progress',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
  void _showRecipeDetails(Recipe recipe, UserProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      recipe.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: recipe.isFavorite ? Colors.red : Colors.grey,
                      ),
                      onPressed: () {
                        _toggleFavorite(recipe);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  recipe.description,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),

                // Recipe Image with fallback to asset image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    child: recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                        ? Image.network(
                      recipe.imageUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildRecipeAssetImage(recipe),
                    )
                        : _buildRecipeAssetImage(recipe),
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildRecipeInfoItem(Icons.timer, '${recipe.prepTime} min'),
                    _buildRecipeInfoItem(Icons.local_fire_department, '${recipe.calories} cal'),
                    _buildRecipeInfoItem(Icons.people, '2 servings'),
                  ],
                ),
                const SizedBox(height: 16),

                // Nutritional Information
                const Text(
                  'Nutritional Information (per serving)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (recipe.nutritionalInfo != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildNutritionChip('Protein', '${recipe.nutritionalInfo!['protein']}g'),
                      _buildNutritionChip('Carbs', '${recipe.nutritionalInfo!['carbs']}g'),
                      _buildNutritionChip('Fats', '${recipe.nutritionalInfo!['fats']}g'),
                      _buildNutritionChip('Fiber', '${recipe.nutritionalInfo!['fiber']}g'),
                      _buildNutritionChip('Sugar', '${recipe.nutritionalInfo!['sugar']}g'),
                    ],
                  ),
                const SizedBox(height: 16),

                // Ingredients
                const Text(
                  'Ingredients',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...recipe.ingredients.map((ingredient) =>
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('• $ingredient'),
                    ),
                ),
                const SizedBox(height: 16),

                // Possible Substitutions
                if (recipe.possibleSubstitutions != null && recipe.possibleSubstitutions!.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Suggested Substitutions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...recipe.possibleSubstitutions!.map((sub) =>
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text('• $sub'),
                          ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),

                // Instructions
                const Text(
                  'Instructions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...recipe.instructions.asMap().entries.map((entry) =>
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.green.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(entry.value),
                          ),
                        ],
                      ),
                    ),
                ),
                const SizedBox(height: 16),

                // Tags
                Wrap(
                  spacing: 8,
                  children: recipe.tags.map((tag) => Chip(
                    label: Text(tag),
                    backgroundColor: Colors.green.shade100,
                  )).toList(),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipeAssetImage(Recipe recipe) {
    return Image.asset(
      recipe.assetPath,
      height: 200,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        height: 200,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.fastfood, size: 50, color: Colors.grey),
        ),
      ),
    );
  }
  Widget _buildRecipeInfoItem(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.green.shade300),
        const SizedBox(height: 4),
        Text(text),
      ],
    );
  }

  Widget _buildNutritionChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
  Widget _buildHomeTab(UserProfile profile, User user) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildWelcomeCard(profile),
          _buildHealthSummary(profile),
          _buildGoalsCard(profile),
          const SizedBox(height: 20),
          _buildSectionTitle('Your Activity Plan'),
          _buildActivitySliderWithImages(profile),
          const SizedBox(height: 20),
          _buildSectionTitle('Recommended Diet Plan'),
          _buildDietPlan(profile),
          const SizedBox(height: 20),
          _buildSectionTitle('Featured Recipes'),
          _buildFeaturedRecipes(profile),
        ],
      ),
    );
  }

  Widget _buildRecipesTab(UserProfile profile) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Recipe Suggestions'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Recommended'),
              Tab(text: 'Favorites'),
              Tab(text: 'Categories'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRecommendedRecipes(profile),
            _buildFavoriteRecipes(),
            _buildRecipeCategories(profile),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddRecipeDialog(profile),
          backgroundColor: Colors.green.shade300,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildProgressTab(UserProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Your Progress Overview',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 20),
          _buildWeeklySummaryCards(),
          const SizedBox(height: 20),
          _buildActivityProgressChart(),
          const SizedBox(height: 20),
          _buildNutritionProgressChart(),
          const SizedBox(height: 20),
          _buildRecentActivitiesSection(),
          const SizedBox(height: 20),
          _buildRecentMealsSection(),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(UserProfile profile) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Profile Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('View Profile'),
          onTap: () => _showProfileDetails(profile),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Edit Profile'),
          onTap: () => _editProfile(profile),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.delete, color: Colors.red),
          title: const Text(
            'Delete Profile',
            style: TextStyle(color: Colors.red),
          ),
          onTap: () => _confirmDeleteProfile(),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Logout'),
          onTap: () => _logout(),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(UserProfile profile) {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${profile.name}!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getWelcomeMessage(profile),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            if (profile.goalDate != null) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _calculateGoalProgress(profile),
                backgroundColor: Colors.grey.shade200,
                color: Colors.green.shade300,
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Text(
                '${(_calculateGoalProgress(profile) * 100).toStringAsFixed(1)}% towards your goal',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHealthSummary(UserProfile profile) {
    final bmi = profile.weight / ((profile.height / 100) * (profile.height / 100));
    final bmiCategory = _getBmiCategory(bmi);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Your Health Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHealthMetric(
                  'BMI',
                  bmi.toStringAsFixed(1),
                  bmiCategory,
                  _getBmiColor(bmi),
                ),
                _buildHealthMetric(
                  'Weight',
                  '${profile.weight} kg',
                  'Current',
                  Colors.blue,
                ),
                if (profile.targetWeight != null)
                  _buildHealthMetric(
                    'Target',
                    '${profile.targetWeight} kg',
                    'Goal',
                    Colors.green,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              bmiCategory,
              style: TextStyle(
                color: _getBmiColor(bmi),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsCard(UserProfile profile) {
    final goalColors = {
      'Weight loss': Colors.red.shade300,
      'Muscle gain': Colors.blue.shade300,
      'Maintain weight': Colors.green.shade300,
      'Improve fitness': Colors.orange.shade300,
      'Manage health condition': Colors.purple.shade300,
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Your Goals',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: profile.goals.map((goal) => Chip(
                label: Text(goal),
                backgroundColor: goalColors[goal] ?? Colors.green,
                labelStyle: const TextStyle(color: Colors.white),
              )).toList(),
            ),
            if (profile.targetWeight != null && profile.goalDate != null) ...[
              const SizedBox(height: 16),
              Text(
                'Target: ${profile.targetWeight} kg by ${DateFormat('MMM d, y').format(profile.goalDate!)}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySliderWithImages(UserProfile profile) {
    final activityBank = [
      Activity(
        id: 'hiit',
        icon: Icons.directions_run,
        title: 'HIIT Workout',
        description: 'Burn maximum calories in minimum time',
        duration: '25 mins',
        imagePath: 'assets/hiit.jpeg',
        estimatedCalories: 300,
      ),
      Activity(
        id: 'cycling',
        icon: Icons.directions_bike,
        title: 'Cycling Intervals',
        description: 'Alternate between high and low intensity',
        duration: '40 mins',
        imagePath: 'assets/cycling.jpg',
        estimatedCalories: 400,
      ),
      Activity(
        id: 'swimming',
        icon: Icons.pool,
        title: 'Swimming Laps',
        description: 'Full-body fat burning exercise',
        duration: '45 mins',
        imagePath: 'assets/swimming.jpg',
        estimatedCalories: 350,
      ),
      Activity(
        id: 'strength',
        icon: Icons.fitness_center,
        title: 'Strength Training',
        description: 'Compound lifts for muscle growth',
        duration: '50 mins',
        imagePath: 'assets/strength.webp',
        estimatedCalories: 250,
      ),
      Activity(
        id: 'bodyweight',
        icon: Icons.fitness_center,
        title: 'Bodyweight Circuit',
        description: 'Build muscle without equipment',
        duration: '40 mins',
        imagePath: 'assets/weights.jpg',
        estimatedCalories: 280,
      ),
      Activity(
        id: 'bands',
        icon: Icons.fitness_center,
        title: 'Resistance Bands',
        description: 'Tone and build lean muscle',
        duration: '35 mins',
        imagePath: 'assets/bands.jpeg',
        estimatedCalories: 200,
      ),
      Activity(
        id: 'walking',
        icon: Icons.directions_walk,
        title: 'Brisk Walking',
        description: 'Maintain fitness with low impact',
        duration: '45 mins',
        imagePath: 'assets/walking.jpg',
        estimatedCalories: 180,
      ),
      Activity(
        id: 'yoga',
        icon: Icons.self_improvement,
        title: 'Yoga Flow',
        description: 'Balance and flexibility',
        duration: '50 mins',
        imagePath: 'assets/yoga.jpg',
        estimatedCalories: 150,
      ),
      Activity(
        id: 'aqua',
        icon: Icons.pool,
        title: 'Aqua Aerobics',
        description: 'Gentle full-body workout',
        duration: '40 mins',
        imagePath: 'assets/aqua.jpg',
        estimatedCalories: 220,
      ),
    ];

    final List<Activity> displayActivities = [];

    if (profile.conditions.contains('Arthritis') ||
        profile.conditions.contains('Joint pain')) {
      displayActivities.addAll([
        activityBank.firstWhere((a) => a.id == 'aqua'),
        activityBank.firstWhere((a) => a.id == 'yoga'),
        activityBank.firstWhere((a) => a.id == 'walking'),
      ]);
    } else {
      for (final goal in profile.goals) {
        if (goal.toLowerCase().contains('weight loss')) {
          displayActivities.addAll([
            activityBank.firstWhere((a) => a.id == 'hiit'),
            activityBank.firstWhere((a) => a.id == 'cycling'),
            activityBank.firstWhere((a) => a.id == 'swimming'),
          ]);
        } else if (goal.toLowerCase().contains('muscle gain')) {
          displayActivities.addAll([
            activityBank.firstWhere((a) => a.id == 'strength'),
            activityBank.firstWhere((a) => a.id == 'bodyweight'),
            activityBank.firstWhere((a) => a.id == 'bands'),
          ]);
        } else if (goal.toLowerCase().contains('general fitness') ||
            goal.toLowerCase().contains('improve fitness')) {
          displayActivities.addAll([
            activityBank.firstWhere((a) => a.id == 'walking'),
            activityBank.firstWhere((a) => a.id == 'yoga'),
            activityBank.firstWhere((a) => a.id == 'aqua'),
          ]);
        } else if (goal.toLowerCase().contains('maintain weight')) {
          displayActivities.addAll([
            activityBank.firstWhere((a) => a.id == 'walking'),
            activityBank.firstWhere((a) => a.id == 'cycling'),
            activityBank.firstWhere((a) => a.id == 'bodyweight'),
          ]);
        }
      }
    }

    displayActivities.toSet().toList();

    if (displayActivities.isEmpty) {
      displayActivities.addAll([
        activityBank.firstWhere((a) => a.id == 'walking'),
        activityBank.firstWhere((a) => a.id == 'yoga'),
        activityBank.firstWhere((a) => a.id == 'bodyweight'),
      ]);
    }

    return Column(
      children: [
        CarouselSlider(
          items: displayActivities.map((activity) {
            return GestureDetector(
              onTap: () => _showActivityDetails(activity, profile),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: AssetImage(activity.imagePath),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(activity.icon, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            activity.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        activity.description,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      if (activity.duration != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.timer, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Duration: ${activity.duration}',
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
          options: CarouselOptions(
            height: 200,
            enlargeCenterPage: true,
            autoPlay: true,
            aspectRatio: 16 / 9,
            viewportFraction: 0.85,
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: _completedActivitiesStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox();
            }
            final today = DateTime.now();
            final todayActivities = snapshot.data!.docs.where((doc) {
              final timestamp = doc['completedAt'] as Timestamp?;
              if (timestamp == null) return false;
              final date = timestamp.toDate();
              return date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
            }).length;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Today: $todayActivities activities completed',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${displayActivities.length} recommended',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDietPlan(UserProfile profile) {
    final diets = _getRecommendedDiets(profile);

    return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
            children: [
            Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Center(
              child: Text(
              'Today\'s AI-Generated Meal Plan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...diets.map((diet) => GestureDetector(
        onTap: () => _showMealDetailsWithNutrition(diet, profile),
    child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Container(
    decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    color: Colors.green.shade50,
    ),
    padding: const EdgeInsets.all(12),
    child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Container(
    width: 8,
    height: 8,
    margin: const EdgeInsets.only(top: 6, right: 12),
    decoration: BoxDecoration(
    color: Colors.green.shade300,
    shape: BoxShape.circle,
    ),
    ),
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    diet.mealTime,
    style: const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 16,
    ),
    ),
    const SizedBox(height: 4),
    Text(diet.description),
    const SizedBox(height: 4),
    if (diet.nutritionalInfo != null)
    Text(
    '${diet.calories} cal • ${diet.nutritionalInfo!['protein']}g protein • ${diet.nutritionalInfo!['carbs']}g carbs',
    style: TextStyle(
    color: Colors.grey.shade600,
    fontSize: 12,
    ),
    )
    else
    Text(
    '${diet.calories} calories',
    style: TextStyle(
    color: Colors.grey.shade600,
    fontSize: 12,
    ),
    ),
    ],
    ),
    ),
    Icon(
    Icons.arrow_forward_ios,
    size: 16,
    color: Colors.grey.shade500,
    ),
    ],
    ),
    ),
    ),
    )).toList(),
    const SizedBox(height: 16),
    Center(
    child: ElevatedButton.icon(
    icon: const Icon(Icons.autorenew),
    label: const Text('Generate New Meal Plan'),
    style: ElevatedButton.styleFrom(
    backgroundColor: Colors.green.shade300,
    foregroundColor: Colors.white,
    ),
    onPressed: () {
    setState(() {});
    },
    ),
    ),
    ],
    ),
    ),
    ),
    StreamBuilder<QuerySnapshot>(
    stream: _completedMealsStream,
    builder: (context, snapshot) {
    if (!snapshot.hasData) {
    return const SizedBox();
    }
    final today = DateTime.now();
    final todayMeals = snapshot.data!.docs.where((doc) {
    final timestamp = doc['completedAt'] as Timestamp?;
    if (timestamp == null) return false;
    final date = timestamp.toDate();
    return date.year == today.year &&
    date.month == today.month &&
    date.day == today.day;
    }).length;

    return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
    Text(
    'Today: $todayMeals/${diets.length} meals completed',
    style: TextStyle(
    color: todayMeals >= diets.length
    ? Colors.green.shade700
        : Colors.orange.shade700,
    fontWeight: FontWeight.bold,
    ),
    ),
    Text(
    '${_calculateTotalCalories(diets)} total calories',
    style: TextStyle(
    color: Colors.grey.shade600,
    ),
    ),
    ],
    );
    },
    ),
    ],
    ),
    );
    }

  Widget _buildFeaturedRecipes(UserProfile profile) {
    final featuredRecipes = _getRecommendedRecipes(profile).take(3).toList();

    return CarouselSlider(
      items: featuredRecipes.map((recipe) {
        return GestureDetector(
          onTap: () => _showRecipeDetails(recipe, profile),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 0), // Remove horizontal margin
            width: double.infinity, // Take full available width
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: _getFeaturedRecipeImageProvider(recipe),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.3),
                  BlendMode.darken,
                ),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${recipe.calories} cal • ${recipe.prepTime} min',
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
      options: CarouselOptions(
        height: 200,
        enlargeCenterPage: true,
        autoPlay: true,
        viewportFraction: 0.9, // Full width items
        // Remove end padding
      ),
    );
  }

  ImageProvider _getFeaturedRecipeImageProvider(Recipe recipe) {
    if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty) {
      try {
        // Validate the URL first
        final uri = Uri.parse(recipe.imageUrl!);
        if (uri.isAbsolute) {
          return NetworkImage(recipe.imageUrl!);
        }
      } catch (e) {
        // Fall through to asset image if URL is invalid
      }
    }
    return AssetImage(recipe.assetPath);
  }

  Widget _buildRecommendedRecipes(UserProfile profile) {
    final recommendedRecipes = _getRecommendedRecipes(profile);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recommendedRecipes.length,
      itemBuilder: (context, index) {
        final recipe = recommendedRecipes[index];
        return _buildRecipeCard(recipe, profile);
      },
    );
  }

  Widget _buildFavoriteRecipes() {
    return StreamBuilder<QuerySnapshot>(
      stream: _favoriteRecipesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No favorite recipes yet'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final recipe = Recipe.fromMap(doc.data() as Map<String, dynamic>);
            return _buildRecipeCard(recipe, UserProfile(
              name: '',
              age: 0,
              height: 0,
              weight: 0,
              activities: [],
              goals: [],
              diets: [],
              conditions: [],
            ));
          },
        );
      },
    );
  }

  Widget _buildRecipeCategories(UserProfile profile) {
    final categories = [
      'Breakfast',
      'Lunch',
      'Dinner',
      'Snacks',
      'Vegetarian',
      'High Protein',
      'Low Carb',
      'Quick Meals'
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showCategoryRecipes(categories[index], profile),
            child: Center(
              child: Text(
                categories[index],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipeCard(Recipe recipe, UserProfile profile) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showRecipeDetails(recipe, profile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Container(
                height: 150,
                width: double.infinity,
                child: recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                    ? Image.network(
                  recipe.imageUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildAssetImage(recipe),
                )
                    : _buildAssetImage(recipe),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        recipe.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: recipe.isFavorite ? Colors.red : Colors.grey,
                        ),
                        onPressed: () => _toggleFavorite(recipe),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recipe.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.timer, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('${recipe.prepTime} min'),
                      const SizedBox(width: 16),
                      Icon(Icons.local_fire_department, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('${recipe.calories} cal'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: recipe.tags.map((tag) => Chip(
                      label: Text(tag),
                      backgroundColor: Colors.green.shade100,
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetImage(Recipe recipe) {
    return Image.asset(
      recipe.assetPath,
      height: 150,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        height: 150,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.fastfood, size: 50, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildWeeklySummaryCards() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getWeeklyProgressData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data ?? {
          'activityCount': 0,
          'mealCount': 0,
          'caloriesBurned': 0,
          'caloriesConsumed': 0,
        };

        return Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Activities',
                value: data['activityCount'].toString(),
                icon: Icons.directions_run,
                color: Colors.blue,
                subtitle: 'this week',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryCard(
                title: 'Meals',
                value: data['mealCount'].toString(),
                icon: Icons.restaurant,
                color: Colors.green,
                subtitle: 'completed',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityProgressChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activity Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Last 7 Days',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _getWeeklyActivityStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_run, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No activity data'),
                          Text('Complete activities to see progress'),
                        ],
                      ),
                    );
                  }

                  final weekData = snapshot.data!;
                  final maxY = weekData.fold<double>(0, (max, day) =>
                  day['count'] > max ? day['count'].toDouble() : max);

                  return BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY > 0 ? maxY + 2 : 5,
                      barGroups: weekData.asMap().entries.map((entry) {
                        final dayData = entry.value;
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: dayData['count'].toDouble(),
                              color: Colors.blue,
                              width: 16,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= weekData.length) {
                                return const Text('');
                              }
                              final date = weekData[index]['date'] as DateTime;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  DateFormat('E').format(date),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              );
                            },
                            reservedSize: 30,
                            interval: maxY > 5 ? (maxY / 5) : 1,
                          ),
                        ),
                        rightTitles: const AxisTitles(),
                        topTitles: const AxisTitles(),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withOpacity(0.2),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionProgressChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nutrition Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Last 7 Days',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _getWeeklyNutritionStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restaurant, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No nutrition data'),
                          Text('Complete meals to see progress'),
                        ],
                      ),
                    );
                  }

                  final weekData = snapshot.data!;
                  final maxCalories = weekData.fold<double>(0, (max, day) =>
                  day['calories'] > max ? day['calories'].toDouble() : max);

                  return LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxCalories > 0 ? maxCalories + 200 : 1000,
                      lineBarsData: [
                        LineChartBarData(
                          spots: weekData.asMap().entries.map((entry) {
                            return FlSpot(
                              entry.key.toDouble(),
                              entry.value['calories'].toDouble(),
                            );
                          }).toList(),
                          isCurved: true,
                          color: Colors.green,
                          barWidth: 4,
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.withOpacity(0.3),
                                Colors.green.withOpacity(0.1),
                              ],
                            ),
                          ),
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: Colors.green,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= weekData.length) {
                                return const Text('');
                              }
                              final date = weekData[index]['date'] as DateTime;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  DateFormat('E').format(date),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              );
                            },
                            reservedSize: 30,
                            interval: maxCalories > 1000 ? (maxCalories / 5) : 200,
                          ),
                        ),
                        rightTitles: const AxisTitles(),
                        topTitles: const AxisTitles(),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withOpacity(0.2),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activities',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: _completedActivitiesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No activities completed yet'),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final activity = doc.data() as Map<String, dynamic>;
                final date = (activity['completedAt'] as Timestamp).toDate();

                return ListTile(
                  leading: const Icon(Icons.directions_run, color: Colors.blue),
                  title: Text(activity['title'] ?? 'Activity'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${activity['duration'] ?? '0'} mins • ${activity['caloriesBurned'] ?? '0'} cal',
                      ),
                      Text(
                        DateFormat('MMM d, h:mm a').format(date),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: Text(
                    DateFormat('EEE').format(date),
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentMealsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Meals',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: _completedMealsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No meals logged yet'),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final meal = doc.data() as Map<String, dynamic>;
                final date = (meal['completedAt'] as Timestamp).toDate();

                return ListTile(
                  leading: const Icon(Icons.restaurant, color: Colors.green),
                  title: Text(meal['mealTime'] ?? 'Meal'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meal['description'] ?? ''),
                      Text(
                        '${meal['calories'] ?? '0'} cal • ${DateFormat('MMM d, h:mm a').format(date)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: Text(
                    DateFormat('EEE').format(date),
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Stream<List<Map<String, dynamic>>> _getWeeklyActivityStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('completedActivities')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final weekStart = now.subtract(const Duration(days: 6));
      final weekEnd = now.add(const Duration(days: 1)); // Include today

      final weekData = List.generate(7, (index) {
        final date = weekStart.add(Duration(days: index));
        return {
          'date': date,
          'count': 0,
          'calories': 0,
          'activities': [],
        };
      });

      for (final doc in snapshot.docs) {
        final activity = doc.data();
        final timestamp = activity['completedAt'] as Timestamp?;
        if (timestamp == null) continue;

        final activityDate = timestamp.toDate();

        if (activityDate.isBefore(weekStart) || activityDate.isAfter(weekEnd)) {
          continue;
        }

        final title = activity['title'] as String? ?? 'Activity';
        final calories = activity['caloriesBurned'] as int? ?? 0;

        for (final day in weekData) {
          final dayDate = day['date'] as DateTime;
          if (activityDate.year == dayDate.year &&
              activityDate.month == dayDate.month &&
              activityDate.day == dayDate.day) {
            day['count'] = (day['count'] as int) + 1;
            day['calories'] = (day['calories'] as int) + calories;
            (day['activities'] as List).add(title);
            break;
          }
        }
      }

      return weekData;
    });
  }

  Stream<List<Map<String, dynamic>>> _getWeeklyNutritionStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('completedMeals')
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final weekStart = now.subtract(const Duration(days: 6));
      final weekEnd = now.add(const Duration(days: 1)); // Include today

      final weekData = List.generate(7, (index) {
        final date = weekStart.add(Duration(days: index));
        return {
          'date': date,
          'calories': 0,
          'meals': [],
        };
      });

      for (final doc in snapshot.docs) {
        final meal = doc.data();
        final timestamp = meal['completedAt'] as Timestamp?;
        if (timestamp == null) continue;

        final mealDate = timestamp.toDate();

        if (mealDate.isBefore(weekStart) || mealDate.isAfter(weekEnd)) {
          continue;
        }

        final calories = (meal['calories'] as int?) ?? 0;
        final description = meal['description'] as String? ?? 'Meal';

        for (final day in weekData) {
          final dayDate = day['date'] as DateTime;
          if (mealDate.year == dayDate.year &&
              mealDate.month == dayDate.month &&
              mealDate.day == dayDate.day) {
            day['calories'] = (day['calories'] as int) + calories;
            (day['meals'] as List).add(description);
            break;
          }
        }
      }

      return weekData;
    });
  }

  Future<Map<String, dynamic>> _getWeeklyProgressData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'activityCount': 0,
        'mealCount': 0,
        'caloriesBurned': 0,
        'caloriesConsumed': 0,
      };
    }

    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 6));
    final weekEnd = now.add(const Duration(days: 1)); // Include today

    try {
      final activitiesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('completedActivities')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('completedAt', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
          .get();

      final mealsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('completedMeals')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('completedAt', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
          .get();

      final caloriesBurned = activitiesSnapshot.docs.fold<int>(0, (sum, doc) {
        return sum + (doc['caloriesBurned'] as int? ?? 0);
      });

      final caloriesConsumed = mealsSnapshot.docs.fold<int>(0, (sum, doc) {
        return sum + (doc['calories'] as int? ?? 0);
      });

      return {
        'activityCount': activitiesSnapshot.size,
        'mealCount': mealsSnapshot.size,
        'caloriesBurned': caloriesBurned,
        'caloriesConsumed': caloriesConsumed,
      };
    } catch (e) {
      print('Error getting weekly progress data: $e');
      return {
        'activityCount': 0,
        'mealCount': 0,
        'caloriesBurned': 0,
        'caloriesConsumed': 0,
      };
    }
  }

  Widget _buildProgressStats(UserProfile profile) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Weekly Stats',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, int>>(
              future: _getWeeklyStats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return const Center(
                    child: Text('No activity data available'),
                  );
                }

                final stats = snapshot.data!;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Activities',
                      stats['activities'].toString(),
                      Icons.directions_run,
                    ),
                    _buildStatItem(
                      'Meals',
                      stats['meals'].toString(),
                      Icons.restaurant,
                    ),
                    _buildStatItem(
                      'Calories',
                      stats['calories'].toString(),
                      Icons.local_fire_department,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, int>> _getWeeklyStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'activities': 0, 'meals': 0, 'calories': 0};

    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 7));

    try {
      final activitiesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('completedActivities')
          .where('completedAt', isGreaterThan: Timestamp.fromDate(weekStart))
          .get();

      final mealsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('completedMeals')
          .where('completedAt', isGreaterThan: Timestamp.fromDate(weekStart))
          .get();

      final calories = activitiesSnapshot.docs.fold<int>(0, (sum, doc) {
        return sum + (doc['caloriesBurned'] as int? ?? 0);
      });

      return {
        'activities': activitiesSnapshot.size,
        'meals': mealsSnapshot.size,
        'calories': calories,
      };
    } catch (e) {
      print('Error getting weekly stats: $e');
      return {'activities': 0, 'meals': 0, 'calories': 0};
    }
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 30, color: Colors.green.shade300),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  List<Recipe> _getRecommendedRecipes(UserProfile profile) {
    final allRecipes = [
      Recipe(
        id: '1',
        name: 'Quinoa Salad',
        description: 'Healthy quinoa salad with vegetables and lemon dressing',
        assetPath: 'assets/quinoa-salad.jpg',
        prepTime: 15,
        calories: 320,
        ingredients: [
          '1 cup quinoa',
          '2 cups water',
          '1 cucumber, diced',
          '1 bell pepper, diced',
          '1/4 cup olive oil',
          'Juice of 1 lemon',
          'Salt and pepper to taste'
        ],
        instructions: [
          'Rinse quinoa under cold water',
          'Cook quinoa in water for 15 minutes',
          'Let quinoa cool',
          'Mix with vegetables',
          'Whisk together olive oil and lemon juice',
          'Pour dressing over salad and toss',
          'Season with salt and pepper'
        ],
        nutritionalInfo: {
          'protein': 12,
          'carbs': 45,
          'fats': 10,
          'fiber': 8,
          'sugar': 5,
        },
        tags: ['Vegetarian', 'Healthy', 'Quick'],
        possibleSubstitutions: profile.diets.contains('Gluten-free')
            ? ['Use gluten-free soy sauce']
            : null,
      ),
      Recipe(
        id: '2',
        name: 'Grilled Chicken',
        description: 'Juicy grilled chicken with herbs and vegetables',
        assetPath: 'assets/grilled-chicken.jpg',
        prepTime: 30,
        calories: 450,
        ingredients: [
          '2 chicken breasts',
          '2 tbsp olive oil',
          '1 tsp garlic powder',
          '1 tsp paprika',
          '1/2 tsp salt',
          '1/4 tsp black pepper',
          '1 lemon, sliced'
        ],
        instructions: [
          'Preheat grill to medium-high',
          'Mix spices with olive oil',
          'Coat chicken with spice mixture',
          'Grill for 6-8 minutes per side',
          'Add lemon slices last 2 minutes',
          'Let rest 5 minutes before serving'
        ],
        nutritionalInfo: {
          'protein': 35,
          'carbs': 5,
          'fats': 20,
          'fiber': 2,
          'sugar': 1,
        },
        tags: ['High Protein', 'Low Carb', 'Grilled'],
        possibleSubstitutions: profile.diets.contains('Vegetarian')
            ? ['Use portobello mushrooms instead of chicken']
            : null,
      ),
      Recipe(
        id: '3',
        name: 'Avocado Toast',
        description: 'Simple and nutritious avocado toast',
        assetPath: 'assets/avocado-toast.jpg',
        prepTime: 5,
        calories: 250,
        ingredients: [
          '2 slices whole grain bread',
          '1 ripe avocado',
          '1 tbsp lemon juice',
          'Salt and pepper to taste',
          'Red pepper flakes (optional)'
        ],
        instructions: [
          'Toast the bread',
          'Mash the avocado with lemon juice, salt, and pepper',
          'Spread the avocado mixture on toast',
          'Sprinkle with red pepper flakes if desired'
        ],
        nutritionalInfo: {
          'protein': 6,
          'carbs': 25,
          'fats': 15,
          'fiber': 10,
          'sugar': 2,
        },
        tags: ['Breakfast', 'Quick', 'Vegetarian'],
        possibleSubstitutions: profile.diets.contains('Gluten-free')
            ? ['Use gluten-free bread']
            : null,
      ),
      Recipe(
        id: '4',
        name: 'Vegetable Stir Fry',
        description: 'Colorful vegetable stir fry with tofu',
        assetPath: 'assets/stir-fry.jpg',
        prepTime: 20,
        calories: 350,
        ingredients: [
          '1 block firm tofu, cubed',
          '2 cups mixed vegetables (bell peppers, broccoli, carrots)',
          '2 tbsp soy sauce',
          '1 tbsp sesame oil',
          '1 tsp ginger, minced',
          '1 tsp garlic, minced'
        ],
        instructions: [
          'Press tofu to remove excess water',
          'Heat oil in a pan and add tofu, cook until golden',
          'Remove tofu and add vegetables',
          'Stir fry vegetables until tender-crisp',
          'Add ginger and garlic, cook for 1 minute',
          'Return tofu to pan, add soy sauce',
          'Stir to combine and serve'
        ],
        nutritionalInfo: {
          'protein': 18,
          'carbs': 20,
          'fats': 12,
          'fiber': 6,
          'sugar': 5,
        },
        tags: ['Vegetarian', 'Dinner', 'High Protein'],
        possibleSubstitutions: profile.diets.contains('Gluten-free')
            ? ['Use tamari instead of soy sauce']
            : null,
      ),
    ];

    return allRecipes.where((recipe) {
      if (profile.diets.contains('Vegetarian') &&
          !recipe.tags.contains('Vegetarian')) {
        return false;
      }

      if (profile.diets.contains('Gluten-free') &&
          recipe.tags.contains('Contains Gluten')) {
        return false;
      }

      if (profile.conditions.contains('Diabetes') &&
          (recipe.nutritionalInfo['sugar'] > 10)) {
        return false;
      }

      if (profile.goals.contains('Weight loss') &&
          (recipe.calories > 400)) {
        return false;
      }

      if (profile.goals.contains('Muscle gain') &&
          (recipe.nutritionalInfo['protein'] < 20)) {
        return false;
      }

      return true;
    }).toList();
  }

  List<Diet> _getRecommendedDiets(UserProfile profile) {
    final List<Diet> diets = [];

    diets.add(Diet(
      id: 'breakfast1',
      mealTime: 'Breakfast',
      description: 'Oatmeal with berries and nuts',
      calories: 350,
      nutritionalInfo: {
        'protein': 12,
        'carbs': 45,
        'fats': 10,
        'fiber': 8,
        'sugar': 15,
      },
      ingredientSubstitutions: profile.conditions.contains('Diabetes')
          ? ['Use sugar-free sweetener instead of honey', 'Add chia seeds for extra fiber']
          : null,
    ));

    diets.add(Diet(
      id: 'lunch1',
      mealTime: 'Lunch',
      description: 'Grilled chicken with quinoa and steamed vegetables',
      calories: 450,
      nutritionalInfo: {
        'protein': 35,
        'carbs': 40,
        'fats': 12,
        'fiber': 6,
        'sugar': 5,
      },
      ingredientSubstitutions: profile.diets.contains('Vegetarian')
          ? ['Replace chicken with tofu or tempeh']
          : null,
    ));

    diets.add(Diet(
      id: 'snack1',
      mealTime: 'Snack',
      description: 'Greek yogurt with honey and almonds',
      calories: 200,
      nutritionalInfo: {
        'protein': 15,
        'carbs': 20,
        'fats': 8,
        'fiber': 2,
        'sugar': 12,
      },
      ingredientSubstitutions: profile.diets.contains('Dairy-free')
          ? ['Use coconut yogurt instead of Greek yogurt']
          : null,
    ));

    diets.add(Diet(
      id: 'dinner1',
      mealTime: 'Dinner',
      description: 'Salmon with sweet potato and asparagus',
      calories: 500,
      nutritionalInfo: {
        'protein': 30,
        'carbs': 35,
        'fats': 20,
        'fiber': 7,
        'sugar': 8,
      },
      ingredientSubstitutions: profile.diets.contains('Vegetarian')
          ? ['Replace salmon with grilled portobello mushrooms']
          : null,
    ));

    if (profile.diets.contains('Vegetarian')) {
      diets[1] = Diet(
        id: 'lunch2',
        mealTime: 'Lunch',
        description: 'Lentil curry with brown rice',
        calories: 400,
        nutritionalInfo: {
          'protein': 18,
          'carbs': 60,
          'fats': 8,
          'fiber': 12,
          'sugar': 5,
        },
      );
      diets[3] = Diet(
        id: 'dinner2',
        mealTime: 'Dinner',
        description: 'Tofu stir-fry with mixed vegetables',
        calories: 450,
        nutritionalInfo: {
          'protein': 20,
          'carbs': 30,
          'fats': 15,
          'fiber': 8,
          'sugar': 6,
        },
      );
    }

    if (profile.goals.contains('Weight loss')) {
      diets[0] = Diet(
        id: 'breakfast2',
        mealTime: 'Breakfast',
        description: 'Egg whites with spinach and whole grain toast',
        calories: 300,
        nutritionalInfo: {
          'protein': 20,
          'carbs': 25,
          'fats': 5,
          'fiber': 4,
          'sugar': 2,
        },
      );
      diets[2] = Diet(
        id: 'snack2',
        mealTime: 'Snack',
        description: 'Apple with almond butter',
        calories: 150,
        nutritionalInfo: {
          'protein': 4,
          'carbs': 20,
          'fats': 8,
          'fiber': 4,
          'sugar': 15,
        },
      );
    }

    if (profile.goals.contains('Muscle gain')) {
      diets[1] = Diet(
        id: 'lunch3',
        mealTime: 'Lunch',
        description: 'Grilled chicken with brown rice and broccoli',
        calories: 550,
        nutritionalInfo: {
          'protein': 45,
          'carbs': 50,
          'fats': 12,
          'fiber': 6,
          'sugar': 3,
        },
      );
      diets.add(Diet(
        id: 'snack3',
        mealTime: 'Post-Workout',
        description: 'Protein shake with banana',
        calories: 300,
        nutritionalInfo: {
          'protein': 30,
          'carbs': 35,
          'fats': 5,
          'fiber': 3,
          'sugar': 20,
        },
      ));
    }

    if (profile.conditions.contains('Diabetes')) {
      diets[0] = Diet(
        id: 'breakfast4',
        mealTime: 'Breakfast',
        description: 'Scrambled eggs with avocado and whole grain toast',
        calories: 350,
        nutritionalInfo: {
          'protein': 18,
          'carbs': 20,
          'fats': 20,
          'fiber': 8,
          'sugar': 2,
        },
        ingredientSubstitutions: ['Use whole grain or low-carb bread'],
      );
      diets[2] = Diet(
        id: 'snack4',
        mealTime: 'Snack',
        description: 'Handful of nuts and cheese cubes',
        calories: 200,
        nutritionalInfo: {
          'protein': 10,
          'carbs': 5,
          'fats': 15,
          'fiber': 3,
          'sugar': 1,
        },
      );
    }

    return diets;
  }

  int _calculateTotalCalories(List<Diet> diets) {
    return diets.fold(0, (sum, diet) => sum + diet.calories);
  }

  void _showActivityDetails(Activity activity, UserProfile profile) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(activity.icon, size: 30),
                  const SizedBox(width: 10),
                  Text(
                    activity.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                activity.description,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              if (activity.duration != null)
                Text(
                  'Duration: ${activity.duration}',
                  style: const TextStyle(fontSize: 16),
                ),
              Text(
                'Estimated calories burned: ${activity.estimatedCalories}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Close'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _markActivityCompleted(activity);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade300,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Mark as Completed'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMealDetailsWithNutrition(Diet meal, UserProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.mealTime,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  meal.description,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Nutritional Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (meal.nutritionalInfo != null)
                  Column(
                    children: [
                      _buildNutritionRow('Calories', '${meal.calories} kcal'),
                      _buildNutritionRow('Protein', '${meal.nutritionalInfo!['protein']}g'),
                      _buildNutritionRow('Carbs', '${meal.nutritionalInfo!['carbs']}g'),
                      _buildNutritionRow('Fats', '${meal.nutritionalInfo!['fats']}g'),
                      _buildNutritionRow('Fiber', '${meal.nutritionalInfo!['fiber']}g'),
                      _buildNutritionRow('Sugar', '${meal.nutritionalInfo!['sugar']}g'),
                    ],
                  ),
                const SizedBox(height: 16),

                if (meal.ingredientSubstitutions != null && meal.ingredientSubstitutions!.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Suggested Substitutions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...meal.ingredientSubstitutions!.map((sub) =>
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text('• $sub'),
                          ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Close'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _markMealCompleted(meal);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade300,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Mark as Completed'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _markActivityCompleted(Activity activity) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final completedActivity = {
      'activityId': activity.id,
      'title': activity.title,
      'completedAt': Timestamp.now(),
      'duration': int.parse(activity.duration!.replaceAll(' mins', '')),
      'caloriesBurned': activity.estimatedCalories,
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('completedActivities')
          .add(completedActivity);

      setState(() {
        _completedActivitiesStream = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('completedActivities')
            .orderBy('completedAt', descending: true)
            .snapshots();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${activity.title} marked as completed!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark activity as completed: $e')),
      );
    }
  }

  Future<void> _markMealCompleted(Diet meal) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final completedMeal = {
      'mealId': meal.id,
      'mealTime': meal.mealTime,
      'description': meal.description,
      'completedAt': Timestamp.now(),
      'calories': meal.calories,
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('completedMeals')
          .add(completedMeal);

      setState(() {
        _completedMealsStream = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('completedMeals')
            .orderBy('completedAt', descending: true)
            .snapshots();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${meal.mealTime} meal marked as completed!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark meal as completed: $e')),
      );
    }
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (recipe.isFavorite) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favoriteRecipes')
            .doc(recipe.id)
            .delete();
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favoriteRecipes')
            .doc(recipe.id)
            .set(recipe.toMap());
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update favorites: $e')),
      );
    }
  }

  void _showRecipeSearch(UserProfile profile) {
    showSearch(
      context: context,
      delegate: RecipeSearchDelegate(profile: profile),
    );
  }

  void _showCategoryRecipes(String category, UserProfile profile) {
    final recipes = _getRecommendedRecipes(profile)
        .where((recipe) => recipe.tags.contains(category))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(category),
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              return _buildRecipeCard(recipes[index], profile);
            },
          ),
        ),
      ),
    );
  }

  void _showAddRecipeDialog(UserProfile profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Recipe'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Recipe Name'),
                onChanged: (value) {},
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Description'),
                onChanged: (value) {},
              ),
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
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showProfileDetails(UserProfile profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Name: ${profile.name}'),
              if (profile.email != null) Text('Email: ${profile.email}'),
              Text('Age: ${profile.age}'),
              Text('Height: ${profile.height} cm'),
              Text('Weight: ${profile.weight} kg'),
              if (profile.gender != null) Text('Gender: ${profile.gender}'),
              const SizedBox(height: 10),
              const Text('Goals:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...profile.goals.map((goal) => Text('- $goal')).toList(),
              const SizedBox(height: 10),
              const Text('Health Conditions:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...profile.conditions.map((cond) => Text('- $cond')).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _editProfile(UserProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GreenProfileForm(),
      ),
    );
  }

  Future<void> _confirmDeleteProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile'),
        content: const Text('Are you sure you want to delete your profile? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
        await user.delete();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
                (route) => false,
          );
        }
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
            (route) => false,
      );
    }
  }

  String _getWelcomeMessage(UserProfile profile) {
    if (profile.goals.contains('Weight loss')) {
      return "Let's work together to achieve your weight loss goals!";
    } else if (profile.goals.contains('Muscle gain')) {
      return "Ready to build some muscle? We've got your back!";
    } else if (profile.goals.contains('Maintain weight')) {
      return "We'll help you maintain your current weight healthily.";
    } else if (profile.goals.contains('Improve fitness')) {
      return "Let's improve your fitness level together!";
    } else if (profile.goals.contains('Manage health condition')) {
      return "We'll help you manage your health effectively.";
    } else {
      return "Stay healthy and active with our personalized recommendations.";
    }
  }

  double _calculateGoalProgress(UserProfile profile) {
    if (profile.targetWeight == null || profile.goalDate == null) return 0.0;
    final totalDays = profile.goalDate!.difference(DateTime.now()).inDays;
    final daysPassed = DateTime.now().difference(profile.createdAt).inDays;
    if (totalDays <= 0 || daysPassed <= 0) return 0.0;
    return (daysPassed / totalDays).clamp(0.0, 1.0);
  }

  Widget _buildHealthMetric(String title, String value, String subtitle, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  String _getBmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }
}

class RecipeSearchDelegate extends SearchDelegate {
  final UserProfile profile;

  RecipeSearchDelegate({required this.profile});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final recipes = _DynamicHomeScreenState()._getRecommendedRecipes(profile)
        .where((recipe) => recipe.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return ListTile(
          title: Text(recipe.name),
          subtitle: Text(recipe.description),
          onTap: () {
            _DynamicHomeScreenState()._showRecipeDetails(recipe, profile);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final recipes = _DynamicHomeScreenState()._getRecommendedRecipes(profile)
        .where((recipe) => recipe.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return ListTile(
          title: Text(recipe.name),
          subtitle: Text(recipe.description),
          onTap: () {
            _DynamicHomeScreenState()._showRecipeDetails(recipe, profile);
          },
        );
      },
    );
  }
}

class UserProfile {
  final String name;
  final String? email;
  final String? photoUrl;
  final String? gender;
  final int age;
  final double height;
  final double weight;
  final List<String> activities;
  final List<String> goals;
  final double? targetWeight;
  final DateTime? goalDate;
  final List<String> diets;
  final List<String> conditions;
  final DateTime createdAt;

  UserProfile({
    required this.name,
    this.email,
    this.photoUrl,
    this.gender,
    required this.age,
    required this.height,
    required this.weight,
    required this.activities,
    required this.goals,
    this.targetWeight,
    this.goalDate,
    required this.diets,
    required this.conditions,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] ?? '',
      email: map['email'],
      photoUrl: map['photoUrl'],
      gender: map['gender'],
      age: map['age'] ?? 0,
      height: (map['height'] ?? 0).toDouble(),
      weight: (map['weight'] ?? 0).toDouble(),
      activities: List<String>.from(map['activityLevel'] != null
          ? [map['activityLevel']]
          : map['activities'] ?? []),
      goals: List<String>.from(map['goals'] ?? []),
      targetWeight: map['targetWeight']?.toDouble(),
      goalDate: map['goalDate']?.toDate(),
      diets: List<String>.from(map['dietaryPreferences'] ?? []),
      conditions: List<String>.from(map['healthConditions'] ?? []),
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }
}

class Activity {
  final String id;
  final IconData icon;
  final String title;
  final String description;
  final String? duration;
  final String imagePath;
  final int estimatedCalories;

  Activity({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    this.duration,
    required this.imagePath,
    required this.estimatedCalories,
  });
}

class Diet {
  final String id;
  final String mealTime;
  final String description;
  final int calories;
  final Map<String, dynamic>? nutritionalInfo;
  final List<String>? ingredientSubstitutions;

  Diet({
    required this.id,
    required this.mealTime,
    required this.description,
    required this.calories,
    this.nutritionalInfo,
    this.ingredientSubstitutions,
  });
}

class Recipe {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String assetPath;
  final int prepTime;
  final int calories;
  final List<String> ingredients;
  final List<String> instructions;
  final Map<String, dynamic> nutritionalInfo;
  final List<String> tags;
  final List<String>? possibleSubstitutions;
  bool isFavorite;

  Recipe({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl = '',
    required this.assetPath,
    required this.prepTime,
    required this.calories,
    required this.ingredients,
    required this.instructions,
    required this.nutritionalInfo,
    required this.tags,
    this.possibleSubstitutions,
    this.isFavorite = false,
  });

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      imageUrl: map['imageUrl'],
      assetPath: map['assetPath'] ?? 'assets/default_recipe.png',
      prepTime: map['prepTime'],
      calories: map['calories'],
      ingredients: List<String>.from(map['ingredients']),
      instructions: List<String>.from(map['instructions']),
      nutritionalInfo: Map<String, dynamic>.from(map['nutritionalInfo']),
      tags: List<String>.from(map['tags']),
      possibleSubstitutions: map['possibleSubstitutions'] != null
          ? List<String>.from(map['possibleSubstitutions'])
          : null,
      isFavorite: map['isFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'assetPath': assetPath,
      'prepTime': prepTime,
      'calories': calories,
      'ingredients': ingredients,
      'instructions': instructions,
      'nutritionalInfo': nutritionalInfo,
      'tags': tags,
      'possibleSubstitutions': possibleSubstitutions,
      'isFavorite': isFavorite,
    };
  }
}