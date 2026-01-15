import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:iconsax/iconsax.dart';
import 'package:pinput/pinput.dart';

import '../../../core/constants/constants.dart';

class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  int _currentStep = 0; // 0: current PIN, 1: new PIN, 2: confirm PIN
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _verifyCurrentPin(String pin) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User data not found');
      }

      final storedPinHash = userDoc.data()?['pinHash'] as String?;

      // If no PIN is set yet, skip verification
      if (storedPinHash == null || storedPinHash.isEmpty) {
        setState(() {
          _isLoading = false;
          _currentStep = 1;
        });
        return;
      }

      final enteredPinHash = _hashPin(pin);

      if (enteredPinHash != storedPinHash) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Incorrect PIN';
          _currentPinController.clear();
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _currentStep = 1;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  void _setNewPin(String pin) {
    setState(() {
      _errorMessage = null;
      _currentStep = 2;
    });
  }

  Future<void> _confirmNewPin(String pin) async {
    if (pin != _newPinController.text) {
      setState(() {
        _errorMessage = 'PINs do not match';
        _confirmPinController.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final newPinHash = _hashPin(pin);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'pinHash': newPinHash});

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.tick_circle, color: AppColors.success, size: 48),
              ),
              const SizedBox(height: AppDimensions.spaceMD),
              Text('PIN Changed!', style: AppTextStyles.headlineSmall()),
              const SizedBox(height: AppDimensions.spaceXS),
              Text(
                'Your transaction PIN has been updated successfully.',
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.pop();
                },
                child: Text('Done', style: AppTextStyles.labelLarge(color: AppColors.backgroundDark)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to update PIN: ${e.toString()}';
      });
    }
  }

  void _onPinCompleted(String pin) {
    switch (_currentStep) {
      case 0:
        _verifyCurrentPin(pin);
        break;
      case 1:
        _setNewPin(pin);
        break;
      case 2:
        _confirmNewPin(pin);
        break;
    }
  }

  String get _stepTitle {
    switch (_currentStep) {
      case 0:
        return 'Enter Current PIN';
      case 1:
        return 'Enter New PIN';
      case 2:
        return 'Confirm New PIN';
      default:
        return '';
    }
  }

  String get _stepSubtitle {
    switch (_currentStep) {
      case 0:
        return 'Enter your current 4-digit transaction PIN';
      case 1:
        return 'Create a new 4-digit PIN';
      case 2:
        return 'Re-enter your new PIN to confirm';
      default:
        return '';
    }
  }

  TextEditingController get _currentController {
    switch (_currentStep) {
      case 0:
        return _currentPinController;
      case 1:
        return _newPinController;
      case 2:
        return _confirmPinController;
      default:
        return _currentPinController;
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: AppTextStyles.headlineLarge(),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.inputBorderDark),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.error),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textPrimaryDark),
          onPressed: () => context.pop(),
        ),
        title: Text('Change PIN', style: AppTextStyles.headlineMedium()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
          child: Column(
            children: [
              // Step indicator
              _buildStepIndicator(),
              const SizedBox(height: AppDimensions.spaceXXL),

              // Title and subtitle
              Text(_stepTitle, style: AppTextStyles.headlineSmall()),
              const SizedBox(height: AppDimensions.spaceXS),
              Text(
                _stepSubtitle,
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceXXL),

              // PIN input
              if (_isLoading)
                const CircularProgressIndicator(color: AppColors.primary)
              else
                Pinput(
                  controller: _currentController,
                  length: 4,
                  obscureText: true,
                  obscuringCharacter: '●',
                  defaultPinTheme: _errorMessage != null ? errorPinTheme : defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  onCompleted: _onPinCompleted,
                  keyboardType: TextInputType.number,
                ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: AppDimensions.spaceMD),
                Text(
                  _errorMessage!,
                  style: AppTextStyles.bodySmall(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ],

              const Spacer(),

              // Security note
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceMD),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.shield_tick, color: AppColors.primary, size: 24),
                    const SizedBox(width: AppDimensions.spaceMD),
                    Expanded(
                      child: Text(
                        'Your PIN is securely encrypted and used to authorize transactions.',
                        style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMD),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == _currentStep;
        final isCompleted = index < _currentStep;

        return Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppColors.success
                    : isActive
                        ? AppColors.primary
                        : AppColors.surfaceDark,
                border: Border.all(
                  color: isCompleted
                      ? AppColors.success
                      : isActive
                          ? AppColors.primary
                          : AppColors.inputBorderDark,
                  width: 2,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        '${index + 1}',
                        style: AppTextStyles.labelMedium(
                          color: isActive ? AppColors.backgroundDark : AppColors.textSecondaryDark,
                        ),
                      ),
              ),
            ),
            if (index < 2) ...[
              Container(
                width: 40,
                height: 2,
                color: isCompleted ? AppColors.success : AppColors.inputBorderDark,
              ),
            ],
          ],
        );
      }),
    );
  }
}
