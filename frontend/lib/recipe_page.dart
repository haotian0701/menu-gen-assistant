// lib/recipe_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// Import ExtractionPage
import 'extraction_page.dart';

/// Helper to strip HTML tags when sharing as plain text
String _stripHtml(String htmlString) {
  final htmlRegex = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
  final cleaned = htmlString
      .replaceAll('```html', '')
      .replaceAll('```', '')
      .replaceAll('&nbsp;', ' ');
  return cleaned.replaceAll(htmlRegex, '').trim();
}

/// Helper to extract the <h1> title from the HTML recipe
String _extractTitle(String html) {
  final match =
      RegExp(r"<h1[^>]*>(.*?)<\/h1>", caseSensitive: false).firstMatch(html);
  return match?.group(1)?.trim() ?? '';
}

class RecipePage extends StatefulWidget {
  final String imageUrl;
  final String recipe; // HTML content
  final List<Map<String, dynamic>> detectedItems;
  final String? videoUrl; // Optional YouTube link

  // Add these fields to store original parameters for regeneration
  final String mealType;
  final String dietaryGoal;
  final String mealTime;
  final String amountPeople;
  final String restrictDiet;

  const RecipePage({
    Key? key,
    required this.imageUrl,
    required this.recipe,
    required this.detectedItems,
    this.videoUrl,
    required this.mealType, // Added
    required this.dietaryGoal, // Added
    required this.mealTime, // Added
    required this.amountPeople, // Added
    required this.restrictDiet, // Added
  }) : super(key: key);

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage> {
  late final String _cleanedRecipe;
  late final String _pageTitle;

  @override
  void initState() {
    super.initState();

    // Initial cleaning: remove fences, &nbsp;
    String tempRecipe = widget.recipe
        .replaceAll('```html', '')
        .replaceAll('```', '')
        .replaceAll('&nbsp;', ' ')
        .trim();

    // Check for and remove wrapping <pre> tags
    // This regex looks for <pre...> at the start and </pre> at the end, capturing content in between.
    // dotAll: true (s flag) makes . match newlines.
    final preRegex = RegExp(r"^\s*<pre[^>]*>(.*)<\/pre>\s*$", caseSensitive: false, dotAll: true);
    final preMatch = preRegex.firstMatch(tempRecipe);

    if (preMatch != null) {
      // If <pre> tags are found wrapping the content, use the inner content
      _cleanedRecipe = preMatch.group(1)!.trim();
    } else {
      // Otherwise, use the result from initial cleaning
      _cleanedRecipe = tempRecipe;
    }

    _pageTitle = _extractTitle(_cleanedRecipe);
  }

  Future<Size> _getImageSize(String url) async {
    final completer = Completer<Size>();
    final image = Image.network(url);
    final stream = image.image.resolve(const ImageConfiguration());
    late ImageStreamListener lis;
    lis = ImageStreamListener((info, _) {
      completer.complete(Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      ));
      stream.removeListener(lis);
    }, onError: (err, _) {
      completer.completeError(err!);
      stream.removeListener(lis);
    });
    stream.addListener(lis);
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(_pageTitle.isNotEmpty ? _pageTitle : 'Recipe')),
      body: Column(
        children: [
          // Image + overlayed chips
          Expanded(
            flex: 2,
            child: FutureBuilder<Size>(
              future: _getImageSize(widget.imageUrl),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error loading image: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final imgSize = snap.data!;
                if (imgSize.width <= 0 || imgSize.height <= 0) {


                  return Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (ctx, err, stack) =>
                    const Center(child: Icon(Icons.error)),
                );
                }
                final aspect = imgSize.width / imgSize.height;
                return AspectRatio(
                  aspectRatio: aspect,
                  child: LayoutBuilder(
                    builder: (ctx, cons) {
                      final w = cons.maxWidth;
                      final h = cons.maxHeight;
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
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: ox,
                            top: oy,
                            width: rw,
                            height: rh,
                            child:
                                Image.network(widget.imageUrl, fit: BoxFit.contain),
                          ),
                          ..._generatePositionedChips(
                              widget.detectedItems, w, h, rw, rh, ox, oy),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // Video button if available
          if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_circle_fill),
                label: const Text('Watch Cooking Video'),
                onPressed: () async {
                  final uri = Uri.parse(widget.videoUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not launch video')),
                    );
                  }
                },
              ),
            ),
          ],

