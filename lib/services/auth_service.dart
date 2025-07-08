import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection reference
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Current user stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  // Current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // REGISTER with email and password
  Future<AuthResult> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String username,
    String? address,
    String? phoneNumber,
    UserRole role = UserRole.user,
  }) async {
    try {
      print('🔐 Starting registration process...');
      
      // Check if user already exists first
      final existingUser = await _checkIfUserExists(email.trim());
      if (existingUser != null) {
        print('✅ User already exists, performing login instead...');
        return await loginWithEmailAndPassword(email: email, password: password);
      }
      
      // Clear any existing anonymous session first
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.isAnonymous) {
        print('🔄 Clearing existing anonymous session...');
        await _auth.signOut();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Create user with email and password
      UserCredential? userCredential;
      try {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        print('✅ Firebase user created: ${userCredential.user?.uid}');
      } catch (e) {
        print('❌ Firebase Auth Error during creation: $e');
        // Check if user was actually created despite error
        await Future.delayed(const Duration(milliseconds: 1000));
        final newCurrentUser = _auth.currentUser;
                 if (newCurrentUser != null && !newCurrentUser.isAnonymous) {
           print('✅ User was created successfully despite error');
           // Handle as if userCredential was created successfully
           // We'll process this user directly without UserCredential
           final userModel = UserModel.fromFirebaseUser(
             newCurrentUser.uid,
             email.trim(),
             username.trim(),
             address: address?.trim(),
             phoneNumber: phoneNumber?.trim(),
             role: role,
           );
           
           // Save user data to Firestore with retry
           await _saveUserToFirestoreWithRetry(userModel);
           
           // Update Firebase user display name (non-critical)
           try {
             await newCurrentUser.updateDisplayName(username.trim());
           } catch (e) {
             print('⚠️ Warning: Could not update display name: $e');
           }
           
           print('✅ Registration completed successfully despite creation error');
           return AuthResult.success(userModel);
         } else {
           rethrow;
         }
      }

      if (userCredential?.user == null) {
        throw Exception('User creation failed');
      }

      // Wait a bit for Firebase Auth state to stabilize
      await Future.delayed(const Duration(milliseconds: 1000));

      // Create user model
      final userModel = UserModel.fromFirebaseUser(
        userCredential!.user!.uid,
        email.trim(),
        username.trim(),
        address: address?.trim(),
        phoneNumber: phoneNumber?.trim(),
        role: role,
      );

      // Save user data to Firestore with retry
      await _saveUserToFirestoreWithRetry(userModel);

      // Update Firebase user display name (non-critical)
      try {
        await userCredential.user!.updateDisplayName(username.trim());
      } catch (e) {
        print('⚠️ Warning: Could not update display name: $e');
      }

      print('✅ Registration completed successfully');
      return AuthResult.success(userModel);

    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      
      // Special handling for email already in use
      if (e.code == 'email-already-in-use') {
        print('🔄 Email already in use, attempting to login instead...');
        return await loginWithEmailAndPassword(email: email, password: password);
      }
      
      return AuthResult.failure(_getFirebaseErrorMessage(e));
    } catch (e) {
      print('❌ General Registration Error: $e');
      print('❌ Error Type: ${e.runtimeType}');
      
      // Check if user was actually created despite the error
      await Future.delayed(const Duration(milliseconds: 1500));
      final currentUser = _auth.currentUser;
      if (currentUser != null && !currentUser.isAnonymous) {
        print('✅ User was created successfully despite error, treating as success');
        
        // Create minimal user model from Firebase user
        final userModel = UserModel.fromFirebaseUser(
          currentUser.uid,
          currentUser.email ?? email.trim(),
          username.trim(),
          address: address?.trim(),
          phoneNumber: phoneNumber?.trim(),
          role: role,
        );
        
        // Try to save user data in background (don't fail if this fails)
        _saveUserToFirestoreWithRetry(userModel).catchError((error) {
          print('⚠️ Background save failed, but registration successful: $error');
        });
        
        return AuthResult.success(userModel);
      }
      
      // Handle specific type casting errors - this is the key improvement
      String errorMessage = e.toString();
      if (errorMessage.contains('PigeonUserDetails') || 
          errorMessage.contains('type cast') ||
          errorMessage.contains('List<Object?>')) {
        
        // For this specific error, try to verify if user was actually created
        print('🔄 Detected Firebase plugin bug, checking if user was created...');
        final verificationResult = await _verifyRegistrationSuccess(email.trim(), password, username.trim(), address, phoneNumber, role);
        if (verificationResult.isSuccess) {
          return verificationResult;
        }
        
        errorMessage = 'Terjadi bug internal Firebase. Silakan coba login jika akun sudah terdaftar.';
      } else if (errorMessage.contains('network')) {
        errorMessage = 'Masalah koneksi internet. Periksa koneksi Anda.';
      } else {
        errorMessage = 'Registrasi gagal. Silakan coba lagi.';
      }
      
      return AuthResult.failure(errorMessage);
    }
  }

  // LOGIN with email and password
  Future<AuthResult> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Starting login process...');
      
      // Clear any existing anonymous session first
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.isAnonymous) {
        print('🔄 Clearing existing anonymous session...');
        await _auth.signOut();
        await Future.delayed(const Duration(milliseconds: 500)); // Small delay
      }
      
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      print('✅ Firebase user logged in: ${userCredential.user?.uid}');

      if (userCredential.user == null) {
        throw Exception('Login failed');
      }

      // Wait a bit for Firebase Auth state to stabilize
      await Future.delayed(const Duration(milliseconds: 500));

      // Get user data from Firestore with retry
      final userModel = await _getUserDataWithRetry(userCredential.user!.uid);
      
      if (userModel == null) {
        // User not found in Firestore, create basic profile
        print('🔄 User not found in Firestore, creating profile...');
        final newUserModel = UserModel.fromFirebaseUser(
          userCredential.user!.uid,
          userCredential.user!.email ?? email.trim(),
          userCredential.user!.displayName ?? email.split('@')[0],
          role: UserRole.user,
        );
        await _saveUserToFirestoreWithRetry(newUserModel);
        return AuthResult.success(newUserModel);
      }

      // Update last login time (non-critical)
      try {
        await _updateLastLoginTime(userCredential.user!.uid);
      } catch (e) {
        print('⚠️ Warning: Could not update last login time: $e');
      }

      print('✅ Login completed successfully');
      return AuthResult.success(userModel);

    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      return AuthResult.failure(_getFirebaseErrorMessage(e));
    } catch (e) {
      print('❌ General Login Error: $e');
      print('❌ Error Type: ${e.runtimeType}');
      
      // Check if user was actually logged in despite the error
      final currentUser = _auth.currentUser;
      if (currentUser != null && !currentUser.isAnonymous) {
        print('✅ User was logged in successfully despite error, treating as success');
        
        // Try to get user data, create minimal if not found
        try {
          final userModel = await _getUserDataWithRetry(currentUser.uid);
          if (userModel != null) {
            return AuthResult.success(userModel);
          }
          
          // Create minimal user model if not found in Firestore
          final newUserModel = UserModel.fromFirebaseUser(
            currentUser.uid,
            currentUser.email ?? email.trim(),
            currentUser.displayName ?? email.split('@')[0],
            role: UserRole.user,
          );
          
          return AuthResult.success(newUserModel);
        } catch (retriveError) {
          print('⚠️ Could not retrieve user data, but login successful: $retriveError');
          
          // Create minimal user model from Firebase user
          final userModel = UserModel.fromFirebaseUser(
            currentUser.uid,
            currentUser.email ?? email.trim(),
            currentUser.displayName ?? email.split('@')[0],
            role: UserRole.user,
          );
          
          return AuthResult.success(userModel);
        }
      }
      
      // Handle specific type casting errors
      String errorMessage = e.toString();
      if (errorMessage.contains('PigeonUserDetails') || 
          errorMessage.contains('type cast') ||
          errorMessage.contains('List<Object?>')) {
        errorMessage = 'Terjadi konflik internal Firebase. Restart aplikasi dan coba lagi.';
      } else if (errorMessage.contains('network')) {
        errorMessage = 'Masalah koneksi internet. Periksa koneksi Anda.';
      } else {
        errorMessage = 'Login gagal. Silakan coba lagi.';
      }
      
      return AuthResult.failure(errorMessage);
    }
  }

  // LOGOUT
  Future<void> logout() async {
    try {
      print('🔐 Logging out user...');
      await _auth.signOut();
      print('✅ User logged out successfully');
    } catch (e) {
      print('❌ Logout error: $e');
      throw Exception('Gagal logout: ${e.toString()}');
    }
  }

  // GET USER DATA from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromFirestore(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  // GET USER DATA from Firestore with retry mechanism
  Future<UserModel?> _getUserDataWithRetry(String uid) async {
    int maxRetries = 3;
    int currentTry = 0;
    
    while (currentTry < maxRetries) {
      try {
        currentTry++;
        print('🔄 Attempting to get user data (try $currentTry/$maxRetries)...');
        
        final doc = await _usersCollection.doc(uid).get()
            .timeout(const Duration(seconds: 10));
            
        if (doc.exists && doc.data() != null) {
          final userData = UserModel.fromFirestore(doc.data() as Map<String, dynamic>);
          print('✅ User data retrieved successfully');
          return userData;
        }
        
        print('⚠️ User data not found in Firestore');
        return null;
        
      } catch (e) {
        print('❌ Error getting user data (try $currentTry): $e');
        
        if (currentTry >= maxRetries) {
          print('⚠️ Failed to get user data after $maxRetries attempts');
          return null;
        }
        
        // Wait before retry
        await Future.delayed(Duration(milliseconds: 500 * currentTry));
      }
    }
    
    return null;
  }

  // GET CURRENT USER DATA
  Future<UserModel?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await getUserData(user.uid);
  }

  // UPDATE USER PROFILE
  Future<AuthResult> updateUserProfile({
    required String uid,
    String? username,
    String? address,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    try {
      print('🔐 Updating user profile...');
      
      // Get current user data
      final currentUserModel = await getUserData(uid);
      if (currentUserModel == null) {
        throw Exception('User not found');
      }

      // Update user model
      final updatedUserModel = currentUserModel.copyWith(
        username: username,
        address: address,
        phoneNumber: phoneNumber,
        profileImageUrl: profileImageUrl,
      );

      // Update in Firestore
      await _usersCollection.doc(uid).update(updatedUserModel.toFirestore());

      // Update Firebase user display name if username changed
      if (username != null && username != currentUserModel.username) {
        await _auth.currentUser?.updateDisplayName(username);
      }

      print('✅ User profile updated successfully');
      return AuthResult.success(updatedUserModel);

    } catch (e) {
      print('❌ Error updating user profile: $e');
      return AuthResult.failure('Gagal mengupdate profil: ${e.toString()}');
    }
  }

  // CHANGE PASSWORD
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      print('🔐 Changing password...');
      
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      print('✅ Password changed successfully');
      return AuthResult.success(null);

    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      return AuthResult.failure(_getFirebaseErrorMessage(e));
    } catch (e) {
      print('❌ Error changing password: $e');
      return AuthResult.failure('Gagal mengubah password: ${e.toString()}');
    }
  }

  // RESET PASSWORD
  Future<AuthResult> resetPassword({required String email}) async {
    try {
      print('🔐 Sending password reset email...');
      
      await _auth.sendPasswordResetEmail(email: email.trim());
      
      print('✅ Password reset email sent successfully');
      return AuthResult.success(null);

    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      return AuthResult.failure(_getFirebaseErrorMessage(e));
    } catch (e) {
      print('❌ Error sending password reset email: $e');
      return AuthResult.failure('Gagal mengirim email reset: ${e.toString()}');
    }
  }

  // DELETE ACCOUNT
  Future<AuthResult> deleteAccount({required String password}) async {
    try {
      print('🔐 Deleting user account...');
      
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      // Delete user data from Firestore
      await _usersCollection.doc(user.uid).delete();

      // Delete Firebase user
      await user.delete();

      print('✅ Account deleted successfully');
      return AuthResult.success(null);

    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      return AuthResult.failure(_getFirebaseErrorMessage(e));
    } catch (e) {
      print('❌ Error deleting account: $e');
      return AuthResult.failure('Gagal menghapus akun: ${e.toString()}');
    }
  }

  // PRIVATE METHODS

  // Check if user already exists by trying to get user data
  Future<User?> _checkIfUserExists(String email) async {
    try {
      print('🔍 Checking if user exists for email: $email');
      
      // Try to get user by email from Firebase Auth
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        print('✅ User exists with email: $email');
        // User exists, but we need to check if they're currently signed in
        final currentUser = _auth.currentUser;
        if (currentUser != null && currentUser.email == email) {
          return currentUser;
        }
      }
      
      print('ℹ️ User does not exist for email: $email');
      return null;
    } catch (e) {
      print('❌ Error checking if user exists: $e');
      return null;
    }
  }

  // Verify registration success by attempting to sign in
  Future<AuthResult> _verifyRegistrationSuccess(
    String email,
    String password,
    String username,
    String? address,
    String? phoneNumber,
    UserRole role,
  ) async {
    try {
      print('🔍 Verifying registration success by attempting login...');
      
      // Wait a bit for Firebase state to stabilize
      await Future.delayed(const Duration(milliseconds: 2000));
      
      // Try to sign in with the credentials
      final result = await loginWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (result.isSuccess) {
        print('✅ Registration verified successfully via login');
        return result;
      }
      
      print('❌ Registration verification failed');
      return AuthResult.failure('Verifikasi registrasi gagal');
      
    } catch (e) {
      print('❌ Error during registration verification: $e');
      return AuthResult.failure('Gagal memverifikasi registrasi');
    }
  }

  // Save user to Firestore
  Future<void> _saveUserToFirestore(UserModel userModel) async {
    try {
      await _usersCollection.doc(userModel.uid).set(userModel.toFirestore());
      print('✅ User data saved to Firestore');
    } catch (e) {
      print('❌ Error saving user to Firestore: $e');
      throw Exception('Gagal menyimpan data user: ${e.toString()}');
    }
  }

  // Save user to Firestore with retry mechanism
  Future<void> _saveUserToFirestoreWithRetry(UserModel userModel) async {
    int maxRetries = 3;
    int currentTry = 0;
    
    while (currentTry < maxRetries) {
      try {
        currentTry++;
        print('🔄 Attempting to save user data (try $currentTry/$maxRetries)...');
        
        await _usersCollection.doc(userModel.uid).set(userModel.toFirestore())
            .timeout(const Duration(seconds: 10));
            
        print('✅ User data saved to Firestore successfully');
        return; // Success, exit retry loop
        
      } catch (e) {
        print('❌ Error saving user to Firestore (try $currentTry): $e');
        
        if (currentTry >= maxRetries) {
          // Last attempt failed, but don't fail the registration
          print('⚠️ Failed to save user data after $maxRetries attempts, but registration considered successful');
          print('⚠️ User can still login, profile will be created on first login');
          return; // Don't throw error, registration should still succeed
        }
        
        // Wait before retry
        await Future.delayed(Duration(milliseconds: 500 * currentTry));
      }
    }
  }

  // Update last login time
  Future<void> _updateLastLoginTime(String uid) async {
    try {
      await _usersCollection.doc(uid).update({
        'lastLoginAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Error updating last login time: $e');
      // Don't throw error, this is not critical
    }
  }

  // Get user-friendly error message
  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      case 'email-already-in-use':
        return 'Email sudah digunakan oleh akun lain.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-not-found':
        return 'Akun dengan email ini tidak ditemukan.';
      case 'wrong-password':
        return 'Password salah. Silakan coba lagi.';
      case 'user-disabled':
        return 'Akun ini telah dinonaktifkan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'operation-not-allowed':
        return 'Operasi tidak diizinkan.';
      case 'invalid-credential':
        return 'Kredensial tidak valid.';
      case 'requires-recent-login':
        return 'Silakan login ulang untuk operasi ini.';
      default:
        return 'Terjadi kesalahan: ${e.message}';
    }
  }
}

// Result wrapper for authentication operations
class AuthResult {
  final bool isSuccess;
  final UserModel? user;
  final String? error;

  AuthResult._({
    required this.isSuccess,
    this.user,
    this.error,
  });

  factory AuthResult.success(UserModel? user) {
    return AuthResult._(
      isSuccess: true,
      user: user,
      error: null,
    );
  }

  factory AuthResult.failure(String error) {
    return AuthResult._(
      isSuccess: false,
      user: null,
      error: error,
    );
  }

  @override
  String toString() {
    return 'AuthResult(isSuccess: $isSuccess, user: $user, error: $error)';
  }
} 