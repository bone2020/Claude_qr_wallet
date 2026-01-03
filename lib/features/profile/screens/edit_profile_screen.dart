import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/constants/constants.dart';
import '../../../providers/auth_provider.dart';
import '../../auth/widgets/custom_text_field.dart';

/// Edit profile screen
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  final _imagePicker = ImagePicker();
  XFile? _newPhoto;
  bool _isLoading = false;
  String? _currentPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  void _loadCurrentUserData() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _fullNameController.text = user.fullName;
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
      _currentPhotoUrl = user.profilePhotoUrl;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
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
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                title: Text(AppStrings.takePhoto, style: AppTextStyles.bodyLarge()),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await _imagePicker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 512,
                    maxHeight: 512,
                    imageQuality: 80,
                  );
                  if (image != null) {
                    setState(() => _newPhoto = image);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                title: Text(AppStrings.uploadPhoto, style: AppTextStyles.bodyLarge()),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await _imagePicker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 512,
                    maxHeight: 512,
                    imageQuality: 80,
                  );
                  if (image != null) {
                    setState(() => _newPhoto = image);
                  }
                },
              ),
              const SizedBox(height: AppDimensions.spaceMD),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _uploadProfilePhoto(String userId) async {
    if (_newPhoto == null) return _currentPhotoUrl;

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$userId.jpg');

      final uploadTask = await storageRef.putFile(
        File(_newPhoto!.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      return _currentPhotoUrl;
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        throw Exception('User not logged in');
      }

      // Upload new photo if selected
      String? photoUrl = _currentPhotoUrl;
      if (_newPhoto != null) {
        photoUrl = await _uploadProfilePhoto(firebaseUser.uid);
      }

      // Update display name in Firebase Auth
      await firebaseUser.updateDisplayName(_fullNameController.text.trim());
      if (photoUrl != null) {
        await firebaseUser.updatePhotoURL(photoUrl);
      }

      // Update user document in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .update({
        'fullName': _fullNameController.text.trim(),
        if (photoUrl != null) 'profilePhotoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Refresh auth state
      ref.read(authNotifierProvider.notifier).refreshUser();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.successProfileUpdated),
          backgroundColor: AppColors.success,
        ),
      );

      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final initials = user?.fullName.isNotEmpty == true
        ? user!.fullName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(AppStrings.editProfile, style: AppTextStyles.headlineMedium()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Profile Photo
                      _buildPhotoSection(initials),

                      const SizedBox(height: AppDimensions.spaceXXL),

                      // Form Fields
                      CustomTextField(
                        label: AppStrings.fullName,
                        hintText: AppStrings.fullNameHint,
                        controller: _fullNameController,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppStrings.errorFieldRequired;
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: AppDimensions.spaceMD),

                      CustomTextField(
                        label: AppStrings.email,
                        hintText: AppStrings.emailHint,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        enabled: false, // Email can't be changed
                      ),

                      const SizedBox(height: AppDimensions.spaceMD),

                      PhoneTextField(
                        controller: _phoneController,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Save Button
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection(String initials) {
    return GestureDetector(
      onTap: _pickImage,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                child: _buildAvatarContent(initials),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.backgroundDark,
                      width: 3,
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 18,
                    color: AppColors.backgroundDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSM),
          Text(
            'Change Photo',
            style: AppTextStyles.bodyMedium(color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent(String initials) {
    // Show new photo if selected
    if (_newPhoto != null) {
      return ClipOval(
        child: Image.file(
          File(_newPhoto!.path),
          fit: BoxFit.cover,
          width: 120,
          height: 120,
          errorBuilder: (_, __, ___) => _buildDefaultAvatar(initials),
        ),
      );
    }

    // Show current photo if exists
    if (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          _currentPhotoUrl!,
          fit: BoxFit.cover,
          width: 120,
          height: 120,
          errorBuilder: (_, __, ___) => _buildDefaultAvatar(initials),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            );
          },
        ),
      );
    }

    // Show default avatar with initials
    return _buildDefaultAvatar(initials);
  }

  Widget _buildDefaultAvatar(String initials) {
    return Center(
      child: Text(
        initials,
        style: AppTextStyles.displaySmall(color: AppColors.primary),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        border: Border(
          top: BorderSide(color: AppColors.inputBorderDark, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeightLG,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSave,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.backgroundDark,
                    ),
                  )
                : Text(
                    AppStrings.save,
                    style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
                  ),
          ),
        ),
      ),
    );
  }
}
