// lib/generating_page.dart

import 'dart:convert';
import 'dart:async';  
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'error_utils.dart';
import 'recipe_page.dart';
import 'animated_loading.dart';

int? parseInt(String? s) => int.tryParse(s ?? '');
double? parseDouble(String? s) => double.tryParse(s ?? '');
class GeneratingPage extends StatefulWidget {
  final String imageUrl;
  final String? mealType;
  final String? dietaryGoal;
  final String? mealTime;
  final String? amountPeople;
  final String? restrictDiet;
  final String? mode;
  final String? preferredRegion;
  final String? skillLevel;
  final String? otherNote;
  final List<String>? kitchenTools;
  final List<Map<String, dynamic>>? manualLabels;
  final Map<String, dynamic>? fitnessData;
  final Map<String, dynamic>? nutritionInfo;

  const GeneratingPage({
    super.key,
    required this.imageUrl,
    this.mealType,
    this.dietaryGoal,
    this.mealTime,
    this.amountPeople,
    this.manualLabels,
    this.restrictDiet,
    this.preferredRegion,
    this.skillLevel,
    this.kitchenTools,
    this.mode,
    this.fitnessData, 
    this.nutritionInfo,
    this.otherNote,
  });

  @override
  State<GeneratingPage> createState() => _GeneratingPageState();
}

class _GeneratingPageState extends State<GeneratingPage> {
  bool _loadingCandidates = true;   
  List<Map<String, dynamic>> _candidates = [];  
  String? _error;
  bool _generatingFinal = false;  
  bool _showCandidates = false;
  bool _loadingDefault = false;
  bool _isGeneratingRecipe = false; // Flag to prevent duplicate recipe generation
  double _progress = 0.0;
  Timer? _progressTimer;
  void _startFakeProgress() {
  _progressTimer?.cancel();
  setState(() => _progress = 0.0);
  _progressTimer = Timer.periodic(const Duration(milliseconds:100), (_) {
    setState(() {
      _progress = (_progress + 0.02).clamp(0.0, 0.9);
    });
  });
}

void _stopFakeProgress() {
  _progressTimer?.cancel();
  setState(() => _progress = 1.0);
}

@override
void dispose() {
  _progressTimer?.cancel();
  super.dispose();
}
                
