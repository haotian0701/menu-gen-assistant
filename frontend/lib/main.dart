// lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'upload_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://krvnkbsxrcwatmspecbw.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtydm5rYnN4cmN3YXRtc3BlY2J3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUwMzk2MjEsImV4cCI6MjA2MDYxNTYyMX0.ZzkcN4D3rXOjVkoTyTCq3GK7ArHNnYY6AfFB2_HXtNE',
    debug: true,
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Menu Generator',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: user == null ? const AuthPage() : const UploadImagePage(),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    setState(() => _loading = true);
    try {
      final res = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      if (res.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-up successful!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-up failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during sign-up: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final res = await supabase.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      if (res.user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UploadImagePage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during login: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login / Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _login,
                    child: const Text('Log In'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _signUp,
                    child: const Text('Sign Up'),
                  ),
                ],
              ),
      ),
    );
  }
}
