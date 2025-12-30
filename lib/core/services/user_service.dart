import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../models/user_model.dart';

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

  /// Get current user profile
  Future<UserModel?> getCurrentUser() async {
    if (_userId == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(_userId).get();
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

      await _firestore.collection('users').doc(_userId).update(updates);

      // Update display name in Firebase Auth if fullName changed
      if (fullName != null) {
        await _auth.currentUser?.updateDisplayName(fullName);
      }

      final updatedUser = await getCurrentUser();
      return UserResult.success(updatedUser!);
    } catch (e) {
      return UserResult.failure('Failed to update profile: $e');
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
      return UserResult.failure('Failed to upload photo: $e');
    }
  }

  // ============================================================
  // KYC OPERATIONS
  // ============================================================

  /// Upload KYC documents
  Future<UserResult> uploadKycDocuments({
    required File idFront,
    File? idBack,
    required String idType,
    required DateTime dateOfBirth,
    File? selfie,
  }) async {
    if (_userId == null) {
      return UserResult.failure('User not authenticated');
    }

    try {
      final kycData = <String, dynamic>{
        'idType': idType,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'submittedAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      };

      // Upload ID front
      final frontRef = _storage
          .ref()
          .child('kyc_documents')
          .child(_userId!)
          .child('id_front.jpg');
      final frontUpload = await frontRef.putFile(idFront);
      kycData['idFrontUrl'] = await frontUpload.ref.getDownloadURL();

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

      // Store KYC data in subcollection
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('kyc')
          .doc('documents')
          .set(kycData);

      // Update user's KYC status
      await _firestore.collection('users').doc(_userId).update({
        'kycCompleted': false, // Will be true after manual/automated verification
        'dateOfBirth': dateOfBirth.toIso8601String(),
      });

      final updatedUser = await getCurrentUser();
      return UserResult.success(updatedUser!);
    } catch (e) {
      return UserResult.failure('Failed to upload KYC documents: $e');
    }
  }

  /// Get KYC status
  Future<KycStatus> getKycStatus() async {
    if (_userId == null) return KycStatus.notStarted;

    try {
      final kycDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('kyc')
          .doc('documents')
          .get();

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

      // Delete storage files
      try {
        await _storage.ref().child('profile_photos').child('$userId.jpg').delete();
      } catch (_) {}

      try {
        await _storage.ref().child('kyc_documents').child(userId).delete();
      } catch (_) {}

      // Delete Firebase Auth account
      await _auth.currentUser?.delete();

      return UserResult.success(null);
    } catch (e) {
      return UserResult.failure('Failed to delete account: $e');
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
