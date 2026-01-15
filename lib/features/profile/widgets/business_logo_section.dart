import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/constants.dart';
import '../../../providers/auth_provider.dart';

/// Business Logo Section Widget for Profile Screen
class BusinessLogoSection extends ConsumerStatefulWidget {
  const BusinessLogoSection({super.key});

  @override
  ConsumerState<BusinessLogoSection> createState() => _BusinessLogoSectionState();
}

class _BusinessLogoSectionState extends ConsumerState<BusinessLogoSection> {
  final _imagePicker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickAndUploadLogo() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXL),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiaryDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceXL),
              Text(
                'Upload Business Logo',
                style: AppTextStyles.headlineSmall(),
              ),
              const SizedBox(height: AppDimensions.spaceMD),
              Text(
                'This logo will appear in your payment QR codes',
                style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceXL),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                title: Text('Take Photo', style: AppTextStyles.bodyLarge()),
                onTap: () => _handleImageSource(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                title: Text('Choose from Gallery', style: AppTextStyles.bodyLarge()),
                onTap: () => _handleImageSource(ImageSource.gallery),
              ),
              const SizedBox(height: AppDimensions.spaceMD),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleImageSource(ImageSource source) async {
    Navigator.pop(context);

    final image = await _imagePicker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (image != null) {
      await _uploadLogo(image);
    }
  }

  Future<void> _uploadLogo(XFile image) async {
    setState(() => _isUploading = true);

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        throw Exception('User not logged in');
      }

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('business_logos')
          .child('${firebaseUser.uid}.png');

      final uploadTask = await storageRef.putFile(
        File(image.path),
        SettableMetadata(contentType: 'image/png'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .update({
        'businessLogoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Refresh auth state
      ref.read(authNotifierProvider.notifier).refreshUser();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business logo uploaded successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading logo: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _removeLogo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        ),
        title: Text('Remove Logo', style: AppTextStyles.headlineSmall()),
        content: Text(
          'Are you sure you want to remove your business logo?',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Remove',
              style: AppTextStyles.labelMedium(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUploading = true);

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        throw Exception('User not logged in');
      }

      // Delete from Firebase Storage
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('business_logos')
            .child('${firebaseUser.uid}.png');
        await storageRef.delete();
      } catch (e) {
        // Ignore if file doesn't exist
        debugPrint('Error deleting logo from storage: $e');
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .update({
        'businessLogoUrl': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Refresh auth state
      ref.read(authNotifierProvider.notifier).refreshUser();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business logo removed'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing logo: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final businessLogoUrl = user?.businessLogoUrl;
    final hasLogo = businessLogoUrl != null && businessLogoUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMD),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.inputBackgroundDark,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.textSecondaryDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppDimensions.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Business Logo',
                      style: AppTextStyles.bodyMedium(),
                    ),
                    Text(
                      hasLogo ? 'Logo uploaded' : 'Add your business logo',
                      style: AppTextStyles.caption(color: AppColors.textSecondaryDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMD),
          Row(
            children: [
              // Logo Preview
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.inputBackgroundDark,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  border: Border.all(
                    color: hasLogo ? AppColors.primary : AppColors.inputBorderDark,
                    width: 2,
                  ),
                ),
                child: _isUploading
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : hasLogo
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMD - 2),
                            child: Image.network(
                              businessLogoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_not_supported_outlined,
                                color: AppColors.textTertiaryDark,
                                size: 32,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppColors.textTertiaryDark,
                            size: 32,
                          ),
              ),
              const SizedBox(width: AppDimensions.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This logo will be embedded in your payment QR codes',
                      style: AppTextStyles.caption(color: AppColors.textTertiaryDark),
                    ),
                    const SizedBox(height: AppDimensions.spaceSM),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isUploading ? null : _pickAndUploadLogo,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              side: const BorderSide(color: AppColors.primary),
                            ),
                            child: Text(
                              hasLogo ? 'Change' : 'Upload',
                              style: AppTextStyles.labelSmall(color: AppColors.primary),
                            ),
                          ),
                        ),
                        if (hasLogo) ...[
                          const SizedBox(width: AppDimensions.spaceSM),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isUploading ? null : _removeLogo,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                side: const BorderSide(color: AppColors.error),
                              ),
                              child: Text(
                                'Remove',
                                style: AppTextStyles.labelSmall(color: AppColors.error),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
