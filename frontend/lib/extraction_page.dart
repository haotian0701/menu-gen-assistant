import 'dart:async';
import 'dart:convert';
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
    super.key,
    required this.imageUrl,
    required this.mealType,
    required this.dietaryGoal,
    required this.mealTime,
    required this.amountPeople,
  });

  @override
  State<ExtractionPage> createState() => _ExtractionPageState();
}

class _ExtractionPageState extends State<ExtractionPage> {
  List<Map<String, dynamic>> detectedItems = [];
  bool isLoading = true;
  Size? _cachedImageSize;

  @override
  void initState() {
    super.initState();
    _fetchDetectedItems();
  }

  Future<void> _fetchDetectedItems() async {
    setState(() => isLoading = true);
    final supabase = Supabase.instance.client;
    final accessToken = supabase.auth.currentSession?.accessToken;
    if (accessToken == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auth error, please log in again')),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    final uri = Uri.parse(
        'https://krvnkbsxrcwatmspecbw.functions.supabase.co/generate_recipe');
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
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data != null && data['items'] is List) {
          final items = List<Map<String, dynamic>>.from(data['items']);
          // 过滤掉没有 bounding_box 的条目
          items.removeWhere((it) => it['bounding_box'] == null);
          if (mounted) {
            setState(() {
              detectedItems = items;
              isLoading = false;
            });
          }
        } else {
          throw Exception(
              "Invalid response format: 'items' key missing or not a list.");
        }
      } else {
        throw Exception('Status ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching items: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<Size> _getImageSize(String url) async {
    if (_cachedImageSize != null) return _cachedImageSize!;
    final completer = Completer<Size>();
    final image = Image.network(url);
    final stream = image.image.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      completer.complete(size);
      stream.removeListener(listener);
    }, onError: (error, _) {
      completer.completeError(error ?? 'Unknown image load error');
      stream.removeListener(listener);
    });
    stream.addListener(listener);
    final result = await completer.future;
    _cachedImageSize = result;
    return result;
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
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;
                      return FutureBuilder<Size>(
                        future: _getImageSize(widget.imageUrl),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final imgSize = snap.data!;
                          final imgAspect = imgSize.width / imgSize.height;
                          final contAspect = w / h;
                          double rw, rh;
                          if (imgAspect > contAspect) {
                            rw = w;
                            rh = imgSize.height * (w / imgSize.width);
                          } else {
                            rh = h;
                            rw = imgSize.width * (h / imgSize.height);
                          }
                          final ox = (w - rw) / 2;
                          final oy = (h - rh) / 2;
                          return Padding(
                            padding: const EdgeInsets.all(8),
                            child: SizedBox(
                              width: w,
                              height: h,
                              child: Stack(
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
                                  ..._buildEditableChips(
                                    detectedItems,
                                    w,
                                    h,
                                    rw,
                                    rh,
                                    ox,
                                    oy,
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
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50)),
                    onPressed: detectedItems.isEmpty
                        ? null
                        : () {
                            final labels = detectedItems.map((item) => {
                                  'item_label': item['item_label'],
                                  'additional_info': item['additional_info'],
                                  'bounding_box': item['bounding_box'],
                                }).toList();
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
                          },
                    child: const Text('Generate Recipe'),
                  ),
                ),
              ],
            ),
    );
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
    final widgets = <Widget>[];
    final occupied = <Rect>[];
    const baseH = 32.0, addH = 14.0, padV = 4.0;

    for (final item in items) {
      final boxMap = item['bounding_box'];
      if (boxMap is! Map<String, dynamic>) continue;

      final xMin = (boxMap['x_min'] as num?)?.toDouble() ?? 0.0;
      final yMin = (boxMap['y_min'] as num?)?.toDouble() ?? 0.0;
      final xMax = (boxMap['x_max'] as num?)?.toDouble() ?? 0.0;
      final yMax = (boxMap['y_max'] as num?)?.toDouble() ?? 0.0;

      double left = offsetX + xMin * renderedWidth;
      double top = offsetY + yMin * renderedHeight;
      double wBox = (xMax - xMin) * renderedWidth;
      double hBox = (yMax - yMin) * renderedHeight;
      wBox = wBox < 0 ? 0 : wBox;
      hBox = hBox < 0 ? 0 : hBox;

      final label = item['item_label']?.toString() ?? '';
      final add = item['additional_info']?.toString() ?? '';
      final hasAdd = add.isNotEmpty;

      final chipW = label.length * 8.0 + 40.0;
      final chipH = baseH + (hasAdd ? addH : 0) + padV * 2;

      double chipLeft = left + wBox / 2 - chipW / 2;
      double chipTop = top + hBox / 2 - chipH / 2;
      chipLeft = chipLeft.clamp(0, containerWidth - chipW);
      chipTop = chipTop.clamp(0, containerHeight - chipH);

      Rect rect = Rect.fromLTWH(chipLeft, chipTop, chipW, chipH * 1.1);
      int attempts = 0;
      while (occupied.any((r) => r.overlaps(rect)) && attempts < 10) {
        chipTop = (chipTop + baseH * 0.5 + 4)
            .clamp(0, containerHeight - chipH);
        rect = Rect.fromLTWH(chipLeft, chipTop, chipW, chipH * 1.1);
        attempts++;
      }
      occupied.add(rect);

      widgets.add(Positioned(
        left: chipLeft,
        top: chipTop,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: padV),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer),
                  textAlign: TextAlign.center),
              if (hasAdd)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(add,
                      style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withOpacity(0.8)),
                      textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
      ));
    }
    return widgets;
  }
}
