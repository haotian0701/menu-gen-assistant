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

  final _mealTime = ['fast', 'medium', 'long'];
  final _amountPeople = ['1', '2', '4'];
  String _selectedTime = 'fast';
  String _selectedPeople = '2';

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
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
            mealTime: _selectedTime,
            amountPeople: _selectedPeople),
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
                SelectableText(_uploadedUrl!,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              if (_uploadedUrl != null) ...[
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        const Text('Meal:'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDropdown(_selectedMeal, _mealTypes, (v) {
                            setState(() => _selectedMeal = v!);
                          }),
                        ),
                        const SizedBox(width: 16),
                        const Text('Goal:'),
                        const SizedBox(width: 8),
                        Expanded(
                          child:
                              _buildDropdown(_selectedGoal, _dietaryGoals, (v) {
                            setState(() => _selectedGoal = v!);
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Time:'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDropdown(_selectedTime, _mealTime, (v) {
                            setState(() => _selectedTime = v!);
                          }),
                        ),
                        const SizedBox(width: 16),
                        const Text('People:'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDropdown(_selectedPeople, _amountPeople,
                              (v) {
                            setState(() => _selectedPeople = v!);
                          }),
                        ),
                      ],
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

Widget _buildDropdown(
    String value, List<String> items, void Function(String?) onChanged) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      border: Border.all(color: Colors.grey.shade400),
      borderRadius: BorderRadius.circular(8),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        value: value,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    ),
  );
}
