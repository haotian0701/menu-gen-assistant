import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'error_utils.dart';

import 'generating_page.dart';
import 'account_icon_button.dart';
import 'upload_page.dart';  // Add import for home page

class ExtractionPage extends StatefulWidget {
  final String imageUrl;
  final List<Map<String, dynamic>>? initialDetectedItems;
  final bool isRegenerating;
  final String? initialMealType;
  final String? initialDietaryGoal;
  final String? initialMealTime;
  final String? initialAmountPeople;
  final String? initialRestrictDiet;
  final String? initialPreferredRegion;
  final String? initialSkillLevel;
  final List<String>? initialKitchenTools;
  final String? mode;

  const ExtractionPage({
    super.key,
    required this.imageUrl,
    this.initialDetectedItems,
    this.isRegenerating = false,
    this.initialMealType,
    this.initialDietaryGoal,
    this.initialMealTime,
    this.initialAmountPeople,
    this.initialRestrictDiet,
    this.initialPreferredRegion,
    this.initialSkillLevel,
    this.initialKitchenTools,
    this.mode,
  });

  @override
  State<ExtractionPage> createState() => _ExtractionPageState();
}

class _ExtractionPageState extends State<ExtractionPage> {
  late ExtractionController _extractionController;
  bool _disposed = false;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _extractionController = ExtractionController(
      imageUrl: widget.imageUrl,
      initialDetectedItems: widget.initialDetectedItems,
      isRegenerating: widget.isRegenerating,
      initialMealType: widget.initialMealType,
      initialDietaryGoal: widget.initialDietaryGoal,
      initialMealTime: widget.initialMealTime,
      initialAmountPeople: widget.initialAmountPeople,
      initialRestrictDiet: widget.initialRestrictDiet,
      initialPreferredRegion: widget.initialPreferredRegion,
      initialSkillLevel: widget.initialSkillLevel,
      initialKitchenTools: widget.initialKitchenTools,
      mode: widget.mode, 
    );
    
    // Listen for auth state changes
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      // Refresh user preferences when auth state changes
      if (!_disposed) {
        _extractionController.refreshUserPreferences();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription.cancel();
    _extractionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_disposed) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth < 800;
                  final isPortrait = constraints.maxHeight > constraints.maxWidth;
                  final padding = isSmallScreen ? 20.0 : 40.0;

                  return Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(padding),
                    child: LayoutBuilder(
                      builder: (context, innerConstraints) {
                        final isSmallScreen = innerConstraints.maxWidth < 800;
                        final isPortrait = innerConstraints.maxHeight >
                            innerConstraints.maxWidth;

                        if (isSmallScreen && isPortrait) {
                          // Mobile portrait – make image taller and enable scrolling
                          final availableH = innerConstraints.maxHeight;
                          final imgH = availableH * 0.65; // 65% for image

                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: imgH,
                                  child: ImageSection(controller: _extractionController),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: OptionsSection(controller: _extractionController),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GenerateButton(
                                        controller: _extractionController,
                                        mode: 'candidates',
                                        label: 'Show Recipe Options',
                                        icon: Icons.tune,
                                        color: Color(0xFF1E40AF),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        } else if (isSmallScreen) {
                          // Small screen landscape - side by side
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: ImageSection(
                                    controller: _extractionController),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: OptionsSection(
                                            controller: _extractionController),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GenerateButton(
                                            controller: _extractionController,
                                            mode: 'candidates',
                                            label: 'Show Recipe Options',
                                            icon: Icons.tune,
                                            color: Color(0xFF1E40AF),
                                          ),
                                        ),
                                      ],
                                    ),

                                  ],
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Large screen - side by side
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: ImageSection(
                                    controller: _extractionController),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: OptionsSection(
                                            controller: _extractionController),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GenerateButton(
                                            controller: _extractionController,
                                            mode: 'candidates',
                                            label: 'Show Recipe Options',
                                            icon: Icons.tune,
                                            color: Color(0xFF1E40AF),
                                          ),
                                        ),
                                      ],
                                    ),

                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                      },
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
}

// =============================================================================
// EXTRACTION CONTROLLER
// =============================================================================

class ExtractionController extends ChangeNotifier {
  final fitnessHeightCtrl = TextEditingController();
  final fitnessWeightCtrl = TextEditingController();
  final fitnessAgeCtrl = TextEditingController();
  final TextEditingController otherNoteCtrl = TextEditingController();
  String fitnessGender = 'Male';
  String fitnessGoal = 'muscle_gain';

