// lib/generating_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'recipe_page.dart';

class GeneratingPage extends StatefulWidget {
  final String imageUrl;
  final String mealType;
  final String dietaryGoal;
  final String? mealTime;
  final String? amountPeople;

  final List<Map<String, dynamic>>? manualLabels;

  const GeneratingPage({
    Key? key,
    required this.imageUrl,
    required this.mealType,
    required this.dietaryGoal,
    this.mealTime,
    this.amountPeople,
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
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first')),
      );
      Navigator.of(context).pop();
      return;
    }

    final uri = Uri.parse(
      'https://krvnkbsxrcwatmspecbw.functions.supabase.co/generate_recipe',
    );

    try {
      final body = <String, dynamic>{
        'image_url': widget.imageUrl,
        'meal_type': widget.mealType,
        'dietary_goal': widget.dietaryGoal,
      };
      if (widget.mealTime != null)    body['meal_time']      = widget.mealTime;
      if (widget.amountPeople!= null) body['amount_people']  = widget.amountPeople;
      if (widget.manualLabels != null) {
        body['manual_labels'] = widget.manualLabels;
      }

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode != 200) {
        throw Exception('Generation Failure ${resp.statusCode}: ${resp.body}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final recipe    = data['recipe']     as String  ;
      final items     = (data['items'] as List).cast<Map<String, dynamic>>();
      final videoUrl  = data['video_url'] as String?; 

      // Write history in Supabase.
      await supabase.from('history').insert({
        'user_id'     : supabase.auth.currentUser!.id,
        'image_url'   : widget.imageUrl,
        'meal_type'   : widget.mealType,
        'dietary_goal': widget.dietaryGoal,
        'detected_items': items,
        'recipe_html' : recipe,
        'video_url'   : videoUrl,
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RecipePage(
            imageUrl:      widget.imageUrl,
            recipe:        recipe,
            detectedItems: items,
            videoUrl:      videoUrl,
          ),
        ),
      );
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
