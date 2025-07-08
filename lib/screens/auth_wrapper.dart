import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'login_screen.dart';
import '../main.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Wait a bit for Firebase to initialize properly
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check if user is logged in
      final user = _authService.currentUser;
      
      if (user != null && !user.isAnonymous) {
        print('🔍 Authenticated user found: ${user.uid}');
        
        // User is logged in, get user data with retry
        try {
          final userData = await _authService.getCurrentUserData();
          setState(() {
            _currentUser = userData;
            _isLoading = false;
          });
        } catch (e) {
          print('⚠️ Error getting user data, but user is authenticated: $e');
          
          // Create minimal user model from Firebase user
          final minimalUser = UserModel.fromFirebaseUser(
            user.uid,
            user.email ?? '',
            user.displayName ?? 'User',
          );
          
          setState(() {
            _currentUser = minimalUser;
            _isLoading = false;
          });
        }
      } else {
        // User is not logged in or is anonymous
        print('🔍 No authenticated user found');
        setState(() {
          _currentUser = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error checking auth status: $e');
      
      // Fallback: try to check one more time after delay
      await Future.delayed(const Duration(seconds: 1));
      final fallbackUser = _authService.currentUser;
      
      setState(() {
        _currentUser = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SplashScreen();
    }

    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasData && snapshot.data != null) {
          // User is logged in
          return const MainScreen();
        } else {
          // User is not logged in
          return const LoginScreen();
        }
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFF6B35),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(75),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.restaurant,
                color: Color(0xFFFF6B35),
                size: 80,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // App Name
            const Text(
              'Sinum',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Tagline
            const Text(
              'Food Delivery App',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w300,
              ),
            ),
            
            const SizedBox(height: 60),
            
            // Loading indicator
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
            
            const SizedBox(height: 20),
            
            // Loading text
            const Text(
              'Memuat...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 