import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'account_icon_button.dart';
import 'generating_page.dart';
import 'extraction_page.dart';
import 'main.dart'; // For AuthPage
import 'saved_recipes_page.dart';
import 'upload_page.dart';

class NutritionPieChart extends StatelessWidget {
  final Map<String, double> data; // keys: 'protein','carbs','fat'

  const NutritionPieChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final pCal = data['protein']! * 4;
    final cCal = data['carbs']! * 4;
    final fCal = data['fat']! * 9;
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: pCal,
            title: 'Protein',
            color: Theme.of(context).colorScheme.secondary,
            radius: 60,
            titlePositionPercentageOffset: 0.8,
            titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          PieChartSectionData(
            value: cCal,
            title: 'Carbs',
            color: Theme.of(context).colorScheme.primary,
            radius: 60,
            titlePositionPercentageOffset: 0.8,
            titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          PieChartSectionData(
            value: fCal,
            title: 'Fat',
            color: Theme.of(context).colorScheme.tertiary,
            radius: 60,
            titlePositionPercentageOffset: 0.8,
            titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
        sectionsSpace: 4,
        centerSpaceRadius: 40,
      ),
    );
  }
}

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
  // Optional custom back action
  final VoidCallback? onBack;

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
    this.nutritionInfo,
    this.onBack,
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
              onBack: widget.onBack,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth < 800;
                  final isPortrait =
                      constraints.maxHeight > constraints.maxWidth;
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
                          nutritionInfo: widget.nutritionInfo,
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
  final VoidCallback? onBack; // optional custom back callback
  final String imageUrl;
  final List<Map<String, dynamic>> detectedItems;
  final String mealType;
  final String dietaryGoal;
  final String mealTime;
  final String amountPeople;
  final String restrictDiet;

  const AppHeader({
    super.key,
    this.onBack,
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
                  onPressed: () {
                    if (onBack != null) {
                      onBack!();
                    } else {
                      _navigateToExtraction(context);
                    }
                  },
                  icon: Icon(
                    Icons.arrow_back,
                    color: Colors.grey.shade700,
                    size: 20,
                  ),
                  tooltip: 'Go back',
                ),
              ),
              const SizedBox(width: 16),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const UploadImagePage()),
                      (route) => false,
                    );
                  },
                  child: BrandSection(isSmallScreen: isSmallScreen),
                ),
              ),
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // Navigate to UploadImagePage on tap
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UploadImagePage()),
          );
        },
        child: Row(
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
        ),
      ),
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
  final Map<String, double>? nutritionInfo;

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
    this.nutritionInfo,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 800;
        final isPortrait = constraints.maxHeight > constraints.maxWidth;
        final isMobilePortrait = isSmallScreen && isPortrait;
        final padding = isMobilePortrait ? 16.0 : (isSmallScreen ? 24.0 : 40.0);

        if (isMobilePortrait) {
          return SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mainImageUrl?.isNotEmpty == true)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        mainImageUrl!,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                            'assets/images/recipe_placeholder.png',
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover),
                      ),
                    ),
                  if (mainImageUrl == null || mainImageUrl?.isEmpty == true)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/recipe_placeholder.png',
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    pageTitle,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (videoUrl?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GestureDetector(
                        onTap: () => launchUrl(Uri.parse(videoUrl!),
                            mode: LaunchMode.externalApplication),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_fill,
                                color: Colors.red.shade400, size: 28),
                            const SizedBox(width: 8),
                            Text('Watch on YouTube',
                                style: TextStyle(
                                    color: Colors.red.shade400,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  RecipeContent(recipe: recipe),
                  if (nutritionInfo != null)
                    Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nutritional Breakdown',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 180,
                              child: NutritionPieChart(data: nutritionInfo!),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
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
                    mainImageUrl: mainImageUrl,
                  ),
                ],
              ),
            ),
          );
        } else {
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
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mainImageUrl?.isNotEmpty == true)
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(isMobilePortrait ? 8 : 12),
                      child: Image.network(
                        mainImageUrl!,
                        width: double.infinity,
                        height: isMobilePortrait ? 180 : 240,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                            'assets/images/recipe_placeholder.png',
                            width: double.infinity,
                            height: isMobilePortrait ? 180 : 240,
                            fit: BoxFit.cover),
                      ),
                    ),
                  if (mainImageUrl == null || mainImageUrl?.isEmpty == true)
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(isMobilePortrait ? 8 : 12),
                      child: Image.asset(
                        'assets/images/recipe_placeholder.png',
                        width: double.infinity,
                        height: isMobilePortrait ? 180 : 240,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    pageTitle,
                    style: TextStyle(
                      fontSize: isMobilePortrait ? 22 : 28,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (videoUrl?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GestureDetector(
                        onTap: () => launchUrl(Uri.parse(videoUrl!),
                            mode: LaunchMode.externalApplication),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_fill,
                                color: Colors.red.shade400, size: 28),
                            const SizedBox(width: 8),
                            Text('Watch on YouTube',
                                style: TextStyle(
                                    color: Colors.red.shade400,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  RecipeContent(recipe: recipe),
                  if (nutritionInfo != null)
                    Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nutritional Breakdown',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 180,
                              child: NutritionPieChart(data: nutritionInfo!),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                    mainImageUrl: mainImageUrl,
                  ),
                ],
              ),
            ),
          );
        }
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
  final String? mainImageUrl;

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
    this.mainImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 800;
        final isPortrait = constraints.maxHeight > constraints.maxWidth;
        final isMobilePortrait = isSmallScreen && isPortrait;

        if (isMobilePortrait) {
          // Mobile portrait - stack buttons vertically with smaller spacing
          return Column(
            children: [
              const SizedBox(height: 20),
              Opacity(
                opacity: isLoggedIn ? 1.0 : 0.5,
                child: _buildPrimaryButton(
                  context,
                  'Save Recipe',
                  Icons.bookmark_add_rounded,
                  isLoggedIn ? () => _saveRecipe(context) : () {},
                  isMobilePortrait: true,
                ),
              ),
              if (!isLoggedIn) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AuthPage()),
                  ),
                  child: const Text('Sign in to save recipes'),
                ),
              ],
              const SizedBox(height: 12),
              Opacity(
                opacity: isLoggedIn ? 1.0 : 1.0,
                child: _buildSecondaryButton(
                  context,
                  'Share Recipe',
                  Icons.share_rounded,
                  () => _shareRecipe(context),
                  isMobilePortrait: true,
                ),
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: isLoggedIn ? 1.0 : 1.0,
                child: _buildTertiaryButton(
                  context,
                  'Generate New Recipe',
                  Icons.refresh_rounded,
                  () => _generateNewRecipe(context),
                  isMobilePortrait: true,
                ),
              ),
            ],
          );
        } else {
          // Desktop and landscape - buttons in a row
          return Row(
            children: [
              Expanded(
                child: Opacity(
                  opacity: isLoggedIn ? 1.0 : 0.5,
                  child: _buildPrimaryButton(
                    context,
                    'Save Recipe',
                    Icons.bookmark_add_rounded,
                    isLoggedIn ? () => _saveRecipe(context) : () {},
                    isMobilePortrait: false,
                  ),
                ),
              ),
              if (!isLoggedIn) ...[
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AuthPage()),
                  ),
                  child: const Text('Sign in to save recipes'),
                ),
              ] else ...[
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Opacity(
                  opacity: isLoggedIn ? 1.0 : 1.0,
                  child: _buildSecondaryButton(
                    context,
                    'Share Recipe',
                    Icons.share_rounded,
                    () => _shareRecipe(context),
                    isMobilePortrait: false,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Opacity(
                  opacity: isLoggedIn ? 1.0 : 1.0,
                  child: _buildTertiaryButton(
                    context,
                    'Generate New Recipe',
                    Icons.refresh_rounded,
                    () => _generateNewRecipe(context),
                    isMobilePortrait: false,
                  ),
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
        color: const Color(0xFF3B82F6),
        borderRadius: BorderRadius.circular(isMobilePortrait ? 10 : 12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.2),
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
        color: const Color(0xFF64748B),
        borderRadius: BorderRadius.circular(isMobilePortrait ? 10 : 12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.2),
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

  void _saveRecipe(BuildContext context) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Please sign in to save recipes.'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }
    try {
      // Insert both user-uploaded and generated preview URLs
      await client.from('saved_recipes').insert({
        'user_id': user.id,
        'recipe_title': pageTitle,
        'recipe_content': recipe,
        'image_url': imageUrl, // original user-uploaded photo
        'main_image_url': mainImageUrl, // preview/generated photo
        'meal_type': mealType,
        'dietary_goal': dietaryGoal,
        'meal_time': mealTime,
        'amount_people': amountPeople,
        'restrict_diet': restrictDiet,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Recipe saved!'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to save recipe: $e'),
            backgroundColor: Colors.redAccent),
      );
    }
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