          // Render recipe HTML
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              child: Padding( // Add Padding around the Column
                padding: const EdgeInsets.all(16.0),
                child: Column( // Wrap Container and Share button in a Column
                  children: [
                    Container( // Apply Container styling
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 1.0), 
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.8), 
                        borderRadius: BorderRadius.circular(12.0), 
                      ),
                      child: Html(
                        data: _cleanedRecipe,
                        style: {
                          "h1": Style(
                            fontSize: FontSize(
                                Theme.of(context).textTheme.headlineSmall!.fontSize!),
                            fontWeight: FontWeight.bold,
                            margin: Margins.only(bottom: 10), 
                          ),
                          "h2": Style(
                            fontSize:
                                FontSize(Theme.of(context).textTheme.titleLarge!.fontSize!),
                            fontWeight: FontWeight.w600,
                            margin: Margins.only(top: 15, bottom: 5), 
                          ),
                          "ul": Style(margin: Margins.symmetric(vertical: 8)), 
                          "li": Style(
                            fontSize: FontSize(
                                Theme.of(context).textTheme.bodyMedium!.fontSize! + 1),
                            padding: HtmlPaddings.only(left: 5),
                          ),
                          "p": Style(
                            fontSize:
                                FontSize(Theme.of(context).textTheme.bodyMedium!.fontSize!),
                            lineHeight: LineHeight.number(1.4),
                            margin: Margins.only(bottom: 8), 
                          ),
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Share button - moved inside the Column and Padding
                    TextButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Share Recipe'),
                      onPressed: () {
                        final shareContent = _stripHtml(_cleanedRecipe);
                        Share.share(shareContent, subject: _pageTitle);
                      },
                    ),
                    const SizedBox(height: 10), // Space between buttons
                    TextButton.icon( // Regenerate Recipe Button
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regenerate Recipe'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ExtractionPage(
                              imageUrl: widget.imageUrl,
                              initialDetectedItems: List<Map<String, dynamic>>.from(
                                widget.detectedItems.map((item) => Map<String, dynamic>.from(item))
                              ),
                              isRegenerating: true,
                              // Pass current recipe options to pre-fill in ExtractionPage
                              initialMealType: widget.mealType,
                              initialDietaryGoal: widget.dietaryGoal,
                              initialMealTime: widget.mealTime,
                              initialAmountPeople: widget.amountPeople,
                              initialRestrictDiet: widget.restrictDiet.isEmpty ? 'None' : widget.restrictDiet, // Handle empty string to 'None'
                            ),
                          ),
                        );
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
    double containerW,
    double containerH,
    double imgW,
    double imgH,
    double offsetX,
    double offsetY,
  ) {
    final chips = <Widget>[];
    final occupied = <Rect>[];
    const baseH = 32.0, extraH = 14.0, vpad = 4.0;

    for (var item in items) {
      final box = item['bounding_box'] as Map<String, dynamic>? ?? {};
      final xMin = (box['x_min'] as num?)?.toDouble() ?? 0.0;
      final yMin = (box['y_min'] as num?)?.toDouble() ?? 0.0;
      final xMax = (box['x_max'] as num?)?.toDouble() ?? 0.0;
      final yMax = (box['y_max'] as num?)?.toDouble() ?? 0.0;
      final label = item['item_label'] as String? ?? 'Unknown';
      final info = item['additional_info'] as String? ?? '';
      final quantity = item['quantity'] as int? ?? 1; // Get quantity
      final hasInfo = info.isNotEmpty;

      final displayLabel = quantity > 1 ? '$quantity $label' : label; // Prepend quantity if > 1

      final cx = offsetX + xMin * imgW + (xMax - xMin) * imgW / 2;
      final cy = offsetY + yMin * imgH + (yMax - yMin) * imgH / 2;
      final chipW = (displayLabel.length * 7.0 + (hasInfo ? info.length * 5.0 : 0) + 24.0).clamp(60.0, containerW * 0.8); // Adjusted width calculation
      final chipH = baseH + (hasInfo ? extraH : 0) + vpad * 2;

      double left = (cx - chipW / 2).clamp(0.0, containerW - chipW);
      double top = (cy - chipH / 2).clamp(0.0, containerH - chipH);
      Rect rect = Rect.fromLTWH(left, top, chipW, chipH * 1.1);
      int tries = 0;
      while (occupied.any((r) => r.overlaps(rect)) && tries < 10) {
        top = (top + baseH * 0.5 + 4).clamp(0.0, containerH - chipH);
        rect = Rect.fromLTWH(left, top, chipW, chipH * 1.1);
        tries++;
      }
      occupied.add(rect);

      chips.add(Positioned(
        left: left,
        top: top,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: vpad),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 3,
                offset: const Offset(1,1),
              )
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(displayLabel, // Use displayLabel
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer)),
              if (hasInfo)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(info,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withOpacity(0.8))),
                ),
            ],
          ),
        ),
      ));
    }

    return chips;
  }
}
