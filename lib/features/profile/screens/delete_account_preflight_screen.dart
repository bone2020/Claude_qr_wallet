import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/wallet_provider.dart';

/// Step 2 of the delete-account flow.
///
/// Checks the most common blocker (wallet balance > 0) up front. Also displays
/// a server-supplied blocker message when arrived here via redirect from the
/// Processing screen after a server guard rejected the deletion.
class DeleteAccountPreflightScreen extends ConsumerStatefulWidget {
  /// Populated when redirected back from the Processing screen with a
  /// server-side guard message (passed via `extra['blockerMessage']`).
  final String? blockerMessage;

  const DeleteAccountPreflightScreen({super.key, this.blockerMessage});

  @override
  ConsumerState<DeleteAccountPreflightScreen> createState() =>
      _DeleteAccountPreflightScreenState();
}

class _DeleteAccountPreflightScreenState
    extends ConsumerState<DeleteAccountPreflightScreen> {
  bool _isChecking = true;
  String? _blockerMessage;
  bool _canProceed = false;
  bool _balanceBlocker = false;

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  void _runChecks() {
    // Arrived via redirect from Processing: the server already told us why.
    final fromServer = widget.blockerMessage;
    if (fromServer != null && fromServer.isNotEmpty) {
      setState(() {
        _blockerMessage = fromServer;
        _balanceBlocker = fromServer.toLowerCase().contains('balance');
        _isChecking = false;
      });
      return;
    }

    // Initial entry: client-side wallet balance check.
    final wallet = ref.read(walletNotifierProvider);
    final balanceMinor = wallet.balance;
    if (balanceMinor > 0) {
      final amount = (balanceMinor / 100).toStringAsFixed(2);
      setState(() {
        _blockerMessage =
            'You still have a balance of ${wallet.currencySymbol}$amount. '
            'Please withdraw all funds before deleting your account.';
        _balanceBlocker = true;
        _isChecking = false;
      });
    } else {
      setState(() {
        _canProceed = true;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimaryDark),
          onPressed: () => context.pop(),
        ),
        title: Text('Delete account', style: AppTextStyles.headlineMedium()),
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isChecking) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: AppDimensions.spaceMD),
            Text(
              'Checking your account...',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
            ),
          ],
        ),
      );
    }

    if (_blockerMessage != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppDimensions.spaceLG),
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.spaceLG),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: AppDimensions.iconXL,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spaceLG),
            Text(
              "We can't delete your account yet",
              style: AppTextStyles.headlineSmall(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spaceMD),
            Text(
              _blockerMessage!,
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spaceXL),
            if (_balanceBlocker) ...[
              ElevatedButton(
                onPressed: () => context.push(AppRoutes.withdraw),
                child: Text(
                  'Withdraw funds',
                  style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMD),
            ],
            OutlinedButton(
              onPressed: () => context.pop(),
              child: Text('Go back', style: AppTextStyles.labelLarge()),
            ),
          ],
        ),
      );
    }

    if (_canProceed) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppDimensions.spaceLG),
            Center(
              child: Container(
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
            ),
            const SizedBox(height: AppDimensions.spaceLG),
            Text(
              'Ready to proceed',
              style: AppTextStyles.headlineSmall(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spaceMD),
            Text(
              'Your account is ready for deletion. Tap Continue to confirm.',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spaceXL),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: Text('Cancel', style: AppTextStyles.labelLarge()),
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceMD),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        context.push(AppRoutes.deleteAccountConfirm),
                    child: Text(
                      'Continue',
                      style:
                          AppTextStyles.labelLarge(color: AppColors.backgroundDark),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Defensive fallback (should not be reached).
    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
  }
}
