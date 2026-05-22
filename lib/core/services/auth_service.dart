import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../models/user_model.dart';
import '../utils/error_handler.dart';
import '../utils/error_handler_localization_resolver.dart';
import 'auth_localization_resolver.dart';

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
        return AuthResult.failure(AuthErrorKey.failedToCreateUser);
      }

      // Update display name
      await user.updateDisplayName(fullName);

      // Create user document in Firestore (NO wallet yet — created after verification)
      final userModel = UserModel(
        id: user.uid,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        country: countryCode ?? 'GH',
        currency: currencyCode ?? 'GHS',
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.uid).set(userModel.toJson());

      // Wallet is NOT created here — it will be created by the Cloud Function
      // after KYC verification (Smile countries) or phone verification (non-Smile countries)

      return AuthResult.success(userModel);
    } on FirebaseAuthException catch (e) {
      return _failureFromAuthCode(e.code);
    } catch (e) {
      debugPrint('auth_service error: $e');
      return AuthResult.genericFailure(ErrorHandler.classifyUserError(e));
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
        return AuthResult.failure(AuthErrorKey.failedToSignIn);
      }

      // Fetch user data from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        return AuthResult.failure(AuthErrorKey.userDataNotFound);
      }

      final userModel = UserModel.fromJson(userDoc.data()!);
      return AuthResult.success(userModel);
    } on FirebaseAuthException catch (e) {
      return _failureFromAuthCode(e.code);
    } catch (e) {
      debugPrint('auth_service error: $e');
      return AuthResult.genericFailure(ErrorHandler.classifyUserError(e));
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
        return AuthResult.failure(AuthErrorKey.googleSignInCancelled);
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
        return AuthResult.failure(AuthErrorKey.failedToSignInWithGoogle);
      }

      // Check if user exists in Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        // Existing user
        final userModel = UserModel.fromJson(userDoc.data()!);
        return AuthResult.success(userModel);
      } else {
        // New user - create document (NO wallet yet — created after verification)
        final userModel = UserModel(
          id: user.uid,
          fullName: user.displayName ?? 'User',
          email: user.email ?? '',
          phoneNumber: user.phoneNumber ?? '',
          profilePhotoUrl: user.photoURL,
          createdAt: DateTime.now(),
        );

        await _firestore.collection('users').doc(user.uid).set(userModel.toJson());

        // Wallet is NOT created here — it will be created by the Cloud Function
        // after KYC verification (Smile countries) or phone verification (non-Smile countries)

        return AuthResult.success(userModel, isNewUser: true);
      }
    } on FirebaseAuthException catch (e) {
      return _failureFromAuthCode(e.code);
    } catch (e) {
      debugPrint('auth_service error: $e');
      return AuthResult.genericFailure(ErrorHandler.classifyUserError(e));
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
        return AuthResult.failure(AuthErrorKey.failedToSignInWithApple);
      }

      // Check if user exists in Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        // Existing user
        final userModel = UserModel.fromJson(userDoc.data()!);
        return AuthResult.success(userModel);
      } else {
        // New user - create document (NO wallet yet — created after verification)
        // Apple may not return name on subsequent sign-ins, so we use what we have
        final fullName = appleCredential.givenName != null && appleCredential.familyName != null
            ? '${appleCredential.givenName} ${appleCredential.familyName}'
            : user.displayName ?? 'User';

        final userModel = UserModel(
          id: user.uid,
          fullName: fullName,
          email: user.email ?? appleCredential.email ?? '',
          phoneNumber: user.phoneNumber ?? '',
          createdAt: DateTime.now(),
        );

        await _firestore.collection('users').doc(user.uid).set(userModel.toJson());

        // Wallet is NOT created here — it will be created by the Cloud Function
        // after KYC verification (Smile countries) or phone verification (non-Smile countries)

        return AuthResult.success(userModel, isNewUser: true);
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.failure(AuthErrorKey.appleSignInCancelled);
      }
      debugPrint('Apple sign in failed: ${e.message}');
      return AuthResult.failure(AuthErrorKey.appleSignInFailed);
    } on FirebaseAuthException catch (e) {
      return _failureFromAuthCode(e.code);
    } catch (e) {
      debugPrint('auth_service error: $e');
      return AuthResult.genericFailure(ErrorHandler.classifyUserError(e));
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
        onError(_englishOf(_classifyAuthCode(e.code)));
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
          return AuthResult.failure(AuthErrorKey.failedToVerifyOtp);
        }

        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userModel = UserModel.fromJson(userDoc.data()!);
          return AuthResult.success(userModel);
        }

        return AuthResult.failure(AuthErrorKey.userNotFound);
      }
    } on FirebaseAuthException catch (e) {
      return _failureFromAuthCode(e.code);
    } catch (e) {
      debugPrint('auth_service error: $e');
      return AuthResult.genericFailure(ErrorHandler.classifyUserError(e));
    }
  }

  /// Phase 4c: Mark phone as verified server-side via markPhoneVerified CF.
  ///
  /// Called after Firebase Auth phone OTP has succeeded (signInWithCredential
  /// or linkWithCredential with PhoneAuthCredential). The server CF will
  /// verify that the Firebase Auth user record has a non-empty phoneNumber
  /// (proving the OTP actually completed) and then write phoneVerified=true
  /// to the user's Firestore document.
  ///
  /// Returns success on server confirmation. Returns failure with a friendly
  /// message on rejection. Caller should treat failure as "user cannot
  /// proceed past phone verification".
  Future<AuthResult> markPhoneVerified() async {
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('markPhoneVerified');
      await callable.call();
      return AuthResult.success(null);
    } on FirebaseFunctionsException catch (e) {
      // ignore: avoid_print
      print('markPhoneVerified failed (${e.code}): ${e.message}');
      return _failureFromAuthCode(e.code);
    } catch (e) {
      debugPrint('auth_service error: $e');
      return AuthResult.genericFailure(ErrorHandler.classifyUserError(e));
    }
  }

  // ============================================================
  // EMAIL VERIFICATION
  // ============================================================

  /// Send email verification link to current user.
  ///
  /// Phase 4a: Tries Resend-based custom flow first (lands in inbox).
  /// Falls back to Firebase native (firebaseapp.com, often spam) if:
  /// - Custom flow is disabled by feature flag, OR
  /// - Cloud Function call fails for any reason.
  ///
  /// Either way, the link is a valid Firebase verification link.
  Future<AuthResult> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.failure(AuthErrorKey.noUserLoggedIn);
      }

      if (user.emailVerified) {
        return AuthResult.success(null); // Already verified
      }

      // Phase 4a: Try custom Resend-based flow first
      try {
        final callable = FirebaseFunctions.instance
            .httpsCallable('sendCustomEmailVerification');
        await callable.call();
        return AuthResult.success(null);
      } on FirebaseFunctionsException catch (e) {
        // 'failed-precondition' = feature flag is off → fall back silently
        // Other errors → log but still fall back to Firebase native
        if (e.code != 'failed-precondition') {
          // ignore: avoid_print
          print('sendCustomEmailVerification failed (${e.code}): ${e.message}. Falling back to Firebase native.');
        }
        await user.sendEmailVerification();
        return AuthResult.success(null);
      } catch (e) {
        // ignore: avoid_print
        print('sendCustomEmailVerification unexpected error: $e. Falling back to Firebase native.');
        await user.sendEmailVerification();
        return AuthResult.success(null);
      }
    } on FirebaseAuthException catch (e) {
      return _failureFromAuthCode(e.code);
    } catch (e) {
      debugPrint('auth_service error: $e');
      return AuthResult.genericFailure(ErrorHandler.classifyUserError(e));
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
        return AuthResult.failure(AuthErrorKey.noUserLoggedIn);
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
      debugPrint('auth_service error: $e');
      return AuthResult.genericFailure(ErrorHandler.classifyUserError(e));
    }
  }

  // ============================================================
  // PASSWORD MANAGEMENT
  // ============================================================

  /// Send password reset email to the given email address.
  ///
  /// Phase 4a: Tries Resend-based custom flow first (lands in inbox).
  /// Falls back to Firebase native if custom flow is disabled or fails.
  ///
  /// Always returns success regardless of whether the email exists,
  /// to prevent email enumeration attacks.
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      // Phase 4a: Try custom Resend-based flow first
      try {
        final callable = FirebaseFunctions.instance
            .httpsCallable('sendCustomPasswordReset');
        await callable.call({'email': email});
        return AuthResult.success(null);
      } on FirebaseFunctionsException catch (e) {
        if (e.code != 'failed-precondition') {
          // ignore: avoid_print
          print('sendCustomPasswordReset failed (${e.code}): ${e.message}. Falling back to Firebase native.');
        }
        await _auth.sendPasswordResetEmail(email: email);
        return AuthResult.success(null);
      } catch (e) {
        // ignore: avoid_print
        print('sendCustomPasswordReset unexpected error: $e. Falling back to Firebase native.');
        await _auth.sendPasswordResetEmail(email: email);
        return AuthResult.success(null);
      }
    } on FirebaseAuthException catch (e) {
      return _failureFromAuthCode(e.code);
    } catch (e) {
      debugPrint('auth_service error: $e');
      return AuthResult.genericFailure(ErrorHandler.classifyUserError(e));
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
        return AuthResult.failure(AuthErrorKey.noUserLoggedIn);
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
      return _failureFromAuthCode(e.code);
    } catch (e) {
      debugPrint('auth_service error: $e');
      return AuthResult.genericFailure(ErrorHandler.classifyUserError(e));
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

  /// Maps a FirebaseAuthException code to an [AuthErrorKey] enum value.
  AuthErrorKey _classifyAuthCode(String code) {
    switch (code) {
      case 'user-not-found':
        return AuthErrorKey.firebaseAccountNotFound;
      case 'wrong-password':
        return AuthErrorKey.firebaseWrongPassword;
      case 'email-already-in-use':
        return AuthErrorKey.firebaseEmailAlreadyInUse;
      case 'invalid-email':
        return AuthErrorKey.firebaseInvalidEmail;
      case 'weak-password':
        return AuthErrorKey.firebaseWeakPassword;
      case 'too-many-requests':
        return AuthErrorKey.firebaseTooManyRequests;
      case 'invalid-verification-code':
        return AuthErrorKey.firebaseInvalidVerificationCode;
      case 'invalid-verification-id':
        return AuthErrorKey.firebaseInvalidVerificationId;
      case 'credential-already-in-use':
        return AuthErrorKey.firebaseCredentialAlreadyInUse;
      case 'network-request-failed':
        return AuthErrorKey.firebaseNetworkRequestFailed;
      default:
        return AuthErrorKey.fallback;
    }
  }

  /// English fallback for the transitional [AuthResult.error] String field.
  ///
  /// Kept in sync with [resolveAuthErrorMessage] in auth_localization_resolver.dart.
  /// IMPORTANT: any English wording change must update BOTH this method AND the
  /// corresponding ARB key in app_en.arb. C.5 will collapse this duplication.
  String _englishOf(AuthErrorKey key) {
    switch (key) {
      // Service-layer
      case AuthErrorKey.failedToCreateUser:
        return 'Failed to create user';
      case AuthErrorKey.failedToSignIn:
        return 'Failed to sign in';
      case AuthErrorKey.userDataNotFound:
        return 'User data not found';
      case AuthErrorKey.googleSignInCancelled:
        return 'Google sign in cancelled';
      case AuthErrorKey.failedToSignInWithGoogle:
        return 'Failed to sign in with Google';
      case AuthErrorKey.failedToSignInWithApple:
        return 'Failed to sign in with Apple';
      case AuthErrorKey.appleSignInCancelled:
        return 'Apple sign in cancelled';
      case AuthErrorKey.appleSignInFailed:
        return 'Apple sign in failed';
      case AuthErrorKey.failedToVerifyOtp:
        return 'Failed to verify OTP';
      case AuthErrorKey.userNotFound:
        return 'User not found';
      case AuthErrorKey.noUserLoggedIn:
        return 'No user logged in';
      case AuthErrorKey.noVerificationId:
        return 'No verification ID. Please request OTP again.';
      // Firebase-code-derived
      case AuthErrorKey.firebaseAccountNotFound:
        return 'No account found with this email';
      case AuthErrorKey.firebaseWrongPassword:
        return 'Incorrect password';
      case AuthErrorKey.firebaseEmailAlreadyInUse:
        return 'An account already exists with this email';
      case AuthErrorKey.firebaseInvalidEmail:
        return 'Please enter a valid email address';
      case AuthErrorKey.firebaseWeakPassword:
        return 'Password must be at least 6 characters';
      case AuthErrorKey.firebaseTooManyRequests:
        return 'Too many attempts. Please try again later';
      case AuthErrorKey.firebaseInvalidVerificationCode:
        return 'Invalid OTP code. Please try again';
      case AuthErrorKey.firebaseInvalidVerificationId:
        return 'Verification session expired. Please request a new code';
      case AuthErrorKey.firebaseCredentialAlreadyInUse:
        return 'This phone number is already linked to another account';
      case AuthErrorKey.firebaseNetworkRequestFailed:
        return 'Network error. Please check your connection';
      // Fallback
      case AuthErrorKey.fallback:
        return 'An error occurred. Please try again';
    }
  }

  /// Compact helper: build an AuthResult.failure from a FirebaseAuthException
  /// code by classifying it into the corresponding [AuthErrorKey].
  AuthResult _failureFromAuthCode(String code) {
    return AuthResult.failure(_classifyAuthCode(code));
  }
}

/// Result wrapper for auth operations
class AuthResult {
  final bool success;
  final UserModel? user;
  final AuthErrorKey? errorKey;
  final GenericErrorKey? genericErrorKey;
  final bool isNewUser;

  AuthResult._({
    required this.success,
    this.user,
    this.errorKey,
    this.genericErrorKey,
    this.isNewUser = false,
  });

  factory AuthResult.success(UserModel? user, {bool isNewUser = false}) {
    return AuthResult._(success: true, user: user, isNewUser: isNewUser);
  }

  factory AuthResult.failure(AuthErrorKey errorKey) {
    return AuthResult._(success: false, errorKey: errorKey);
  }

  factory AuthResult.genericFailure(GenericErrorKey genericErrorKey) {
    return AuthResult._(success: false, genericErrorKey: genericErrorKey);
  }
}
