import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smile_id/smile_id.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/user_service.dart';
import '../../../core/services/smile_id_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';

/// KYC screen for identity verification using Smile ID
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
  String? _userId;

  bool _isLoading = false;
  bool _smileIdVerified = false;
  String? _smileIdResult;

  List<Map<String, dynamic>> _idTypes = [];

  @override
  void initState() {
    super.initState();
    _loadUserCountry();
    _generateUserId();
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    super.dispose();
  }

  void _generateUserId() {
    final user = ref.read(currentUserProvider);
    _userId = user?.id ?? _smileIdService.generateUserId();
  }

  void _loadUserCountry() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _userCountryCode = user.country;

      if (_userCountryCode == null || _userCountryCode!.isEmpty) {
        _userCountryCode = _smileIdService.extractCountryCode(user.phoneNumber);
      }
    }

    _userCountryCode ??= 'GH';

    setState(() {
      _idTypes = _smileIdService.getIdTypesForCountry(_userCountryCode);
    });
  }

  bool get _requiresIdNumber {
    if (_selectedIdType == null) return false;
    final idType = _idTypes.firstWhere(
      (type) => type['value'] == _selectedIdType,
      orElse: () => {'requiresNumber': false},
    );
    return idType['requiresNumber'] == true;
  }

  bool get _isPassport => _selectedIdType == 'PASSPORT';

  String get _selectedIdLabel {
    if (_selectedIdType == null) return '';
    final idType = _idTypes.firstWhere(
      (type) => type['value'] == _selectedIdType,
      orElse: () => {'label': ''},
    );
    return idType['label'] ?? '';
  }

  /// Navigate to Smile ID verification screen
  Future<void> _startSmileIdVerification() async {
    if (_selectedIdType == null) {
      _showError('Please select an ID type first');
      return;
    }

    if (_requiresIdNumber) {
      final validation = _smileIdService.validateIdNumber(
        _idNumberController.text.trim(),
        _selectedIdType!,
        _userCountryCode!,
      );
      if (!validation.isValid) {
        _showError(validation.error ?? 'Invalid ID number');
        return;
      }
    }

    // Navigate to Smile ID verification screen
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => _SmileIdVerificationScreen(
          userId: _userId!,
          countryCode: _userCountryCode!,
          idType: _smileIdService.getSmileIdDocumentType(_selectedIdType!, _userCountryCode!),
          idNumber: _requiresIdNumber ? _idNumberController.text.trim() : null,
          requiresIdNumber: _requiresIdNumber,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _smileIdVerified = true;
        _smileIdResult = result;
      });
      _showSuccess('Verification completed successfully!');
    }
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
      _showError('Error picking image: $e');
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

  Future<void> _handleContinue() async {
    if (_selectedIdType == null) {
      _showError('Please select an ID type');
      return;
    }

    if (_requiresIdNumber && _idNumberController.text.trim().isEmpty) {
      _showError('Please enter your $_selectedIdLabel number');
      return;
    }

    // If Smile ID verified, we can skip manual document upload
    if (!_smileIdVerified) {
      if (_idFrontImage == null) {
        _showError('Please upload the front of your ID or verify with Smile ID');
        return;
      }
      if (!_isPassport && _idBackImage == null) {
        _showError('Please upload the back of your ID');
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

      final result = await userService.uploadKycDocuments(
        idFront: _idFrontImage != null ? File(_idFrontImage!.path) : null,
        idBack: _idBackImage != null ? File(_idBackImage!.path) : null,
        idType: _selectedIdType!,
        dateOfBirth: _dateOfBirth!,
        selfie: _profilePhoto != null ? File(_profilePhoto!.path) : null,
        idNumber: _requiresIdNumber ? _idNumberController.text.trim() : null,
        smileIdVerified: _smileIdVerified,
        smileIdResult: _smileIdResult,
      );

      if (!mounted) return;

      if (result.success) {
        if (result.user != null) {
          ref.read(authNotifierProvider.notifier).updateUser(result.user!);
        }
        await ref.read(currencyNotifierProvider.notifier).loadUserCurrency();
        context.go(AppRoutes.main);
      } else {
        _showError(result.error ?? 'Failed to upload KYC documents');
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
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

                    _buildHeader()
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: -0.2, end: 0, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXXL),

                    _buildIdTypeDropdown()
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceLG),

                    if (_selectedIdType != null && _requiresIdNumber) ...[
                      _buildIdNumberInput()
                          .animate()
                          .fadeIn(delay: 150.ms, duration: 400.ms),
                      const SizedBox(height: AppDimensions.spaceLG),
                    ],

                    // Smile ID Verification Button
                    if (_selectedIdType != null) ...[
                      _buildSmileIdVerificationCard()
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 400.ms),
                      const SizedBox(height: AppDimensions.spaceLG),
                    ],

                    // Manual upload (optional if Smile ID verified)
                    if (_selectedIdType != null && !_smileIdVerified) ...[
                      _buildIdUpload()
                          .animate()
                          .fadeIn(delay: 250.ms, duration: 400.ms),
                      const SizedBox(height: AppDimensions.spaceLG),
                    ],

                    _buildDateOfBirth()
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXXL),
                  ],
                ),
              ),
            ),

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
                  _smileIdVerified = false;
                  _smileIdResult = null;
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
    switch (_selectedIdType) {
      case 'NIN':
        return 'Your 11-digit National Identification Number';
      case 'BVN':
        return 'Your 11-digit Bank Verification Number';
      case 'SSNIT':
        return 'Your SSNIT number (1 letter + 12 digits)';
      case 'NATIONAL_ID':
        if (_userCountryCode == 'ZA') {
          return 'Your 13-digit South African ID number';
        }
        return 'Your National ID number';
      default:
        return 'Enter your ID number as shown on your document';
    }
  }

  Widget _buildSmileIdVerificationCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLG),
      decoration: BoxDecoration(
        color: _smileIdVerified
            ? AppColors.success.withOpacity(0.1)
            : AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(
          color: _smileIdVerified ? AppColors.success : AppColors.inputBorderDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _smileIdVerified ? Icons.verified_rounded : Icons.fingerprint_rounded,
                color: _smileIdVerified ? AppColors.success : AppColors.primary,
              ),
              const SizedBox(width: AppDimensions.spaceSM),
              Expanded(
                child: Text(
                  _smileIdVerified ? 'Verified with Smile ID' : 'Quick Verification',
                  style: AppTextStyles.titleMedium(
                    color: _smileIdVerified ? AppColors.success : null,
                  ),
                ),
              ),
              if (_smileIdVerified)
                const Icon(Icons.check_circle, color: AppColors.success),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSM),
          Text(
            _smileIdVerified
                ? 'Your identity has been verified successfully'
                : 'Verify your identity instantly with face recognition',
            style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
          ),
          if (!_smileIdVerified) ...[
            const SizedBox(height: AppDimensions.spaceMD),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startSmileIdVerification,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Verify with Smile ID'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.backgroundDark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIdUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Or upload manually',
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceSM),
        _buildUploadCard(
          title: _isPassport ? AppStrings.uploadMainPage : AppStrings.uploadFront,
          image: _idFrontImage,
          onTap: () => _showImageSourceSheet('front'),
        ),
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
                      child: const Icon(Icons.check, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 32, color: AppColors.textSecondaryDark),
                  const SizedBox(height: AppDimensions.spaceXS),
                  Text(title, style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark)),
                ],
              ),
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
                const Icon(Icons.calendar_today_rounded, color: AppColors.textSecondaryDark, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        border: Border(top: BorderSide(color: AppColors.inputBorderDark, width: 0.5)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeightLG,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleContinue,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.backgroundDark),
                  )
                : Text(
                    AppStrings.continueText,
                    style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Smile ID Verification Screen - Shows the actual Smile ID widgets
class _SmileIdVerificationScreen extends StatelessWidget {
  final String userId;
  final String countryCode;
  final String idType;
  final String? idNumber;
  final bool requiresIdNumber;

  const _SmileIdVerificationScreen({
    required this.userId,
    required this.countryCode,
    required this.idType,
    this.idNumber,
    required this.requiresIdNumber,
  });

  @override
  Widget build(BuildContext context) {
    // Choose widget based on whether ID number is required
    if (requiresIdNumber && idNumber != null) {
      // Use Biometric KYC for ID number verification (NIN, BVN, etc.)
      return Scaffold(
        body: SmileIDBiometricKYC(
          country: countryCode,
          idType: idType,
          idNumber: idNumber,
          userId: userId,
          allowAgentMode: false,
          showAttribution: true,
          showInstructions: true,
          onSuccess: (result) {
            Navigator.pop(context, result);
          },
          onError: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Verification failed: $error'), backgroundColor: Colors.red),
            );
            Navigator.pop(context);
          },
        ),
      );
    } else {
      // Use Document Verification for passport, driver's license, etc.
      return Scaffold(
        body: SmileIDDocumentVerification(
          countryCode: countryCode,
          documentType: idType,
          userId: userId,
          captureBothSides: idType != 'PASSPORT',
          allowAgentMode: false,
          showAttribution: true,
          showInstructions: true,
          onSuccess: (result) {
            Navigator.pop(context, result);
          },
          onError: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Verification failed: $error'), backgroundColor: Colors.red),
            );
            Navigator.pop(context);
          },
        ),
      );
    }
  }
}
