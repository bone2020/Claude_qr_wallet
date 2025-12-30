import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';

/// Receive money screen with QR code display
class ReceiveMoneyScreen extends StatelessWidget {
  const ReceiveMoneyScreen({super.key});

  // Mock data - replace with actual user data
  static const String _walletId = 'QRW-8472-9103';
  static const String _userName = 'John Doe';

  String get _qrData => 'qrwallet://pay?id=$_walletId&name=${Uri.encodeComponent(_userName)}';

  void _copyWalletId(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: _walletId));
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
  Widget build(BuildContext context) {
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
              _buildQrCodeCard(context)
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
              _buildWalletIdCard(context)
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

  Widget _buildQrCodeCard(BuildContext context) {
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
            data: _qrData,
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
            _userName,
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

  Widget _buildWalletIdCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _copyWalletId(context),
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
                  _walletId,
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
