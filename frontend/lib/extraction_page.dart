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

  const ExtractionPage({
    Key? key,
    required this.imageUrl,
    required this.mealType,
    required this.dietaryGoal,
    required this.mealTime,
    required this.amountPeople,
  }) : super(key: key);

  @override
  State<ExtractionPage> createState() => _ExtractionPageState();
}

class _ExtractionPageState extends State<ExtractionPage> {
  List<Map<String, dynamic>>? detectedItems;
  bool isLoading = true;

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
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode != 200) {
        throw Exception('Status ${resp.statusCode}: ${resp.body}');
      }

      final data = jsonDecode(resp.body);
      final items = List<Map<String, dynamic>>.from(data['items'] ?? []);

      // drop only null
      final filtered = items.where((it) => it['bounding_box'] is Map).toList();

      // If no boxes on the first pass, retry once more automatically
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
      // On any error, auto-retry once
      if (_retryCount < 1) {
        _retryCount++;
        debugPrint('Error fetching items, retrying (#$_retryCount): $e');
        return _fetchDetectedItems();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching items: $e')),
        );
        Navigator.of(context).pop();
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
      final hasAdd = add.isNotEmpty;

      final left = offsetX + xMin * renderedW;
      final top = offsetY + yMin * renderedH;
      final wBox = (xMax - xMin) * renderedW;
      final hBox = (yMax - yMin) * renderedH;

      final chipW = label.length * 8.0 + 40.0;
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
                        if (!showAdditional)
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            tooltip: 'Add details (e.g., amount)',
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
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
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
          // If done loading but zero items: show a retry button
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
