// lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'upload_page.dart'; // Ensure this is the correct import for UploadImagePage
import 'account_icon_button.dart'; 

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Menu Generator',
      theme: ThemeData(primarySwatch: Colors.teal),
      // Always start with UploadImagePage, auth state will be handled by AccountIconButton and page logic
      home: const UploadImagePage(),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameController = TextEditingController(); // Added for username
  bool _isLogin = true; // To toggle between Login and Sign Up view
  bool _loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose(); // Dispose username controller
    super.dispose();
  }

  Future<void> _signUp() async {
    if (usernameController.text.trim().isEmpty && !_isLogin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot be empty for sign-up.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
        data: { // Store username in user_metadata
          'username': usernameController.text.trim(),
        },
      );
      if (mounted) {
        if (res.user != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign-up successful! Please log in.')),
          );
          setState(() {
            _isLogin = true; // Switch to login view after successful sign up
            passwordController.clear(); // Clear password for login
          });
        } else if (res.session == null && res.user == null) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign-up successful! Check your email for verification.')),
          );
          setState(() {
            _isLogin = true;
            passwordController.clear();
          });
        }
         else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.user?.toString() ?? 'Sign-up failed. User might already exist or email needs confirmation.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during sign-up: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final res = await supabase.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      if (mounted) {
        if (res.user != null) {
          // Navigate back to the previous page or to UploadImagePage
          // If AuthPage was pushed, Navigator.pop(context) is enough
          // If it's a replacement, then pushReplacement to UploadImagePage
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const UploadImagePage()),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed. Check credentials.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during login: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView( // Added SingleChildScrollView for smaller screens
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isLogin) // Show username field only for sign-up
                      TextField(
                        controller: usernameController,
                        decoration: const InputDecoration(labelText: 'Username'),
                        textInputAction: TextInputAction.next,
                      ),
                    if (!_isLogin) const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _isLogin ? _login() : _signUp(),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLogin ? _login : _signUp,
                      child: Text(_isLogin ? 'Log In' : 'Sign Up'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                        });
                      },
                      child: Text(
                        _isLogin
                            ? 'Need an account? Sign Up'
                            : 'Have an account? Log In',
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