  void setFitnessGender(String v) {
    fitnessGender = v;
    notifyListeners();
  }
  void setFitnessGoal(String v) {
    fitnessGoal = v;
    notifyListeners();
  }
  final String imageUrl;
  final List<Map<String, dynamic>>? initialDetectedItems;
  final bool isRegenerating;
  final String? initialMealType;
  final String? initialDietaryGoal;
  final String? initialMealTime;
  final String? initialAmountPeople;
  final String? initialRestrictDiet;
  final String? initialPreferredRegion;
  final String? initialSkillLevel;
  final List<String>? initialKitchenTools;
  final String? mode;


  List<Map<String, dynamic>>? _detectedItems;
  bool _isLoading = true;
  String? _errorMessage;
  int _retryCount = 0;
  bool _disposed = false;

  // State variables for dropdowns
  String _selectedMeal   = 'general';
  String _selectedGoal   = 'normal';
  String _selectedTime   = 'fast';
  String _selectedPeople = '1';
  String _selectedDiet   = 'None';

  // Options for dropdowns
  final _mealTypes = ['general', 'breakfast', 'lunch', 'dinner'];
  final _dietaryGoals = ['normal', 'fat_loss', 'muscle_gain'];
  final _mealTimeOptions = ['fast', 'medium', 'long'];
  final _amountPeopleOptions = ['1', '2', '4', '6+'];
  final _restrictDietOptions = [
    'None',
    'Vegan',
    'Vegetarian',
    'Gluten-free',
    'Lactose-free'
  ];
  final _preferredRegions = ['Any', 'Asia', 'Europe', 'Mediterranean', 'America',
  'Middle Eastern', 'African', 'Latin American',];
  final _skillLevels = ['Beginner', 'Intermediate', 'Advanced'];
  final _kitchenTools = [
    'Stove Top', 'Oven', 'Microwave', 'Air Fryer', 'Sous Vide Machine',
    'Blender', 'Food Processor', 'BBQ', 'Slow Cooker', 'Pressure Cooker'
  ];

  // Label mappings for user-friendly display
  static const Map<String, String> _mealTypeLabels = {
    'general': 'General',
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
  };

  static const Map<String, String> _mealTimeLabels = {
    'fast': 'Quick (15-30 min)',
    'medium': 'Medium (30-60 min)',
    'long': 'Long (60+ min)',
  };

  static const Map<String, String> _fitnessGoalLabels = {
    'muscle_gain': 'Muscle Gain',
    'fat_loss': 'Fat Loss',
    'healthy_eating': 'Healthy Eating',
  };

  // State for extra fields
  String _selectedRegion = 'Any';
  String _selectedSkill  = 'Beginner';
  Set<String> _selectedKitchenTools = {};

  ExtractionController({
    required this.imageUrl,
    this.initialDetectedItems,
    this.isRegenerating = false,
    this.initialMealType,
    this.initialDietaryGoal,
    this.initialMealTime,
    this.initialAmountPeople,
    this.initialRestrictDiet,
    this.initialPreferredRegion,
    this.initialSkillLevel,
    this.initialKitchenTools,
    this.mode,
  }) {
    _initializeState();
  }

  void _initializeState() async {
    final prefs = await _loadUserPreferences();

    // Initialize selected options
    _selectedMeal = (initialMealType != null && _mealTypes.contains(initialMealType))
        ? initialMealType!
        : (prefs['meal_type'] ?? _mealTypes.first);

    _selectedGoal = (initialDietaryGoal != null && _dietaryGoals.contains(initialDietaryGoal))
        ? initialDietaryGoal!
        : (prefs['dietary_goal'] ?? _dietaryGoals.first);

    _selectedTime = (initialMealTime != null && _mealTimeOptions.contains(initialMealTime))
        ? initialMealTime!
        : (prefs['meal_time'] ?? _mealTimeOptions.first);

    _selectedPeople = (initialAmountPeople != null && _amountPeopleOptions.contains(initialAmountPeople))
        ? initialAmountPeople!
        : (prefs['amount_people'] ?? _amountPeopleOptions.first);

    if (initialRestrictDiet != null &&
        initialRestrictDiet!.isNotEmpty &&
        _restrictDietOptions.contains(initialRestrictDiet)) {
      _selectedDiet = initialRestrictDiet!;
    } else {
      _selectedDiet = prefs['restrict_diet'] ?? 'None';
    }
    _selectedRegion = initialPreferredRegion ?? prefs['preferred_region'] ?? _preferredRegions.first;
    _selectedSkill = initialSkillLevel ?? prefs['skill_level'] ?? _skillLevels.first;
    
    if (initialKitchenTools != null) {
      _selectedKitchenTools = Set<String>.from(initialKitchenTools!);
    } else {
      final tools = (prefs['kitchen_tools'] as List?)?.cast<String>() ?? [];
      _selectedKitchenTools = tools.isNotEmpty ? tools.toSet() : {'Stove Top', 'Oven'};
    }

    // Fitness mode preferences
    fitnessHeightCtrl.text = (prefs['height_cm'] ?? '').toString();
    fitnessWeightCtrl.text = (prefs['weight_kg'] ?? '').toString();
    fitnessAgeCtrl.text = (prefs['age'] ?? '').toString();
    fitnessGender = prefs['gender'] ?? 'Male';
    fitnessGoal = prefs['fitness_goal'] ?? 'muscle_gain';

    if (!_disposed) {
      notifyListeners();
    }

    if (isRegenerating &&
        initialDetectedItems != null &&
        initialDetectedItems!.isNotEmpty) {
      _detectedItems = List<Map<String, dynamic>>.from(
          initialDetectedItems!.map((item) => Map<String, dynamic>.from(item)));
      _isLoading = false;
      if (!_disposed) notifyListeners();
    } else {
      _fetchDetectedItems();
    }
  }

