import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'recipe_page.dart';

class GeneratingPage extends StatefulWidget {
  final String imageUrl;
  final String mealType;
  final String dietaryGoal;

  const GeneratingPage({
    Key? key,
    required this.imageUrl,
    required this.mealType,
    required this.dietaryGoal,
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
    final uri = Uri.parse('http://localhost:8000/generate_recipe');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'image_url':    widget.imageUrl,
        'meal_type':    widget.mealType,
        'dietary_goal': widget.dietaryGoal,
      }),
    );

    if (resp.statusCode == 200) {
      final data   = jsonDecode(resp.body);
      final labels = List<String>.from(data['labels']);
      final recipe = data['recipe'] as String;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RecipePage(
            imageUrl: widget.imageUrl,
            labels:   labels,
            recipe:   recipe,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generation error: ${resp.body}')),
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
