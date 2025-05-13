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
  final String mealType;
  final String dietaryGoal;
  final String mealTime;
  final String amountPeople;
  final String restrictDiet;

  const ExtractionPage({
    Key? key,
    required this.imageUrl,
    required this.mealType,
    required this.dietaryGoal,
    required this.mealTime,
    required this.amountPeople,
    required this.restrictDiet,
  }) : super(key: key);

  @override
  State<ExtractionPage> createState() => _ExtractionPageState();
}

class _ExtractionPageState extends State<ExtractionPage> {
  List<Map<String, dynamic>>? detectedItems;
  bool isLoading = true;
  String? errorMessage;

  /// Track how many times retried
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchDetectedItems();
  }

  Future<void> _fetchDetectedItems() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final supabase = Supabase.instance.client;
    final accessToken = supabase.auth.currentSession?.accessToken;
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auth error. Please log in again.')),
      );
      Navigator.of(context).pop();
      return;
    }

    final uri = Uri.parse(
      'https://krvnkbsxrcwatmspecbw.functions.supabase.co/generate_recipe',
    );

    try {
      final resp = await http
          .post(
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
              'meal_time': widget.mealTime,
              'amount_people': widget.amountPeople,
              'restrict_diet': widget.restrictDiet,
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
        return _fetchDetectedItems();
      }

      setState(() {
        detectedItems = filtered;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching items: $e');
      // On any error, auto-retry once
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
    final labels = detectedItems!
        .map((it) => {
              'item_label': it['item_label'],
              'additional_info': it['additional_info'],
              'bounding_box': it['bounding_box'],
              'quantity': it['quantity'], // Pass quantity
            })
        .toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GeneratingPage(
          imageUrl: widget.imageUrl,
          mealType: widget.mealType,
          dietaryGoal: widget.dietaryGoal,
          mealTime: widget.mealTime,
          amountPeople: widget.amountPeople,
          restrictDiet: widget.restrictDiet,

          manualLabels: labels,
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
          // If done loading but error: show error and retry
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
          // If done loading but zero items: show a message and retry button
          : (detectedItems != null && detectedItems!.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No items detected.'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          _retryCount = 0;
                          _fetchDetectedItems();
                        },
                        child: const Text('Retry Extraction'),
                      ),
                    ],
                  ),
                )
              // Otherwise show the normal review UI
              : Column(
                  children: [
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
                                  if (detectedItems != null)
                                    ..._buildEditableChips(
                                      detectedItems!,
                                      cw,
                                      ch,
                                      rw,
                                      rh,
                                      ox,
                                      oy,
                                    ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                        onPressed:
                            (detectedItems == null || detectedItems!.isEmpty) ? null : _onGeneratePressed,
                        child: const Text('Generate Recipe'),
                      ),
                    ),
                  ],
                ),
    );
  }
}
