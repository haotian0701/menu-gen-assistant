import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'generating_page.dart';
import 'account_icon_button.dart';

class ExtractionPage extends StatefulWidget {
  final String imageUrl;
  final List<Map<String, dynamic>>? initialDetectedItems;
  final bool isRegenerating;
  final String? initialMealType;
  final String? initialDietaryGoal;
  final String? initialMealTime;
  final String? initialAmountPeople;
  final String? initialRestrictDiet;

  const ExtractionPage({
    Key? key,
    required this.imageUrl,
    this.initialDetectedItems,
    this.isRegenerating = false,
    this.initialMealType,
    this.initialDietaryGoal,
    this.initialMealTime,
    this.initialAmountPeople,
    this.initialRestrictDiet,
  }) : super(key: key);

  @override
  State<ExtractionPage> createState() => _ExtractionPageState();
}

class _ExtractionPageState extends State<ExtractionPage> {
  late ExtractionController _extractionController;
  bool _disposed = false;

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
    );
  }

  @override
  void dispose() {
    _disposed = true;
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
      backgroundColor: const Color(0xFFF8FAFC), // ← Add this line
      body: Column(
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
                        // Mobile portrait - stack vertically
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: ImageSection(
                                  controller: _extractionController),
                            ),
                            const SizedBox(height: 24),
                            Expanded(
                              flex: 2,
                              child: OptionsSection(
                                  controller: _extractionController),
                            ),
                            const SizedBox(height: 16),
                            GenerateButton(controller: _extractionController),
                          ],
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
                                    child: OptionsSection(
                                        controller: _extractionController),
                                  ),
                                  const SizedBox(height: 16),
                                  GenerateButton(
                                      controller: _extractionController),
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
                                    child: OptionsSection(
                                        controller: _extractionController),
                                  ),
                                  const SizedBox(height: 16),
                                  GenerateButton(
                                      controller: _extractionController),
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
    );
  }
}

// =============================================================================
// EXTRACTION CONTROLLER
// =============================================================================

class ExtractionController extends ChangeNotifier {
  final String imageUrl;
  final List<Map<String, dynamic>>? initialDetectedItems;
  final bool isRegenerating;
  final String? initialMealType;
  final String? initialDietaryGoal;
  final String? initialMealTime;
  final String? initialAmountPeople;
  final String? initialRestrictDiet;

  List<Map<String, dynamic>>? _detectedItems;
  bool _isLoading = true;
  String? _errorMessage;
  int _retryCount = 0;
  bool _disposed = false;

  // State variables for dropdowns
  late String _selectedMeal;
  late String _selectedGoal;
  late String _selectedTime;
  late String _selectedPeople;
  late String _selectedDiet;

  // Options for dropdowns
  final _mealTypes = ['breakfast', 'lunch', 'dinner'];
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

  ExtractionController({
    required this.imageUrl,
    this.initialDetectedItems,
    this.isRegenerating = false,
    this.initialMealType,
    this.initialDietaryGoal,
    this.initialMealTime,
    this.initialAmountPeople,
    this.initialRestrictDiet,
  }) {
    _initializeState();
  }

