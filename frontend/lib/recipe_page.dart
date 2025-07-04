import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'account_icon_button.dart';
import 'generating_page.dart';
import 'extraction_page.dart';

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

String _stripHtml(String htmlString) {
  final htmlRegex = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
  final cleaned = htmlString
      .replaceAll('```html', '')
      .replaceAll('```', '')
      .replaceAll('&nbsp;', ' ');
  return cleaned.replaceAll(htmlRegex, '').trim();
}

String _extractTitle(String html) {
  final match =
      RegExp(r"<h1[^>]*>(.*?)<\/h1>", caseSensitive: false).firstMatch(html);
  return match?.group(1)?.trim() ?? '';
}

// =============================================================================
// MAIN PAGE CLASS
// =============================================================================

class RecipePage extends StatefulWidget {
  final String imageUrl;
  final String recipe;
  final List<Map<String, dynamic>> detectedItems;
  final String? videoUrl;
  final String mealType;
  final String dietaryGoal;
  final String mealTime;
  final String amountPeople;
  final String restrictDiet;
  final String? mainImageUrl;
  final bool? isFitnessMode;
  final Map<String, double>? nutritionInfo;

  const RecipePage({
    super.key,
    required this.imageUrl,
    required this.recipe,
    required this.detectedItems,
    this.videoUrl,
    required this.mealType,
    required this.dietaryGoal,
    required this.mealTime,
    required this.amountPeople,
    required this.restrictDiet,
    this.mainImageUrl,
    this.isFitnessMode,
    this.nutritionInfo
  });

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage> {
  late final String _cleanedRecipe;
  late final String _pageTitle;

  @override
  void initState() {
    super.initState();
    String tempRecipe = widget.recipe
        .replaceAll('```html', '')
        .replaceAll('```', '')
        .replaceAll('&nbsp;', ' ')
        .trim();

    final preRegex = RegExp(r"^\s*<pre[^>]*>(.*)<\/pre>\s*$",
        caseSensitive: false, dotAll: true);
    final preMatch = preRegex.firstMatch(tempRecipe);

    if (preMatch != null) {
      _cleanedRecipe = preMatch.group(1)!.trim();
    } else {
      _cleanedRecipe = tempRecipe;
    }

    _pageTitle = _extractTitle(_cleanedRecipe);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              imageUrl: widget.imageUrl,
              detectedItems: widget.detectedItems,
              mealType: widget.mealType,
              dietaryGoal: widget.dietaryGoal,
              mealTime: widget.mealTime,
              amountPeople: widget.amountPeople,
              restrictDiet: widget.restrictDiet,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth < 800;
                  final isPortrait = constraints.maxHeight > constraints.maxWidth;
                  final isMobilePortrait = isSmallScreen && isPortrait;
                  final padding =
                      isMobilePortrait ? 16.0 : (isSmallScreen ? 24.0 : 40.0);

                  return Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(padding),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isMobilePortrait
                              ? double.infinity
                              : (isSmallScreen ? double.infinity : 800),
                        ),
                        child: RecipeSection(
                          recipe: _cleanedRecipe,
                          pageTitle: _pageTitle,
                          videoUrl: widget.videoUrl,
                          imageUrl: widget.imageUrl,
                          detectedItems: widget.detectedItems,
                          mealType: widget.mealType,
                          dietaryGoal: widget.dietaryGoal,
                          mealTime: widget.mealTime,
                          amountPeople: widget.amountPeople,
                          restrictDiet: widget.restrictDiet,
                          mainImageUrl: widget.mainImageUrl, 
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// APP HEADER COMPONENT
// =============================================================================

class AppHeader extends StatelessWidget {
  final String imageUrl;
  final List<Map<String, dynamic>> detectedItems;
  final String mealType;
  final String dietaryGoal;
  final String mealTime;
  final String amountPeople;
  final String restrictDiet;

  const AppHeader({
    super.key,
    required this.imageUrl,
    required this.detectedItems,
    required this.mealType,
    required this.dietaryGoal,
    required this.mealTime,
    required this.amountPeople,
    required this.restrictDiet,
  });

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
                  onPressed: () => _navigateToExtraction(context),
                  icon: Icon(
                    Icons.arrow_back,
                    color: Colors.grey.shade700,
                    size: 20,
                  ),
                  tooltip: 'Go back to extraction',
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

  void _navigateToExtraction(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ExtractionPage(
          imageUrl: imageUrl,
          initialDetectedItems: detectedItems,
          isRegenerating: true,
          initialMealType: mealType,
          initialDietaryGoal: dietaryGoal,
          initialMealTime: mealTime,
          initialAmountPeople: amountPeople,
          initialRestrictDiet: restrictDiet,
        ),
      ),
    );
  }
}

class BrandSection extends StatelessWidget {
  final bool isSmallScreen;

