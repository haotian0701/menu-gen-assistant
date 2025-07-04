import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
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

  // Current selections
  late String _selectedMeal;
  late String _selectedGoal;
  late String _selectedTime;
  late String _selectedPeople;
  late String _selectedDiet;
  late String _selectedRegion;
  late String _selectedSkill;
  late Set<String> _selectedTools;

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
        });
      }
    }

    setState(() => _loading = false);
  }

  Future<void> _savePreferences() async {
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
    };

    await client.from('user_preferences').upsert(payload);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Default Preferences')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
                        'These preferences are automatically used for Quick Mode and pre-fill the options in Advanced Mode.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDropdown('Meal Type', _selectedMeal, _mealTypes,
                        (v) => setState(() => _selectedMeal = v)),
                    const SizedBox(height: 16),
                    _buildDropdown('Dietary Goal', _selectedGoal, _dietaryGoals,
                        (v) => setState(() => _selectedGoal = v)),
                    const SizedBox(height: 16),
                    _buildDropdown('Meal Time', _selectedTime, _mealTimeOptions,
                        (v) => setState(() => _selectedTime = v)),
                    const SizedBox(height: 16),
                    _buildDropdown('Amount of People', _selectedPeople, _amountPeopleOptions,
                        (v) => setState(() => _selectedPeople = v)),
                    const SizedBox(height: 16),
                    _buildDropdown('Dietary Restrictions', _selectedDiet, _restrictDietOptions,
                        (v) => setState(() => _selectedDiet = v)),
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