import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/user_service.dart';
import '../../../core/services/user_localization_resolver.dart';

/// Step 4 of the delete-account flow.
///
/// Calls the server-side deletion and routes to Success, or back to Preflight
/// with the server's blocker message. Back navigation is disabled so the user
/// cannot leave mid-deletion.
class DeleteAccountProcessingScreen extends ConsumerStatefulWidget {
  /// Forwarded from the confirmation screen via route extra. When true,
  /// the server-side deletion accepts a sub-threshold balance sweep.
  final bool confirmForfeit;

  const DeleteAccountProcessingScreen({
    super.key,
    this.confirmForfeit = false,
  });

  @override
  ConsumerState<DeleteAccountProcessingScreen> createState() =>
      _DeleteAccountProcessingScreenState();
}

class _DeleteAccountProcessingScreenState
    extends ConsumerState<DeleteAccountProcessingScreen> {
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runDeletion());
  }

  Future<void> _runDeletion() async {
    if (_hasStarted) return;
    _hasStarted = true;

    final result = await UserService().requestAccountDeletion();
    if (!mounted) return;

    if (result.success) {
      context.go(AppRoutes.deleteAccountSuccess);
      return;
    }

    if (result.serverMessage != null) {
      context.go(
        AppRoutes.deleteAccountPreflight,
        extra: {'blockerMessage': result.serverMessage},
      );
      return;
    }

    if (result.errorKey == UserErrorKey.userNotAuthenticated) {
      context.go(AppRoutes.welcome);
      return;
    }

    context.go(
      AppRoutes.deleteAccountPreflight,
      extra: {
        'blockerMessage':
            'Something went wrong. Please try again or contact support.',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: AppDimensions.spaceLG),
                  Text(
                    'Deleting your account...',
                    style: AppTextStyles.headlineSmall(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.spaceMD),
                  Text(
                    "This may take a moment. Please don't close the app.",
                    style: AppTextStyles.bodyMedium(
                        color: AppColors.textSecondaryDark),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
