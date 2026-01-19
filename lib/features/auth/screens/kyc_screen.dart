import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/user_service.dart';
import '../../../core/services/smile_id_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';

/// KYC screen for identity verification
class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  final _imagePicker = ImagePicker();
  final _idNumberController = TextEditingController();
  final _smileIdService = SmileIDService.instance;

  String? _selectedIdType;
  XFile? _idFrontImage;
  XFile? _idBackImage;
  DateTime? _dateOfBirth;
  XFile? _profilePhoto;
  String? _userCountryCode;

  bool _isLoading = false;
  bool _isVerifying = false;

  // Smile ID verification state
  SmileIDResult? _verificationResult;
  bool get _isVerified => _verificationResult?.success == true;

  List<Map<String, dynamic>> _idTypes = [];

  @override
  void initState() {
    super.initState();
    _loadUserCountry();
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    super.dispose();
  }

  void _loadUserCountry() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      // Try to get country from user model
      _userCountryCode = user.country;
      
      // If no country, try to extract from phone number
      if (_userCountryCode == null || _userCountryCode!.isEmpty) {
        _userCountryCode = _smileIdService.extractCountryCode(user.phoneNumber);
      }
    }
    
    // Default to Ghana if no country detected
    _userCountryCode ??= 'GH';
    
    // Load ID types for this country
    setState(() {
      _idTypes = _smileIdService.getIdTypesForCountry(_userCountryCode);
    });
  }

  /// Check if the selected ID type requires a number input
  bool get _requiresIdNumber {
    if (_selectedIdType == null) return false;
    final idType = _idTypes.firstWhere(
      (type) => type['value'] == _selectedIdType,
      orElse: () => {'requiresNumber': false},
    );
    return idType['requiresNumber'] == true;
  }

  /// Check if selected ID is a passport (only has front page)
  bool get _isPassport => _selectedIdType == 'PASSPORT';

  /// Get the label for the selected ID type
  String get _selectedIdLabel {
    if (_selectedIdType == null) return '';
    final idType = _idTypes.firstWhere(
      (type) => type['value'] == _selectedIdType,
      orElse: () => {'label': ''},
    );
    return idType['label'] ?? '';
  }

  Future<void> _pickImage(ImageSource source, String type) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          switch (type) {
            case 'front':
              _idFrontImage = image;
              break;
            case 'back':
              _idBackImage = image;
              break;
            case 'profile':
              _profilePhoto = image;
              break;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showImageSourceSheet(String type) {
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
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera, type);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                title: Text(AppStrings.uploadPhoto, style: AppTextStyles.bodyLarge()),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery, type);
                },
              ),
              const SizedBox(height: AppDimensions.spaceMD),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 18),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surfaceDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => _dateOfBirth = date);
    }
  }

  /// Start Smile ID verification process
  Future<void> _startSmileIdVerification() async {
    if (_selectedIdType == null) {
      _showError('Please select an ID type first');
      return;
    }

    // Validate ID number if required
    if (_requiresIdNumber) {
      final idNumber = _idNumberController.text.trim();
      if (idNumber.isEmpty) {
        _showError('Please enter your ID number first');
        return;
      }

      final validation = _smileIdService.validateIdNumber(
        idNumber,
        _selectedIdType!,
        _userCountryCode ?? 'GH',
      );

      if (!validation.isValid) {
        _showError(validation.error ?? 'Invalid ID number format');
        return;
      }
    }

    setState(() => _isVerifying = true);

    try {
      final user = ref.read(currentUserProvider);
      final userId = user?.id ?? _smileIdService.generateUserId();
      final smileIdType = _smileIdService.getSmileIdDocumentType(
        _selectedIdType!,
        _userCountryCode ?? 'GH',
      );

      SmileIDResult result;

      if (_requiresIdNumber) {
        // Use Biometric KYC for ID types that require a number (NIN, BVN, SSNIT)
        // This verifies the ID number against government database AND captures selfie
        result = await _smileIdService.doBiometricKyc(
          userId: userId,
          countryCode: _userCountryCode ?? 'GH',
          idType: smileIdType,
          idNumber: _idNumberController.text.trim(),
          firstName: user?.fullName?.split(' ').first,
          lastName: user?.fullName?.split(' ').skip(1).join(' '),
        );
      } else {
        // Use Enhanced Document Verification for document-based verification
        // This captures ID document AND selfie, then compares faces
        result = await _smileIdService.doEnhancedDocumentVerification(
          userId: userId,
          countryCode: _userCountryCode ?? 'GH',
          idType: smileIdType,
        );
      }

      if (!mounted) return;

      setState(() {
        _verificationResult = result;
        _isVerifying = false;
      });

      if (result.success) {
        _showSuccess('Identity verified successfully!');
      } else {
        _showError(result.error ?? 'Verification failed. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      _showError('Verification error: ${e.toString()}');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _handleContinue() async {
    // Validate required fields
    if (_selectedIdType == null) {
      _showError('Please select an ID type');
      return;
    }

    // Validate ID number if required
    if (_requiresIdNumber) {
      final idNumber = _idNumberController.text.trim();
      if (idNumber.isEmpty) {
        _showError('Please enter your $_selectedIdLabel number');
        return;
      }

      // Validate ID number format
      final validation = _smileIdService.validateIdNumber(
        idNumber,
        _selectedIdType!,
        _userCountryCode ?? 'GH',
      );

      if (!validation.isValid) {
        _showError(validation.error ?? 'Invalid ID number format');
        return;
      }
    }

    // Check for Smile ID verification OR manual document upload
    if (!_isVerified) {
      // If not verified via Smile ID, require manual document upload
      if (_idFrontImage == null) {
        _showError('Please verify your identity or upload the front of your ID');
        return;
      }
      if (!_isPassport && _idBackImage == null) {
        _showError('Please upload the back of your ID');
        return;
      }
      if (_profilePhoto == null) {
        _showError('Please upload a profile photo');
        return;
      }
    }

    if (_dateOfBirth == null) {
      _showError('Please select your date of birth');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userService = UserService();
      UserResult result;

      if (_isVerified) {
        // Use Smile ID verified data
        result = await userService.saveSmileIdKycData(
          idType: _selectedIdType!,
          idNumber: _requiresIdNumber ? _idNumberController.text.trim() : null,
          countryCode: _userCountryCode ?? 'GH',
          dateOfBirth: _dateOfBirth!,
          smileIdJobId: _verificationResult?.jobId,
          smileIdResultCode: _verificationResult?.resultCode,
          userData: _verificationResult?.userData,
          selfie: _profilePhoto != null ? File(_profilePhoto!.path) : null,
        );
      } else {
        // Fallback to manual document upload
        result = await userService.uploadKycDocuments(
          idFront: File(_idFrontImage!.path),
          idBack: _idBackImage != null ? File(_idBackImage!.path) : null,
          idType: _selectedIdType!,
          dateOfBirth: _dateOfBirth!,
          selfie: _profilePhoto != null ? File(_profilePhoto!.path) : null,
          idNumber: _requiresIdNumber ? _idNumberController.text.trim() : null,
        );
      }

      if (!mounted) return;

      if (result.success) {
        // Update local user state if user data was returned
        if (result.user != null) {
          ref.read(authNotifierProvider.notifier).updateUser(result.user!);
        }
        // Load user's currency before navigating
        await ref.read(currencyNotifierProvider.notifier).loadUserCurrency();
        // Navigate to main screen
        context.go(AppRoutes.main);
      } else {
        _showError(result.error ?? 'Failed to save KYC data');
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppDimensions.spaceLG),

                    // Header
                    _buildHeader()
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: -0.2, end: 0, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXXL),

                    // ID Type Dropdown
                    _buildIdTypeDropdown()
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceLG),

                    // ID Number Input (if required)
                    if (_selectedIdType != null && _requiresIdNumber) ...[
                      _buildIdNumberInput()
                          .animate()
                          .fadeIn(delay: 150.ms, duration: 400.ms),
                      const SizedBox(height: AppDimensions.spaceLG),
                    ],

                    // Smile ID Verification Button
                    if (_selectedIdType != null) ...[
                      _buildVerificationSection()
                          .animate()
                          .fadeIn(delay: 175.ms, duration: 400.ms),
                      const SizedBox(height: AppDimensions.spaceLG),
                    ],

                    // ID Upload (only if not verified via Smile ID)
                    if (_selectedIdType != null && !_isVerified) ...[
                      _buildIdUpload()
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 400.ms),
                      const SizedBox(height: AppDimensions.spaceLG),
                    ],

                    // Date of Birth
                    _buildDateOfBirth()
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceLG),

                    // Profile Photo
                    _buildProfilePhoto()
                        .animate()
                        .fadeIn(delay: 400.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXXL),
                  ],
                ),
              ),
            ),

            // Bottom Buttons
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.completeProfile,
          style: AppTextStyles.displaySmall(),
        ),
        const SizedBox(height: AppDimensions.spaceXS),
        Text(
          AppStrings.completeProfileSubtitle,
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
      ],
    );
  }

  Widget _buildIdTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.governmentId,
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceXS),
        Container(
          decoration: BoxDecoration(
            color: AppColors.inputBackgroundDark,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            border: Border.all(color: AppColors.inputBorderDark),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedIdType,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMD),
                child: Text(
                  AppStrings.selectIdType,
                  style: AppTextStyles.inputHint(),
                ),
              ),
              isExpanded: true,
              dropdownColor: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              items: _idTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type['value'] as String,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMD),
                    child: Text(
                      type['label'] as String,
                      style: AppTextStyles.inputText(),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedIdType = value;
                  _idFrontImage = null;
                  _idBackImage = null;
                  _idNumberController.clear();
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdNumberInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_selectedIdLabel Number',
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceXS),
        Container(
          decoration: BoxDecoration(
            color: AppColors.inputBackgroundDark,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            border: Border.all(color: AppColors.inputBorderDark),
          ),
          child: TextField(
            controller: _idNumberController,
            style: AppTextStyles.inputText(),
            decoration: InputDecoration(
              hintText: 'Enter your $_selectedIdLabel number',
              hintStyle: AppTextStyles.inputHint(),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceMD,
                vertical: AppDimensions.spaceMD,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spaceXS),
        Text(
          _getIdNumberHint(),
          style: AppTextStyles.bodySmall(color: AppColors.textTertiaryDark),
        ),
      ],
    );
  }

  String _getIdNumberHint() {
    if (_selectedIdType == null) {
      return 'Enter your ID number as shown on your document';
    }
    return _smileIdService.getIdFormatHint(_selectedIdType!, _userCountryCode ?? 'GH');
  }

  Widget _buildVerificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Identity Verification',
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceXS),
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceMD),
          decoration: BoxDecoration(
            color: _isVerified
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.inputBackgroundDark,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            border: Border.all(
              color: _isVerified ? AppColors.success : AppColors.inputBorderDark,
            ),
          ),
          child: Column(
            children: [
              if (_isVerified) ...[
                // Verified state
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: AppDimensions.spaceMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verified Successfully',
                            style: AppTextStyles.bodyLarge(color: AppColors.success),
                          ),
                          Text(
                            'Your identity has been verified via Smile ID',
                            style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Not verified state - show verify button
                Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: AppColors.primary,
                      size: 32,
                    ),
                    const SizedBox(width: AppDimensions.spaceMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Verification',
                            style: AppTextStyles.bodyLarge(),
                          ),
                          Text(
                            'Verify instantly with face recognition',
                            style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceMD),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isVerifying ? null : _startSmileIdVerification,
                    icon: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.backgroundDark,
                            ),
                          )
                        : const Icon(Icons.face_rounded),
                    label: Text(
                      _isVerifying ? 'Verifying...' : 'Verify with Smile ID',
                      style: AppTextStyles.labelMedium(color: AppColors.backgroundDark),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceMD),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceSM),
                Center(
                  child: Text(
                    'Or upload documents manually below',
                    style: AppTextStyles.bodySmall(color: AppColors.textTertiaryDark),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Front / Main Page
        _buildUploadCard(
          title: _isPassport ? AppStrings.uploadMainPage : AppStrings.uploadFront,
          image: _idFrontImage,
          onTap: () => _showImageSourceSheet('front'),
        ),

        // Back (not for passport)
        if (!_isPassport) ...[
          const SizedBox(height: AppDimensions.spaceMD),
          _buildUploadCard(
            title: AppStrings.uploadBack,
            image: _idBackImage,
            onTap: () => _showImageSourceSheet('back'),
          ),
        ],
      ],
    );
  }

  Widget _buildUploadCard({
    required String title,
    required XFile? image,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.inputBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border.all(
            color: image != null ? AppColors.primary : AppColors.inputBorderDark,
            style: image != null ? BorderStyle.solid : BorderStyle.none,
          ),
        ),
        child: image != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                    child: Image.file(
                      File(image.path),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildUploadPlaceholder(title),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
            : _buildUploadPlaceholder(title),
      ),
    );
  }

  Widget _buildUploadPlaceholder(String title) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(
          color: AppColors.inputBorderDark,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 32,
            color: AppColors.textSecondaryDark,
          ),
          const SizedBox(height: AppDimensions.spaceXS),
          Text(
            title,
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
          ),
        ],
      ),
    );
  }

  Widget _buildDateOfBirth() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.dateOfBirth,
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceXS),
        GestureDetector(
          onTap: _selectDateOfBirth,
          child: Container(
            height: AppDimensions.inputHeightMD,
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMD),
            decoration: BoxDecoration(
              color: AppColors.inputBackgroundDark,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              border: Border.all(color: AppColors.inputBorderDark),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _dateOfBirth != null
                        ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                        : AppStrings.selectDate,
                    style: _dateOfBirth != null
                        ? AppTextStyles.inputText()
                        : AppTextStyles.inputHint(),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.textSecondaryDark,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePhoto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.profilePhoto,
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceXS),
        GestureDetector(
          onTap: () => _showImageSourceSheet('profile'),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.inputBackgroundDark,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              border: Border.all(
                color: _profilePhoto != null ? AppColors.primary : AppColors.inputBorderDark,
              ),
            ),
            child: _profilePhoto != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                    child: Image.file(
                      File(_profilePhoto!.path),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildProfilePlaceholder(),
                    ),
                  )
                : _buildProfilePlaceholder(),
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePlaceholder() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.person_add_alt_1_rounded,
          size: 28,
          color: AppColors.textSecondaryDark,
        ),
        const SizedBox(width: AppDimensions.spaceSM),
        Text(
          AppStrings.uploadPhoto,
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        border: Border(
          top: BorderSide(color: AppColors.inputBorderDark, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeightLG,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleContinue,
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
                        AppStrings.continueText,
                        style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
