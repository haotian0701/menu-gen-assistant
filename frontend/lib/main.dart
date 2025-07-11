// lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
    
    // If no specific error is matched, return a generic message
    return 'An error occurred. Please try again later.';
  }

  Future<void> _signInWithGoogle() async {
    _clearError();
    setState(() => _loading = true);
    
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.app://callback',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Successfully signed in with Google!'),
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

  Future<void> _signInWithApple() async {
    if (!Platform.isIOS) {
      setState(() {
        _errorMessage = 'Apple Sign In is only available on iOS devices';
      });
      return;
    }
    
    _clearError();
    setState(() => _loading = true);
    
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      
      final res = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: credential.identityToken!,
        nonce: credential.authorizationCode,
      );
      
      if (mounted) {
        if (res.user != null && res.session != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Successfully signed in with Apple!'),
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
            _errorMessage = 'Apple Sign In failed. Please try again.';
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
        title: Text(_isLogin ? 'Sign In' : 'Create Account'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF374151),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 600;
            final isMobilePortrait = constraints.maxHeight > constraints.maxWidth && isSmallScreen;
            
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 32,
                  vertical: isSmallScreen ? 16 : 24,
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isSmallScreen ? double.infinity : 420,
                    minHeight: isMobilePortrait ? constraints.maxHeight * 0.6 : 0,
                  ),
                  padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: isSmallScreen ? 12 : 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _loading
                      ? SizedBox(
                          height: 200,
                          child: const AnimatedLoadingWidget(type: LoadingType.loading),
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Header section
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isLogin ? Icons.login : Icons.person_add,
                                      size: isSmallScreen ? 32 : 40,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 16 : 20),
                                  Text(
                                    _isLogin ? 'Welcome Back!' : 'Join Cookpilot',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 24 : 28,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _isLogin 
                                        ? 'Sign in to access your recipes and preferences'
                                        : 'Create an account to save recipes and personalize your experience',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14 : 16,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isSmallScreen ? 24 : 32),
                              
                              // Form fields
                              if (!_isLogin)
                                Column(
                                  children: [
                                    TextFormField(
                                      controller: usernameController,
                                      decoration: InputDecoration(
                                        labelText: 'Username',
                                        prefixIcon: const Icon(Icons.person_outline),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                      ),
                                      textInputAction: TextInputAction.next,
                                      validator: _validateUsername,
                                      onChanged: (_) => _clearError(),
                                    ),
                                    SizedBox(height: isSmallScreen ? 16 : 20),
                                  ],
                                ),
                              TextFormField(
                                controller: emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: _validateEmail,
                                onChanged: (_) => _clearError(),
                              ),
                              SizedBox(height: isSmallScreen ? 16 : 20),
                              TextFormField(
                                controller: passwordController,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                validator: _validatePassword,
                                onChanged: (_) => _clearError(),
                                onFieldSubmitted: (_) => _isLogin ? _login() : _signUp(),
                              ),
                              
                              // Error message
                              if (_errorMessage != null) ...[
                                SizedBox(height: isSmallScreen ? 16 : 20),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.red.shade700,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              
                              SizedBox(height: isSmallScreen ? 24 : 32),
                              
                              // Main action button
                              SizedBox(
                                height: isSmallScreen ? 48 : 52,
                                child: ElevatedButton(
                                  onPressed: _isLogin ? _login : _signUp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    _isLogin ? 'Sign In' : 'Create Account',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 16 : 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              
                              SizedBox(height: isSmallScreen ? 20 : 24),
                              
                              // OAuth divider and buttons
                              Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.grey.shade300)),
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
                                  Expanded(child: Divider(color: Colors.grey.shade300)),
                                ],
                              ),
                              
                              SizedBox(height: isSmallScreen ? 20 : 24),
                              
                              // OAuth buttons
                              Row(
                                children: [
                                  // Google Sign In
                                  Expanded(
                                    child: SizedBox(
                                      height: isSmallScreen ? 48 : 52,
                                      child: OutlinedButton.icon(
                                        onPressed: _signInWithGoogle,
                                        icon: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: const BoxDecoration(
                                            image: DecorationImage(
                                              image: NetworkImage('https://developers.google.com/identity/images/g-logo.png'),
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                        label: Text(
                                          'Google',
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 14 : 16,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF374151),
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: const Color(0xFF374151),
                                          side: BorderSide(color: Colors.grey.shade300),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 12),
                                  
                                  // Apple Sign In (only show on iOS or for demonstration)
                                  Expanded(
                                    child: SizedBox(
                                      height: isSmallScreen ? 48 : 52,
                                      child: OutlinedButton.icon(
                                        onPressed: Platform.isIOS ? _signInWithApple : () {
                                          setState(() {
                                            _errorMessage = 'Apple Sign In is only available on iOS devices';
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.apple,
                                          size: 20,
                                          color: Color(0xFF000000),
                                        ),
                                        label: Text(
                                          'Apple',
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 14 : 16,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF374151),
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: const Color(0xFF374151),
                                          side: BorderSide(color: Colors.grey.shade300),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: isSmallScreen ? 20 : 24),
                              
                              // Switch mode button
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
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    vertical: isSmallScreen ? 12 : 16,
                                  ),
                                ),
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14 : 16,
                                      color: const Color(0xFF6B7280),
                                    ),
                                    children: [
                                      TextSpan(
                                        text: _isLogin
                                            ? "Don't have an account? "
                                            : 'Already have an account? ',
                                      ),
                                      TextSpan(
                                        text: _isLogin ? 'Sign Up' : 'Sign In',
                                        style: const TextStyle(
                                          color: Color(0xFF10B981),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

