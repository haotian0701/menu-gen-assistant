// lib/extraction_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'generating_page.dart';

class ExtractionPage extends StatefulWidget {
  final String imageUrl;
  final List<Map<String, dynamic>>? initialDetectedItems;
  final bool isRegenerating;

  // Fields for initial options (passed during regeneration or set to defaults)
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
    // Added for regeneration flow to pre-fill options
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
  List<Map<String, dynamic>>? detectedItems;
  bool isLoading = true;
  String? errorMessage;
  int _retryCount = 0;

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
  final _amountPeopleOptions = ['1', '2', '4', '6+']; // Added 6+ as an example
  final _restrictDietOptions = ['None', 'Vegan', 'Vegetarian', 'Gluten-free', 'Lactose-free'];


  @override
  void initState() {
    super.initState();

    // Initialize selected options
    _selectedMeal = widget.initialMealType ?? _mealTypes.first;
    _selectedGoal = widget.initialDietaryGoal ?? _dietaryGoals.first;
    _selectedTime = widget.initialMealTime ?? _mealTimeOptions.first;
    _selectedPeople = widget.initialAmountPeople ?? _amountPeopleOptions.first;
    _selectedDiet = widget.initialRestrictDiet ?? _restrictDietOptions.first;

    if (widget.isRegenerating && widget.initialDetectedItems != null && widget.initialDetectedItems!.isNotEmpty) {
      detectedItems = List<Map<String, dynamic>>.from(
        widget.initialDetectedItems!.map((item) => Map<String, dynamic>.from(item))
      );
      isLoading = false;
    } else {
      _fetchDetectedItems();
    }
  }

  Future<void> _fetchDetectedItems() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final supabase = Supabase.instance.client;
    final accessToken = supabase.auth.currentSession?.accessToken;
    if (accessToken == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auth error. Please log in again.')),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    final uri = Uri.parse(
      'https://krvnkbsxrcwatmspecbw.functions.supabase.co/generate_recipe',
    );

    try {
      // When fetching items, we use the *currently selected* options on this page,
      // or defaults if it's the first load from upload page.
      // The backend 'extract_only' mode might not use all these, but good to be consistent.
      final resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'image_url': widget.imageUrl,
              'meal_type': _selectedMeal,       // Use state variable
              'dietary_goal': _selectedGoal,    // Use state variable
              'mode': 'extract_only',
              'meal_time': _selectedTime,       // Use state variable
              'amount_people': _selectedPeople, // Use state variable
              'restrict_diet': _selectedDiet,   // Use state variable
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode != 200) {
        throw Exception('Status ${resp.statusCode}: ${resp.body}');
      }

      final data = jsonDecode(resp.body);
      final items = List<Map<String, dynamic>>.from(data['items'] ?? []);

      // Backend now returns items with quantity, pre-grouped.
      // Filter out items that might lack a bounding box if necessary, though backend should handle this.
      final filtered = items.where((it) => it['bounding_box'] is Map || it['bounding_box'] == null).toList();


      // If no items on the first pass, retry once more automatically
      if (filtered.isEmpty && _retryCount < 1) {
        _retryCount++;
        debugPrint('No items detected—retrying extraction (#$_retryCount)');
        // Ensure fetch uses current dropdown values if retrying
        return _fetchDetectedItems();
      }

