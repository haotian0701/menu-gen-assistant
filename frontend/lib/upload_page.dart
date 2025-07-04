// lib/upload_page.dart

import 'dart:typed_data';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' show basename;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'extraction_page.dart';
import 'account_icon_button.dart';
import 'generating_page.dart';

// =============================================================================
// MAIN PAGE CLASS
// =============================================================================

class UploadImagePage extends StatefulWidget {
  const UploadImagePage({super.key});

  @override
  State<UploadImagePage> createState() => _UploadImagePageState();
}

class _UploadImagePageState extends State<UploadImagePage> {
  final _client = Supabase.instance.client;
  final _uploadController = UploadController();

  @override
  void dispose() {
    _uploadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth < 800;
                  final isPortrait = constraints.maxHeight > constraints.maxWidth;
                  final padding = isSmallScreen ? 20.0 : 40.0;

                  return Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(padding),
                    child: LayoutBuilder(
                      builder: (context, innerConstraints) {
                        final isSmallScreen = innerConstraints.maxWidth < 800;
                        final isPortrait = innerConstraints.maxHeight >
                            innerConstraints.maxWidth;

                        if (isSmallScreen && isPortrait) {
                          // Mobile portrait - only show upload section (generate button is inside)
                          return UploadSection(
                            controller: _uploadController,
                            onUploadSuccess: _handleUploadSuccess,
                          );
                        } else if (isSmallScreen) {
                          // Small screen landscape - stack vertically with status panel
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: UploadSection(
                                  controller: _uploadController,
                                  onUploadSuccess: _handleUploadSuccess,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Expanded(
                                flex: 1,
                                child: StatusPanel(
                                  controller: _uploadController,
                                  onGenerateRecipe: _handleGenerateRecipe,
                                  onGenerateInstant: _handleInstantGenerate,
                                  onGenerateFitness: _handleGenerateFitness,
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Large screen - side by side
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: UploadSection(
                                  controller: _uploadController,
                                  onUploadSuccess: _handleUploadSuccess,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 1,
                                child: StatusPanel(
                                  controller: _uploadController,
                                  onGenerateRecipe: _handleGenerateRecipe,
                                  onGenerateInstant: _handleInstantGenerate,
                                  onGenerateFitness: _handleGenerateFitness,
                                ),
                              ),
                            ],
                          );
                        }
                      },
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

  void _handleUploadSuccess() {
    // Handle successful upload - URL is already stored in controller
  }

  void _handleGenerateRecipe() {
    _navigateToExtraction();
  }

  void _handleInstantGenerate() {
    _generateInstantly();
  }

  Future<Map<String, dynamic>?> _fetchPreferences() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return null;

    final resp = await client
        .from('user_preferences')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    if (resp == null || resp.isEmpty) return null;
    return resp as Map<String, dynamic>;
  }

  Future<void> _navigateToExtraction() async {
    if (_uploadController.uploadedUrl == null) return;
    final prefs = await _fetchPreferences();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExtractionPage(
          imageUrl: _uploadController.uploadedUrl!,
          initialMealType: prefs?['meal_type'] as String?,
          initialDietaryGoal: prefs?['dietary_goal'] as String?,
          initialMealTime: prefs?['meal_time'] as String?,
          initialAmountPeople: prefs?['amount_people'] as String?,
          initialRestrictDiet: prefs?['restrict_diet'] as String?,
          initialPreferredRegion: prefs?['preferred_region'] as String?,
          initialSkillLevel: prefs?['skill_level'] as String?,
          initialKitchenTools: (prefs?['kitchen_tools'] as List?)?.cast<String>() ?? ['Stove Top', 'Oven'],
        ),
      ),
    );
  }

