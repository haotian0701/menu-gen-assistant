// lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'upload_page.dart'; // Ensure this is the correct import for UploadImagePage
import 'animated_loading.dart';

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    
    // Listen to auth state changes
    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      
      if (event == AuthChangeEvent.signedIn && session != null) {
        // User signed in successfully
        print('User signed in: ${session.user.email}');
        
        // Show success message if we have a context
        if (mounted) {
          // You can add a global success notification here if needed
          print('Authentication successful!');
        }
      } else if (event == AuthChangeEvent.signedOut) {
        print('User signed out');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cookpilot Recipe Assistant',
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
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true; // To toggle between Login and Sign Up view
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose(); // Dispose username controller
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    return null;
  }

  String? _validateUsername(String? value) {
    if (!_isLogin) {
      if (value == null || value.trim().isEmpty) {
        return 'Username is required';
      }
      
      if (value.trim().length < 3) {
        return 'Username must be at least 3 characters';
      }
      
      final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
      if (!usernameRegex.hasMatch(value.trim())) {
        return 'Username can only contain letters, numbers, and underscores';
      }
    }
    
    return null;
  }

  String _getReadableErrorMessage(String error) {
    final lowerError = error.toLowerCase();
    
    if (lowerError.contains('invalid login credentials') || 
        lowerError.contains('invalid_credentials')) {
      return 'Invalid email or password. Please check your credentials and try again.';
    }
    
    if (lowerError.contains('email not confirmed') || 
        lowerError.contains('email_not_confirmed')) {
      return 'Please check your email and click the confirmation link before signing in.';
    }
    
    if (lowerError.contains('user already registered') || 
        lowerError.contains('user_already_exists')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    
    if (lowerError.contains('weak password') || 
        lowerError.contains('password')) {
      return 'Password is too weak. Please use at least 6 characters.';
    }
    
    if (lowerError.contains('invalid email') || 
        lowerError.contains('email')) {
      return 'Please enter a valid email address.';
    }
    
    if (lowerError.contains('network') || 
        lowerError.contains('connection')) {
      return 'Network error. Please check your internet connection and try again.';
    }
    
    if (lowerError.contains('rate limit') || 
        lowerError.contains('too many')) {
      return 'Too many attempts. Please wait a few minutes before trying again.';
    }
    
    if (lowerError.contains('oauth') || 
        lowerError.contains('provider')) {
      return 'OAuth sign-in failed. Please try again or use email/password instead.';
    }
    
    if (lowerError.contains('cancelled') || 
        lowerError.contains('canceled')) {
      return 'Sign-in was cancelled. Please try again.';
    }
    
    // If no specific error is matched, return a generic message
    return 'An error occurred. Please try again later.';
  }

  Future<void> _signInWithGitHub() async {
    _clearError();
    setState(() => _loading = true);
    
    try {
      // Let Supabase handle the redirect automatically
      // This will work for both localhost and production (Netlify)
      await supabase.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: Uri.base.toString(),
      );
      
      // The redirect will be handled automatically by Supabase
      // No need for manual navigation on web
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getReadableErrorMessage(e.message);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getReadableErrorMessage(e.toString());
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    _clearError();
    setState(() => _loading = true);
    
    try {
      final res = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
        data: {
          // Store username in user_metadata
          'username': usernameController.text.trim(),
        },
      );
      
      if (mounted) {
        if (res.user != null && res.session != null) {
          // User is immediately signed in
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Account created successfully!'),
                ],
              ),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          Navigator.pop(context);
        } else if (res.user != null && res.session == null) {
          // Email confirmation required
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.email, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Please check your email and click the confirmation link to activate your account.'),
                  ),
                ],
              ),
              backgroundColor: Color(0xFF3B82F6),
              duration: Duration(seconds: 5),
            ),
          );
          setState(() {
            _isLogin = true; // Switch to login view after successful sign up
            passwordController.clear(); // Clear password for login
          });
        } else {
          setState(() {
            _errorMessage = 'Sign-up failed. Please try again.';
          });
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getReadableErrorMessage(e.message);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getReadableErrorMessage(e.toString());
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    _clearError();
    setState(() => _loading = true);
    
    try {
      final res = await supabase.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      
      if (mounted) {
        if (res.user != null && res.session != null) {
          // Successful login
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Welcome back!'),
                ],
              ),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          
          // Navigate back to the previous page or to UploadImagePage
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const UploadImagePage()),
            );
          }
        } else {
          setState(() {
            _errorMessage = 'Login failed. Please check your credentials.';
          });
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getReadableErrorMessage(e.message);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getReadableErrorMessage(e.toString());
        });
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
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/app_icon.png',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.restaurant, size: 24);
              },
            ),
            const SizedBox(width: 8),
            Text(_isLogin ? 'Cookpilot - Login' : 'Cookpilot - Sign Up'),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: _loading
                ? const AnimatedLoadingWidget(type: LoadingType.loading)
                : Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_isLogin)
                          TextFormField(
                            controller: usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              border: OutlineInputBorder(),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: _validateUsername,
                            onChanged: (_) => _clearError(),
                          ),
                        if (!_isLogin) const SizedBox(height: 16),
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: _validateEmail,
                          onChanged: (_) => _clearError(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          validator: _validatePassword,
                          onChanged: (_) => _clearError(),
                          onFieldSubmitted: (_) => _isLogin ? _login() : _signUp(),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLogin ? _login : _signUp,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _isLogin ? 'Log In' : 'Sign Up',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // OAuth divider and buttons
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade400)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade400)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // OAuth buttons
                        // GitHub Sign In
                        OutlinedButton.icon(
                          onPressed: _signInWithGitHub,
                          icon: const Icon(
                            Icons.code,
                            size: 20,
                            color: Colors.black,
                          ),
                          label: const Text(
                            'Continue with GitHub',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            _clearError();
                            setState(() {
                              _isLogin = !_isLogin;
                              // Clear form when switching modes
                              if (_isLogin) {
                                usernameController.clear();
                              }
                            });
                          },
                          child: Text(
                            _isLogin
                                ? 'Need an account? Sign Up'
                                : 'Have an account? Log In',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