  const BrandSection({
    super.key,
    required this.isSmallScreen,
  });

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

// =============================================================================
// RECIPE SECTION COMPONENT
// =============================================================================

class RecipeSection extends StatelessWidget {
  final String recipe;
  final String pageTitle;
  final String? videoUrl;
  final String imageUrl;
  final List<Map<String, dynamic>> detectedItems;
  final String mealType;
  final String dietaryGoal;
  final String mealTime;
  final String amountPeople;
  final String restrictDiet;
  final String? mainImageUrl;

  const RecipeSection({
    super.key,
    required this.recipe,
    required this.pageTitle,
    this.videoUrl,
    required this.imageUrl,
    required this.detectedItems,
    required this.mealType,
    required this.dietaryGoal,
    required this.mealTime,
    required this.amountPeople,
    required this.restrictDiet,
    this.mainImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 800;
        final isPortrait = constraints.maxHeight > constraints.maxWidth;
        final isMobilePortrait = isSmallScreen && isPortrait;
        final padding = isMobilePortrait ? 16.0 : (isSmallScreen ? 24.0 : 40.0);

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobilePortrait ? 8 : 12),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: isMobilePortrait ? 6 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: RecipeHeader(pageTitle: pageTitle)),
                if (mainImageUrl != null && mainImageUrl!.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          mainImageUrl!,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/images/recipe_placeholder.png',
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
              SizedBox(
                  height: isMobilePortrait ? 16 : (isSmallScreen ? 24 : 32)),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      RecipeContent(recipe: recipe),
                      SizedBox(height: isMobilePortrait ? 24 : 32),
                      if (videoUrl != null && videoUrl!.isNotEmpty) ...[
                        VideoButton(videoUrl: videoUrl!),
                        SizedBox(height: isMobilePortrait ? 20 : 24),
                      ],
                      ActionButtons(
                        pageTitle: pageTitle,
                        recipe: recipe,
                        imageUrl: imageUrl,
                        detectedItems: detectedItems,
                        mealType: mealType,
                        dietaryGoal: dietaryGoal,
                        mealTime: mealTime,
                        amountPeople: amountPeople,
                        restrictDiet: restrictDiet,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RecipeHeader extends StatelessWidget {
  final String pageTitle;

  const RecipeHeader({
    super.key,
    required this.pageTitle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 800;
        final isPortrait = constraints.maxHeight > constraints.maxWidth;
        final isMobilePortrait = isSmallScreen && isPortrait;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pageTitle.isNotEmpty ? pageTitle : 'Generated Recipe',
              style: TextStyle(
                fontSize: isMobilePortrait ? 20 : (isSmallScreen ? 22 : 24),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobilePortrait ? 6 : (isSmallScreen ? 8 : 12)),
            Text(
              'Your recipe based on the detected ingredients',
              style: TextStyle(
                fontSize: isMobilePortrait ? 14 : (isSmallScreen ? 15 : 16),
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }
}

class VideoButton extends StatelessWidget {
  final String videoUrl;

  const VideoButton({
    super.key,
    required this.videoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 800;
        final isPortrait = constraints.maxHeight > constraints.maxWidth;
        final isMobilePortrait = isSmallScreen && isPortrait;
        final height = isMobilePortrait ? 48.0 : 44.0;

        return Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isMobilePortrait ? 10 : 8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E40AF).withOpacity(0.2),
                blurRadius: isMobilePortrait ? 6 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            icon: Icon(
              Icons.play_circle_fill,
              size: isMobilePortrait ? 20 : 18,
            ),
            label: Text(
              'Watch Cooking Video',
              style: TextStyle(
                fontSize: isMobilePortrait ? 15 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () async {
              final uri = Uri.parse(videoUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Could not launch video'),
                    backgroundColor: const Color(0xFFEF4444),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E40AF),
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isMobilePortrait ? 10 : 8),
              ),
            ),
          ),
        );
      },
    );
  }
}

class RecipeContent extends StatelessWidget {
  final String recipe;

  const RecipeContent({
    super.key,
    required this.recipe,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 800;
        final isPortrait = constraints.maxHeight > constraints.maxWidth;
        final isMobilePortrait = isSmallScreen && isPortrait;
        final padding = isMobilePortrait ? 16.0 : (isSmallScreen ? 20.0 : 24.0);

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(isMobilePortrait ? 8.0 : 12.0),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Html(
            data: recipe,
            style: {
              "h1": Style(
                textAlign: TextAlign.center,
                fontSize: FontSize(isMobilePortrait ? 22 : 28),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
                margin: Margins.only(bottom: isMobilePortrait ? 12 : 16),
              ),
              "h2": Style(
                fontSize: FontSize(isMobilePortrait ? 18 : 22),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
                margin: Margins.only(
                    top: isMobilePortrait ? 20 : 24,
                    bottom: isMobilePortrait ? 8 : 12),
              ),
              "h3": Style(
                fontSize: FontSize(isMobilePortrait ? 16 : 18),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
                margin: Margins.only(
                    top: isMobilePortrait ? 16 : 20,
                    bottom: isMobilePortrait ? 6 : 8),
              ),
              "p": Style(
                fontSize: FontSize(isMobilePortrait ? 15 : 16),
                lineHeight: LineHeight.number(1.6),
                color: const Color(0xFF475569),
                margin: Margins.only(bottom: isMobilePortrait ? 10 : 12),
              ),
              "ul": Style(
                margin: Margins.only(bottom: isMobilePortrait ? 12 : 16),
              ),
              "ol": Style(
                margin: Margins.only(bottom: isMobilePortrait ? 12 : 16),
              ),
              "li": Style(
                fontSize: FontSize(isMobilePortrait ? 15 : 16),
                lineHeight: LineHeight.number(1.6),
                color: const Color(0xFF475569),
                margin: Margins.only(bottom: isMobilePortrait ? 6 : 8),
              ),
              "strong": Style(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
              "em": Style(
                fontStyle: FontStyle.italic,
                color: const Color(0xFF64748B),
              ),
            },
            onLinkTap: (url, _, __) async {
              if (url != null && await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication);
              }
            },
          ),
        );
      },
    );
  }
}

class ActionButtons extends StatelessWidget {
  final String pageTitle;
  final String recipe;
  final String imageUrl;
  final List<Map<String, dynamic>> detectedItems;
  final String mealType;
  final String dietaryGoal;
  final String mealTime;
  final String amountPeople;
  final String restrictDiet;

