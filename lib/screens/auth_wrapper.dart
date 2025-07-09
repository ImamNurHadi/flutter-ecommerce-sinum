import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'login_screen.dart';
import 'admin_main_screen.dart';
import '../main.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  bool _showDebugInfo = false;
  
  // State tracking
  String? _currentUserUid;
  UserModel? _currentUserData;
  bool _isLoading = false;
  String _lastKnownRole = 'unknown';
  int _refreshCount = 0;
  
  // Timers and subscriptions
  StreamSubscription<User?>? _authStateSubscription;
  Timer? _periodicCheckTimer;
  DateTime? _lastSuccessfulLoad;

  @override
  void initState() {
    super.initState();
    debugPrint('🔄 AuthWrapper: initState() called');
    
    // Register this instance for global refresh
    AuthWrapperRefresh.register(this);
    
    // Setup listeners
    _setupAuthStateListener();
    // _startPeriodicCheck(); // Disabled to prevent excessive refresh
    
    // Load initial data
    _initialLoad();
  }

  @override
  void dispose() {
    debugPrint('🔄 AuthWrapper: dispose() called');
    _authStateSubscription?.cancel();
    _periodicCheckTimer?.cancel();
    AuthWrapperRefresh.register(null);
    super.dispose();
  }

  void _startPeriodicCheck() {
    // Disabled to prevent excessive refresh
    /*
    debugPrint('🔄 AuthWrapper: Starting periodic check every 5 seconds');
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkForUserChanges();
    });
    */
  }

  void _stopPeriodicCheckTemporarily() {
    // Disabled to prevent excessive refresh
    /*
    debugPrint('🔄 AuthWrapper: Stopping periodic check temporarily');
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null;
    
    // Resume after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        debugPrint('🔄 AuthWrapper: Resuming periodic check');
        _startPeriodicCheck();
      }
    });
    */
  }

  void _setupAuthStateListener() {
    debugPrint('🔄 AuthWrapper: Setting up auth state listener...');
    
    _authStateSubscription = _authService.authStateChanges.listen((User? user) {
      debugPrint('🔄 AuthWrapper: Auth state changed!');
      debugPrint('   - Previous UID: $_currentUserUid');
      debugPrint('   - New UID: ${user?.uid}');
      debugPrint('   - Email: ${user?.email}');
      
      if (_currentUserUid != user?.uid) {
        debugPrint('🔄 AuthWrapper: User changed via auth state listener!');
        _handleUserChange(user);
      }
    });
  }

  void _checkForUserChanges() {
    // Disabled to prevent excessive refresh
    /*
    final currentUser = _authService.currentUser;
    final currentUid = currentUser?.uid;
    
    debugPrint('🔄 AuthWrapper: Periodic check - Current UID: $currentUid, Stored UID: $_currentUserUid');
    
    // Skip if already stable and has data
    if (_currentUserUid == currentUid && _currentUserData != null && !_isLoading) {
      debugPrint('✅ AuthWrapper: State is stable, skipping periodic check');
      return;
    }
    
    // Skip if recently loaded successfully
    if (_lastSuccessfulLoad != null && 
        DateTime.now().difference(_lastSuccessfulLoad!).inSeconds < 10) {
      debugPrint('✅ AuthWrapper: Recently loaded successfully, skipping periodic check');
      return;
    }
    
    if (_currentUserUid != currentUid) {
      debugPrint('🔄 AuthWrapper: User change detected via periodic check!');
      debugPrint('   - Previous UID: $_currentUserUid');
      debugPrint('   - New UID: $currentUid');
      _handleUserChange(currentUser);
    }
    
    // Also check if we have user but no data
    if (currentUser != null && _currentUserData == null && !_isLoading) {
      debugPrint('🔄 AuthWrapper: User exists but no data, forcing reload');
      _handleUserChange(currentUser);
    }
    */
  }

  void _handleUserChange(User? user) {
    debugPrint('🔄 AuthWrapper: Handling user change...');
    debugPrint('   - New User: ${user?.email ?? 'null'}');
    debugPrint('   - Current Widget Mounted: $mounted');
    
    if (!mounted) {
      debugPrint('❌ AuthWrapper: Widget not mounted, skipping');
      return;
    }
    
    // Complete reset of state
    _currentUserUid = user?.uid;
    _currentUserData = null;
    _lastKnownRole = 'unknown';
    _refreshCount++;
    
    debugPrint('   - New UID: $_currentUserUid');
    debugPrint('   - Refresh count: $_refreshCount');
    
    // Force rebuild and load new data
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
      
      // Load data after a small delay to ensure state is updated
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _loadUserData();
        }
      });
    }
  }

  Future<void> _initialLoad() async {
    debugPrint('🔄 AuthWrapper: Initial load...');
    await _loadUserData();
  }

  Future<void> _loadUserData() async {
    debugPrint('🔄 AuthWrapper: Loading user data... (attempt $_refreshCount)');
    
    if (!mounted) {
      debugPrint('❌ AuthWrapper: Widget not mounted during load');
      return;
    }
    
    try {
      final user = _authService.currentUser;
      if (user == null || user.isAnonymous) {
        debugPrint('❌ AuthWrapper: No authenticated user');
        if (mounted) {
          setState(() {
            _currentUserData = null;
            _isLoading = false;
            _lastKnownRole = 'none';
          });
        }
        return;
      }

      debugPrint('✅ AuthWrapper: Firebase user found');
      debugPrint('   - UID: ${user.uid}');
      debugPrint('   - Email: ${user.email}');
      debugPrint('   - Display Name: ${user.displayName}');
      
      // Clear any cache in AuthService first
      await _authService.forceRefreshUserData();
      
      // Get fresh data from Firestore with retry
      UserModel? userData;
      int retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries && userData == null) {
        retryCount++;
        debugPrint('🔄 AuthWrapper: Attempting to get user data (try $retryCount/$maxRetries)');
        
        try {
          userData = await _authService.getUserData(user.uid);
          if (userData != null) {
            debugPrint('✅ AuthWrapper: Got user data from Firestore');
            debugPrint('   - Email: ${userData.email}');
            debugPrint('   - Username: ${userData.username}');
            debugPrint('   - Role: ${userData.role}');
            debugPrint('   - IsAdmin: ${userData.isAdmin}');
            break;
          }
        } catch (e) {
          debugPrint('❌ AuthWrapper: Error getting user data (try $retryCount): $e');
          if (retryCount < maxRetries) {
            await Future.delayed(Duration(milliseconds: 500 * retryCount));
          }
        }
      }
      
      if (userData != null) {
        debugPrint('✅ AuthWrapper: Fresh user data loaded successfully!');
        
        // Check if role changed
        if (_lastKnownRole != userData.role.value) {
          debugPrint('🔄 AuthWrapper: Role changed from $_lastKnownRole to ${userData.role.value}');
          _lastKnownRole = userData.role.value;
        }
        
        if (mounted) {
          setState(() {
            _currentUserData = userData;
            _isLoading = false;
            _lastSuccessfulLoad = DateTime.now();
          });
          
          debugPrint('✅ AuthWrapper: State updated with user data');
          debugPrint('   - Current data role: ${_currentUserData?.role}');
          debugPrint('   - Current data isAdmin: ${_currentUserData?.isAdmin}');
        }
      } else {
        debugPrint('⚠️ AuthWrapper: No user data in Firestore, creating minimal user');
        final minimalUser = UserModel.fromFirebaseUser(
          user.uid,
          user.email ?? '',
          user.displayName ?? 'User',
        );
        
        debugPrint('📝 AuthWrapper: Created minimal user');
        debugPrint('   - Role: ${minimalUser.role}');
        debugPrint('   - IsAdmin: ${minimalUser.isAdmin}');
        
        if (mounted) {
          setState(() {
            _currentUserData = minimalUser;
            _isLoading = false;
            _lastKnownRole = minimalUser.role.value;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ AuthWrapper: Error loading user data: $e');
      if (mounted) {
        setState(() {
          _currentUserData = null;
          _isLoading = false;
          _lastKnownRole = 'error';
        });
      }
    }
  }

  void _forceRefresh() {
    debugPrint('🔄 AuthWrapper: Force refresh triggered manually');
    debugPrint('   - Current mounted state: $mounted');
    debugPrint('   - Current user UID: $_currentUserUid');
    debugPrint('   - Current user data: ${_currentUserData?.email ?? 'null'}');
    
    if (!mounted) {
      debugPrint('❌ AuthWrapper: Widget not mounted, skipping force refresh');
      return;
    }
    
    final currentUser = _authService.currentUser;
    debugPrint('🔄 AuthWrapper: Forcing refresh with current user: ${currentUser?.email ?? 'null'}');
    
    // Simple refresh without debouncing
    _refreshCount++;
    _currentUserData = null;
    _lastKnownRole = 'unknown';
    
    debugPrint('   - Force refresh count: $_refreshCount');
    
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
      
      // Load data immediately
      _loadUserData();
    }
  }

  Widget _buildMainContent() {
    final user = _authService.currentUser;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    debugPrint('🔄 AuthWrapper: Building main content...');
    debugPrint('   - Firebase User: ${user?.email ?? 'null'}');
    debugPrint('   - IsLoading: $_isLoading');
    debugPrint('   - CurrentUserData: ${_currentUserData?.email ?? 'null'}');
    debugPrint('   - CurrentUserData Role: ${_currentUserData?.role ?? 'null'}');
    debugPrint('   - CurrentUserData IsAdmin: ${_currentUserData?.isAdmin ?? 'null'}');
    debugPrint('   - LastKnownRole: $_lastKnownRole');
    debugPrint('   - RefreshCount: $_refreshCount');
    debugPrint('   - Timestamp: $timestamp');
    
    // No user logged in
    if (user == null) {
      debugPrint('🚫 AuthWrapper: No user, showing login');
      return LoginScreen(key: ValueKey('login_$timestamp'));
    }

    // Loading user data
    if (_isLoading || _currentUserData == null) {
      debugPrint('⏳ AuthWrapper: Loading user data... showing splash');
      return SplashScreen(key: ValueKey('splash_$timestamp'));
    }

    // Debug overlay
    if (_showDebugInfo) {
      return Scaffold(
        key: ValueKey('debug_$timestamp'),
        appBar: AppBar(
          title: const Text('AuthWrapper Debug'),
          backgroundColor: Colors.red,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AuthWrapper Debug Info',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildDebugInfo('Firebase UID', user.uid),
              _buildDebugInfo('Firebase Email', user.email ?? 'null'),
              _buildDebugInfo('Firebase Display Name', user.displayName ?? 'null'),
              const Divider(),
              _buildDebugInfo('User Data Email', _currentUserData?.email ?? 'null'),
              _buildDebugInfo('User Data Username', _currentUserData?.username ?? 'null'),
              _buildDebugInfo('Role', _currentUserData?.role.value ?? 'null'),
              _buildDebugInfo('Is Admin', _currentUserData?.isAdmin.toString() ?? 'null'),
              const Divider(),
              _buildDebugInfo('Current UID', _currentUserUid ?? 'null'),
              _buildDebugInfo('Last Known Role', _lastKnownRole),
              _buildDebugInfo('Is Loading', _isLoading.toString()),
              _buildDebugInfo('Refresh Count', _refreshCount.toString()),
              _buildDebugInfo('Timestamp', timestamp.toString()),
              _buildDebugInfo('Widget Mounted', mounted.toString()),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showDebugInfo = false;
                      });
                    },
                    child: const Text('Hide Debug'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _authService.logout();
                    },
                    child: const Text('Logout'),
                  ),
                  ElevatedButton(
                    onPressed: _forceRefresh,
                    child: const Text('Force Refresh'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      debugPrint('🔄 Manual force refresh user data');
                      await _authService.forceRefreshUserData();
                      _forceRefresh();
                    },
                    child: const Text('Manual Refresh'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _handleUserChange(user);
                    },
                    child: const Text('Simulate User Change'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Navigate based on role
    debugPrint('🔍 AuthWrapper: Determining navigation based on role...');
    debugPrint('   - User Data: ${_currentUserData?.email}');
    debugPrint('   - Role: ${_currentUserData?.role}');
    debugPrint('   - IsAdmin: ${_currentUserData?.isAdmin}');

    if (_currentUserData!.isAdmin) {
      debugPrint('✅ AuthWrapper: User is ADMIN - Showing AdminMainScreen');
      return AdminMainScreen(key: ValueKey('admin_${user.uid}_$_refreshCount'));
    } else {
      debugPrint('✅ AuthWrapper: User is USER - Showing MainScreen');
      return MainScreen(key: ValueKey('user_${user.uid}_$_refreshCount'));
    }
  }

  Widget _buildDebugInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 AuthWrapper: build() called (refresh count: $_refreshCount)');
    
    // Direct return without AnimatedSwitcher to prevent flickering
    return _buildMainContent();
  }
}

// Global method to force refresh AuthWrapper
class AuthWrapperRefresh {
  static _AuthWrapperState? _instance;
  
  static void register(_AuthWrapperState? state) {
    _instance = state;
    debugPrint('🔄 AuthWrapperRefresh: Instance ${state != null ? 'registered' : 'cleared'}');
    
    if (state != null) {
      debugPrint('🔄 AuthWrapperRefresh: Instance details:');
      debugPrint('   - Widget mounted: ${state.mounted}');
      debugPrint('   - Current UID: ${state._currentUserUid}');
      debugPrint('   - Current data: ${state._currentUserData?.email ?? 'null'}');
    }
  }
  
  static void forceRefresh() {
    debugPrint('🔄 AuthWrapperRefresh: Force refresh called');
    debugPrint('   - Instance exists: ${_instance != null}');
    
    if (_instance != null) {
      debugPrint('   - Instance mounted: ${_instance!.mounted}');
      debugPrint('   - Calling _forceRefresh()...');
      _instance!._forceRefresh();
    } else {
      debugPrint('❌ AuthWrapperRefresh: No instance registered!');
    }
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFF6B35),
      body: GestureDetector(
        onLongPress: () {
          if (context.mounted) {
            // Find the _AuthWrapperState and trigger debug mode
            final state = context.findAncestorStateOfType<_AuthWrapperState>();
            if (state != null) {
              state.setState(() {
                state._showDebugInfo = true;
              });
            }
          }
        },
        child: Center(
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
                'Kelola Toko Makanan Anda',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w300,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Loading Indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              
              const SizedBox(height: 20),
              
              // Loading text
              const Text(
                'Memuat data pengguna...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w300,
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Debug hint
              const Text(
                'Long press untuk debug',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 