  @override
  void initState() {
    super.initState();
    if (widget.mode == 'candidates') {
      _generateCandidates();
    } else if (widget.mode == 'final' || widget.mode == 'fitness') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _generateFinalRecipe('', '');
      });
    }
  }

  Future<void> _generateCandidates() async {
    _startFakeProgress();
    setState(() {               
     _loadingCandidates = true; 
     _showCandidates = true; 
    });
    final supabaseInstance = Supabase.instance; // Get the Supabase instance
    final client = supabaseInstance.client; // Get the Supabase client instance

    // Correctly access the user's token from the current session
    final session = client.auth.currentSession;
    final accessToken = session?.accessToken;
    final anonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtydm5rYnN4cmN3YXRtc3BlY2J3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUwMzk2MjEsImV4cCI6MjA2MDYxNTYyMX0.ZzkcN4D3rXOjVkoTyTCq3GK7ArHNnYY6AfFB2_HXtNE";

    // Ensure we have either an access token or the anon key for the Authorization header
    if (accessToken == null && anonKey.isEmpty) {
      print('Error: Neither access token nor anon key is available.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication keys not available.')),
        );
        Navigator.of(context).pop(); // Go back
      }
      return;
    }

    final uri = Uri.parse(
      'https://krvnkbsxrcwatmspecbw.functions.supabase.co/generate_recipe',
    );

    try {
      final body = <String, dynamic>{
        'image_url': widget.imageUrl,
        'meal_type': widget.mealType,
        'dietary_goal': widget.dietaryGoal,
        'mode': (widget.manualLabels != null && widget.manualLabels!.isNotEmpty)
            ? null
            : 'extract_first',
        'stage': 'candidates', 
      };
      

      if (widget.mealTime != null) body['meal_time'] = widget.mealTime;
      if (widget.amountPeople != null) {
        body['amount_people'] = widget.amountPeople;
      }
      if (widget.restrictDiet != null) {
        body['restrict_diet'] = widget.restrictDiet;
      }

      if (widget.manualLabels != null && widget.manualLabels!.isNotEmpty) {
        body['manual_labels'] = widget.manualLabels;
        if (body.containsKey('mode') && body['mode'] == 'extract_first') {
          body.remove('mode');
        }
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization':
            'Bearer ${accessToken ?? anonKey}', // Use accessToken or fallback to anonKey
      };

      final data = await handleJsonPost(
        future: http.post(uri, headers: headers, body: jsonEncode(body)),
        context: context,
      );
      if (data != null && mounted) {
      setState(() {
        _candidates = List<Map<String, dynamic>>.from(data['candidates'] as List);
      });
      }
    } catch (e) {
      // errors already handled via handleJsonPost snackbar; no further action
    } finally {
      _stopFakeProgress();
      if (mounted) setState(() => _loadingCandidates = false);
    }
  }


  Future<void> _generateFinalRecipe(String selectedTitle, [String? selectedImage]) async {
  // Prevent duplicate calls
  if (_isGeneratingRecipe) return;
  _isGeneratingRecipe = true;
  
  _startFakeProgress();
  setState(() { 
    _generatingFinal = true;
    _loadingCandidates = false;
    _progress = 0.05;
     });

  setState(() {
    _progress = 0.2;
  });
  final supabaseInstance = Supabase.instance;
  final client = supabaseInstance.client;
  final session = client.auth.currentSession;
  final accessToken = session?.accessToken;
  final anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtydm5rYnN4cmN3YXRtc3BlY2J3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUwMzk2MjEsImV4cCI6MjA2MDYxNTYyMX0.ZzkcN4D3rXOjVkoTyTCq3GK7ArHNnYY6AfFB2_HXtNE";

  final uri = Uri.parse(
    'https://krvnkbsxrcwatmspecbw.functions.supabase.co/generate_recipe',
  );
  setState(() {
    _progress = 0.35;
  });
  final body = <String, dynamic>{
    'image_url': widget.imageUrl,
  };

  if (widget.mode == 'fitness') {
    body['mode'] = 'fitness';
    
    // Use default values if not provided
    double height = 180.0; // Default height: 180cm
    double weight = 80.0;   // Default weight: 80kg
    int age = 30;           // Default age: 30 years
    String gender = 'Male'; // Default gender: Male
    String goal = 'muscle_gain'; // Default fitness goal
    
    List<String> assumedValues = [];
    
    if (widget.fitnessData != null) {
      body['fitness_data'] = widget.fitnessData;
      final fd = widget.fitnessData!;
      
      if (fd['height'] != null && fd['height'].toString().isNotEmpty) {
        height = parseDouble(fd['height'].toString()) ?? height;
      } else {
        assumedValues.add('height (180cm)');
      }
      
      if (fd['weight'] != null && fd['weight'].toString().isNotEmpty) {
        weight = parseDouble(fd['weight'].toString()) ?? weight;
      } else {
        assumedValues.add('weight (80kg)');
      }
      
      if (fd['age'] != null && fd['age'].toString().isNotEmpty) {
        age = parseInt(fd['age'].toString()) ?? age;
      } else {
        assumedValues.add('age (30 years)');
      }
      
      if (fd['gender'] != null && fd['gender'].toString().isNotEmpty) {
        gender = fd['gender'];
      }
      
      if (fd['goal'] != null && fd['goal'].toString().isNotEmpty) {
        goal = fd['goal'];
      }
    } else {
      // All values are assumed when fitnessData is null
      assumedValues.addAll(['height (180cm)', 'weight (80kg)', 'age (30 years)']);
    }
    
    // Always include these values (using defaults if not provided)
    body['height_cm'] = height;
    body['weight_kg'] = weight;
    body['age'] = age;
    body['gender'] = gender;
    body['fitness_goal'] = goal;
    
    // Add a note about assumed values for the LLM
    if (assumedValues.isNotEmpty) {
      body['assumed_values_note'] = 'Note: The following values were assumed as defaults: ${assumedValues.join(', ')}. Please mention in your response that these are assumed values.';
    }
    
    if (widget.manualLabels != null && widget.manualLabels!.isNotEmpty) {
      body['manual_labels'] = widget.manualLabels;
    }
  } else {
    body['meal_type'] = widget.mealType ?? '';
    body['dietary_goal'] = widget.dietaryGoal ?? '';
    body['selected_title'] = selectedTitle;
    if (widget.manualLabels != null && widget.manualLabels!.isNotEmpty) {
      body['manual_labels'] = widget.manualLabels;
    }
  }
  
  // Common parameters for both modes
  if (widget.mealTime != null) body['meal_time'] = widget.mealTime;
  if (widget.amountPeople != null) body['amount_people'] = widget.amountPeople;
  if (widget.restrictDiet != null) body['restrict_diet'] = widget.restrictDiet;
  if (selectedImage != null && selectedImage.isNotEmpty) {
    body['client_image_url'] = selectedImage;
  }
  if (widget.manualLabels != null && widget.manualLabels!.isNotEmpty) {
    body['manual_labels'] = widget.manualLabels;
  }

  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${accessToken ?? anonKey}',
  };

  try {
    final data = await handleJsonPost(
      future: http.post(uri, headers: headers, body: jsonEncode(body)),
      context: context,
    );
  setState(() {
  _progress = 0.8; 
  });
    if (data == null) return;

    final recipe = data['recipe'] as String;
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    final videoUrl = data['video_url'] as String?;
    final mainImageUrl = data['main_image_url'] as String?;
    final raw = data['nutrition_info'] as Map<String, dynamic>?;
    final nutritionInfo = <String,double>{
      'calories': raw?['calories']?.toDouble() ?? 0,
      'protein': raw?['protein']?.toDouble() ?? 0,
      'carbs':   raw?['carbs']?.toDouble()   ?? 0,
      'fat':     raw?['fat']?.toDouble()     ?? 0,
    };

    // Note: History is now handled by the backend Edge Function to avoid duplicates

    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RecipePage(
          imageUrl: widget.imageUrl,
          recipe: recipe,
          detectedItems: items,
          videoUrl: videoUrl,
          mealType: widget.mealType ?? '',
          dietaryGoal: widget.dietaryGoal ?? '',
          mealTime: widget.mealTime ?? '',
          amountPeople: widget.amountPeople ?? '',
          restrictDiet: widget.restrictDiet ?? '',
          mainImageUrl: mainImageUrl,
          isFitnessMode: widget.mode == 'fitness',
          nutritionInfo: nutritionInfo,
      ),
      ),
    );
    setState(() {
      _progress = 1.0; 
    });
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating recipe: $e')),
      );
    }
    } finally {
      _stopFakeProgress();
      if (mounted) setState(() { 
        _generatingFinal = false; 
        _isGeneratingRecipe = false; // Reset the flag
      });
  }
}





