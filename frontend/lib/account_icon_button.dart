import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async'; // Import for StreamSubscription
import 'main.dart'; // For AuthPage
import 'history_page.dart'; // For HistoryPage

class AccountIconButton extends StatefulWidget {
  const AccountIconButton({super.key});

  @override
  State<AccountIconButton> createState() => _AccountIconButtonState();
}

class _AccountIconButtonState extends State<AccountIconButton> {
  User? _user;
  String? _username;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _user = Supabase.instance.client.auth.currentUser;
    _username = _user?.userMetadata?['username'] as String?;

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      setState(() {
        _user = data.session?.user;
        _username = _user?.userMetadata?['username'] as String?;
      });
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    // Note: Supabase's onAuthStateChange stream is a broadcast stream.
    // Individual listeners on broadcast streams are typically not closed directly by the listener.
    // The stream itself is managed by the Supabase client.
    // If this were a single-subscription stream controller owned by this widget, you'd cancel it.
    // For onAuthStateChange, it's generally safe to assume it's managed globally.
    super.dispose();
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        // Navigator.popUntil(context, (route) => route.isFirst); // Go to initial page
        // Or, if UploadImagePage is always home, this might not be strictly needed
        // as the state change will rebuild UIs.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed out successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign out failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _user != null;
    final displayName = _username ?? _user?.email?.split('@').first ?? 'Food Friend';

    return PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle),
      tooltip: 'Account',
      onSelected: (value) {
        if (value == 'history') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HistoryPage()),
          );
        } else if (value == 'auth') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AuthPage()),
          );
        } else if (value == 'logout') {
          _signOut();
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false, // Not selectable
          child: Text(isLoggedIn ? 'Hello $displayName!' : 'Hello Food Friend!'),
        ),
        const PopupMenuDivider(),
        if (isLoggedIn)
          const PopupMenuItem<String>(
            value: 'history',
            child: ListTile(
              leading: Icon(Icons.history),
              title: Text('View History'),
            ),
          ),
        if (!isLoggedIn)
          const PopupMenuItem<String>(
            value: 'auth',
            child: ListTile(
              leading: Icon(Icons.login),
              title: Text('Sign In / Sign Up'),
            ),
          ),
        if (isLoggedIn)
          const PopupMenuItem<String>(
            value: 'logout',
            child: ListTile(
              leading: Icon(Icons.logout),
              title: Text('Log Out'),
            ),
          ),
      ],
    );
  }
}