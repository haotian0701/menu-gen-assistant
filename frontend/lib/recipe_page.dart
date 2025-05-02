import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart'; // Import flutter_html
import 'package:share_plus/share_plus.dart';

// Helper function to strip HTML tags for sharing plain text
String _stripHtml(String htmlString) {
  // This is a basic regex, might not cover all edge cases but handles common tags.
  final htmlRegex = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
  // Also remove potential markdown fences before stripping tags for sharing
  final cleanedString = htmlString.replaceAll('```html', '').replaceAll('```', '');
  return cleanedString.replaceAll(htmlRegex, '').replaceAll('&nbsp;', ' ').trim();
}

class RecipePage extends StatelessWidget {
  final String imageUrl;
  final String recipe; // This will now contain HTML
  final List<Map<String, dynamic>> detectedItems;

  const RecipePage({
    Key? key,
    required this.imageUrl,
    required this.recipe, // Keep receiving the recipe string (now HTML)
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
    // Clean the recipe string before using it
    final cleanedRecipe = recipe
        .replaceAll('```html', '') // Remove leading markdown fence
        .replaceAll('```', '')     // Remove trailing markdown fence
        .trim();                  // Remove any leading/trailing whitespace

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
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 1.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Html(
                        data: cleanedRecipe, // Use the cleaned recipe string
                        style: {
                          "h1": Style(
                            fontSize: FontSize(Theme.of(context).textTheme.headlineSmall!.fontSize!),
                            fontWeight: FontWeight.bold,
                            margin: Margins.only(bottom: 10),
                          ),
                          "h2": Style(
                            fontSize: FontSize(Theme.of(context).textTheme.titleLarge!.fontSize!),
                            fontWeight: FontWeight.w600,
                            margin: Margins.only(top: 15, bottom: 5),
                          ),
                          "li": Style(
                            fontSize: FontSize(Theme.of(context).textTheme.bodyMedium!.fontSize! + 1),
                            padding: HtmlPaddings.only(left: 5),
                          ),
                          "p": Style(
                            fontSize: FontSize(Theme.of(context).textTheme.bodyMedium!.fontSize!),
                            lineHeight: LineHeight.number(1.4),
                          ),
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Share recipe'),
                      onPressed: () {
                        String shareTitle = 'Generated Recipe';
                        // Use cleanedRecipe for title extraction as well
                        final titleMatch = RegExp(r"<h1.*?>(.*?)<\/h1>", caseSensitive: false).firstMatch(cleanedRecipe);
                        if (titleMatch != null) {
                          // Pass the matched group (inner content) to _stripHtml
                          shareTitle = _stripHtml(titleMatch.group(1) ?? '');
                        }
                        // Pass the original recipe to _stripHtml which handles cleaning fences now
                        final String shareContent = _stripHtml(recipe);
                        Share.share(shareContent, subject: shareTitle);
                      },
                    ),
                  ],
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
    const double baseChipHeight = 32.0;
    const double additionalInfoHeight = 14.0;
    const double verticalPadding = 4.0;

    for (var item in items) {
      final box = item['bounding_box'] as Map<String, dynamic>? ?? {};
      final label = item['item_label'] as String? ?? 'Unknown';
      final additionalInfo = item['additional_info'] as String?;
      final bool hasAdditionalInfo = additionalInfo != null && additionalInfo.isNotEmpty;

      double left = (box['x_min'] as double? ?? 0.0) * imageWidth;
      double top = (box['y_min'] as double? ?? 0.0) * imageHeight;
      double width = ((box['x_max'] as double? ?? 0.0) - (box['x_min'] as double? ?? 0.0)) * imageWidth;
      double height = ((box['y_max'] as double? ?? 0.0) - (box['y_min'] as double? ?? 0.0)) * imageHeight;

      width = width < 0 ? 0 : width;
      height = height < 0 ? 0 : height;

      double chipWidthEstimate = label.length * 8.0 + 40.0;
      double chipHeightEstimate = baseChipHeight + (hasAdditionalInfo ? additionalInfoHeight : 0.0) + (verticalPadding * 2);

      double chipLeft = left + width / 2 - chipWidthEstimate / 2;
      double chipTop = top + height / 2 - chipHeightEstimate / 2;

      chipLeft = chipLeft.clamp(0, imageWidth - chipWidthEstimate);
      chipTop = chipTop.clamp(0, imageHeight - chipHeightEstimate);

      Rect chipRect = Rect.fromLTWH(chipLeft, chipTop, chipWidthEstimate, chipHeightEstimate * 1.1);
      int attempts = 0;
      while (occupiedAreas.any((r) => r.overlaps(chipRect)) && attempts < 10) {
        chipTop += baseChipHeight * 0.5 + 4;
        chipTop = chipTop.clamp(0, imageHeight - chipHeightEstimate);
        chipRect = Rect.fromLTWH(chipLeft, chipTop, chipWidthEstimate, chipHeightEstimate * 1.1);
        if (chipTop >= imageHeight - chipHeightEstimate) break;
        attempts++;
      }
      occupiedAreas.add(chipRect);

      chips.add(Positioned(
        left: chipLeft,
        top: chipTop,
        child: Container(
          width: chipWidthEstimate,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: verticalPadding),
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
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
              if (hasAdditionalInfo)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(
                    additionalInfo!,
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
      ));
    }

    return chips;
  }
}