  Future<Map<String, dynamic>> _loadUserPreferences() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return {};

    final data = await client
        .from('user_preferences')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    
    return data ?? {};
  }


  // Getters
  List<Map<String, dynamic>>? get detectedItems => _detectedItems;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedMeal => _selectedMeal;
  String get selectedGoal => _selectedGoal;
  String get selectedTime => _selectedTime;
  String get selectedPeople => _selectedPeople;
  String get selectedDiet => _selectedDiet;
  List<String> get mealTypes => _mealTypes;
  List<String> get dietaryGoals => _dietaryGoals;
  List<String> get mealTimeOptions => _mealTimeOptions;
  List<String> get amountPeopleOptions => _amountPeopleOptions;
  List<String> get restrictDietOptions => _restrictDietOptions;
  bool get hasDetectedItems =>
      _detectedItems != null && _detectedItems!.isNotEmpty;
  String get selectedRegion => _selectedRegion;
  String get selectedSkill => _selectedSkill;
  Set<String> get selectedKitchenTools => _selectedKitchenTools;

  List<String> get preferredRegions => _preferredRegions;
  List<String> get skillLevels => _skillLevels;
  List<String> get kitchenTools => _kitchenTools;
  
  // Setters
  void setSelectedMeal(String value) {
    if (_disposed) return;
    _selectedMeal = value;
    notifyListeners();
  }

  void setSelectedGoal(String value) {
    if (_disposed) return;
    _selectedGoal = value;
    notifyListeners();
  }

  void setSelectedTime(String value) {
    if (_disposed) return;
    _selectedTime = value;
    notifyListeners();
  }

  void setSelectedPeople(String value) {
    if (_disposed) return;
    _selectedPeople = value;
    notifyListeners();
  }

  void setSelectedDiet(String value) {
    if (_disposed) return;
    _selectedDiet = value;
    notifyListeners();
  }
  void setSelectedRegion(String value) {
    if (_disposed) return;
    _selectedRegion = value;
    notifyListeners();
  }
  void setSelectedSkill(String value) {
    if (_disposed) return;
    _selectedSkill = value;
    notifyListeners();
  }
  void toggleKitchenTool(String tool) {
    if (_disposed) return;
    if (_selectedKitchenTools.contains(tool)) {
      _selectedKitchenTools.remove(tool);
    } else {
      _selectedKitchenTools.add(tool);
    }
    notifyListeners();
  }

  void updateItemLabel(int index, String label, String? additionalInfo) {
    if (_disposed) return;
    if (_detectedItems != null && index < _detectedItems!.length) {
      _detectedItems![index]['item_label'] = label;
      _detectedItems![index]['additional_info'] = additionalInfo;
      notifyListeners();
    }
  }

  Future<void> _fetchDetectedItems() async {
    if (_disposed) return;

    _setLoading(true);
    _setErrorMessage(null);

    final supabaseInstance = Supabase.instance;
    final client = supabaseInstance.client;
    final session = client.auth.currentSession;
    final accessToken = session?.accessToken;
    final anonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtydm5rYnN4cmN3YXRtc3BlY2J3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUwMzk2MjEsImV4cCI6MjA2MDYxNTYyMX0.ZzkcN4D3rXOjVkoTyTCq3GK7ArHNnYY6AfFB2_HXtNE";

    final uri = Uri.parse(
      'https://krvnkbsxrcwatmspecbw.functions.supabase.co/generate_recipe',
    );

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${accessToken ?? anonKey}',
      };

      final resp = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode(<String, dynamic>{
              'image_url': imageUrl,
              'mode': 'extract_only',
              'meal_type': _selectedMeal,
              'dietary_goal': _selectedGoal,
              'meal_time': _selectedTime,
              'amount_people': _selectedPeople,
              'restrict_diet': _selectedDiet == 'None' ? '' : _selectedDiet,
              'preferred_region': _selectedRegion,
              'skill_level': _selectedSkill,
              'kitchen_tools': _selectedKitchenTools.toList(),
              'stage': 'candidates',  
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (_disposed) return;

      if (resp.statusCode != 200) {
        final parsed = parseErrorResponse(resp.statusCode, resp.body);
        final msg = parsed.userError
            ? parsed.message
            : 'Unexpected error occurred. Please try again.';
        _setErrorMessage(msg);
        _setLoading(false);
        return;
      }

      final data = jsonDecode(resp.body);
      final items = List<Map<String, dynamic>>.from(data['items'] ?? []);

      final filtered = items
          .where(
              (it) => it['bounding_box'] is Map || it['bounding_box'] == null)
          .toList();

      if (filtered.isEmpty && _retryCount < 1) {
        _retryCount++;
        debugPrint('No items detected—retrying extraction (#$_retryCount)');
        return _fetchDetectedItems();
      }

      _setDetectedItems(filtered);
      _setLoading(false);
    } catch (e) {
      if (_disposed) return;

      debugPrint('Error fetching items: $e');
      if (_retryCount < 1) {
        _retryCount++;
        debugPrint('Error fetching items, retrying (#$_retryCount): $e');
        return _fetchDetectedItems();
      }
      _setLoading(false);
      _setErrorMessage('Network error – please check your connection and try again.');
    }
  }

  void retryFetch() {
    if (_disposed) return;
    _retryCount = 0;
    _fetchDetectedItems();
  }

  void _setLoading(bool loading) {
    if (_disposed) return;
    _isLoading = loading;
    notifyListeners();
  }

  void _setErrorMessage(String? error) {
    if (_disposed) return;
    _errorMessage = error;
    notifyListeners();
  }

  void _setDetectedItems(List<Map<String, dynamic>> items) {
    if (_disposed) return;
    _detectedItems = items;
    notifyListeners();
  }

  Future<void> refreshUserPreferences() async {
    // Only refresh if user preferences are relevant for the current state
    // Don't reload if we have explicit initial values (like when regenerating)
    if (initialMealType != null || initialDietaryGoal != null) {
      return; // Skip refresh if this is a regeneration with specific values
    }
    
    final prefs = await _loadUserPreferences();
    
    // Update selections only if they haven't been explicitly set
    bool updated = false;
    
    final newMeal = prefs['meal_type'] ?? _mealTypes.first;
    if (_selectedMeal != newMeal && _mealTypes.contains(newMeal)) {
      _selectedMeal = newMeal;
      updated = true;
    }
    
    final newGoal = prefs['dietary_goal'] ?? _dietaryGoals.first;
    if (_selectedGoal != newGoal && _dietaryGoals.contains(newGoal)) {
      _selectedGoal = newGoal;
      updated = true;
    }
    
    final newTime = prefs['meal_time'] ?? _mealTimeOptions.first;
    if (_selectedTime != newTime && _mealTimeOptions.contains(newTime)) {
      _selectedTime = newTime;
      updated = true;
    }
    
    final newPeople = prefs['amount_people'] ?? _amountPeopleOptions.first;
    if (_selectedPeople != newPeople && _amountPeopleOptions.contains(newPeople)) {
      _selectedPeople = newPeople;
      updated = true;
    }
    
    final newDiet = prefs['restrict_diet'] ?? 'None';
    if (_selectedDiet != newDiet && _restrictDietOptions.contains(newDiet)) {
      _selectedDiet = newDiet;
      updated = true;
    }
    
    final newRegion = prefs['preferred_region'] ?? _preferredRegions.first;
    if (_selectedRegion != newRegion && _preferredRegions.contains(newRegion)) {
      _selectedRegion = newRegion;
      updated = true;
    }
    
    final newSkill = prefs['skill_level'] ?? _skillLevels.first;
    if (_selectedSkill != newSkill && _skillLevels.contains(newSkill)) {
      _selectedSkill = newSkill;
      updated = true;
    }
    
    final newTools = (prefs['kitchen_tools'] as List?)?.cast<String>().toSet() ?? <String>{};
    if (_selectedKitchenTools != newTools) {
      _selectedKitchenTools = newTools;
      updated = true;
    }
    
    if (updated) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    fitnessHeightCtrl.dispose();
    fitnessWeightCtrl.dispose();
    fitnessAgeCtrl.dispose();
    otherNoteCtrl.dispose();
    _disposed = true;
    super.dispose();
  }
}

