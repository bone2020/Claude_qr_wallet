import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../models/user_model.dart';
import '../utils/error_handler.dart';
import '../utils/error_handler_localization_resolver.dart';
import '../utils/network_retry.dart';
import 'user_localization_resolver.dart';

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
      return UserResult.failure(UserErrorKey.userNotAuthenticated);
    }

    try {
      final updates = <String, dynamic>{};

      if (fullName != null) updates['fullName'] = fullName;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (dateOfBirth != null) updates['dateOfBirth'] = dateOfBirth.toIso8601String();
      if (country != null) updates['country'] = country;

      if (updates.isEmpty) {
        return UserResult.failure(UserErrorKey.noUpdatesProvided);
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
      debugPrint('user_service error: $e');
      return UserResult.genericFailure(ErrorHandler.classifyUserError(e));
    }
  }

  /// Upload and update profile photo
  Future<UserResult> updateProfilePhoto(File imageFile) async {
    if (_userId == null) {
      return UserResult.failure(UserErrorKey.userNotAuthenticated);
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
      debugPrint('user_service error: $e');
      return UserResult.genericFailure(ErrorHandler.classifyUserError(e));
    }
  }

  // ============================================================
  // KYC OPERATIONS
  // ============================================================

  /// Complete KYC verification by setting kycStatus via Cloud Function.
  ///
  /// This must be called server-side because Firestore rules block client-side
  /// writes to kycStatus for security. The Cloud Function uses Admin SDK to
  /// bypass these rules after validating that KYC documents exist.
  Future<void> _completeKycVerification() async {
    final callable = FirebaseFunctions.instance.httpsCallable('completeKycVerification');
    await callable.call();
    // Errors are propagated to the caller - KYC is not complete if this fails
  }

 /// Upload KYC documents.
  ///
  /// New parameters (added by audit fix §4.1 Phase 2.0):
  ///
  /// - [livenessImages]: optional list of liveness frame files captured by the
  ///   Smile ID SDK. When provided, each frame is uploaded to Storage and its
  ///   path is returned via [UserResult.kycMediaPaths.livenessStoragePaths].
  ///   Required by the server-side BIOMETRIC_KYC submission flow.
  /// - [mediaScope]: optional path-prefix segment used to isolate this upload
  ///   attempt from previous attempts. When non-null, uploads land under
  ///   `kyc_documents/{userId}/{mediaScope}/`. When null, uploads fall back to
  ///   the legacy flat layout `kyc_documents/{userId}/`. Callers that want
  ///   per-attempt isolation (and audit traceability matching Smile ID jobs)
  ///   should pass the Smile ID job ID extracted from the SDK result.
  ///
  /// Returns [UserResult.success] with a populated [KycMediaPaths] containing
  /// the storage paths of all files that were uploaded. Callers that need to
  /// invoke the server-side submitBiometricKycVerification callable should
  /// read these paths off the result.
  Future<UserResult> uploadKycDocuments({
    File? idFront,
    File? idBack,
    required String idType,
    required DateTime dateOfBirth,
    File? selfie,
    List<File>? livenessImages,
    String? mediaScope,
    String? idNumber,
    bool smileIdVerified = false,
    String? smileIdResult,
  }) async {
    if (_userId == null) {
      return UserResult.failure(UserErrorKey.userNotAuthenticated);
    }

    // Require ID front image unless verified via Smile ID
    if (idFront == null && !smileIdVerified) {
      return UserResult.failure(UserErrorKey.idFrontImageRequired);
    }

    try {
      // Per-attempt path prefix. When mediaScope is provided (typically a
      // Smile ID job ID) uploads land in a per-attempt subfolder so retries
      // don't overwrite or partial-mix with previous attempts. When mediaScope
      // is null/empty, paths fall back to the legacy flat layout for
      // backward compatibility with screens that haven't adopted scoping yet.
      final String prefix = (mediaScope != null && mediaScope.isNotEmpty)
          ? 'kyc_documents/$_userId/$mediaScope'
          : 'kyc_documents/$_userId';

      String? idFrontStoragePath;
      String? idBackStoragePath;
      String? selfieStoragePath;
      final livenessStoragePaths = <String>[];

      final kycData = <String, dynamic>{
        'idType': idType,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'submittedAt': DateTime.now().toIso8601String(),
        'status': 'pending_review',
        'smileIdVerified': smileIdVerified,
        if (idNumber != null) 'idNumber': idNumber,
        if (smileIdResult != null) 'smileIdResult': smileIdResult,
        if (mediaScope != null && mediaScope.isNotEmpty) 'mediaScope': mediaScope,
      };

      // Upload ID front (if provided)
      if (idFront != null) {
        idFrontStoragePath = '$prefix/id_front.jpg';
        final frontRef = _storage.ref().child(idFrontStoragePath);
        final frontUpload = await frontRef.putFile(idFront);
        kycData['idFrontUrl'] = await frontUpload.ref.getDownloadURL();
        kycData['idFrontStoragePath'] = idFrontStoragePath;
      }

      // Upload ID back (if provided)
      if (idBack != null) {
        idBackStoragePath = '$prefix/id_back.jpg';
        final backRef = _storage.ref().child(idBackStoragePath);
        final backUpload = await backRef.putFile(idBack);
        kycData['idBackUrl'] = await backUpload.ref.getDownloadURL();
        kycData['idBackStoragePath'] = idBackStoragePath;
      }

      // Upload selfie (if provided)
      if (selfie != null) {
        selfieStoragePath = '$prefix/selfie.jpg';
        final selfieRef = _storage.ref().child(selfieStoragePath);
        final selfieUpload = await selfieRef.putFile(selfie);
        kycData['selfieUrl'] = await selfieUpload.ref.getDownloadURL();
        kycData['selfieStoragePath'] = selfieStoragePath;
      }

      // Upload liveness frames (if provided). Each frame produces a stable
      // path of the form `$prefix/liveness_$i.jpg`. The backend
      // submitBiometricKycVerification callable expects a non-empty array
      // of these paths to fulfill Smile ID's BIOMETRIC_KYC liveness signal.
      if (livenessImages != null && livenessImages.isNotEmpty) {
        for (var i = 0; i < livenessImages.length; i++) {
          final path = '$prefix/liveness_$i.jpg';
          final ref = _storage.ref().child(path);
          await ref.putFile(livenessImages[i]);
          livenessStoragePaths.add(path);
        }
        kycData['livenessStoragePaths'] = livenessStoragePaths;
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

      // Phase 4b: kycCompleted and kycVerified are now server-only; they are
      // set atomically by completeKycVerification CF when kycStatus is set
      // to 'verified' (see functions/index.js:2922). Client only persists
      // dateOfBirth here.
      await NetworkRetry.execute(
        () => _firestore.collection('users').doc(_userId).update({
          'dateOfBirth': dateOfBirth.toIso8601String(),
        }),
        config: RetryConfig.network,
      );

      // Set kycStatus via Cloud Function (server-side only for security)
      if (smileIdVerified) {
        await _completeKycVerification();
      }

      final updatedUser = await getCurrentUser();
      return UserResult.success(
        updatedUser!,
        kycMediaPaths: KycMediaPaths(
          selfieStoragePath: selfieStoragePath,
          livenessStoragePaths: livenessStoragePaths,
          idFrontStoragePath: idFrontStoragePath,
          idBackStoragePath: idBackStoragePath,
        ),
      );
    } catch (e) {
      debugPrint('user_service error: $e');
      return UserResult.genericFailure(ErrorHandler.classifyUserError(e));
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
        case 'pending_review':
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
      return UserResult.failure(UserErrorKey.userNotAuthenticated);
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

      // Phase 4b: kycCompleted and kycVerified are now server-only; they are
      // set atomically by completeKycVerification CF when kycStatus is set
      // to 'verified' (see functions/index.js:2922).
      final userUpdates = <String, dynamic>{
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

      // Set kycStatus via Cloud Function (server-side only for security)
      await _completeKycVerification();

      final updatedUser = await getCurrentUser();
      return UserResult.success(updatedUser!);
    } catch (e) {
      debugPrint('user_service error: $e');
      return UserResult.genericFailure(ErrorHandler.classifyUserError(e));
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

  /// Request account deletion via the server-side Cloud Function.
  ///
  /// This calls the `deleteUserData` Cloud Function which:
  ///   - Validates all blockers (pending withdrawals, MoMo, balance > 0,
  ///     open disputes, outstanding debts) and refuses if any are present
  ///   - Snapshots all user data into `compliance_archive/{userId}` with
  ///     7-year retention (AML compliance)
  ///   - Moves storage files (profile photos, KYC docs, QR codes, receipts)
  ///     to the locked `qr-wallet-1993-compliance` bucket
  ///   - Deletes the original Firestore data, wallet, and Firebase Auth user
  ///   - Keeps audit log entries intact (with userId) for fraud traceability
  ///
  /// Returns:
  ///   - [UserResult.success] (with null data) if deletion completed
  ///   - [UserResult.failure] with [UserErrorKey.userNotAuthenticated] if
  ///     called while signed out
  ///   - [UserResult.serverFailure] carrying the server's human-readable
  ///     message if a server guard refused the deletion (the caller can
  ///     display this directly or pattern-match it to offer a specific
  ///     remediation action like "go to withdraw")
  ///
  /// On success, the caller is responsible for signing out and navigating
  /// away from authenticated screens — the auth account is gone, but the
  /// Flutter app's cached auth state may not have noticed yet.
  Future<UserResult> requestAccountDeletion({bool confirmForfeit = false}) async {
    if (_userId == null) {
      return UserResult.failure(UserErrorKey.userNotAuthenticated);
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'deleteUserData',
        options: HttpsCallableOptions(
          // Server timeout is 300s; give the client a bit more headroom.
          timeout: const Duration(seconds: 330),
        ),
      );
      await callable.call(<String, dynamic>{
        'confirmDeletion': 'DELETE_MY_ACCOUNT',
        // confirmForfeit is only honored server-side when the user's balance
        // is below MIN_WITHDRAWAL_THRESHOLD; setting it on a zero-balance or
        // above-threshold account is harmless.
        if (confirmForfeit) 'confirmForfeit': true,
      });
      return UserResult.success(null);
    } on FirebaseFunctionsException catch (e) {
      // Server returns user-facing messages from throwAppError(...). Pass them
      // through to the UI verbatim — they're already worded for end users.
      debugPrint('requestAccountDeletion FF error: ${e.code} - ${e.message}');
      final message = e.message ?? 'Account deletion failed. Please try again.';
      return UserResult.serverFailure(message);
    } catch (e) {
      debugPrint('user_service requestAccountDeletion error: $e');
      return UserResult.genericFailure(ErrorHandler.classifyUserError(e));
    }
  }
}

/// Storage paths for KYC media files uploaded by [UserService.uploadKycDocuments].
///
/// Returned via [UserResult.kycMediaPaths] when the upload succeeds. These paths
/// reference files in Firebase Storage and are intended to be passed verbatim
/// to server-side callable functions (e.g. submitBiometricKycVerification) so
/// the backend can download the original files and forward them to identity
/// providers like Smile ID.
///
/// When the upload is scoped (i.e. the caller passed `mediaScope`), all paths
/// share the per-attempt prefix `kyc_documents/{userId}/{mediaScope}/`. When
/// the upload is not scoped, paths fall back to the legacy flat layout
/// `kyc_documents/{userId}/`.
class KycMediaPaths {
  final String? selfieStoragePath;
  final List<String> livenessStoragePaths;
  final String? idFrontStoragePath;
  final String? idBackStoragePath;

  const KycMediaPaths({
    this.selfieStoragePath,
    this.livenessStoragePaths = const [],
    this.idFrontStoragePath,
    this.idBackStoragePath,
  });
}

/// Result wrapper for user operations
class UserResult {
  final bool success;
  final UserModel? user;
  final UserErrorKey? errorKey;
  final GenericErrorKey? genericErrorKey;

  /// Human-readable message returned directly from a server Cloud Function
  /// (e.g. a deleteUserData guard refusal). Already worded for end users —
  /// display verbatim. Null for all enum-key-based results.
  final String? serverMessage;
  final KycMediaPaths? kycMediaPaths;

  UserResult._({
    required this.success,
    this.user,
    this.errorKey,
    this.genericErrorKey,
    this.serverMessage,
    this.kycMediaPaths,
  });

  factory UserResult.success(UserModel? user, {KycMediaPaths? kycMediaPaths}) {
    return UserResult._(
      success: true,
      user: user,
      kycMediaPaths: kycMediaPaths,
    );
  }

  factory UserResult.failure(UserErrorKey errorKey) {
    return UserResult._(success: false, errorKey: errorKey);
  }

  factory UserResult.genericFailure(GenericErrorKey genericErrorKey) {
    return UserResult._(success: false, genericErrorKey: genericErrorKey);
  }

  /// Failure carrying a human-readable message produced by the server
  /// (passed through verbatim to the UI). Used when a Cloud Function returns
  /// an already-user-facing error, e.g. deleteUserData guard refusals.
  factory UserResult.serverFailure(String message) {
    return UserResult._(success: false, serverMessage: message);
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