      if(mounted) {
        setState(() {
          detectedItems = filtered;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching items: $e');
      if (_retryCount < 1) {
        _retryCount++;
        debugPrint('Error fetching items, retrying (#$_retryCount): $e');
        return _fetchDetectedItems();
      }
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error fetching items: $e';
        });
        // Optionally, show snackbar or allow manual retry via button
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error fetching items: $e')),
        // );
        // Navigator.of(context).pop(); // Don't pop, show error and retry button
      }
    }
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

  /// Draw all editable chips over the image.
  List<Widget> _buildEditableChips(
    List<Map<String, dynamic>> items,
    double containerW,
    double containerH,
    double renderedW,
    double renderedH,
    double offsetX,
    double offsetY,
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

      final left = offsetX + xMin * renderedW;
      final top = offsetY + yMin * renderedH;
      final wBox = (xMax - xMin) * renderedW;
      final hBox = (yMax - yMin) * renderedH;

      final chipW = (displayLabel.length * 7.0 + (hasAdd ? add.length * 5.0 : 0) + 24.0).clamp(60.0, containerW * 0.8); // Adjusted width calculation
      final chipH = baseH + (hasAdd ? extraH : 0) + padV * 2;

      double cx = left + wBox / 2 - chipW / 2;
      double cy = top + hBox / 2 - chipH / 2;
      cx = cx.clamp(0, containerW - chipW);
      cy = cy.clamp(0, containerH - chipH);

      Rect rect = Rect.fromLTWH(cx, cy, chipW, chipH * 1.1);
      int attempts = 0;
      while (occupied.any((r) => r.overlaps(rect)) && attempts < 10) {
        cy = (cy + baseH * 0.5 + 4).clamp(0, containerH - chipH);
        rect = Rect.fromLTWH(cx, cy, chipW, chipH * 1.1);
        attempts++;
      }
      occupied.add(rect);

      widgets.add(
        Positioned(
          left: cx,
          top: cy,
          child: GestureDetector(
            onTap: () async {
              // Show the same edit dialog you already have
              final item = items[i];
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
                        // Quantity is not editable here, it's a result of grouping
                        if (!showAdditional)
                          TextButton.icon( // Changed to TextButton for better UI
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Add details'),
                            onPressed: () => setSt(() => showAdditional = true),
                          ),
                        if (showAdditional)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: TextField(
                              controller: addCtrl,
                              decoration: const InputDecoration(labelText: 'Additional Info (optional)'),
                            ),
                          ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
                setState(() {
                  items[i]['item_label'] = result['label'];
                  items[i]['additional_info'] = result['additional'];
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: padV),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 3,
                    offset: const Offset(1, 1),
                  )
                ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayLabel, // Use displayLabel
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
                          color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
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

  void _onGeneratePressed() {
    if (detectedItems == null || detectedItems!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items to generate a recipe from.')),
      );
      return;
    }
    final labels = detectedItems!
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
          imageUrl: widget.imageUrl,
          // Pass the selected options from this page's state
          mealType: _selectedMeal,
          dietaryGoal: _selectedGoal,
          mealTime: _selectedTime,
          amountPeople: _selectedPeople,
          restrictDiet: _selectedDiet == 'None' ? '' : _selectedDiet, // Handle 'None' case
          manualLabels: labels,
        ),
      ),
    );
  }

  // Helper for dropdowns (can be defined here or imported if made common)
  Widget _buildDropdown(
    String currentValue,
    List<String> items,
    void Function(String?) onChanged, {
    String? hintText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: currentValue,
          hint: hintText != null ? Text(hintText) : null,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isRegenerating ? 'Adjust Items & Regenerate' : 'Review & Edit Items'),
        leading: widget.isRegenerating
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Recipe',
                onPressed: () {
                  // Check if there's a route to pop to.
                  // If ExtractionPage was pushed directly (e.g. from UploadPage then RecipePage then here),
                  // simple pop works.
                  // If it replaced the stack somehow, this might need more robust navigation.
                  // For now, assuming it was pushed onto RecipePage.
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }
                  // else {
                  //  Fallback if it can't pop (e.g., if it's the first page in a regeneration flow somehow)
                  //  Consider navigating to a default page or handling as an error.
                  //  For this use case, pop should generally be fine.
                  // }
                },
              )
            : null, // Shows default back button if pushed onto stack and not regenerating (e.g. from UploadPage)
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 48),
                        const SizedBox(height: 16),
                        Text('Failed to load items.', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(errorMessage!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          onPressed: () {
                            _retryCount = 0; // Reset retry count for manual retry
                            _fetchDetectedItems();
                          },
                        ),
                        TextButton(
                          child: const Text('Go Back'),
                          onPressed: () => Navigator.of(context).pop(),
                        )
                      ],
                    ),
                  ),
                )
              : Column( // Main content column
                  children: [
                    // Image and Chips section (Expanded)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final cw = constraints.maxWidth;
                          final ch = constraints.maxHeight;
                          return FutureBuilder<Size>(
                            future: _getImageSize(widget.imageUrl),
                            builder: (ctx, snap) {
                              if (snap.hasError) {
                                return Center(child: Text('Error loading image: ${snap.error}'));
                              }
                              if (!snap.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              final imgSize = snap.data!;
                              if (imgSize.width <= 0 || imgSize.height <= 0) {
                                return const Center(child: Icon(Icons.broken_image, size: 64));
                              }
                              final imgAR = imgSize.width / imgSize.height;
                              final contAR = cw / ch;
                              double rw, rh;
                              if (imgAR > contAR) {
                                rw = cw;
                                rh = imgSize.height * (cw / imgSize.width);
                              } else {
                                rh = ch;
                                rw = imgSize.width * (ch / imgSize.height);
                              }
                              final ox = (cw - rw) / 2;
                              final oy = (ch - rh) / 2;

                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: ox,
                                    top: oy,
                                    width: rw,
                                    height: rh,
                                    child: Image.network(
                                      widget.imageUrl,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  if (detectedItems != null && detectedItems!.isNotEmpty)
                                    ..._buildEditableChips(
                                      detectedItems!,
                                      cw,
                                      ch,
                                      rw,
                                      rh,
                                      ox,
                                      oy,
                                    )
                                  else if (detectedItems != null && detectedItems!.isEmpty && !isLoading)
                                    const Center(child: Text('No items detected. Edit or retry.')),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // Options Section (Not expanded, scrollable if needed)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SingleChildScrollView( // Added for smaller screens
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Recipe Options:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: Text('Meal Type:')),
                                Expanded(
                                  flex: 2,
                                  child: _buildDropdown(_selectedMeal, _mealTypes, (val) => setState(() => _selectedMeal = val!)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: Text('Dietary Goal:')),
                                Expanded(
                                  flex: 2,
                                  child: _buildDropdown(_selectedGoal, _dietaryGoals, (val) => setState(() => _selectedGoal = val!)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: Text('Meal Time:')),
                                Expanded(
                                  flex: 2,
                                  child: _buildDropdown(_selectedTime, _mealTimeOptions, (val) => setState(() => _selectedTime = val!)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: Text('Amount of People:')),
                                Expanded(
                                  flex: 2,
                                  child: _buildDropdown(_selectedPeople, _amountPeopleOptions, (val) => setState(() => _selectedPeople = val!)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: Text('Dietary Restrictions:')),
                                Expanded(
                                  flex: 2,
                                  child: _buildDropdown(_selectedDiet, _restrictDietOptions, (val) => setState(() => _selectedDiet = val!)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Generate Button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                        onPressed: (detectedItems == null || detectedItems!.isEmpty) ? null : _onGeneratePressed,
                        child: const Text('Generate Recipe'),
                      ),
                    ),
                  ],
                ),
    );
  }
}
