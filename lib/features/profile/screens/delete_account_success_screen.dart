import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';

/// Step 5 of the delete-account flow.
///
/// Confirms completion, signs the user out, and returns them to Welcome —
/// either automatically after a short delay or via the Done button.
class DeleteAccountSuccessScreen extends ConsumerStatefulWidget {
  const DeleteAccountSuccessScreen({super.key});

  @override
  ConsumerState<DeleteAccountSuccessScreen> createState() =>
      _DeleteAccountSuccessScreenState();
}

class _DeleteAccountSuccessScreenState
    extends ConsumerState<DeleteAccountSuccessScreen> {
  bool _hasSignedOut = false;
  bool _navigated = false;
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
  }

  Future<void> _finish() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Already gone server-side; ignore.
    }
    if (!mounted) return;
    setState(() => _hasSignedOut = true);
    _redirectTimer = Timer(const Duration(seconds: 3), _goWelcome);
  }

  void _goWelcome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go(AppRoutes.welcome);
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
            child: !_hasSignedOut
                ? const CircularProgressIndicator(color: AppColors.primary)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.spaceLG),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: AppDimensions.iconXL,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceLG),
                      Text(
                        'Your account has been deleted',
                        style: AppTextStyles.headlineSmall(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.spaceMD),
                      Text(
                        "Thank you for using QR Wallet. We're sorry to see you go.",
                        style: AppTextStyles.bodyMedium(
                            color: AppColors.textSecondaryDark),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.spaceXL),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _goWelcome,
                          child: Text(
                            'Done',
                            style: AppTextStyles.labelLarge(
                                color: AppColors.backgroundDark),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
