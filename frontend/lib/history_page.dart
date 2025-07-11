// lib/history_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'recipe_page.dart';
import 'account_icon_button.dart'; // Import the new widget
import 'main.dart'; // For AuthPage
import 'animated_loading.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _records = [];
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    
    // Listen for auth state changes
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      // Reload history when auth state changes
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _error = 'Please log in to view your history.';
        _loading = false;
        _records = []; // Clear any existing records
      });
      return;
    }

    try {
      final userId = currentUser.id;
      final List<Map<String, dynamic>> records = await _supabase
        .from('history')
        .select() 
        .eq('user_id', userId)
        .order('created_at', ascending: false);

      setState(() {
        _records = records;
      });
    } on PostgrestException catch (err) {
      setState(() {
        _error = 'Failed to load history：${err.message}';
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load history：$e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }



  String _formatDate(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
           '${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:'
           '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _supabase.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My History'),
        actions: [
          const AccountIconButton(), // Add the new account icon button
          // Remove the old refresh button if AccountIconButton handles navigation well
          // or keep it if direct refresh is desired. For now, let's keep it.
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory, // Keep refresh if needed
          ),
        ],
      ),
      body: currentUser == null // Check if user is null for body rendering
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Please log in to view your history.'),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement( // Or push
                        MaterialPageRoute(builder: (_) => const AuthPage()),
                      );
                    },
                    child: const Text('Log In / Sign Up'),
                  )
                ],
              ),
            )
          : _loading
              ? const AnimatedLoadingWidget(type: LoadingType.loading)
              : _error != null
                  ? Center(child: Text(_error!))
                  : _records.isEmpty
                      ? const Center(child: Text('No history available'))
                      : _buildGroupedListView(),
    );
  }
  Widget _buildGroupedListView() {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (var rec in _records) {
      final mt = rec['meal_type'] as String? ?? '';
      final dg = rec['dietary_goal'] as String? ?? '';
      final rd = rec['restrict_diet'] as String? ?? '';
      final parts = <String>[];
      if (mt.isNotEmpty) parts.add(mt);
      if (dg.isNotEmpty && dg != 'normal') parts.add(dg);
      if (rd.isNotEmpty && rd != 'None') parts.add(rd);
      final category = parts.isNotEmpty ? parts.join(' · ') : 'Uncategorized';
      groups.putIfAbsent(category, () => []).add(rec);
    }

    final children = <Widget>[];
    groups.forEach((category, recs) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            category.toUpperCase(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      );
      for (var rec in recs) {
        // Distinct user-uploaded vs generated preview
        final uploadedUrl = rec['image_url'] as String;
        final previewUrl = (rec['main_image_url'] as String?)?.isNotEmpty == true
            ? rec['main_image_url'] as String
            : uploadedUrl;
        final createdAt = _formatDate(rec['created_at'] as String);
        String title = (rec['recipe_title'] as String?)?.trim() ?? '';
        if (title.isEmpty) {
          final rawHtml = rec['recipe_html'] as String? ?? '';
          final match = RegExp(r"<h1[^>]*>(.*?)<\/h1>", caseSensitive: false)
              .firstMatch(rawHtml);
          title = match?.group(1)?.trim() ?? 'Untitled Recipe';
        }
        // Decode HTML entities in the title
        title = _decodeHtmlEntities(title); 
        children.add(
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                previewUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
              ),
            ),
            title: Text(title),
            subtitle: Text(createdAt),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final recipeHtml = rec['recipe_html'] as String;
              final items = (rec['detected_items'] as List)
                  .cast<Map<String, dynamic>>();
              final mealTime = rec['meal_time'] as String? ?? '';
              final amountPeople = rec['amount_people'] as String? ?? '';
              final restrictDiet = rec['restrict_diet'] as String? ?? '';
              final isFitnessMode = rec['is_fitness_mode'] as bool? ?? false;
              final nutritionInfo = rec['nutrition_info'] != null
                  ? (rec['nutrition_info'] as Map<String, dynamic>).map(
                      (key, value) => MapEntry(key, (value as num).toDouble()),
                    )
                  : null;

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RecipePage(
                    imageUrl: uploadedUrl,
                    mainImageUrl: previewUrl,
                    recipe: recipeHtml,
                    detectedItems: items,
                    mealType: rec['meal_type'] as String? ?? '',
                    dietaryGoal: rec['dietary_goal'] as String? ?? '',
                    mealTime: mealTime,
                    amountPeople: amountPeople,
                    restrictDiet: restrictDiet,
                    isFitnessMode: isFitnessMode,
                    nutritionInfo: nutritionInfo,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
              );
            },
          ),
        );
      }
    });

    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: children,
    );
  }
}

// Helper function to decode HTML entities
String _decodeHtmlEntities(String text) {
  return text
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&copy;', '©')
      .replaceAll('&reg;', '®')
      .replaceAll('&trade;', '™');
}