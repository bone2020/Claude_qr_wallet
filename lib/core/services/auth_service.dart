import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../models/user_model.dart';
import '../../models/wallet_model.dart';
import '../utils/error_handler.dart';

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
      final walletId = await _generateUniqueWalletId();

      // Create user document in Firestore
      final userModel = UserModel(
        id: user.uid,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        walletId: walletId,
        country: countryCode ?? 'GH',
        currency: currencyCode ?? 'GHS',
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.uid).set(userModel.toJson());

      // Create wallet document with user's currency
      final walletModel = WalletModel(
        id: user.uid,
        walletId: walletId,
        userId: user.uid,
        currency: currencyCode ?? 'GHS',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('wallets').doc(user.uid).set(walletModel.toJson());

      return AuthResult.success(userModel);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure(ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  /// Create a verified user account AFTER KYC has passed
  /// This is called only after successful KYC verification
  Future<AuthResult> createVerifiedUser({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String kycStatus,
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
      final walletId = await _generateUniqueWalletId();

      // Create user document in Firestore WITH kycStatus
      final userModel = UserModel(
        id: user.uid,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        walletId: walletId,
        country: countryCode ?? 'GH',
        currency: currencyCode ?? 'GHS',
        createdAt: DateTime.now(),
        kycStatus: kycStatus,
        kycCompleted: true,
        isVerified: true,
      );

      await _firestore.collection('users').doc(user.uid).set(userModel.toJson());

      // Create wallet document with user's currency
      final walletModel = WalletModel(
        id: user.uid,
        walletId: walletId,
        userId: user.uid,
        currency: currencyCode ?? 'GHS',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('wallets').doc(user.uid).set(walletModel.toJson());

      return AuthResult.success(userModel);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure(ErrorHandler.getUserFriendlyMessage(e));
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
      return AuthResult.failure(ErrorHandler.getUserFriendlyMessage(e));
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
        final walletId = await _generateUniqueWalletId();

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
      return AuthResult.failure(ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  // ============================================================
  // APPLE SIGN IN
  // ============================================================

  /// Generate a random string for nonce
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Returns the sha256 hash of [input] in hex notation.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Sign in with Apple
  Future<AuthResult> signInWithApple() async {
    try {
      // Generate nonce for security
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Request Apple sign in
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Create OAuth credential
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      // Sign in to Firebase with the credential
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = userCredential.user;

      if (user == null) {
        return AuthResult.failure('Failed to sign in with Apple');
      }

      // Check if user exists in Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        // Existing user
        final userModel = UserModel.fromJson(userDoc.data()!);
        return AuthResult.success(userModel);
      } else {
        // New user - create documents
        final walletId = await _generateUniqueWalletId();

        // Apple may not return name on subsequent sign-ins, so we use what we have
        final fullName = appleCredential.givenName != null && appleCredential.familyName != null
            ? '${appleCredential.givenName} ${appleCredential.familyName}'
            : user.displayName ?? 'User';

        final userModel = UserModel(
          id: user.uid,
          fullName: fullName,
          email: user.email ?? appleCredential.email ?? '',
          phoneNumber: user.phoneNumber ?? '',
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
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.failure('Apple sign in cancelled');
      }
      return AuthResult.failure('Apple sign in failed: ${e.message}');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure(ErrorHandler.getUserFriendlyMessage(e));
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
          'kycStatus': 'pending_manual',
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
      return AuthResult.failure(ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  // ============================================================
  // EMAIL VERIFICATION
  // ============================================================

  /// Send email verification link to current user
  Future<AuthResult> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.failure('No user logged in');
      }

      if (user.emailVerified) {
        return AuthResult.success(null); // Already verified
      }

      await user.sendEmailVerification();
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getAuthErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure(ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  /// Check if current user's email is verified
  /// Returns true if verified, false otherwise
  Future<bool> checkEmailVerified() async {
    try {
      final user = currentUser;
      if (user == null) return false;

      // Reload user to get latest emailVerified status
      await user.reload();

      // Get fresh instance after reload
      final refreshedUser = _auth.currentUser;
      return refreshedUser?.emailVerified ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Update user's verified status in Firestore after email verification
  Future<AuthResult> markEmailVerified() async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.failure('No user logged in');
      }

      // Update Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'isVerified': true,
      });

      // Return updated user
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userModel = UserModel.fromJson(userDoc.data()!);
        return AuthResult.success(userModel);
      }

      return AuthResult.success(null);
    } catch (e) {
      return AuthResult.failure(ErrorHandler.getUserFriendlyMessage(e));
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
      return AuthResult.failure(ErrorHandler.getUserFriendlyMessage(e));
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
      return AuthResult.failure(ErrorHandler.getUserFriendlyMessage(e));
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

  /// Generate unique wallet ID with Firestore uniqueness check
  /// Generate unique wallet ID with Firestore uniqueness check
  /// Uses alphanumeric format with ~60 bits entropy for security
  Future<String> _generateUniqueWalletId() async {
    // Alphanumeric charset (excludes confusing chars: 0, 1, I, L, O)
    const charset = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
    final random = Random.secure();
    
    String generatePart(int length) {
      return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
    }
    
    while (true) {
      // Generate: QRW-XXXX-XXXX-XXXX (12 random chars = ~60 bits entropy)
      final walletId = 'QRW-${generatePart(4)}-${generatePart(4)}-${generatePart(4)}';

      // Check if wallet ID already exists in Firestore
      final querySnapshot = await _firestore
          .collection('wallets')
          .where('walletId', isEqualTo: walletId)
          .limit(1)
          .get();

      // Return if unique, otherwise loop again
      if (querySnapshot.docs.isEmpty) {
        return walletId;
      }
    }
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