  Future<void> _generateInstantly() async {
    if (_uploadController.uploadedUrl == null) return;

    final prefs = await _fetchPreferences();

    final mealType = prefs?['meal_type'] as String? ?? 'general';
    final dietaryGoal = prefs?['dietary_goal'] as String? ?? 'normal';
    final mealTime = prefs?['meal_time'] as String? ?? 'fast';
    final amountPeople = prefs?['amount_people'] as String? ?? '1';
    final restrictDiet = prefs?['restrict_diet'] as String?;
    final preferredRegion = prefs?['preferred_region'] as String?;
    final skillLevel = prefs?['skill_level'] as String?;
    final kitchenTools = (prefs?['kitchen_tools'] as List?)?.cast<String>() ?? ['Stove Top', 'Oven'];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GeneratingPage(
          imageUrl: _uploadController.uploadedUrl!,
          mealType: mealType,
          dietaryGoal: dietaryGoal,
          mealTime: mealTime,
          amountPeople: amountPeople,
          restrictDiet: restrictDiet,
          preferredRegion: preferredRegion,
          skillLevel: skillLevel,
          kitchenTools: kitchenTools,
          manualLabels: const <Map<String, dynamic>>[],
          mode: 'final',
        ),
      ),
    );
  }
    void _handleGenerateFitness() {
    if (_uploadController.uploadedUrl != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExtractionPage(
            imageUrl: _uploadController.uploadedUrl!,
            mode: 'fitness', 
          ),
        ),
      );
    }
  }
}




// =============================================================================
// UPLOAD CONTROLLER
// =============================================================================

class UploadController extends ChangeNotifier {
  Uint8List? _fileBytes;
  String? _uploadedUrl;
  bool _loading = false;

  Uint8List? get fileBytes => _fileBytes;
  String? get uploadedUrl => _uploadedUrl;
  bool get loading => _loading;
  bool get hasUploadedFile => _fileBytes != null;
  bool get isReadyForGeneration => _uploadedUrl != null;

  Future<void> uploadImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    _setLoading(true);
    _clearUpload();

    try {
      final file = result.files.first;
      final bytes = file.bytes!;
      final origName = basename(file.name);
      final filename = '${DateTime.now().millisecondsSinceEpoch}_$origName';
      final path = 'public/$filename';

      final client = Supabase.instance.client;
      await client.storage.from('food-images').uploadBinary(path, bytes);
      final url = client.storage.from('food-images').getPublicUrl(path);

      _setFileBytes(bytes);
      _setUploadedUrl(url);
    } catch (e) {
      // Error handling will be done by the UI
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _loading = loading;
    notifyListeners();
  }

  void _setFileBytes(Uint8List bytes) {
    _fileBytes = bytes;
    notifyListeners();
  }

  void _setUploadedUrl(String url) {
    _uploadedUrl = url;
    notifyListeners();
  }

  void _clearUpload() {
    _fileBytes = null;
    _uploadedUrl = null;
    notifyListeners();
  }

  void clearUpload() {
    _clearUpload();
  }

}

// =============================================================================
// APP HEADER COMPONENT
// =============================================================================

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

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
              BrandSection(isSmallScreen: isSmallScreen),
              const Spacer(),
              const AccountIconButton(),
            ],
          ),
        );
      },
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

class NavigationSection extends StatelessWidget {
  const NavigationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475569),
            ),
          ),
        ),
        const SizedBox(width: 16),
        const AccountIconButton(),
      ],
    );
  }
}

// =============================================================================
// UPLOAD SECTION COMPONENT
// =============================================================================

class UploadSection extends StatelessWidget {
  final UploadController controller;
  final VoidCallback onUploadSuccess;

