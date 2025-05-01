import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

class RecipePage extends StatelessWidget {
  final String imageUrl;
  final List<String> labels;
  final String recipe;
  final List<Map<String, dynamic>> detectedItems;

  const RecipePage({
    Key? key,
    required this.imageUrl,
    required this.labels,
    required this.recipe,
    required this.detectedItems,
  }) : super(key: key);

  Future<Size> _getImageSize(String imageUrl) async {
    final image = Image.network(imageUrl);
    final completer = Completer<Size>();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recipe & Ingredients')),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: FutureBuilder<Size>(
              future: _getImageSize(imageUrl),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final imageSize = snapshot.data!;
                final aspectRatio = imageSize.width / imageSize.height;

                return AspectRatio(
                  aspectRatio: aspectRatio,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final imageWidth = constraints.maxWidth;
                      final imageHeight = constraints.maxHeight;

                      return OverflowBox(
                        alignment: Alignment.topLeft,
                        maxWidth: double.infinity,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Image.network(
                              imageUrl,
                              width: imageWidth,
                              height: imageHeight,
                              fit: BoxFit.contain,
                            ),
                            ..._generatePositionedChips(
                              detectedItems,
                              imageWidth,
                              imageHeight,
                              context,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: SingleChildScrollView(
                child: Text(
                  recipe,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _generatePositionedChips(
    List<Map<String, dynamic>> items,
    double imageWidth,
    double imageHeight,
    BuildContext context,
  ) {
    final List<Widget> chips = [];
    final List<Rect> occupiedAreas = [];

    for (var item in items) {
      final box = item['bounding_box'];
      final label = item['item_label'];

      double left = (box['x_min'] ?? 0.0) * imageWidth;
      double top = (box['y_min'] ?? 0.0) * imageHeight;
      double width = ((box['x_max'] ?? 0.0) - (box['x_min'] ?? 0.0)) * imageWidth;
      double height = ((box['y_max'] ?? 0.0) - (box['y_min'] ?? 0.0)) * imageHeight;

      // Estimate chip width based on label length
      double chipWidthEstimate = label.length * 8.0 + 32; // char * px + padding
      double chipHeight = 32;

      // Center chip horizontally and vertically in the box
      double chipLeft = left + width / 2 - chipWidthEstimate / 2;
      double chipTop = top + height / 2 - chipHeight / 2;

      // Resolve overlap by shifting downward
      Rect chipRect = Rect.fromLTWH(chipLeft, chipTop, chipWidthEstimate, chipHeight);
      while (occupiedAreas.any((r) => r.overlaps(chipRect))) {
        chipTop += chipHeight + 4;
        chipRect = Rect.fromLTWH(chipLeft, chipTop, chipWidthEstimate, chipHeight);
      }
      occupiedAreas.add(chipRect);

      chips.add(Positioned(
        left: chipLeft,
        top: chipTop,
        child: Chip(
          label: Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          labelStyle: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ));
    }

    return chips;
  }
}