// =============================================================================
// APP HEADER COMPONENT
// =============================================================================

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;
        final horizontalPadding = isSmallScreen ? 20.0 : 40.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Back button
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.arrow_back, color: Colors.grey.shade700, size: 20),
                  tooltip: 'Go back',
                ),
              ),
              const SizedBox(width: 16),
              // Clickable brand section
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const UploadImagePage()),
                      (route) => false,
                    );
                  },
                  child: BrandSection(isSmallScreen: isSmallScreen),
                ),
              ),
              const Spacer(),
              const AccountIconButton(),
            ],
          ),
        );
      },
    );
  }
}

class BrandSection extends StatelessWidget {
  final bool isSmallScreen;

  const BrandSection({super.key, required this.isSmallScreen});

  @override
  Widget build(BuildContext context) {
    // Hoverable brand logo/title
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const UploadImagePage()),
            (route) => false,
          );
        },
        child: Row(
          children: [
            Container(
              width: isSmallScreen ? 32 : 40,
              height: isSmallScreen ? 32 : 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
              ),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: isSmallScreen ? 32 : 40,
                height: isSmallScreen ? 32 : 40,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to default icon if custom icon fails to load
                  return Container(
                    padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E40AF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.restaurant,
                      color: Colors.white,
                      size: isSmallScreen ? 16 : 20,
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cookpilot',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                if (!isSmallScreen)
                  const Text(
                    'AI-Powered Recipe Generator',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationSection extends StatelessWidget {
  const NavigationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475569),
            ),
          ),
        ),
        const SizedBox(width: 16),
        const AccountIconButton(),
      ],
    );
  }
}

