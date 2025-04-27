import 'package:flutter/material.dart';

class RecipePage extends StatelessWidget {
  final String imageUrl;
  final List<String> labels;
  final String recipe;

  const RecipePage({
    Key? key,
    required this.imageUrl,
    required this.labels,
    required this.recipe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Recipe')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(imageUrl, height: 200, fit: BoxFit.cover),
            const SizedBox(height: 16),
            const Text('Detected Ingredients:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: labels.map((l) => Chip(label: Text(l))).toList(),
            ),
            const Divider(height: 32),
            const Text('Recipe:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(recipe),
          ],
        ),
      ),
    );
  }
}
