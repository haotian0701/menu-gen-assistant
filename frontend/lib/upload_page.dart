// File 1: upload_page.dart (modified to go to extraction_page instead of generating_page)
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' show basename;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'extraction_page.dart';

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

  final _mealTypes = ['breakfast', 'lunch', 'dinner'];
  final _dietaryGoals = ['normal', 'fat_loss', 'muscle_gain'];
  String _selectedMeal = 'dinner';
  String _selectedGoal = 'normal';

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _loading = true;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
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
          mealType: _selectedMeal,
          dietaryGoal: _selectedGoal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload & Identify Items')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: _loading ? null : _pickAndUpload,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Select & Upload Image'),
              ),
              if (_fileBytes != null) ...[
                const SizedBox(height: 16),
                Image.memory(_fileBytes!, height: 200),
                const SizedBox(height: 8),
                SelectableText(_uploadedUrl!, style: Theme.of(context).textTheme.bodySmall),
              ],
              if (_uploadedUrl != null) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Meal: '),
                    DropdownButton<String>(
                      value: _selectedMeal,
                      items: _mealTypes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) => setState(() => _selectedMeal = v!),
                    ),
                    const SizedBox(width: 32),
                    const Text('Goal: '),
                    DropdownButton<String>(
                      value: _selectedGoal,
                      items: _dietaryGoals.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (v) => setState(() => _selectedGoal = v!),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _onIdentifyPressed,
                  child: const Text('Identify Items'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
