// extraction_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'generating_page.dart';

class ExtractionPage extends StatefulWidget {
  final String imageUrl;
  final String mealType;
  final String dietaryGoal;

  const ExtractionPage({
    Key? key,
    required this.imageUrl,
    required this.mealType,
    required this.dietaryGoal,
  }) : super(key: key);

  @override
  State<ExtractionPage> createState() => _ExtractionPageState();
}

class _ExtractionPageState extends State<ExtractionPage> {
  List<Map<String, dynamic>>? detectedItems;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetectedItems();
  }

  Future<void> _fetchDetectedItems() async {
    print("ExtractionPage: Starting _fetchDetectedItems..."); // Log start
    setState(() {
      isLoading = true; // Ensure loading is true at the start
    });
    final supabase = Supabase.instance.client;
    final accessToken = supabase.auth.currentSession?.accessToken;

    if (accessToken == null) {
      print("ExtractionPage: Error - Access token is null."); // Log error
      if (mounted) { // Check if widget is still in the tree
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Authentication error. Please log in again.')),
         );
         Navigator.of(context).pop();
      }
      return;
    }

    final uri = Uri.parse('https://krvnkbsxrcwatmspecbw.functions.supabase.co/generate_recipe');
    print("ExtractionPage: Calling Supabase function at $uri"); // Log URI

    try {
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'image_url': widget.imageUrl,
          'meal_type': widget.mealType,
          'dietary_goal': widget.dietaryGoal,
          'mode': 'extract_only',
        }),
      ).timeout(const Duration(seconds: 30)); // Add a timeout

      print("ExtractionPage: Received response status code: ${resp.statusCode}"); // Log status code
      // print("ExtractionPage: Response body: ${resp.body}"); // Optional: Log raw body (can be large)

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        print("ExtractionPage: Response JSON decoded successfully."); // Log decode success

        // Check if 'items' key exists and is a list
        if (data != null && data['items'] is List) {
            final items = List<Map<String, dynamic>>.from(data['items']);
            print("ExtractionPage: Items parsed: ${items.length} items found."); // Log item count

            if (mounted) { // Check if widget is still mounted before calling setState
              setState(() {
                detectedItems = items;
                isLoading = false;
                print("ExtractionPage: State updated, isLoading set to false."); // Log state update
              });
            }
        } else {
           print("ExtractionPage: Error - 'items' key missing or not a list in response."); // Log data structure error
           throw Exception("Invalid response format from server: 'items' key missing or not a list.");
        }

      } else {
        print("ExtractionPage: Error - Non-200 status code: ${resp.statusCode}. Body: ${resp.body}"); // Log non-200 error
        throw Exception('Detection failed with status ${resp.statusCode}: ${resp.body}');
      }
    } catch (e, stackTrace) { // Catch potential errors like timeout, format exceptions etc.
      print("ExtractionPage: Error fetching/processing items: $e"); // Log the caught error
      print("ExtractionPage: StackTrace: $stackTrace"); // Log stack trace
      if (mounted) { // Check if widget is still mounted
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error fetching items: $e')),
         );
         // Don't set isLoading to false here, just pop
         Navigator.of(context).pop();
      }
    }
  }

  Future<Size> _getImageSize(String url) async {
    final completer = Completer<Size>();
    final image = Image.network(url);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ));
      }),
    );
    return completer.future;
  }

  List<Widget> _buildEditableChips(
    List<Map<String, dynamic>> items,
    double containerWidth,
    double containerHeight,
    double renderedWidth,
    double renderedHeight,
    double offsetX,
    double offsetY,
  ) {
    final List<Widget> widgets = [];
    final List<Rect> occupied = [];
    const double baseChipHeight = 32.0; // Height of the main label part
    const double additionalInfoHeight = 14.0; // Estimated height for the additional line + padding
    const double verticalPadding = 4.0; // Padding inside the container

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final box = item['bounding_box'];
      final label = item['item_label'] as String;
      final additionalInfo = item['additional_info'] as String?;

      final left = offsetX + (box['x_min'] ?? 0.0) * renderedWidth;
      final top = offsetY + (box['y_min'] ?? 0.0) * renderedHeight;
      final width = ((box['x_max'] ?? 0.0) - (box['x_min'] ?? 0.0)) * renderedWidth;
      final height = ((box['y_max'] ?? 0.0) - (box['y_min'] ?? 0.0)) * renderedHeight;

      // Estimate width based on the main label only for now
      final estimatedChipWidth = label.length * 8.0 + 40.0;

      // Calculate the total estimated height of the widget (Container with Column)
      final bool hasAdditionalInfo = additionalInfo != null && additionalInfo.isNotEmpty;
      final double estimatedTotalHeight = baseChipHeight + (hasAdditionalInfo ? additionalInfoHeight : 0.0) + (verticalPadding * 2);

      // Adjust chipTop calculation to center the *entire* widget vertically
      double chipLeft = left + width / 2 - estimatedChipWidth / 2;
      double chipTop = top + height / 2 - estimatedTotalHeight / 2; // Center based on total height

      // Clamp position within bounds, considering the total estimated height
      chipLeft = chipLeft.clamp(0, containerWidth - estimatedChipWidth);
      chipTop = chipTop.clamp(0, containerHeight - estimatedTotalHeight); // Clamp using total height

      // Use estimated total height for overlap checking
      Rect checkRect = Rect.fromLTWH(chipLeft, chipTop, estimatedChipWidth, estimatedTotalHeight * 1.1); // Check slightly larger area

      int attempts = 0; // Safety break for overlap loop
      while (occupied.any((r) => r.overlaps(checkRect)) && attempts < 20) {
        chipTop += baseChipHeight * 0.5 + 4; // Move down
        chipTop = chipTop.clamp(0, containerHeight - estimatedTotalHeight); // Re-clamp
        checkRect = Rect.fromLTWH(chipLeft, chipTop, estimatedChipWidth, estimatedTotalHeight * 1.1);
        // Break if we hit the bottom edge after clamping
        if (chipTop >= containerHeight - estimatedTotalHeight) break;
        attempts++;
      }
      occupied.add(checkRect);

      widgets.add(Positioned(
        left: chipLeft,
        top: chipTop,
        child: GestureDetector(
          onTap: () async {
            final labelController = TextEditingController(text: label);
            final additionalController = TextEditingController(text: additionalInfo ?? '');
            bool showAdditionalField = additionalInfo != null && additionalInfo.isNotEmpty;

            final result = await showDialog<Map<String, String?>>(
              context: context,
              builder: (context) {
                return StatefulBuilder(
                  builder: (context, setDialogState) {
                    return AlertDialog(
                      title: const Text('Edit Label'),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: labelController,
                              autofocus: true,
                              decoration: const InputDecoration(labelText: 'Item Label'),
                            ),
                            if (!showAdditionalField)
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                tooltip: 'Add details (e.g., amount)',
                                onPressed: () {
                                  setDialogState(() {
                                    showAdditionalField = true;
                                  });
                                },
                              ),
                            if (showAdditionalField)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: TextField(
                                  controller: additionalController,
                                  decoration: const InputDecoration(labelText: 'Additional Info (optional)'),
                                ),
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
                            final newLabel = labelController.text.trim();
                            final newAdditional = additionalController.text.trim();
                            if (newLabel.isNotEmpty) {
                              Navigator.pop(context, {
                                'label': newLabel,
                                'additional': showAdditionalField && newAdditional.isNotEmpty ? newAdditional : null,
                              });
                            }
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    );
                  },
                );
              },
            );

            if (result != null) {
              setState(() {
                detectedItems![i]['item_label'] = result['label'];
                detectedItems![i]['additional_info'] = result['additional'];
              });
            }
          },
          child: Container(
            // Use estimated width for the container to help with centering
            width: estimatedChipWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: verticalPadding), // Use defined padding
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12, // Keep font sizes consistent
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (hasAdditionalInfo) // Use the boolean flag
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      additionalInfo!, // Can use ! because hasAdditionalInfo is true
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ));
    }

    return widgets;
  }

  void _onGeneratePressed() {
    if (detectedItems == null) return;

    final labelsToSend = detectedItems!.map((item) {
      // Ensure all necessary data is included
      return {
        'item_label': item['item_label'],
        'additional_info': item['additional_info'],
        'bounding_box': item['bounding_box'], // Add bounding_box back
      };
    }).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GeneratingPage(
          imageUrl: widget.imageUrl,
          mealType: widget.mealType,
          dietaryGoal: widget.dietaryGoal,
          manualLabels: labelsToSend, // This now includes bounding_box
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review & Edit Items')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final containerWidth = constraints.maxWidth;
                      final containerHeight = constraints.maxHeight;

                      return FutureBuilder<Size>(
                        future: _getImageSize(widget.imageUrl),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text('Error loading image size: ${snapshot.error}'));
                          }

                          final imgSize = snapshot.data!;
                          if (imgSize.width == 0 || imgSize.height == 0) {
                            return const Center(child: Text('Error: Invalid image dimensions'));
                          }

                          final double imgAspectRatio = imgSize.width / imgSize.height;
                          final double containerAspectRatio = containerWidth / containerHeight;
                          double scaleFactor;
                          double renderedWidth;
                          double renderedHeight;

                          if (imgAspectRatio > containerAspectRatio) {
                            scaleFactor = containerWidth / imgSize.width;
                            renderedWidth = containerWidth;
                            renderedHeight = imgSize.height * scaleFactor;
                          } else {
                            scaleFactor = containerHeight / imgSize.height;
                            renderedHeight = containerHeight;
                            renderedWidth = imgSize.width * scaleFactor;
                          }

                          final double offsetX = (containerWidth - renderedWidth) / 2;
                          final double offsetY = (containerHeight - renderedHeight) / 2;

                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: containerWidth,
                              height: containerHeight,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: offsetX,
                                    top: offsetY,
                                    width: renderedWidth,
                                    height: renderedHeight,
                                    child: Image.network(
                                      widget.imageUrl,
                                      fit: BoxFit.contain,
                                      width: renderedWidth,
                                      height: renderedHeight,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Center(child: Icon(Icons.error, color: Colors.red)),
                                    ),
                                  ),
                                  if (detectedItems != null)
                                    ..._buildEditableChips(
                                      detectedItems!,
                                      containerWidth,
                                      containerHeight,
                                      renderedWidth,
                                      renderedHeight,
                                      offsetX,
                                      offsetY,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: _onGeneratePressed,
                    child: const Text('Generate Recipe'),
                  ),
                )
              ],
            ),
    );
  }
}
