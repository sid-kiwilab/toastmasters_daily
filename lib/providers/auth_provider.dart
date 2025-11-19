import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoggedIn = false;
  String? _userId;
  String? _userEmail;
  String? _userName;
  bool _isEmailVerified = false;
  bool _authStateResolved = false; // Flag to track if auth state has been determined

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  bool get isEmailVerified => _isEmailVerified;
  User? get currentUser => _auth.currentUser;
  bool get authStateResolved => _authStateResolved; // Whether auth state has been checked

  // Constructor - check auth status on initialization
  AuthProvider() {
    // Check initial auth state synchronously
    final initialUser = _auth.currentUser;
    if (initialUser != null) {
      _isLoggedIn = true;
      _userId = initialUser.uid;
      _userEmail = initialUser.email;
      _userName = initialUser.displayName ?? initialUser.email?.split('@')[0] ?? 'User';
      _isEmailVerified = initialUser.emailVerified;
    }
    _authStateResolved = true; // Mark as resolved after initial check
    notifyListeners();
    
    // Listen for auth state changes
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _isLoggedIn = true;
        _userId = user.uid;
        _userEmail = user.email;
        _userName = user.displayName ?? user.email?.split('@')[0] ?? 'User';
        _isEmailVerified = user.emailVerified;
      } else {
        _isLoggedIn = false;
        _userId = null;
        _userEmail = null;
        _userName = null;
        _isEmailVerified = false;
      }
      _authStateResolved = true; // Mark as resolved when state changes
      notifyListeners();
    });
  }

  // Send verification email function
  Future<bool> sendVerificationEmail() async {
    try {
      User? user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      print('Send verification email error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('Send verification email error: $e');
      return false;
    }
  }

  // Sign up function
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Create user with email and password
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update user profile with display name
      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(name);
        
        // Send verification email
        await userCredential.user!.sendEmailVerification();
        
        // Refresh user data
        await userCredential.user!.reload();
        
        _isLoggedIn = true;
        _userId = userCredential.user!.uid;
        _userEmail = userCredential.user!.email;
        _userName = userCredential.user!.displayName ?? name;
        _isEmailVerified = userCredential.user!.emailVerified;
        
        notifyListeners();
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      print('Signup error: ${e.code} - ${e.message}');
      rethrow; // Re-throw so the screen can catch and display the specific error
    } catch (e) {
      print('Signup error: $e');
      return false;
    }
  }

  // Login function
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      // Sign in with email and password
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        _isLoggedIn = true;
        _userId = userCredential.user!.uid;
        _userEmail = userCredential.user!.email;
        _userName = userCredential.user!.displayName ?? 
                   userCredential.user!.email?.split('@')[0] ?? 
                   'User';
        
        notifyListeners();
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      print('Login error: ${e.code} - ${e.message}');
      rethrow; // Re-throw so the screen can catch and display the specific error
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  // Logout function
  Future<void> logout() async {
    try {
      await _auth.signOut();
      
      _isLoggedIn = false;
      _userId = null;
      _userEmail = null;
      _userName = null;
      
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      print('Logout error: ${e.code} - ${e.message}');
    } catch (e) {
      print('Logout error: $e');
    }
  }

  // Reset password function
  Future<bool> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      print('Reset password error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('Reset password error: $e');
      return false;
    }
  }

  // Check if user is already logged in (for app startup)
  Future<void> checkAuthStatus() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        _isLoggedIn = true;
        _userId = user.uid;
        _userEmail = user.email;
        _userName = user.displayName ?? user.email?.split('@')[0] ?? 'User';
        _isEmailVerified = user.emailVerified;
      } else {
        _isLoggedIn = false;
        _userId = null;
        _userEmail = null;
        _userName = null;
        _isEmailVerified = false;
      }
      notifyListeners();
    } catch (e) {
      print('Auth status check error: $e');
    }
  }

  // Clear user data (for testing or error recovery)
  void clearUserData() {
    _isLoggedIn = false;
    _userId = null;
    _userEmail = null;
    _userName = null;
    _isEmailVerified = false;
    notifyListeners();
  }

  // Get error message for Firebase Auth exceptions
  String getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'The email address is already in use by another account.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
