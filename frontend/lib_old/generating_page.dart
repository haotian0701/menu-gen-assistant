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
  final String? restrictDiet;

  final List<Map<String, dynamic>>? manualLabels;

  const GeneratingPage({
    super.key,
    required this.imageUrl,
    required this.mealType,
    required this.dietaryGoal,
    this.mealTime,
    this.amountPeople,
    this.manualLabels,
    this.restrictDiet,
  });

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
    final supabaseInstance = Supabase.instance; // Get the Supabase instance
    final client = supabaseInstance.client; // Get the Supabase client instance

    // Correctly access the user's token from the current session
    final session = client.auth.currentSession;
    final accessToken = session?.accessToken; 
    final anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtydm5rYnN4cmN3YXRtc3BlY2J3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUwMzk2MjEsImV4cCI6MjA2MDYxNTYyMX0.ZzkcN4D3rXOjVkoTyTCq3GK7ArHNnYY6AfFB2_HXtNE";


    // Ensure we have either an access token or the anon key for the Authorization header
    if (accessToken == null && anonKey == null) {
       print('Error: Neither access token nor anon key is available.');
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Authentication keys not available.')),
          );
          Navigator.of(context).pop(); // Go back
       }
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
        'mode': (widget.manualLabels != null && widget.manualLabels!.isNotEmpty) ? null : 'extract_first',
      };

      if (widget.mealTime != null) body['meal_time'] = widget.mealTime;
      if (widget.amountPeople != null) body['amount_people'] = widget.amountPeople;
      if (widget.restrictDiet != null) body['restrict_diet'] = widget.restrictDiet;

      if (widget.manualLabels != null && widget.manualLabels!.isNotEmpty) {
        body['manual_labels'] = widget.manualLabels;
        if (body.containsKey('mode') && body['mode'] == 'extract_first') {
          body.remove('mode');
        }
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${accessToken ?? anonKey}', // Use accessToken or fallback to anonKey
      };

      final resp = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );

      if (resp.statusCode != 200) {
        throw Exception('Generation Failure ${resp.statusCode}: ${resp.body}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final recipe = data['recipe'] as String;
      final items = (data['items'] as List).cast<Map<String, dynamic>>();
      final videoUrl = data['video_url'] as String?;

      // Conditionally write history in Supabase.
      final user = client.auth.currentUser; // Get the current user again
      if (user != null) { // Only save to history if user is logged in
        await client.from('history').insert({
          'user_id': user.id,
          'image_url': widget.imageUrl,
          'meal_type': widget.mealType,
          'dietary_goal': widget.dietaryGoal,
          'detected_items': items,
          'recipe_html': recipe,
          'video_url': videoUrl,
          'amount_people': widget.amountPeople,
          'meal_time': widget.mealTime,
          'restrict_diet': widget.restrictDiet,
        });
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RecipePage(
            imageUrl:      widget.imageUrl,
            recipe:        recipe,
            detectedItems: items,
            videoUrl:      videoUrl,
            mealType: widget.mealType,
            dietaryGoal: widget.dietaryGoal,
            mealTime: widget.mealTime ?? '',
            amountPeople: widget.amountPeople ?? '',
            restrictDiet: widget.restrictDiet ?? '',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error generating recipe: $e')),
         );
         Navigator.of(context).pop();
      }
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