  const UploadSection({
    super.key,
    required this.controller,
    required this.onUploadSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 800;
            final isPortrait = constraints.maxHeight > constraints.maxWidth;
            final isMobilePortrait = isSmallScreen && isPortrait;

            return Container(
              padding: EdgeInsets.all(isSmallScreen ? 20.0 : 32.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: isSmallScreen
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const UploadHeader(),
                        SizedBox(height: isSmallScreen ? 16 : 32),
                        Expanded(child: UploadArea(controller: controller)),
                        SizedBox(height: isSmallScreen ? 16 : 32),
                        UploadButton(
                          controller: controller,
                          onUploadSuccess: onUploadSuccess,
                        ),
                        if (controller.isReadyForGeneration) ...[
                          const SizedBox(height: 12),
                          GenerateRecipeButton(onGenerateRecipe: () {
                            if (controller.uploadedUrl != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ExtractionPage(
                                      imageUrl: controller.uploadedUrl!),
                                ),
                              );
                            }
                          }),
                          const SizedBox(height: 12),
                          GenerateInstantlyButton(onGenerateInstant: () {
                            if (controller.uploadedUrl != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GeneratingPage(
                                    imageUrl: controller.uploadedUrl!,
                                    mealType: '',
                                    dietaryGoal: 'normal',
                                    mealTime: 'fast',
                                    amountPeople: '1',
                                    restrictDiet: null,
                                    manualLabels: const <Map<String, dynamic>>[],
                                    mode: 'final',
                                  ),
                                ),
                              );
                            }
                          }),
                        ],
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const UploadHeader(),
                          SizedBox(height: isSmallScreen ? 20 : 32),
                          UploadArea(controller: controller),
                          SizedBox(height: isSmallScreen ? 20 : 32),
                          UploadButton(
                            controller: controller,
                            onUploadSuccess: onUploadSuccess,
                          ),
                        ],
                      ),
                    ),
            );
          },
        );
      },
    );
  }
}

class UploadHeader extends StatelessWidget {
  const UploadHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 800;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload Ingredients Image',
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 24,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: isSmallScreen ? 4 : 8),
            Text(
              'Take a photo or upload an image of your ingredients to generate a recipe',
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        );
      },
    );
  }
}

class UploadArea extends StatelessWidget {
  final UploadController controller;

