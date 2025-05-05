// lib/recipe_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper function to strip HTML tags when sharing as plain text
String _stripHtml(String htmlString) {
  final htmlRegex = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
  var cleaned = htmlString
      .replaceAll('```html', '')
      .replaceAll('```', '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(htmlRegex, '')
      .trim();
  return cleaned;
}

/// Helper to extract the <h1> title from the HTML recipe
String _extractTitle(String html) {
  final match = RegExp(r"<h1[^>]*>(.*?)<\/h1>", caseSensitive: false).firstMatch(html);
  return match?.group(1)?.trim() ?? '';
}

class RecipePage extends StatefulWidget {
  final String imageUrl;
  final String recipe; // HTML content
  final List<Map<String, dynamic>> detectedItems;
  final String? videoUrl; // Optional YouTube link

  const RecipePage({
    Key? key,
    required this.imageUrl,
    required this.recipe,
    required this.detectedItems,
    this.videoUrl,
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
    // Remove markdown fences if any
    _cleanedRecipe = widget.recipe
        .replaceAll('```html', '')
        .replaceAll('```', '')
        .trim();
    // Extract <h1> as the page title
    _pageTitle = _extractTitle(_cleanedRecipe);
  }

  Future<Size> _getImageSize(String url) async {
    final completer = Completer<Size>();
    final image = Image.network(url);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((info, _) {
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
      appBar: AppBar(title: Text(_pageTitle.isNotEmpty ? _pageTitle : 'Recipe')),
      body: Column(
        children: [
          // Display the uploaded image with ingredient chips
          Expanded(
            flex: 2,
            child: FutureBuilder<Size>(
              future: _getImageSize(widget.imageUrl),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final imgSize = snap.data!;
                final aspectRatio = imgSize.width / imgSize.height;
                return AspectRatio(
                  aspectRatio: aspectRatio,
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
                            child: Image.network(widget.imageUrl, fit: BoxFit.contain),
                          ),
                          // You can overlay chips here if needed
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
              padding: const EdgeInsets.all(16.0),
              child: Html(
                data: _cleanedRecipe,
                style: {
                  "h1": Style(
                    fontSize: FontSize(Theme.of(context).textTheme.headlineSmall!.fontSize!),
                    fontWeight: FontWeight.bold,
                    margin: Margins.only(bottom: 12),
                  ),
                  "h2": Style(
                    fontSize: FontSize(Theme.of(context).textTheme.titleLarge!.fontSize!),
                    fontWeight: FontWeight.w600,
                    margin: Margins.only(top: 16, bottom: 8),
                  ),
                  "ul": Style(margin: Margins.symmetric(vertical: 8)),
                  "li": Style(
                    fontSize: FontSize(Theme.of(context).textTheme.bodyMedium!.fontSize! + 1),
                    padding: HtmlPaddings.only(left: 8),
                  ),
                  "p": Style(
                    fontSize: FontSize(Theme.of(context).textTheme.bodyMedium!.fontSize!),
                    lineHeight: LineHeight.number(1.4),
                    margin: Margins.only(bottom: 8),
                  ),
                },
              ),
            ),
          ),

          // Share button
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: TextButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share Recipe'),
              onPressed: () {
                final shareText = _stripHtml(widget.recipe);
                Share.share(
                  shareText,
                  subject: _pageTitle.isNotEmpty ? _pageTitle : 'Recipe',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
