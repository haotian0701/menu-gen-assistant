// lib/history_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'recipe_page.dart';
import 'account_icon_button.dart'; // Import the new widget
import 'main.dart'; // For AuthPage

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

  @override
  void initState() {
    super.initState();
    _loadHistory();
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
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _records.isEmpty
                      ? const Center(child: Text('No history available'))
                      : ListView.builder(
                          itemCount: _records.length,
                          itemBuilder: (context, i) {
                            final rec = _records[i];
                            final imageUrl = rec['image_url'] as String;
                            final mealType = rec['meal_type'] as String;
                            final dietaryGoal = rec['dietary_goal'] as String;
                            final createdAt = _formatDate(rec['created_at'] as String);

                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  imageUrl,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image),
                                ),
                              ),
                              title: Text(
                                '${mealType[0].toUpperCase()}${mealType.substring(1)} · $dietaryGoal',
                              ),
                              subtitle: Text(createdAt),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                final recipeHtml = rec['recipe_html'] as String;
                                final items = (rec['detected_items'] as List)
                                    .cast<Map<String, dynamic>>();
                                // Retrieve the additional required fields from the record
                                // Provide default values if they might be null in the database
                                final mealTime = rec['meal_time'] as String? ?? ''; // Correctly read
                                final amountPeople = rec['amount_people'] as String? ?? ''; // Correctly read
                                final restrictDiet = rec['restrict_diet'] as String? ?? ''; // Will default to '' if column is missing

                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RecipePage(
                                      imageUrl: imageUrl,
                                      recipe: recipeHtml,
                                      detectedItems: items,
                                      mealType: mealType, 
                                      dietaryGoal: dietaryGoal, 
                                      mealTime: mealTime,
                                      amountPeople: amountPeople,
                                      restrictDiet: restrictDiet, // This will be '' if not in DB
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
    );
  }
}
