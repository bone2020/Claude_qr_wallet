import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/wallet_provider.dart';

/// Receive money screen with QR code display
class ReceiveMoneyScreen extends ConsumerWidget {
  const ReceiveMoneyScreen({super.key});

  void _copyWalletId(BuildContext context, String walletId) {
    Clipboard.setData(ClipboardData(text: walletId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.walletIdCopied),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareQrCode(BuildContext context) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share feature coming soon'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  void _downloadQrCode(BuildContext context) {
    // TODO: Implement download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download feature coming soon'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get real data from providers
    final walletId = ref.watch(walletNotifierProvider).walletId;
    final user = ref.watch(currentUserProvider);
    final userName = user?.fullName ?? 'User';

    // Generate QR data with real values
    final qrData = 'qrwallet://pay?id=$walletId&name=${Uri.encodeComponent(userName)}';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(AppStrings.receiveMoney, style: AppTextStyles.headlineMedium()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
          child: Column(
            children: [
              const Spacer(),

              // QR Code Card
              _buildQrCodeCard(context, qrData, userName)
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1, 1),
                    duration: 500.ms,
                    curve: Curves.easeOut,
                  ),

              const SizedBox(height: AppDimensions.spaceXXL),

              // Wallet ID
              _buildWalletIdCard(context, walletId)
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, delay: 200.ms, duration: 400.ms),

              const Spacer(),

              // Action Buttons
              _buildActionButtons(context)
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 400.ms),

              const SizedBox(height: AppDimensions.spaceLG),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrCodeCard(BuildContext context, String qrData, String userName) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceXL),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // QR Code
          QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: AppDimensions.qrCodeSize,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppColors.backgroundDark,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppColors.backgroundDark,
            ),
            embeddedImage: null, // TODO: Add logo if desired
            embeddedImageStyle: const QrEmbeddedImageStyle(
              size: Size(40, 40),
            ),
          ),

          const SizedBox(height: AppDimensions.spaceLG),

          // User Name
          Text(
            userName,
            style: AppTextStyles.headlineMedium(color: AppColors.backgroundDark),
          ),

          const SizedBox(height: AppDimensions.spaceXXS),

          Text(
            AppStrings.myQrCode,
            style: AppTextStyles.bodySmall(color: AppColors.textSecondaryLight),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletIdCard(BuildContext context, String walletId) {
    return GestureDetector(
      onTap: () => _copyWalletId(context, walletId),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceLG,
          vertical: AppDimensions.spaceMD,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border.all(color: AppColors.inputBorderDark),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.walletId,
                  style: AppTextStyles.caption(color: AppColors.textSecondaryDark),
                ),
                const SizedBox(height: 2),
                Text(
                  walletId.isNotEmpty ? walletId : 'Loading...',
                  style: AppTextStyles.bodyLarge(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(width: AppDimensions.spaceMD),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
              ),
              child: const Icon(
                Iconsax.copy,
                size: 18,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _shareQrCode(context),
            icon: const Icon(Iconsax.share, size: 20),
            label: Text(AppStrings.shareQrCode),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimaryDark,
              side: const BorderSide(color: AppColors.inputBorderDark),
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceMD),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spaceMD),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _downloadQrCode(context),
            icon: const Icon(Iconsax.document_download, size: 20),
            label: Text(AppStrings.downloadQrCode),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceMD),
            ),
          ),
        ),
      ],
    );
  }
}