// =============================================================================
// IMAGE SECTION COMPONENT
// =============================================================================

class ImageSection extends StatelessWidget {
  final ExtractionController controller;

  const ImageSection({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 800;
            final isPortrait = constraints.maxHeight > constraints.maxWidth;
            final isMobilePortrait = isSmallScreen && isPortrait;

            if (isMobilePortrait) {
              // Mobile portrait - no padding, container fits image exactly
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: const ImageHeader(),
                    ),
                    controller.isLoading
                        ? const Expanded(child: _LoadingState())
                        : controller.errorMessage != null
                            ? Expanded(
                                child: _ErrorState(controller: controller))
                            : Expanded(child: _ImageDisplay(controller: controller)),
                  ],
                ),
              );
            } else {
              // Desktop and landscape - keep original layout with padding
              final padding = isSmallScreen ? 20.0 : 32.0;

              return Container(
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ImageHeader(),
                    SizedBox(height: isSmallScreen ? 16 : 32),
                    Expanded(
                      child: controller.isLoading
                          ? const _LoadingState()
                          : controller.errorMessage != null
                              ? _ErrorState(controller: controller)
                              : _ImageDisplay(controller: controller),
                    ),
                  ],
                ),
              );
            }
          },
        );
      },
    );
  }
}

class ImageHeader extends StatelessWidget {
  const ImageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 800;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review Detected Items',
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 24,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: isSmallScreen ? 4 : 8),
            Text(
              'Review and edit the detected ingredients before generating your recipe',
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Detecting ingredients...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final ExtractionController controller;

  const _ErrorState({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load items.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              controller.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E40AF).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: controller.retryFetch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageDisplay extends StatelessWidget {
  final ExtractionController controller;

  const _ImageDisplay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FutureBuilder<Size>(
          future: _getImageSize(controller.imageUrl),
          builder: (ctx, snap) {
            if (snap.hasError) {
              return Center(
                child: Text(
                  'Error loading image: ${snap.error}',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final imgSize = snap.data!;
            if (imgSize.width <= 0 || imgSize.height <= 0) {
              return const Center(
                child: Icon(Icons.broken_image,
                    size: 64, color: Color(0xFF64748B)),
              );
            }

            // Calculate scale so that both width and height fit within the
            // available space while maintaining aspect ratio. We only scale
            // down (never up) to avoid unnecessary upscaling.
            final containerWidth = constraints.maxWidth;
            final containerHeight = constraints.maxHeight;

            final scaleW = containerWidth / imgSize.width;
            final scaleH = containerHeight / imgSize.height;
            final scale = math.min(1.0, math.min(scaleW, scaleH));

            final displayWidth = imgSize.width * scale;
            final displayHeight = imgSize.height * scale;

            return SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: displayWidth,
                  height: displayHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        width: displayWidth,
                        height: displayHeight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            controller.imageUrl,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      if (controller.hasDetectedItems)
                        ..._buildEditableChips(
                          controller.detectedItems!,
                          displayWidth,
                          displayHeight,
                          scale,
                          controller,
                          context,
                        )
                      else if (controller.detectedItems != null &&
                          controller.detectedItems!.isEmpty)
                        const Center(
                          child: Text(
                            'No items detected. Please try again.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Size> _getImageSize(String url) async {
    final completer = Completer<Size>();
    final image = Image.network(url);
    final stream = image.image.resolve(const ImageConfiguration());
    late final ImageStreamListener l;
    l = ImageStreamListener((info, _) {
      completer.complete(Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      ));
      stream.removeListener(l); // Prevent memory leak
    }, onError: (err, _) {
      completer.completeError(err);
      stream.removeListener(l);
    });
    stream.addListener(l);
    return completer.future;
  }

  List<Widget> _buildEditableChips(
    List<Map<String, dynamic>> items,
    double displayWidth,
    double displayHeight,
    double scale,
    ExtractionController controller,
    BuildContext context,
  ) {
    final widgets = <Widget>[];
    final occupied = <Rect>[];
    const baseH = 32.0, extraH = 14.0, padV = 4.0;

    // Helper to clamp bounding-box coordinates into [0,1]
    double norm(num? v) => (v ?? 0).toDouble().clamp(0.0, 1.0);

    // Helper to measure text width precisely
    double textWidth(String txt, TextStyle style) {
      final tp = TextPainter(
        text: TextSpan(text: txt, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      return tp.width;
    }

    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final box = it['bounding_box'] as Map<String, dynamic>;
      // Sanity-checked & normalised coordinates
      final xMin = norm(box['x_min']);
      final yMin = norm(box['y_min']);
      final xMax = norm(box['x_max']);
      final yMax = norm(box['y_max']);

      // Skip obviously broken boxes
      if (xMax < xMin || yMax < yMin) continue;

      final label = it['item_label'] as String? ?? '';
      final add = it['additional_info'] as String? ?? '';
      final quantity = it['quantity'] as int? ?? 1;
      final hasAdd = add.isNotEmpty;

      final displayLabel = quantity > 1 ? '$quantity $label' : label;

      // Calculate the position of the detected object in the displayed image
      final objectLeft = xMin * displayWidth;
      final objectTop = yMin * displayHeight;
      final objectWidth = (xMax - xMin) * displayWidth;
      final objectHeight = (yMax - yMin) * displayHeight;

      // Calculate chip dimensions using real text metrics for accuracy
      const labelStyle = TextStyle(fontSize: 12);
      const addStyle = TextStyle(fontSize: 10);
      double w = textWidth(displayLabel, labelStyle);
      if (hasAdd) {
        w = math.max(w, textWidth(add, addStyle));
      }
      final chipW = (w + 24).clamp(60.0, displayWidth * 0.8);
      final chipH = baseH + (hasAdd ? extraH : 0) + padV * 2;

      // Try multiple candidate anchors: above, below, left, right of object
      const gap = 8.0;
      final candidates = <Offset>[
        // center of the bounding box
        Offset(objectLeft + objectWidth / 2 - chipW / 2,
            objectTop + objectHeight / 2 - chipH / 2),
        // above
        Offset(objectLeft + objectWidth / 2 - chipW / 2, objectTop - chipH - gap),
        // below
        Offset(objectLeft + objectWidth / 2 - chipW / 2, objectTop + objectHeight + gap),
        // left
        Offset(objectLeft - chipW - gap, objectTop + objectHeight / 2 - chipH / 2),
        // right
        Offset(objectLeft + objectWidth + gap, objectTop + objectHeight / 2 - chipH / 2),
      ];

      Rect? place;
      for (final cand in candidates) {
        final cx = cand.dx.clamp(0.0, displayWidth - chipW);
        final cy = cand.dy.clamp(0.0, displayHeight - chipH);
        final r = Rect.fromLTWH(cx, cy, chipW, chipH);
        if (!occupied.any((o) => o.overlaps(r))) {
          place = r;
          break;
        }
      }

      // Fallback: vertical scan downward from above-centre
      if (place == null) {
        double cx = (objectLeft + objectWidth / 2 - chipW / 2)
            .clamp(0.0, displayWidth - chipW);
        double cy = (objectTop - chipH - gap).clamp(0.0, displayHeight - chipH);
        Rect r = Rect.fromLTWH(cx, cy, chipW, chipH);
        int attempts = 0;
        while (occupied.any((o) => o.overlaps(r)) && attempts < 20) {
          cy = (cy + baseH * 0.5 + 4).clamp(0.0, displayHeight - chipH);
          r = Rect.fromLTWH(cx, cy, chipW, chipH);
          attempts++;
        }
        place = r;
      }

      final placeRect = place; // safe: place is always set by now
      occupied.add(placeRect);

      widgets.add(
        Positioned(
          left: placeRect.left,
          top: placeRect.top,
          child: GestureDetector(
            onTap: () => _showEditDialog(context, i, it, controller),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: padV),
              decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 3,
                      offset: const Offset(1, 1),
                    )
                  ]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  if (hasAdd)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        add,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withOpacity(0.8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  void _showEditDialog(BuildContext context, int index,
      Map<String, dynamic> item, ExtractionController controller) async {
    final labelCtrl = TextEditingController(text: item['item_label']);
    final addCtrl = TextEditingController(text: item['additional_info'] ?? '');
    bool showAdditional = addCtrl.text.isNotEmpty;

    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (c, setSt) => AlertDialog(
          title: const Text('Edit Label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                autofocus: true,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Item Label',
                  counterText: '',
                ),
              ),
              if (!showAdditional)
                TextButton.icon(
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add details'),
                  onPressed: () => setSt(() => showAdditional = true),
                ),
              if (showAdditional)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: TextField(
                    controller: addCtrl,
                    maxLength: 30,
                    decoration: const InputDecoration(
                        labelText: 'Additional Info (optional)',
                        counterText: ''),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newLabel = labelCtrl.text.trim();
                final newAdd = addCtrl.text.trim();
                if (newLabel.isNotEmpty) {
                  Navigator.pop(context, {
                    'label': newLabel,
                    'additional': newAdd.isEmpty ? null : newAdd,
                  });
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      controller.updateItemLabel(index, result['label']!, result['additional']);
    }
  }
}

// =============================================================================
// OPTIONS SECTION COMPONENT
// =============================================================================

class OptionsSection extends StatelessWidget {
  final ExtractionController controller;

  const OptionsSection({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 800;
            final padding = isSmallScreen ? 20.0 : 32.0;

            return Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const OptionsHeader(),
                    SizedBox(height: isSmallScreen ? 20 : 32),
                    OptionsGrid(controller: controller),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class OptionsHeader extends StatelessWidget {
  const OptionsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 800;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recipe Options',
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 24,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: isSmallScreen ? 4 : 8),
            Text(
              'Customize your recipe preferences and dietary requirements',
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        );
      },
    );
  }
}

class OptionsGrid extends StatelessWidget {
  final ExtractionController controller;

  const OptionsGrid({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 800;
        final mode = controller.mode;
        if (mode == 'fitness') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField('Height (cm)', controller.fitnessHeightCtrl, isSmallScreen),
              const SizedBox(height: 16),
              _buildTextField('Weight (kg)', controller.fitnessWeightCtrl, isSmallScreen),
              const SizedBox(height: 16),
              _buildTextField('Age', controller.fitnessAgeCtrl, isSmallScreen),
              const SizedBox(height: 16),
              _buildDropdownField(
                'Gender',
                controller.fitnessGender,
                ['Male', 'Female'],
                (v) => controller.setFitnessGender(v),
                isSmallScreen,
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                'Fitness Goal',
                controller.fitnessGoal,
                ['muscle_gain', 'fat_loss', 'healthy_eating'],
                (v) => controller.setFitnessGoal(v),
                isSmallScreen,
                labelMap: ExtractionController._fitnessGoalLabels,
              ),
              const SizedBox(height: 16),
              _AdvancedOptions(controller: controller, isSmallScreen: isSmallScreen),
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildOptionField(
                    'Meal Type',
                    controller.selectedMeal,
                    controller.mealTypes,
                    controller.setSelectedMeal,
                    isSmallScreen,
                    labelMap: ExtractionController._mealTypeLabels,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
              ],
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            Row(
              children: [
                Expanded(
                  child: _buildOptionField(
                    'Meal Time',
                    controller.selectedTime,
                    controller.mealTimeOptions,
                    controller.setSelectedTime,
                    isSmallScreen,
                    labelMap: ExtractionController._mealTimeLabels,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: _buildOptionField(
                    'Amount of People',
                    controller.selectedPeople,
                    controller.amountPeopleOptions,
                    controller.setSelectedPeople,
                    isSmallScreen,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            _buildOptionField(
              'Dietary Restrictions',
              controller.selectedDiet,
              controller.restrictDietOptions,
              controller.setSelectedDiet,
              isSmallScreen,
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            _AdvancedOptions(controller: controller, isSmallScreen: isSmallScreen),
          ],
        );
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, bool isSmallScreen) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      style: TextStyle(fontSize: isSmallScreen ? 13 : 15),
    );
  }

  Widget _buildDropdownField(
    String label, 
    String value, 
    List<String> options, 
    ValueChanged<String> onChanged, 
    bool isSmallScreen, {
    Map<String, String>? labelMap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: TextStyle(
            fontSize: isSmallScreen ? 13 : 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              items: options.map((e) => DropdownMenuItem(
                value: e,
                child: Text(
                  labelMap != null && labelMap.containsKey(e) ? labelMap[e]! : e,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              )).toList(),
              onChanged: (v) => onChanged(v!),
            ),
          ),
        ),
      ],
    );
  }
}

  Widget _buildOptionField(
    String label,
    String currentValue,
    List<String> options,
    void Function(String) onChanged,
    bool isSmallScreen, {
    Map<String, String>? labelMap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 13 : 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: currentValue,
              items: options
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          labelMap != null && labelMap.containsKey(e) ? labelMap[e]! : e,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (value) => onChanged(value!),
            ),
          ),
        ),
      ],
    );
  }


class _AdvancedOptions extends StatefulWidget {
  final ExtractionController controller;
  final bool isSmallScreen;
  const _AdvancedOptions({required this.controller, required this.isSmallScreen});

  @override
  State<_AdvancedOptions> createState() => _AdvancedOptionsState();
}

class _AdvancedOptionsState extends State<_AdvancedOptions> {
  bool _show = false;
  
  Widget _buildOptionField(
    String label,
    String currentValue,
    List<String> options,
    void Function(String) onChanged,
    bool isSmallScreen,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 13 : 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: currentValue,
              items: options
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          e,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (value) => onChanged(value!),
            ),
          ),
        ),
      ],
    );
  }
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isSmallScreen = widget.isSmallScreen;
    final tools = controller.kitchenTools;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _show = !_show),
          icon: Icon(_show ? Icons.expand_less : Icons.expand_more),
          label: Text(_show ? 'Hide More Options' : 'Show More Options'),
        ),
        if (_show) ...[
          Row(
            children: [
              Expanded(
                child: _buildOptionField(
                  'Preferred Region',
                  controller.selectedRegion,
                  controller.preferredRegions,
                  controller.setSelectedRegion,
                  isSmallScreen,
                ),
              ),
              SizedBox(width: isSmallScreen ? 12 : 16),
              Expanded(
                child: _buildOptionField(
                  'Skill Level',
                  controller.selectedSkill,
                  controller.skillLevels,
                  controller.setSelectedSkill,
                  isSmallScreen,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 16 : 20),
          Text(
            'Kitchen Tools',
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 8),
          LayoutBuilder(
            builder: (ctx, ct) {
              final itemWidth = (ct.maxWidth / 2) - (isSmallScreen ? 6 : 8);
              return Wrap(
                spacing: isSmallScreen ? 6 : 8,
                runSpacing: 0,
                children: tools.map((tool) => SizedBox(
                  width: itemWidth,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(tool,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 14,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    value: controller.selectedKitchenTools.contains(tool),
                    onChanged: (_) => setState(() => controller.toggleKitchenTool(tool)),
                  ),
                )).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller.otherNoteCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Additional Notes (optional)',
              hintText: 'e.g. no cilantro, extra spicy, avoid nuts...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: TextStyle(fontSize: isSmallScreen ? 13 : 15),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// GENERATE BUTTON COMPONENT
// =============================================================================

class GenerateButton extends StatelessWidget {
  final ExtractionController controller;
  final String mode;
  final String label;
  final IconData icon;
  final Color color;

  const GenerateButton({
    super.key,
    required this.controller,
    required this.mode,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 800;
            final buttonHeight = isSmallScreen ? 44.0 : 52.0;

            return Container(
              width: double.infinity,
              height: buttonHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF059669).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: controller.hasDetectedItems
                    ? () => _onGeneratePressed(context)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      size: isSmallScreen ? 18 : 20,
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 10),
                    Text(
                      controller.mode == 'fitness' ? 'Generate Recipe' : label,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onGeneratePressed(BuildContext context) {
    // fitness mode
    if (controller.mode == 'fitness') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GeneratingPage(
            imageUrl: controller.imageUrl,
            mealType: controller.mode == 'fitness' ? null : controller.selectedMeal,
            dietaryGoal: controller.mode == 'fitness' ? null : controller.selectedGoal,
            mode: 'fitness',
            fitnessData: {
              'height': controller.fitnessHeightCtrl.text,
              'weight': controller.fitnessWeightCtrl.text,
              'age': controller.fitnessAgeCtrl.text,
              'gender': controller.fitnessGender,
              'goal': controller.fitnessGoal,

            },
            preferredRegion: controller.selectedRegion,
            skillLevel: controller.selectedSkill,
            kitchenTools: controller.selectedKitchenTools.toList(),
            
            manualLabels: controller.detectedItems,
          ),
        ),
      );
      return;
    }
    if (!controller.hasDetectedItems) {
      return;
    }

    final labels = controller.detectedItems!
        .map((it) => {
              'item_label': it['item_label'],
              'additional_info': it['additional_info'],
              'bounding_box': it['bounding_box'],
              'quantity': it['quantity'],
            })
        .toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GeneratingPage(
          imageUrl: controller.imageUrl,
          mealType: controller.selectedMeal,
          dietaryGoal: controller.selectedGoal,
          mealTime: controller.selectedTime,
          amountPeople: controller.selectedPeople,
          restrictDiet: controller.selectedDiet == 'None'
              ? null
              : controller.selectedDiet,
          preferredRegion: controller.selectedRegion,
          skillLevel: controller.selectedSkill,
          kitchenTools: controller.selectedKitchenTools.toList(),
          otherNote: controller.otherNoteCtrl.text.trim(),
          manualLabels: labels,
          mode: mode, 
        ),
      ),
    );
  }
}
