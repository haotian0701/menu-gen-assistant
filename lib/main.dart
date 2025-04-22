import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'upload_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://krvnkbsxrcwatmspecbw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtydm5rYnN4cmN3YXRtc3BlY2J3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUwMzk2MjEsImV4cCI6MjA2MDYxNTYyMX0.ZzkcN4D3rXOjVkoTyTCq3GK7ArHNnYY6AfFB2_HXtNE',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Auth Demo',
      home: AuthPage(),
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

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> signUp() async {
    try {
      final res = await supabase.auth.signUp(
        email: emailController.text,
        password: passwordController.text,
      );
      if (res.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign‑up successful!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign‑up failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during sign‑up: $e')),
      );
    }
  }

  Future<void> login() async {
    try {
      final res = await supabase.auth.signInWithPassword(
        email: emailController.text,
        password: passwordController.text,
      );
      if (res.user != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UploadPage()),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login / Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
            ElevatedButton(onPressed: login,  child: const Text('Log In')),
            ElevatedButton(onPressed: signUp, child: const Text('Sign Up')),
          ],
        ),
      ),
    );
  }
}

// You can remove WelcomePage if unused, or translate its text similarly
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Center(
        child: Text('Hello, ${user?.email ?? "User"}!'),
      ),
    );
  }
}
