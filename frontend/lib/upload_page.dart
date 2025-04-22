// lib/upload_page.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' show basename;
import 'package:supabase_flutter/supabase_flutter.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  Uint8List? _fileBytes;
  String? _uploadedUrl;
  bool _loading = false;
  final _client = Supabase.instance.client;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _loading = true);

    final file     = result.files.first;
    final bytes    = file.bytes!;
    final origName = basename(file.name);
    // Prepend a timestamp to guarantee uniqueness
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename  = '${timestamp}_$origName';
    final path      = 'public/$filename';

    try {
      // Upload the uniquely‑named file
      await _client.storage.from('food-images').uploadBinary(path, bytes);
      final url = _client.storage.from('food-images').getPublicUrl(path);

      // Insert placeholder menu record
      await _client.from('menus').insert({
        'user_id':   _client.auth.currentUser!.id,
        'image_url': url,
        'menu_text': 'Generating…',
      });

      setState(() {
        _fileBytes   = bytes;
        _uploadedUrl = url;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload successful!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Food Image')),
      body: Center(
        child: _loading
          ? const CircularProgressIndicator()
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_fileBytes != null)
                  Image.memory(_fileBytes!, height: 200),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _pickAndUpload,
                  child: const Text('Select & Upload Image'),
                ),
                if (_uploadedUrl != null) ...[
                  const SizedBox(height: 12),
                  Text('Uploaded to:', style: Theme.of(context).textTheme.bodySmall),
                  Text(_uploadedUrl!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
      ),
    );
  }
}
