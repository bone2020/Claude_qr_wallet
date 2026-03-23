import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/user_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/wallet_provider.dart';

/// Manual KYC screen for non-SmileID countries.
/// User uploads photos of their ID document + selfie.
/// Phone verification is MANDATORY after upload.
class ManualKycScreen extends ConsumerStatefulWidget {
  final String countryCode;

  const ManualKycScreen({
    super.key,
    required this.countryCode,
  });

  @override
  ConsumerState<ManualKycScreen> createState() => _ManualKycScreenState();
}

class _ManualKycScreenState extends ConsumerState<ManualKycScreen> {
  final _imagePicker = ImagePicker();

  String? _selectedIdType;
  XFile? _idFrontImage;
  XFile? _idBackImage;
  DateTime? _dateOfBirth;
  XFile? _selfieImage;
  bool _isLoading = false;

  final List<Map<String, String>> _idTypes = [
    {'value': 'national_id', 'label': 'National ID'},
    {'value': 'drivers_license', 'label': "Driver's License"},
    {'value': 'passport', 'label': 'International Passport'},
    {'value': 'voter_id', 'label': "Voter's ID"},
  ];

  bool get _isPassport => _selectedIdType == 'passport';

  Future<void> _pickImage(ImageSource source, String type) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        setState(() {
          switch (type) {
            case 'front':
              _idFrontImage = image;
              break;
            case 'back':
              _idBackImage = image;
              break;
            case 'selfie':
              _selfieImage = image;
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                  title: Text('Take Photo', style: AppTextStyles.bodyLarge()),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera, type);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: AppColors.primary),
                  title: Text('Choose from Gallery', style: AppTextStyles.bodyLarge()),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery, type);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectDateOfBirth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
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
    // Validate required fields
    if (_selectedIdType == null) {
      _showError('Please select an ID type');
      return;
    }
    if (_idFrontImage == null) {
      _showError('Please upload the front of your ID');
      return;
    }
    if (!_isPassport && _idBackImage == null) {
      _showError('Please upload the back of your ID');
      return;
    }
    if (_dateOfBirth == null) {
      _showError('Please select your date of birth');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Step 1: Mandatory phone verification FIRST
      final phoneVerified = await context.push<bool>(
        AppRoutes.kycPhoneVerification,
        extra: {
          'countryCode': widget.countryCode,
          'documentVerified': false, // No SmileID = phone verification is mandatory
        },
      );

      if (!mounted) return;

      if (phoneVerified != true) {
        _showError('Phone verification is required to complete registration');
        setState(() => _isLoading = false);
        return;
      }

      // Step 2: Upload documents
      final userService = UserService();
      final result = await userService.uploadKycDocuments(
        idFront: File(_idFrontImage!.path),
        idBack: _idBackImage != null ? File(_idBackImage!.path) : null,
        idType: _selectedIdType!,
        dateOfBirth: _dateOfBirth!,
        selfie: _selfieImage != null ? File(_selfieImage!.path) : null,
        smileIdVerified: false,
      );

      if (!mounted) return;

      if (result.success) {
        if (result.user != null) {
          ref.read(authNotifierProvider.notifier).updateUser(result.user!);
        }

        // Create wallet (server sets kycStatus: 'verified')
        final createWallet = FirebaseFunctions.instance.httpsCallable('createWalletForUser');
        await createWallet.call();

        // Refresh wallet and currency after verification
        await ref.read(walletNotifierProvider.notifier).refreshWallet();
        await ref.read(currencyNotifierProvider.notifier).loadUserCurrency();
        await PushNotificationService().saveTokenToFirestore();

        if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: Text('Identity Verification', style: AppTextStyles.headlineMedium()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Verify Your Identity',
                      style: AppTextStyles.displaySmall(),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: AppDimensions.spaceXS),
                    Text(
                      'Please upload a clear photo of your government-issued ID and a selfie. Phone verification will be required.',
                      style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                    ).animate().fadeIn(duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXXL),

                    // ID Type Dropdown
                    Text(
                      'Government ID Type',
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
                            child: Text('Select ID Type', style: AppTextStyles.inputHint()),
                          ),
                          isExpanded: true,
                          dropdownColor: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                          items: _idTypes.map((type) {
                            return DropdownMenuItem<String>(
                              value: type['value'],
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMD),
                                child: Text(type['label']!, style: AppTextStyles.inputText()),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedIdType = value;
                              _idFrontImage = null;
                              _idBackImage = null;
                            });
                          },
                        ),
                      ),
                    ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceLG),

                    // ID Upload
                    if (_selectedIdType != null) ...[
                      // Front
                      _buildUploadCard(
                        title: _isPassport ? 'Upload Main Page' : 'Upload Front',
                        image: _idFrontImage,
                        onTap: () => _showImageSourceSheet('front'),
                      ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                      // Back (not for passport)
                      if (!_isPassport) ...[
                        const SizedBox(height: AppDimensions.spaceMD),
                        _buildUploadCard(
                          title: 'Upload Back',
                          image: _idBackImage,
                          onTap: () => _showImageSourceSheet('back'),
                        ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
                      ],

                      const SizedBox(height: AppDimensions.spaceLG),
                    ],

                    // Date of Birth
                    Text(
                      'Date of Birth',
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
                                    : 'Select Date',
                                style: _dateOfBirth != null
                                    ? AppTextStyles.inputText()
                                    : AppTextStyles.inputHint(),
                              ),
                            ),
                            Icon(Icons.calendar_today_rounded, color: AppColors.textSecondaryDark, size: 20),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceLG),

                    // Selfie
                    Text(
                      'Selfie Photo',
                      style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
                    ),
                    const SizedBox(height: AppDimensions.spaceXS),
                    _buildUploadCard(
                      title: 'Take a Selfie',
                      image: _selfieImage,
                      onTap: () => _showImageSourceSheet('selfie'),
                    ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXXL),
                  ],
                ),
              ),
            ),

            // Bottom Button
            Container(
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
                            'Continue',
                            style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
                      child: const Icon(Icons.check, size: 16, color: Colors.white),
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
        border: Border.all(color: AppColors.inputBorderDark),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_upload_outlined, size: 32, color: AppColors.textSecondaryDark),
          const SizedBox(height: AppDimensions.spaceXS),
          Text(title, style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark)),
        ],
      ),
    );
  }
}
