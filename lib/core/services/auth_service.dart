import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:math';

import '../../models/user_model.dart';
import '../../models/wallet_model.dart';

/// Authentication service handling all Firebase Auth operations
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  // ============================================================
  // EMAIL/PASSWORD AUTHENTICATION
  // ============================================================

  /// Sign up with email and password
  /// Creates user in Firebase Auth and Firestore
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    String? countryCode,
    String? currencyCode,
  }) async {
    try {
      // Create user in Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return AuthResult.failure('Failed to create user');
      }

      // Update display name
      await user.updateDisplayName(fullName);

      // Generate unique wallet ID
      final walletId = _generateWalletId();

      // Create user document in Firestore
      final userModel = UserModel(
        id: user.uid,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        walletId: walletId,
        country: countryCode ?? 'NG',
        currency: currencyCode ?? 'NGN',
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.uid).set(userModel.toJson());

      // Create wallet document with user's currency
      final walletModel = WalletModel(
        id: user.uid,
        walletId: walletId,
        userId: user.uid,
        currency: currencyCode ?? 'NGN',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('wallets').doc(user.uid).set(walletModel.toJson());

      return AuthResult.success(userModel);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  /// Sign in with email and password
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return AuthResult.failure('Failed to sign in');
      }

      // Fetch user data from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        return AuthResult.failure('User data not found');
      }

      final userModel = UserModel.fromJson(userDoc.data()!);
      return AuthResult.success(userModel);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  // ============================================================
  // GOOGLE SIGN IN
  // ============================================================

  /// Sign in with Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return AuthResult.failure('Google sign in cancelled');
      }

      // Obtain the auth details from the request
      final googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        return AuthResult.failure('Failed to sign in with Google');
      }

      // Check if user exists in Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        // Existing user
        final userModel = UserModel.fromJson(userDoc.data()!);
        return AuthResult.success(userModel);
      } else {
        // New user - create documents
        final walletId = _generateWalletId();

        final userModel = UserModel(
          id: user.uid,
          fullName: user.displayName ?? 'User',
          email: user.email ?? '',
          phoneNumber: user.phoneNumber ?? '',
          profilePhotoUrl: user.photoURL,
          walletId: walletId,
          createdAt: DateTime.now(),
        );

        await _firestore.collection('users').doc(user.uid).set(userModel.toJson());

        final walletModel = WalletModel(
          id: user.uid,
          walletId: walletId,
          userId: user.uid,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _firestore.collection('wallets').doc(user.uid).set(walletModel.toJson());

        return AuthResult.success(userModel, isNewUser: true);
      }
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  // ============================================================
  // PHONE AUTHENTICATION
  // ============================================================

  /// Send OTP to phone number
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerify,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onAutoVerify,
      verificationFailed: (FirebaseAuthException e) {
        onError(_getAuthErrorMessage(e.code));
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
      timeout: const Duration(seconds: 60),
    );
  }

  /// Verify OTP code
  Future<AuthResult> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      // Link phone number to current user or sign in
      if (currentUser != null) {
        await currentUser!.linkWithCredential(credential);
        
        // Update user's phone verification status
        await _firestore.collection('users').doc(currentUser!.uid).update({
          'isVerified': true,
        });

        final userDoc = await _firestore.collection('users').doc(currentUser!.uid).get();
        final userModel = UserModel.fromJson(userDoc.data()!);
        return AuthResult.success(userModel);
      } else {
        final userCredential = await _auth.signInWithCredential(credential);
        final user = userCredential.user;
        
        if (user == null) {
          return AuthResult.failure('Failed to verify OTP');
        }

        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userModel = UserModel.fromJson(userDoc.data()!);
          return AuthResult.success(userModel);
        }

        return AuthResult.failure('User not found');
      }
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  // ============================================================
  // PASSWORD MANAGEMENT
  // ============================================================

  /// Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  /// Update password
  Future<AuthResult> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.failure('No user logged in');
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  /// Sign out current user
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Generate unique wallet ID
  String _generateWalletId() {
    final random = Random();
    final part1 = random.nextInt(9000) + 1000;
    final part2 = random.nextInt(9000) + 1000;
    return 'QRW-$part1-$part2';
  }

  /// Get user-friendly error message
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'invalid-verification-code':
        return 'Invalid OTP code. Please try again';
      case 'invalid-verification-id':
        return 'Verification session expired. Please request a new code';
      case 'credential-already-in-use':
        return 'This phone number is already linked to another account';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'An error occurred. Please try again';
    }
  }
}

/// Result wrapper for auth operations
class AuthResult {
  final bool success;
  final UserModel? user;
  final String? error;
  final bool isNewUser;

  AuthResult._({
    required this.success,
    this.user,
    this.error,
    this.isNewUser = false,
  });

  factory AuthResult.success(UserModel? user, {bool isNewUser = false}) {
    return AuthResult._(success: true, user: user, isNewUser: isNewUser);
  }

  factory AuthResult.failure(String error) {
    return AuthResult._(success: false, error: error);
  }
}
