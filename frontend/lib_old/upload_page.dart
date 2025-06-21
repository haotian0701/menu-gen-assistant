// lib/upload_page.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' show basename;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'extraction_page.dart';
import 'account_icon_button.dart'; // Import the new widget

class UploadImagePage extends StatefulWidget {
  const UploadImagePage({Key? key}) : super(key: key);

  @override
  State<UploadImagePage> createState() => _UploadImagePageState();
}

class _UploadImagePageState extends State<UploadImagePage> {
  final _client = Supabase.instance.client;

  Uint8List? _fileBytes;
  String? _uploadedUrl;
  bool _loading = false;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _loading = true;
      _fileBytes = null; 
      _uploadedUrl = null;
    });

    final file = result.files.first;
    final bytes = file.bytes!;
    final origName = basename(file.name);
    final filename = '${DateTime.now().millisecondsSinceEpoch}_$origName';
    final path = 'public/$filename';

    try {
      await _client.storage.from('food-images').uploadBinary(path, bytes);
      final url = _client.storage.from('food-images').getPublicUrl(path);
      setState(() {
        _fileBytes = bytes;
        _uploadedUrl = url;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: \$e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onIdentifyPressed() {
    if (_uploadedUrl == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExtractionPage(
          imageUrl: _uploadedUrl!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload & Identify Items'),
        actions: const [
          AccountIconButton(),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Make buttons take full width
          children: [
            // Image Preview Section (now first)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: _fileBytes == null ? Colors.grey.shade50 : Colors.transparent,
                ),
                child: _fileBytes != null
                    ? ClipRRect( // Ensures image respects border radius
                        borderRadius: BorderRadius.circular(7.0), // Slightly less than container
                        child: Image.memory(
                          _fileBytes!,
                          fit: BoxFit.contain, // Scales down to fit, preserving aspect ratio
                        ),
                      )
                    : const Center(
                        child: Text(
                          'Image preview will appear here',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16), // Space after image preview

            // Select & Upload Image Button (now after image preview)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _loading ? null : _pickAndUpload,
              child: _loading
                  ? const SizedBox(
                      height: 24, // Consistent height for indicator
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Text('Select & Upload Image', style: TextStyle(fontSize: 16)),
            ),

            // Identify Items & Set Options Button (remains conditional and at the end)
            if (_uploadedUrl != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _onIdentifyPressed,
                child: const Text('Identify Items & Set Options', style: TextStyle(fontSize: 16)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
