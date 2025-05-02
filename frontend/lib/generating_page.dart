// generating_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'recipe_page.dart';

class GeneratingPage extends StatefulWidget {
  final String imageUrl;
  final String mealType;
  final String dietaryGoal;
  final List<Map<String, dynamic>>? manualLabels;

  const GeneratingPage({
    Key? key,
    required this.imageUrl,
    required this.mealType,
    required this.dietaryGoal,
    this.manualLabels,
  }) : super(key: key);

  @override
  State<GeneratingPage> createState() => _GeneratingPageState();
}

class _GeneratingPageState extends State<GeneratingPage> {
  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final supabase = Supabase.instance.client;
    final accessToken = supabase.auth.currentSession?.accessToken;

    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first.')),
      );
      Navigator.of(context).pop();
      return;
    }

    final uri = Uri.parse('https://krvnkbsxrcwatmspecbw.functions.supabase.co/generate_recipe');

    try {
      final Map<String, dynamic> body = {
        'image_url': widget.imageUrl,
        'meal_type': widget.mealType,
        'dietary_goal': widget.dietaryGoal,
      };

      if (widget.manualLabels != null) {
        body['manual_labels'] = widget.manualLabels;
      }

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final recipe = data['recipe'] as String? ?? 'No recipe generated.';
        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => RecipePage(
                imageUrl: widget.imageUrl,
                recipe: recipe,
                detectedItems: items,
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation error: ${resp.body}')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generating...')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Generating your recipe...'),
          ],
        ),
      ),
    );
  }
}