  const ActionButtons({
    super.key,
    required this.pageTitle,
    required this.recipe,
    required this.imageUrl,
    required this.detectedItems,
    required this.mealType,
    required this.dietaryGoal,
    required this.mealTime,
    required this.amountPeople,
    required this.restrictDiet,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 800;
        final isPortrait = constraints.maxHeight > constraints.maxWidth;
        final isMobilePortrait = isSmallScreen && isPortrait;

        if (isMobilePortrait) {
          // Mobile portrait - stack buttons vertically with smaller spacing
          return Column(
            children: [
              _buildPrimaryButton(
                context,
                'Save Recipe',
                Icons.bookmark_add_rounded,
                () => _saveRecipe(context),
                isMobilePortrait: true,
              ),
              const SizedBox(height: 12),
              _buildSecondaryButton(
                context,
                'Share Recipe',
                Icons.share_rounded,
                () => _shareRecipe(context),
                isMobilePortrait: true,
              ),
              const SizedBox(height: 12),
              _buildTertiaryButton(
                context,
                'Generate New Recipe',
                Icons.refresh_rounded,
                () => _generateNewRecipe(context),
                isMobilePortrait: true,
              ),
            ],
          );
        } else {
          // Desktop and landscape - buttons in a row
          return Row(
            children: [
              Expanded(
                child: _buildPrimaryButton(
                  context,
                  'Save Recipe',
                  Icons.bookmark_add_rounded,
                  () => _saveRecipe(context),
                  isMobilePortrait: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSecondaryButton(
                  context,
                  'Share Recipe',
                  Icons.share_rounded,
                  () => _shareRecipe(context),
                  isMobilePortrait: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTertiaryButton(
                  context,
                  'Generate New Recipe',
                  Icons.refresh_rounded,
                  () => _generateNewRecipe(context),
                  isMobilePortrait: false,
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildPrimaryButton(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onPressed, {
    required bool isMobilePortrait,
  }) {
    final height = isMobilePortrait ? 52.0 : 56.0;
    final iconSize = isMobilePortrait ? 20.0 : 22.0;
    final fontSize = isMobilePortrait ? 15.0 : 16.0;

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isMobilePortrait ? 10 : 12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: isMobilePortrait ? 8 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(isMobilePortrait ? 10 : 12),
          child: Container(
            padding:
                EdgeInsets.symmetric(horizontal: isMobilePortrait ? 20 : 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: iconSize,
                ),
                SizedBox(width: isMobilePortrait ? 10 : 12),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onPressed, {
    required bool isMobilePortrait,
  }) {
    final height = isMobilePortrait ? 52.0 : 56.0;
    final iconSize = isMobilePortrait ? 20.0 : 22.0;
    final fontSize = isMobilePortrait ? 15.0 : 16.0;

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobilePortrait ? 10 : 12),
        border: Border.all(
          color: const Color(0xFF3B82F6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            blurRadius: isMobilePortrait ? 6 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(isMobilePortrait ? 10 : 12),
          child: Container(
            padding:
                EdgeInsets.symmetric(horizontal: isMobilePortrait ? 20 : 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: const Color(0xFF3B82F6),
                  size: iconSize,
                ),
                SizedBox(width: isMobilePortrait ? 10 : 12),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTertiaryButton(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onPressed, {
    required bool isMobilePortrait,
  }) {
    final height = isMobilePortrait ? 52.0 : 56.0;
    final iconSize = isMobilePortrait ? 20.0 : 22.0;
    final fontSize = isMobilePortrait ? 15.0 : 16.0;

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(isMobilePortrait ? 10 : 12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: isMobilePortrait ? 6 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(isMobilePortrait ? 10 : 12),
          child: Container(
            padding:
                EdgeInsets.symmetric(horizontal: isMobilePortrait ? 20 : 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: const Color(0xFF64748B),
                  size: iconSize,
                ),
                SizedBox(width: isMobilePortrait ? 10 : 12),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _saveRecipe(BuildContext context) {
    // Implementation for saving recipe
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            const Text('Recipe saved successfully!'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _shareRecipe(BuildContext context) {
    Share.share(
      '$pageTitle\n\n$recipe',
      subject: pageTitle,
    );
  }

  void _generateNewRecipe(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GeneratingPage(
          imageUrl: imageUrl,
          manualLabels: detectedItems,
          mealType: mealType,
          dietaryGoal: dietaryGoal,
          mealTime: mealTime,
          amountPeople: amountPeople,
          restrictDiet: restrictDiet,
          mode: 'candidates',
        ),
      ),
    );
  }
}
