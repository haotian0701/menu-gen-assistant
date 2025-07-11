import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'recipe_page.dart';
import 'account_icon_button.dart';
import 'main.dart'; // For AuthPage
import 'animated_loading.dart';

class SavedRecipesPage extends StatefulWidget {
  const SavedRecipesPage({super.key});

  @override
  State<SavedRecipesPage> createState() => _SavedRecipesPageState();
}

class _SavedRecipesPageState extends State<SavedRecipesPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _loadSavedRecipes();
  }

  Future<void> _loadSavedRecipes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Please log in to view saved recipes.';
        _loading = false;
        _records = [];
      });
      return;
    }
    try {
      final List<Map<String, dynamic>> records = await _supabase
          .from('saved_recipes')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      setState(() => _records = records);
    } on PostgrestException catch (err) {
      setState(() {
        _error = 'Failed to load saved recipes: ${err.message}';
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load saved recipes: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatDate(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')} '
           '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  Future<void> _unsaveRecipe(String id) async {
    try {
      await _supabase.from('saved_recipes').delete().eq('id', id);
      _loadSavedRecipes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove recipe: $e'), backgroundColor: Colors.redAccent),
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

  @override
  Widget build(BuildContext context) {
    final currentUser = _supabase.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Recipes'),
        actions: [
          const AccountIconButton(),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSavedRecipes),
        ],
      ),
      body: currentUser == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Please log in to view saved recipes.'),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const AuthPage()),
                    ),
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
                      ? const Center(child: Text('No saved recipes'))
                      : ListView.builder(
                          itemCount: _records.length,
                          itemBuilder: (context, i) {
                            final rec = _records[i];
                            // Distinguish user-uploaded vs generated preview
                            final uploadedUrl = rec['image_url'] as String;
                            final previewUrl = (rec['main_image_url'] as String?)?.isNotEmpty == true
                                ? rec['main_image_url'] as String
                                : uploadedUrl;
                            final createdAt = _formatDate(rec['created_at'] as String);
                            var title = (rec['recipe_title'] as String?)?.trim() ?? '';
                            if (title.isEmpty) title = 'Untitled Recipe';
                            // Decode HTML entities in the title
                            title = _decodeHtmlEntities(title);
                            return ListTile(
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
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Unsave Recipe',
                                onPressed: () => _unsaveRecipe(rec['id'] as String),
                              ),
                              onTap: () {
                                final recipeHtml = rec['recipe_content'] as String;
                                final items = (rec['detected_items'] as List?)
                                    ?.cast<Map<String, dynamic>>()
                                    ?? <Map<String, dynamic>>[];
                                final videoUrl = rec['video_url'] as String?;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RecipePage(
                                      imageUrl: uploadedUrl,
                                      recipe: recipeHtml,
                                      detectedItems: items,
                                      videoUrl: videoUrl,
                                      mealType: rec['meal_type'] as String? ?? '',
                                      dietaryGoal: rec['dietary_goal'] as String? ?? '',
                                      mealTime: rec['meal_time'] as String? ?? '',
                                      amountPeople: rec['amount_people'] as String? ?? '',
                                      restrictDiet: rec['restrict_diet'] as String? ?? '',
                                      mainImageUrl: previewUrl,
                                      isFitnessMode: rec['is_fitness_mode'] as bool? ?? false,
                                      nutritionInfo: (rec['nutrition_info'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toDouble())),
                                      onBack: () => Navigator.of(context).pop(),
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