  const UploadArea({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 800;
            final isPortrait = constraints.maxHeight > constraints.maxWidth;
            final isMobilePortrait = isSmallScreen && isPortrait;

            // Calculate responsive height based on available space
            final availableHeight = constraints.maxHeight;
            final uploadAreaHeight = availableHeight > 600
                ? 320.0
                : (availableHeight * 0.4).clamp(200.0, 320.0);

            return Container(
              height: uploadAreaHeight,
              decoration: BoxDecoration(
                border: Border.all(
                  color: controller.hasUploadedFile
                      ? const Color(0xFF059669)
                      : Colors.grey.shade300,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(8),
                color: controller.hasUploadedFile
                    ? Colors.transparent
                    : const Color(0xFFFAFAFA),
              ),
              child: controller.hasUploadedFile
                  ? _buildImagePreview()
                  : _buildUploadPlaceholder(),
            );
          },
        );
      },
    );
  }

  Widget _buildImagePreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FutureBuilder<Size>(
          future: _getImageSize(controller.fileBytes!),
          builder: (ctx, snap) {
            if (snap.hasError) {
              return Center(
                child: Text(
                  'Error loading image: ${snap.error}',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final imgSize = snap.data!;
            if (imgSize.width <= 0 || imgSize.height <= 0) {
              return const Center(
                child: Icon(Icons.broken_image,
                    size: 64, color: Color(0xFF64748B)),
              );
            }

            // Calculate scale so that both width and height fit within the
            // available space while maintaining aspect ratio. We only scale
            // down (never up) to avoid pixelation.
            final containerWidth = constraints.maxWidth;
            final containerHeight = constraints.maxHeight;

            // Determine the scale required for each dimension and pick the
            // smallest so the image fits in both directions.
            final scaleW = containerWidth / imgSize.width;
            final scaleH = containerHeight / imgSize.height;
            final scale = math.min(1.0, math.min(scaleW, scaleH));

            final displayWidth = imgSize.width * scale;
            final displayHeight = imgSize.height * scale;

            return Center(
              child: SizedBox(
                width: displayWidth,
                height: displayHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      width: displayWidth,
                      height: displayHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          controller.fileBytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          controller.clearUpload();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Size> _getImageSize(Uint8List bytes) async {
    final completer = Completer<Size>();
    final image = Image.memory(bytes);
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

  Widget _buildUploadPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.upload_file_outlined,
            size: 56,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            'Click to upload ingredients image',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Supports JPG, PNG, and PDF files',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class UploadButton extends StatelessWidget {
  final UploadController controller;
  final VoidCallback onUploadSuccess;

  const UploadButton({
    super.key,
    required this.controller,
    required this.onUploadSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 800;
            final buttonHeight = isSmallScreen ? 44.0 : 52.0;

            return Container(
              width: double.infinity,
              height: buttonHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E40AF).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: controller.loading ? null : _handleUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: controller.loading
                    ? _buildLoadingContent()
                    : _buildNormalContent(isSmallScreen),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Uploading...',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildNormalContent(bool isSmallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.upload_file, size: 20),
        const SizedBox(width: 10),
        Text(
          'Upload Image',
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _handleUpload() async {
    try {
      await controller.uploadImage();
      onUploadSuccess();
    } catch (e) {
      // Error handling would be done here
    }
  }
}

// =============================================================================
// STATUS PANEL COMPONENT
// =============================================================================

class StatusPanel extends StatelessWidget {
  final UploadController controller;
  final VoidCallback onGenerateRecipe;
  final VoidCallback onGenerateInstant;
  final VoidCallback onGenerateFitness;

  const StatusPanel({
    super.key,
    required this.controller,
    required this.onGenerateRecipe,
    required this.onGenerateInstant,
    required this.onGenerateFitness,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return SingleChildScrollView(
          child: Column(
            children: [
              const StatusCard(),
              const SizedBox(height: 16),
              if (controller.isReadyForGeneration) ...[
                GenerateRecipeButton(onGenerateRecipe: onGenerateRecipe),
                const SizedBox(height: 12),
                GenerateInstantlyButton(onGenerateInstant: onGenerateInstant),
                const SizedBox(height: 12),
                GenerateFitnessButton(onGenerateFitness: onGenerateFitness),
              ],
            ],
          ),
        );
      },
    );
  }
}

class StatusCard extends StatelessWidget {
  const StatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 500;
        final padding = isSmallScreen ? 12.0 : 20.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Status',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              ListenableBuilder(
                listenable: context
                    .findAncestorStateOfType<_UploadImagePageState>()!
                    ._uploadController,
                builder: (context, child) {
                  final controller = context
                      .findAncestorStateOfType<_UploadImagePageState>()!
                      ._uploadController;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusItem(
                        'Upload',
                        controller.hasUploadedFile ? '✓' : '○',
                        controller.hasUploadedFile
                            ? const Color(0xFF059669)
                            : Colors.grey.shade400,
                        isSmallScreen,
                      ),
                      SizedBox(height: isSmallScreen ? 6 : 8),
                      _buildStatusItem(
                        'Ready',
                        controller.isReadyForGeneration ? '✓' : '○',
                        controller.isReadyForGeneration
                            ? const Color(0xFF059669)
                            : Colors.grey.shade400,
                        isSmallScreen,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusItem(
      String title, String status, Color color, bool isSmallScreen) {
    return Row(
      children: [
        Text(
          status,
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        SizedBox(width: isSmallScreen ? 6 : 8),
        Text(
          title,
          style: TextStyle(
            fontSize: isSmallScreen ? 11 : 13,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class GenerateRecipeButton extends StatelessWidget {
  final VoidCallback onGenerateRecipe;

  const GenerateRecipeButton({
    super.key,
    required this.onGenerateRecipe,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 500;
        final buttonHeight = isSmallScreen ? 36.0 : 44.0;

        if (!isSmallScreen) {
          // Desktop / large – previous layout
          return Container(
            width: double.infinity,
            height: buttonHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: onGenerateRecipe,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 16),
                  const SizedBox(width: 6),
                  const Text('Extract Labels',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 6),
                  _infoIcon(context, false),
                ],
              ),
            ),
          );
        }

        // Small screen – main action + separate grey info button (1/6 width)
        return SizedBox(
          height: buttonHeight,
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.analytics_outlined, size: 14),
                  label: const Text('Extract Labels',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  onPressed: onGenerateRecipe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Advanced Mode'),
                        content: const Text(_advancedModeBody),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: const Icon(Icons.info_outline, size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoIcon(BuildContext context, bool isSmallScreen) {
    return Tooltip(
      richMessage: TextSpan(
        children: [
          const TextSpan(
            text: 'Advanced Mode: Get Your Chef Hat On!\n\n',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: _advancedModeBody),
        ],
      ),
      waitDuration: const Duration(milliseconds: 300),
      child: Icon(
        Icons.info_outline,
        size: isSmallScreen ? 22 : 14,
        color: Colors.white,
      ),
    );
  }
}

class GenerateInstantlyButton extends StatelessWidget {
  final VoidCallback onGenerateInstant;

  const GenerateInstantlyButton({super.key, required this.onGenerateInstant});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 500;
        final buttonHeight = isSmallScreen ? 36.0 : 44.0;

        if (!isSmallScreen) {
          return Container(
            width: double.infinity,
            height: buttonHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: onGenerateInstant,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.flash_on, size: 16),
                  const SizedBox(width: 6),
                  const Text('Generate Instantly',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 6),
                  _infoIcon(context, false),
                ],
              ),
            ),
          );
        }

        // small screen
        return SizedBox(
          height: buttonHeight,
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.flash_on, size: 14),
                  label: const Text('Generate Instantly',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  onPressed: onGenerateInstant,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Quick Mode'),
                        content: const Text(_quickModeBody),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                  ),
                  child: const Icon(Icons.info_outline, size: 18, color: Colors.white),
                ),
              )
            ],
          ),
        );
      },
    );
  }
  Widget _infoIcon(BuildContext context, bool isSmallScreen) {
    return Tooltip(
      richMessage: TextSpan(
        children: [
          const TextSpan(
            text: 'Quick Mode: The "Abracadabra" of Recipes!\n\n',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: _quickModeBody),
        ],
      ),
      waitDuration: const Duration(milliseconds: 300),
      child: Icon(
        Icons.info_outline,
        size: isSmallScreen ? 22 : 14,
        color: Colors.white,
      ),
    );
  }
}

class GenerateFitnessButton extends StatelessWidget {
  final VoidCallback onGenerateFitness;

  const GenerateFitnessButton({super.key, required this.onGenerateFitness});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 500;
        final buttonHeight = isSmallScreen ? 36.0 : 44.0;
        if (!isSmallScreen) {
          return Container(
            width: double.infinity,
            height: buttonHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.fitness_center, size: 18),
              label: const Text(
                'Fitness Mode',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              onPressed: onGenerateFitness,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          );
        }

        // small screen
        return SizedBox(
          height: buttonHeight,
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.fitness_center, size: 14),
                  label: const Text('Fitness Mode',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  onPressed: onGenerateFitness,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Fitness Mode'),
                        content: const Text(_fitnessModeBody),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                  ),
                  child: const Icon(Icons.info_outline, size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

const String _advancedModeBody = 'Ready to get specific? In Advanced Mode, you\'re in full control.\n\nDouble-check your detected food items, then add important details like the meal type you\'re aiming for and any food restrictions to keep things delicious and safe.\n\nWe\'ll then present you with 3 tempting recipe suggestions for your discerning palate.\n\nIt\'s like building your perfect meal, brick by delicious brick!';

const String _quickModeBody = 'No time to spare? No problem! Quick Mode is our express lane to deliciousness.\n\nJust hit the button and we\'ll instantly conjure up a recipe for you.\n\nIt\'s the fastest way to go from "what should I eat?" to "yum!"';

const String _fitnessModeBody = 'In Fitness Mode, you can generate recipes tailored for fitness, and fill in your personal data such as height, weight, gender, age, and fitness goals. Great for meal planning, calorie control, and building a healthier diet!'; 