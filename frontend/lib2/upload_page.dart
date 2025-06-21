// lib/upload_page.dart

import 'dart:typed_data';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' show basename;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'extraction_page.dart';
import 'account_icon_button.dart';

// =============================================================================
// MAIN PAGE CLASS
// =============================================================================

class UploadImagePage extends StatefulWidget {
  const UploadImagePage({Key? key}) : super(key: key);

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
      body: Column(
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
    );
  }

  void _handleUploadSuccess() {
    // Handle successful upload - URL is already stored in controller
  }

  void _handleGenerateRecipe() {
    if (_uploadController.uploadedUrl != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ExtractionPage(imageUrl: _uploadController.uploadedUrl!),
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

  @override
  void dispose() {
    super.dispose();
  }
}

// =============================================================================
// APP HEADER COMPONENT
// =============================================================================

class AppHeader extends StatelessWidget {
  const AppHeader({Key? key}) : super(key: key);

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
    Key? key,
    required this.isSmallScreen,
  }) : super(key: key);

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
  const NavigationSection({Key? key}) : super(key: key);

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
    Key? key,
    required this.controller,
    required this.onUploadSuccess,
  }) : super(key: key);

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
  const UploadHeader({Key? key}) : super(key: key);

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
    Key? key,
    required this.controller,
  }) : super(key: key);

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

            // Calculate scale to fit the image width exactly to the container width
            final containerWidth = constraints.maxWidth;
            final scale = containerWidth / imgSize.width;

            final displayWidth = imgSize.width * scale;
            final displayHeight = imgSize.height * scale;

            return SizedBox(
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
                        fit: BoxFit.cover,
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
    Key? key,
    required this.controller,
    required this.onUploadSuccess,
  }) : super(key: key);

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
                    : _buildNormalContent(),
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

  Widget _buildNormalContent() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.upload_file, size: 20),
        SizedBox(width: 10),
        Text(
          'Upload Image',
          style: TextStyle(
            fontSize: 16,
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

  const StatusPanel({
    Key? key,
    required this.controller,
    required this.onGenerateRecipe,
  }) : super(key: key);

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
              if (controller.isReadyForGeneration)
                GenerateRecipeButton(onGenerateRecipe: onGenerateRecipe),
            ],
          ),
        );
      },
    );
  }
}

class StatusCard extends StatelessWidget {
  const StatusCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 300;
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
    Key? key,
    required this.onGenerateRecipe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 300;
        final buttonHeight = isSmallScreen ? 36.0 : 44.0;

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
                Icon(
                  Icons.analytics_outlined,
                  size: isSmallScreen ? 14 : 16,
                ),
                SizedBox(width: isSmallScreen ? 4 : 6),
                Text(
                  'Identify Items',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
