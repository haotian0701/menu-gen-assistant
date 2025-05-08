// lib/history_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'recipe_page.dart';

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

    try {
      final userId = _supabase.auth.currentUser!.id;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _loading
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
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RecipePage(
                                  imageUrl: imageUrl,
                                  recipe: recipeHtml,
                                  detectedItems: items,
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
