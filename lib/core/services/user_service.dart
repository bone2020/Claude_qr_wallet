import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../models/user_model.dart';
import '../utils/error_handler.dart';
import '../utils/network_retry.dart';

/// User service handling profile and user data operations
class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  // ============================================================
  // USER PROFILE
  // ============================================================

  /// Get current user profile with retry logic
  Future<UserModel?> getCurrentUser() async {
    if (_userId == null) return null;

    try {
      final doc = await NetworkRetry.execute(
        () => _firestore.collection('users').doc(_userId).get(),
        config: RetryConfig.quick,
      );
      if (!doc.exists) return null;
      return UserModel.fromJson(doc.data()!);
    } catch (e) {
      throw UserException('Failed to fetch user: $e');
    }
  }

  /// Stream of user profile (real-time updates)
  Stream<UserModel?> watchCurrentUser() {
    if (_userId == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(_userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromJson(doc.data()!);
    });
  }

  /// Update user profile
  Future<UserResult> updateProfile({
    String? fullName,
    String? phoneNumber,
    DateTime? dateOfBirth,
    String? country,
  }) async {
    if (_userId == null) {
      return UserResult.failure('User not authenticated');
    }

    try {
      final updates = <String, dynamic>{};

      if (fullName != null) updates['fullName'] = fullName;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (dateOfBirth != null) updates['dateOfBirth'] = dateOfBirth.toIso8601String();
      if (country != null) updates['country'] = country;

      if (updates.isEmpty) {
        return UserResult.failure('No updates provided');
      }

      await NetworkRetry.execute(
        () => _firestore.collection('users').doc(_userId).update(updates),
        config: RetryConfig.network,
      );

      // Update display name in Firebase Auth if fullName changed
      if (fullName != null) {
        await _auth.currentUser?.updateDisplayName(fullName);
      }

      final updatedUser = await getCurrentUser();
      return UserResult.success(updatedUser!);
    } catch (e) {
      return UserResult.failure(ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  /// Upload and update profile photo
  Future<UserResult> updateProfilePhoto(File imageFile) async {
    if (_userId == null) {
      return UserResult.failure('User not authenticated');
    }

    try {
      // Upload to Firebase Storage
      final ref = _storage
          .ref()
          .child('profile_photos')
          .child('$_userId.jpg');

      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update user document
      await _firestore.collection('users').doc(_userId).update({
        'profilePhotoUrl': downloadUrl,
      });

      // Update Firebase Auth photo URL
      await _auth.currentUser?.updatePhotoURL(downloadUrl);

      final updatedUser = await getCurrentUser();
      return UserResult.success(updatedUser!);
    } catch (e) {
      return UserResult.failure(ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  // ============================================================
  // KYC OPERATIONS
  // ============================================================

  /// Set KYC status on the server via Cloud Function.
  /// This sets the canonical kycStatus field that Cloud Functions enforce.
  Future<void> _setKycStatusOnServer(String status) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('updateKycStatus');
      await callable.call({'status': status});
    } catch (e) {
      // Log but don't fail the entire KYC flow — the legacy kycCompleted
      // field still provides backward-compatible enforcement
      // ignore: avoid_print
      print('Warning: Failed to set kycStatus via Cloud Function: $e');
    }
  }

  /// Mark user as KYC verified when SmileID returns "already enrolled" error.
  /// This means the user was previously verified via SmileID, so we should
  /// immediately set their kycStatus to 'verified' without requiring them
  /// to complete the full KYC flow again.
  ///
  /// This calls the markUserAlreadyEnrolled Cloud Function which handles
  /// all the server-side updates atomically.
  Future<UserResult> markKycVerifiedForAlreadyEnrolledUser({
    String? idType,
    DateTime? dateOfBirth,
  }) async {
    if (_userId == null) {
      return UserResult.failure('User not authenticated');
    }

    try {
      // Call the dedicated Cloud Function for "already enrolled" users
      // This function sets kycStatus: 'verified' directly without requiring
      // prior KYC document approval (since SmileID already verified them)
      final callable = FirebaseFunctions.instance.httpsCallable('markUserAlreadyEnrolled');
      final result = await callable.call({
        'idType': idType,
      });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] != true) {
        return UserResult.failure(data['error'] ?? 'Failed to update KYC status');
      }

      // Update date of birth locally if provided
      if (dateOfBirth != null) {
        await _firestore.collection('users').doc(_userId).update({
          'dateOfBirth': dateOfBirth.toIso8601String(),
        });
      }

      final updatedUser = await getCurrentUser();
      return UserResult.success(updatedUser);
    } catch (e) {
      // ignore: avoid_print
      print('Error in markKycVerifiedForAlreadyEnrolledUser: $e');
      return UserResult.failure(ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  /// Upload KYC documents
  Future<UserResult> uploadKycDocuments({
    File? idFront,
    File? idBack,
    required String idType,
    required DateTime dateOfBirth,
    File? selfie,
    String? idNumber,
    bool smileIdVerified = false,
    String? smileIdResult,
  }) async {
    if (_userId == null) {
      return UserResult.failure('User not authenticated');
    }

    // Require ID front image unless verified via Smile ID
    if (idFront == null && !smileIdVerified) {
      return UserResult.failure('ID front image is required');
    }

    try {
      final kycData = <String, dynamic>{
        'idType': idType,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'submittedAt': DateTime.now().toIso8601String(),
        'status': smileIdVerified ? 'verified' : 'pending',
        'smileIdVerified': smileIdVerified,
        if (idNumber != null) 'idNumber': idNumber,
        if (smileIdResult != null) 'smileIdResult': smileIdResult,
      };

      // Upload ID front (if provided)
      if (idFront != null) {
        final frontRef = _storage
            .ref()
            .child('kyc_documents')
            .child(_userId!)
            .child('id_front.jpg');
        final frontUpload = await frontRef.putFile(idFront);
        kycData['idFrontUrl'] = await frontUpload.ref.getDownloadURL();
      }

      // Upload ID back (if provided)
      if (idBack != null) {
        final backRef = _storage
            .ref()
            .child('kyc_documents')
            .child(_userId!)
            .child('id_back.jpg');
        final backUpload = await backRef.putFile(idBack);
        kycData['idBackUrl'] = await backUpload.ref.getDownloadURL();
      }

      // Upload selfie (if provided)
      if (selfie != null) {
        final selfieRef = _storage
            .ref()
            .child('kyc_documents')
            .child(_userId!)
            .child('selfie.jpg');
        final selfieUpload = await selfieRef.putFile(selfie);
        kycData['selfieUrl'] = await selfieUpload.ref.getDownloadURL();
      }

      // Store KYC data in subcollection with retry
      await NetworkRetry.execute(
        () => _firestore
            .collection('users')
            .doc(_userId)
            .collection('kyc')
            .doc('documents')
            .set(kycData),
        config: RetryConfig.network,
      );

      // Update user's KYC status with retry (legacy fields for backward compat)
      await NetworkRetry.execute(
        () => _firestore.collection('users').doc(_userId).update({
          'kycCompleted': true,
          'kycVerified': smileIdVerified,
          'dateOfBirth': dateOfBirth.toIso8601String(),
        }),
        config: RetryConfig.network,
      );

      // Set canonical kycStatus via Cloud Function (server-authoritative)
      if (smileIdVerified) {
        await _setKycStatusOnServer('verified');
      } else {
        await _setKycStatusOnServer('pending');
      }

      final updatedUser = await getCurrentUser();
      return UserResult.success(updatedUser!);
    } catch (e) {
      return UserResult.failure(ErrorHandler.getKycErrorMessage('document_upload', e));
    }
  }

  /// Get KYC status with retry logic
  Future<KycStatus> getKycStatus() async {
    if (_userId == null) return KycStatus.notStarted;

    try {
      final kycDoc = await NetworkRetry.execute(
        () => _firestore
            .collection('users')
            .doc(_userId)
            .collection('kyc')
            .doc('documents')
            .get(),
        config: RetryConfig.quick,
      );

      if (!kycDoc.exists) return KycStatus.notStarted;

      final status = kycDoc.data()?['status'] as String?;
      switch (status) {
        case 'pending':
          return KycStatus.pending;
        case 'approved':
          return KycStatus.approved;
        case 'rejected':
          return KycStatus.rejected;
        default:
          return KycStatus.notStarted;
      }
    } catch (e) {
      return KycStatus.notStarted;
    }
  }

  /// Save Smile ID KYC verification data
  Future<UserResult> saveSmileIdKycData({
    required String idType,
    String? idNumber,
    required String countryCode,
    required DateTime dateOfBirth,
    String? smileIdJobId,
    String? smileIdResultCode,
    Map<String, dynamic>? userData,
    File? selfie,
  }) async {
    if (_userId == null) {
      return UserResult.failure('User not authenticated');
    }

    try {
      final kycData = <String, dynamic>{
        'idType': idType,
        'idNumber': idNumber,
        'countryCode': countryCode,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'submittedAt': DateTime.now().toIso8601String(),
        'status': 'approved', // Smile ID verified
        'verificationMethod': 'smile_id',
        'smileIdJobId': smileIdJobId,
        'smileIdResultCode': smileIdResultCode,
      };

      // Add extracted user data from Smile ID if available
      if (userData != null) {
        kycData['verifiedData'] = userData;
      }

      // Upload selfie if provided
      if (selfie != null) {
        final selfieRef = _storage
            .ref()
            .child('kyc_documents')
            .child(_userId!)
            .child('selfie.jpg');
        final selfieUpload = await selfieRef.putFile(selfie);
        kycData['selfieUrl'] = await selfieUpload.ref.getDownloadURL();
      }

      // Store KYC data in subcollection with retry
      await NetworkRetry.execute(
        () => _firestore
            .collection('users')
            .doc(_userId)
            .collection('kyc')
            .doc('documents')
            .set(kycData),
        config: RetryConfig.network,
      );

      // Update user's KYC status and country
      final userUpdates = <String, dynamic>{
        'kycCompleted': true,
        'kycVerified': true,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'country': countryCode,
      };

      // If Smile ID returned user data, update profile
      if (userData != null) {
        if (userData['fullName'] != null) {
          userUpdates['fullName'] = userData['fullName'];
          await _auth.currentUser?.updateDisplayName(userData['fullName']);
        }
      }

      await NetworkRetry.execute(
        () => _firestore.collection('users').doc(_userId).update(userUpdates),
        config: RetryConfig.network,
      );

      // Set canonical kycStatus via Cloud Function (server-authoritative)
      await _setKycStatusOnServer('verified');

      final updatedUser = await getCurrentUser();
      return UserResult.success(updatedUser!);
    } catch (e) {
      return UserResult.failure(ErrorHandler.getKycErrorMessage('biometric_kyc', e));
    }
  }

  // ============================================================
  // USER LOOKUP
  // ============================================================

  /// Get user by wallet ID
  Future<UserModel?> getUserByWalletId(String walletId) async {
    try {
      final walletQuery = await _firestore
          .collection('wallets')
          .where('walletId', isEqualTo: walletId)
          .limit(1)
          .get();

      if (walletQuery.docs.isEmpty) return null;

      final userId = walletQuery.docs.first.data()['userId'] as String;
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) return null;
      return UserModel.fromJson(userDoc.data()!);
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // SETTINGS
  // ============================================================

  /// Update user settings
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    if (_userId == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('settings')
        .doc('preferences')
        .set(settings, SetOptions(merge: true));
  }

  /// Get user settings
  Future<Map<String, dynamic>> getSettings() async {
    if (_userId == null) return {};

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('settings')
          .doc('preferences')
          .get();

      return doc.data() ?? {};
    } catch (e) {
      return {};
    }
  }

  // ============================================================
  // ACCOUNT DELETION
  // ============================================================

  /// Delete user account
  Future<UserResult> deleteAccount() async {
    if (_userId == null) {
      return UserResult.failure('User not authenticated');
    }

    try {
      final userId = _userId!;

      // Delete user data from Firestore
      await _firestore.collection('users').doc(userId).delete();
      await _firestore.collection('wallets').doc(userId).delete();

      // Delete storage files (best effort - continue deletion even if these fail)
      try {
        await _storage.ref().child('profile_photos').child('$userId.jpg').delete();
      } on FirebaseException catch (e) {
        // Only ignore 'object-not-found' errors - file may not exist
        if (e.code != 'object-not-found') {
          // Log unexpected storage errors but continue with account deletion
          // ignore: avoid_print
          print('Warning: Failed to delete profile photo during account deletion: ${e.code} - ${e.message}');
        }
      }

      try {
        await _storage.ref().child('kyc_documents').child(userId).delete();
      } on FirebaseException catch (e) {
        // Only ignore 'object-not-found' errors - folder may not exist
        if (e.code != 'object-not-found') {
          // Log unexpected storage errors but continue with account deletion
          // ignore: avoid_print
          print('Warning: Failed to delete KYC documents during account deletion: ${e.code} - ${e.message}');
        }
      }

      // Delete Firebase Auth account
      await _auth.currentUser?.delete();

      return UserResult.success(null);
    } catch (e) {
      return UserResult.failure(ErrorHandler.getUserFriendlyMessage(e));
    }
  }
}

/// Result wrapper for user operations
class UserResult {
  final bool success;
  final UserModel? user;
  final String? error;

  UserResult._({
    required this.success,
    this.user,
    this.error,
  });

  factory UserResult.success(UserModel? user) {
    return UserResult._(success: true, user: user);
  }

  factory UserResult.failure(String error) {
    return UserResult._(success: false, error: error);
  }
}

/// KYC verification status
enum KycStatus {
  notStarted,
  pending,
  approved,
  rejected,
}

/// Custom exception for user operations
class UserException implements Exception {
  final String message;
  UserException(this.message);

  @override
  String toString() => message;
}
