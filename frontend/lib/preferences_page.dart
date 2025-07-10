import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'animated_loading.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  // Backend values - these are saved to database
  final _mealTypes = ['general', 'breakfast', 'lunch', 'dinner'];
  final _dietaryGoals = ['normal', 'fat_loss', 'muscle_gain'];
  final _mealTimeOptions = ['fast', 'medium', 'long'];
  final _amountPeopleOptions = ['1', '2', '4', '6+'];
  final _restrictDietOptions = ['None', 'Vegan', 'Vegetarian', 'Gluten-free', 'Lactose-free'];
  final _preferredRegions = ['Any', 'Asia', 'Europe', 'Mediterranean', 'America', 'Middle Eastern', 'African', 'Latin American'];
  final _skillLevels = ['Beginner', 'Intermediate', 'Advanced'];
  final _kitchenTools = [
    'Stove Top',
    'Oven',
    'Microwave',
    'Air Fryer',
    'Sous Vide Machine',
    'Blender',
    'Food Processor',
    'BBQ',
    'Slow Cooker',
    'Pressure Cooker'
  ];
  final heightCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final _genders = ['Male', 'Female'];
  final _fitnessGoals = ['muscle_gain', 'fat_loss', 'healthy_eating'];

  // Validation state
  String? _heightError;
  String? _weightError;
  String? _ageError;

  // Display label mappings
  static const Map<String, String> _mealTypeLabels = {
    'general': 'Any Meal',
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
  };

  static const Map<String, String> _dietaryGoalLabels = {
    'normal': 'Balanced Diet',
    'fat_loss': 'Fat Loss',
    'muscle_gain': 'Muscle Gain',
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

  // Helper methods for label conversion
  String _getDisplayLabel(String value, Map<String, String> labelMap) {
    return labelMap[value] ?? value;
  }

  String _getBackendValue(String displayLabel, Map<String, String> labelMap) {
    for (var entry in labelMap.entries) {
      if (entry.value == displayLabel) {
        return entry.key;
      }
    }
    return displayLabel;
  }

  List<String> _getDisplayLabels(List<String> values, Map<String, String> labelMap) {
    return values.map((value) => _getDisplayLabel(value, labelMap)).toList();
  }

  // Validation methods
  String? _validateHeight(String value) {
    if (value.trim().isEmpty) return null; // Optional field
    final height = int.tryParse(value.trim());
    if (height == null) return 'Please enter a valid number';
    if (height < 50 || height > 250) return 'Height must be between 50-250 cm';
    return null;
  }

  String? _validateWeight(String value) {
    if (value.trim().isEmpty) return null; // Optional field
    final weight = int.tryParse(value.trim());
    if (weight == null) return 'Please enter a valid number';
    if (weight < 20 || weight > 300) return 'Weight must be between 20-300 kg';
    return null;
  }

  String? _validateAge(String value) {
    if (value.trim().isEmpty) return null; // Optional field
    final age = int.tryParse(value.trim());
    if (age == null) return 'Please enter a valid number';
    if (age < 13 || age > 120) return 'Age must be between 13-120 years';
    return null;
  }

  void _validateFields() {
    setState(() {
      _heightError = _validateHeight(heightCtrl.text);
      _weightError = _validateWeight(weightCtrl.text);
      _ageError = _validateAge(ageCtrl.text);
    });
  }

  // Current selections
  late String _selectedMeal;
  late String _selectedGoal;
  late String _selectedTime;
  late String _selectedPeople;
  late String _selectedDiet;
  late String _selectedRegion;
  late String _selectedSkill;
  late Set<String> _selectedTools;
  late String _selectedGender;
  late String _selectedFitnessGoal;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    // Defaults
    _selectedMeal = 'general';
    _selectedGoal = 'normal';
    _selectedTime = 'fast';
    _selectedPeople = '1';
    _selectedDiet = 'None';
    _selectedRegion = 'Any';
    _selectedSkill = 'Beginner';
    _selectedTools = {'Stove Top', 'Oven'};
    heightCtrl.text         = '';
    weightCtrl.text         = '';
    ageCtrl.text            = '';
    _selectedGender         = _genders.first; 
    _selectedFitnessGoal    = _fitnessGoals.first;

    if (user != null) {
      final data = await client
          .from('user_preferences')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (data != null && data.isNotEmpty) {
        setState(() {
          _selectedMeal = data['meal_type'] ?? _selectedMeal;
          _selectedGoal = data['dietary_goal'] ?? _selectedGoal;
          _selectedTime = data['meal_time'] ?? _selectedTime;
          _selectedPeople = data['amount_people'] ?? _selectedPeople;
          _selectedDiet = data['restrict_diet'] ?? _selectedDiet;
          _selectedRegion = data['preferred_region'] ?? _selectedRegion;
          _selectedSkill = data['skill_level'] ?? _selectedSkill;
          final tools = (data['kitchen_tools'] as List?)?.cast<String>() ?? [];
          _selectedTools = tools.toSet();
          heightCtrl.text      = (data['height_cm']    ?? '').toString();
          weightCtrl.text      = (data['weight_kg']    ?? '').toString();
          ageCtrl.text         = (data['age']          ?? '').toString();
          _selectedGender      = data['gender']        ?? _selectedGender;
          _selectedFitnessGoal = data['fitness_goal']  ?? _selectedFitnessGoal;
        });
      }
    }

    setState(() => _loading = false);
  }

  Future<void> _savePreferences() async {
    // Validate all fields before saving
    _validateFields();
    
    // Check if there are any validation errors
    if (_heightError != null || _weightError != null || _ageError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the validation errors before saving'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final payload = {
      'user_id': user.id,
      'meal_type': _selectedMeal,
      'dietary_goal': _selectedGoal,
      'meal_time': _selectedTime,
      'amount_people': _selectedPeople,
      'restrict_diet': _selectedDiet,
      'preferred_region': _selectedRegion,
      'skill_level': _selectedSkill,
      'kitchen_tools': _selectedTools.toList(),
      'height_cm'      : int.tryParse(heightCtrl.text.trim()),
      'weight_kg'      : int.tryParse(weightCtrl.text.trim()),
      'age'            : int.tryParse(ageCtrl.text.trim()),
      'gender'         : _selectedGender,
      'fitness_goal'   : _selectedFitnessGoal,
    };

    try {
      await client.from('user_preferences').upsert(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  void dispose() {
    heightCtrl.dispose();
    weightCtrl.dispose();
    ageCtrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Default Preferences')),
      body: _loading
          ? const AnimatedLoadingWidget(type: LoadingType.loading)
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'These preferences are automatically used for Quick Mode and pre-fill the options in Advanced Mode and Fitness Mode',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDropdown('Meal Type', _getDisplayLabel(_selectedMeal, _mealTypeLabels), _getDisplayLabels(_mealTypes, _mealTypeLabels),
                        (v) => setState(() => _selectedMeal = _getBackendValue(v, _mealTypeLabels))),
                    const SizedBox(height: 16),
                    _buildDropdown('Dietary Goal', _getDisplayLabel(_selectedGoal, _dietaryGoalLabels), _getDisplayLabels(_dietaryGoals, _dietaryGoalLabels),
                        (v) => setState(() => _selectedGoal = _getBackendValue(v, _dietaryGoalLabels))),
                    const SizedBox(height: 16),
                    _buildDropdown('Meal Time', _getDisplayLabel(_selectedTime, _mealTimeLabels), _getDisplayLabels(_mealTimeOptions, _mealTimeLabels),
                        (v) => setState(() => _selectedTime = _getBackendValue(v, _mealTimeLabels))),
                    const SizedBox(height: 16),
                    _buildDropdown('Amount of People', _selectedPeople, _amountPeopleOptions,
                        (v) => setState(() => _selectedPeople = v)),
                    const SizedBox(height: 16),
                    _buildDropdown('Dietary Restrictions', _selectedDiet, _restrictDietOptions,
                        (v) => setState(() => _selectedDiet = v)),

                    const SizedBox(height: 24),
                    const Text('Fitness Profile',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: heightCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Height (cm)',
                        errorText: _heightError,
                        hintText: '50-250 cm',
                      ),
                      onChanged: (_) {
                        setState(() {
                          _heightError = _validateHeight(heightCtrl.text);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: weightCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Weight (kg)',
                        errorText: _weightError,
                        hintText: '20-300 kg',
                      ),
                      onChanged: (_) {
                        setState(() {
                          _weightError = _validateWeight(weightCtrl.text);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ageCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Age',
                        errorText: _ageError,
                        hintText: '13-120 years',
                      ),
                      onChanged: (_) {
                        setState(() {
                          _ageError = _validateAge(ageCtrl.text);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown('Gender', _selectedGender, _genders,
                        (v) => setState(() => _selectedGender = v)),
                    const SizedBox(height: 12),
                    _buildDropdown('Fitness Goal', _getDisplayLabel(_selectedFitnessGoal, _fitnessGoalLabels), _getDisplayLabels(_fitnessGoals, _fitnessGoalLabels),
                        (v) => setState(() => _selectedFitnessGoal = _getBackendValue(v, _fitnessGoalLabels))),
                    const Divider(height: 32),
                    const SizedBox(height: 24),
                    _buildDropdown('Preferred Region', _selectedRegion, _preferredRegions,
                        (v) => setState(() => _selectedRegion = v)),
                    const SizedBox(height: 16),
                    _buildDropdown('Skill Level', _selectedSkill, _skillLevels,
                        (v) => setState(() => _selectedSkill = v)),
                    const SizedBox(height: 24),
                    const Text('Kitchen Tools', style: TextStyle(fontWeight: FontWeight.w600)),
                    ..._kitchenTools.map((tool) => SwitchListTile(
                          title: Text(tool),
                          value: _selectedTools.contains(tool),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onChanged: (_) {
                            setState(() {
                              if (_selectedTools.contains(tool)) {
                                _selectedTools.remove(tool);
                              } else {
                                _selectedTools.add(tool);
                              }
                            });
                          },
                        )),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Save Options'),
                        onPressed: _savePreferences,
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDropdown(String label, String current, List<String> options,
      void Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: current,
              isExpanded: true,
              items: options
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => onChanged(v!),
            ),
          ),
        ),
      ],
    );
  }
} 