  void _initializeState() {
    // Initialize selected options
    _selectedMeal = initialMealType ?? _mealTypes.first;
    _selectedGoal = initialDietaryGoal ?? _dietaryGoals.first;
    _selectedTime = initialMealTime ?? _mealTimeOptions.first;
    _selectedPeople = initialAmountPeople ?? _amountPeopleOptions.first;

    if (initialRestrictDiet != null &&
        initialRestrictDiet!.isNotEmpty &&
        _restrictDietOptions.contains(initialRestrictDiet)) {
      _selectedDiet = initialRestrictDiet!;
    } else {
      _selectedDiet = 'None';
    }

    if (isRegenerating &&
        initialDetectedItems != null &&
        initialDetectedItems!.isNotEmpty) {
      _detectedItems = List<Map<String, dynamic>>.from(
          initialDetectedItems!.map((item) => Map<String, dynamic>.from(item)));
      _isLoading = false;
    } else {
      _fetchDetectedItems();
    }
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
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (_disposed) return;

      if (resp.statusCode != 200) {
        throw Exception('Status ${resp.statusCode}: ${resp.body}');
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
      _setErrorMessage('Error fetching items: $e');
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// =============================================================================
// APP HEADER COMPONENT
// =============================================================================

class AppHeader extends StatelessWidget {
  const AppHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;
        final horizontalPadding = isSmallScreen ? 20.0 : 40.0;

        return Container(
          width: double.infinity,
          padding:
              EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade200,
                width: 1,
              ),
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
                  icon: Icon(
                    Icons.arrow_back,
                    color: Colors.grey.shade700,
                    size: 20,
                  ),
                  tooltip: 'Go back',
                ),
              ),
              const SizedBox(width: 16),
              BrandSection(isSmallScreen: isSmallScreen),
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

  const BrandSection({
    Key? key,
    required this.isSmallScreen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
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
        ),
        SizedBox(width: isSmallScreen ? 8 : 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recipe.AI',
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
    );
  }
}

class NavigationSection extends StatelessWidget {
  const NavigationSection({Key? key}) : super(key: key);

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
    Key? key,
    required this.controller,
  }) : super(key: key);

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
                            : _ImageDisplay(controller: controller),
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
  const ImageHeader({Key? key}) : super(key: key);

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

            // Calculate scale to fit the image width exactly to the container width
            final containerWidth = constraints.maxWidth;
            final scale = containerWidth / imgSize.width;

            final displayWidth = imgSize.width * scale;
            final displayHeight = imgSize.height * scale;

            return SingleChildScrollView(
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
                          fit: BoxFit.cover,
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
            );
          },
        );
      },
    );
  }

  Future<Size> _getImageSize(String url) async {
    final completer = Completer<Size>();
    final image = Image.network(url);
    final listener = ImageStreamListener((info, _) {
      completer.complete(Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      ));
    }, onError: (err, _) {
      completer.completeError(err ?? 'Image load error');
    });
    image.image.resolve(const ImageConfiguration()).addListener(listener);
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

    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final box = it['bounding_box'] as Map<String, dynamic>;
      final xMin = (box['x_min'] as num?)?.toDouble() ?? 0.0;
      final yMin = (box['y_min'] as num?)?.toDouble() ?? 0.0;
      final xMax = (box['x_max'] as num?)?.toDouble() ?? 0.0;
      final yMax = (box['y_max'] as num?)?.toDouble() ?? 0.0;
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

      // Calculate chip dimensions
      final chipW =
          (displayLabel.length * 7.0 + (hasAdd ? add.length * 5.0 : 0) + 24.0)
              .clamp(60.0, displayWidth * 0.8);
      final chipH = baseH + (hasAdd ? extraH : 0) + padV * 2;

      // Position the chip above the detected object
      double cx = objectLeft +
          objectWidth / 2 -
          chipW / 2; // Center horizontally over the object
      double cy =
          objectTop - chipH - 8; // Position above the object with 8px gap

      // Ensure the chip stays within the container bounds
      cx = cx.clamp(0, displayWidth - chipW);
      cy = cy.clamp(0, displayHeight - chipH);

      // Check for overlaps and adjust if necessary
      Rect rect = Rect.fromLTWH(cx, cy, chipW, chipH * 1.1);
      int attempts = 0;
      while (occupied.any((r) => r.overlaps(rect)) && attempts < 10) {
        // If there's an overlap, try moving the chip down
        cy = (cy + baseH * 0.5 + 4).clamp(0, displayHeight - chipH);
        rect = Rect.fromLTWH(cx, cy, chipW, chipH * 1.1);
        attempts++;
      }
      occupied.add(rect);

      widgets.add(
        Positioned(
          left: cx,
          top: cy,
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
                decoration: const InputDecoration(labelText: 'Item Label'),
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
                    decoration: const InputDecoration(
                        labelText: 'Additional Info (optional)'),
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
    Key? key,
    required this.controller,
  }) : super(key: key);

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
  const OptionsHeader({Key? key}) : super(key: key);

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
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 800;

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
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: _buildOptionField(
                    'Dietary Goal',
                    controller.selectedGoal,
                    controller.dietaryGoals,
                    controller.setSelectedGoal,
                    isSmallScreen,
                  ),
                ),
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
          ],
        );
      },
    );
  }

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
}

// =============================================================================
// GENERATE BUTTON COMPONENT
// =============================================================================

class GenerateButton extends StatelessWidget {
  final ExtractionController controller;

  const GenerateButton({
    Key? key,
    required this.controller,
  }) : super(key: key);

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
                      'Generate Recipe',
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
          manualLabels: labels,
        ),
      ),
    );
  }
}