@override
Widget build(BuildContext context) {
  final bool isLoading = _loadingCandidates || _generatingFinal || _loadingDefault;

  return Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          Image.asset(
            'assets/images/app_icon.png',
            width: 24,
            height: 24,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.restaurant, size: 24);
            },
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Cookpilot',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),

      bottom: isLoading
        ? PreferredSize(
            preferredSize: const Size.fromHeight(4.0),
            child: LinearProgressIndicator(
              value: (_progress > 0 && _progress <= 1.0) ? _progress : null,
              minHeight: 4,
            ),
          )
        : null,
    ),

    body: isLoading
      ? const AnimatedLoadingWidget(type: LoadingType.cooking)
      : (_error != null
          ? Center(child: Text(_error!))
          : _buildContent()
        ),
  );
}

Widget _buildContent() {
  return Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        if (widget.mode == 'final')
          ElevatedButton.icon(
            icon: const Icon(Icons.flash_on),
            label: const Text('Generate Instantly'),
            onPressed: _loadingDefault ? null : () => _generateFinalRecipe('', ''),
          ),
        if (widget.mode == 'candidates') ...[
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Options'),
            onPressed: _loadingCandidates ? null : _generateCandidates,
          ),
          const SizedBox(height: 24),
          if (_showCandidates && _candidates.isNotEmpty)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth < 800;
                  if (isSmallScreen) {
                    return ListView.separated(
                      itemCount: _candidates.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, i) => _CandidateCard(
                        candidate: _candidates[i],
                        onSelect: () => _generateFinalRecipe(
                          _candidates[i]['title'] ?? '',
                          _candidates[i]['image_url'] ?? '',
                        ),
                        fullWidth: true,
                      ),
                    );
                  }
                  final perCardSpace = constraints.maxWidth / _candidates.length;
                  final cardWidth = perCardSpace * 0.7;
                  return Center(
                    child: SizedBox(
                      height: constraints.maxHeight * 0.7,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_candidates.length, (i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: SizedBox(
                              width: cardWidth,
                              child: _CandidateCard(
                                candidate: _candidates[i],
                                onSelect: () => _generateFinalRecipe(
                                  _candidates[i]['title'] ?? '',
                                  _candidates[i]['image_url'] ?? '',
                                ),
                                fullWidth: false,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ],
    ),
  );
}
}
// =============================================================================
// CANDIDATE CARD WIDGET
// =============================================================================
class _CandidateCard extends StatefulWidget {
  final Map<String, dynamic> candidate;
  final VoidCallback onSelect;
  final bool fullWidth;

  const _CandidateCard({
    Key? key,
    required this.candidate,
    required this.onSelect,
    required this.fullWidth,
  }) : super(key: key);

  @override
  State<_CandidateCard> createState() => _CandidateCardState();
}

class _CandidateCardState extends State<_CandidateCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    
    final title = widget.candidate['title'] ?? 'No title';
    final desc = widget.candidate['description'] ?? '';
    final imgUrl = widget.candidate['image_url'] ?? '';

    final cardColor = _hover ? Colors.grey.shade200 : Colors.grey.shade50;
    final elevation = _hover ? 6.0 : 2.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedScale(
          scale: _hover ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Card(
            elevation: elevation,
            color: cardColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: imgUrl.isNotEmpty
                      ? Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                              'assets/images/recipe_placeholder.png',
                              fit: BoxFit.cover),
                        )
                      : Image.asset('assets/images/recipe_placeholder.png',
                          fit: BoxFit.cover),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        desc,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
