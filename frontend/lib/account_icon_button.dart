import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async'; // Import for StreamSubscription
import 'main.dart'; // For AuthPage
import 'history_page.dart'; // For HistoryPage
import 'preferences_page.dart';

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
    final displayName =
        _username ?? _user?.email?.split('@').first ?? 'Guest User';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;
        final isPortrait = constraints.maxHeight > constraints.maxWidth;
        final isMobilePortrait = isSmallScreen && isPortrait;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: PopupMenuButton<String>(
            icon: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: isMobilePortrait ? 120 : 240),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobilePortrait ? 6 : 12,
                    vertical: isMobilePortrait ? 4 : 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(isMobilePortrait ? 3 : 6),
                        decoration: BoxDecoration(
                          color: isLoggedIn
                              ? const Color(0xFF10B981)
                              : const Color(0xFF6B7280),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isLoggedIn ? Icons.person : Icons.person_outline,
                          color: Colors.white,
                          size: isMobilePortrait ? 12 : 16,
                        ),
                      ),
                      SizedBox(width: isMobilePortrait ? 5 : 8),
                      Flexible(
                        child: Text(
                          isLoggedIn ? displayName : 'Sign In',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: const Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                            fontSize: isMobilePortrait ? 10 : 14,
                          ),
                        ),
                      ),
                      SizedBox(width: isMobilePortrait ? 2 : 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.grey.shade600,
                        size: isMobilePortrait ? 14 : 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            tooltip: 'Account',
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 4,
            onSelected: (value) {
              if (value == 'history') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HistoryPage()),
                );
              } else if (value == 'auth') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AuthPage()),
                );
              } else if (value == 'preferences') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PreferencesPage()),
                );
              } else if (value == 'logout') {
                _signOut();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isLoggedIn
                              ? const Color(0xFF10B981)
                              : const Color(0xFF6B7280),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isLoggedIn ? Icons.person : Icons.person_outline,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLoggedIn ? displayName : 'Welcome',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            Text(
                              isLoggedIn
                                  ? 'Signed in'
                                  : 'Sign in to access features',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
              if (isLoggedIn)
                PopupMenuItem<String>(
                  value: 'history',
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.history,
                            color: Color(0xFF2563EB),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Recipe History',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!isLoggedIn)
                PopupMenuItem<String>(
                  value: 'auth',
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.login,
                            color: Color(0xFF10B981),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Sign In / Sign Up',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isLoggedIn)
                PopupMenuItem<String>(
                  value: 'preferences',
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.settings,
                            color: Color(0xFF6366F1),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Default Preferences',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isLoggedIn)
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.logout,
                            color: Color(0xFFEF4444),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Sign Out',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
