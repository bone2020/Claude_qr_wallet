import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/wallet_provider.dart';

/// Receive money screen with QR code display
class ReceiveMoneyScreen extends ConsumerStatefulWidget {
  const ReceiveMoneyScreen({super.key});

  @override
  ConsumerState<ReceiveMoneyScreen> createState() => _ReceiveMoneyScreenState();
}

class _ReceiveMoneyScreenState extends ConsumerState<ReceiveMoneyScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isDownloading = false;

  void _copyWalletId(String walletId) {
    Clipboard.setData(ClipboardData(text: walletId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.walletIdCopied),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareQrCode(String walletId, String userName) {
    final shareText = '''
Send me money on QR Wallet!

Name: $userName
Wallet ID: $walletId

Or scan my QR code in the app.
''';

    Share.share(shareText, subject: 'My QR Wallet ID');
  }

  Future<void> _downloadQrCode() async {
    if (_isDownloading) return;

    setState(() => _isDownloading = true);

    try {
      // Check gallery access using Gal
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Storage permission required to save QR code'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }

      // Capture QR code as image
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 10),
      );

      if (imageBytes != null) {
        // Save to temp file first
        final tempDir = await getTemporaryDirectory();
        final fileName = 'qr_wallet_${DateTime.now().millisecondsSinceEpoch}.png';
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(imageBytes);

        // Save to gallery using Gal
        await Gal.putImage(tempFile.path);

        // Clean up temp file
        await tempFile.delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR code saved to gallery!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving QR code: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

              // QR Code Card (wrapped with Screenshot)
              Screenshot(
                controller: _screenshotController,
                child: _buildQrCodeCard(qrData, userName),
              )
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
              _buildWalletIdCard(walletId)
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, delay: 200.ms, duration: 400.ms),

              const Spacer(),

              // Action Buttons
              _buildActionButtons(walletId, userName)
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 400.ms),

              const SizedBox(height: AppDimensions.spaceLG),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrCodeCard(String qrData, String userName) {
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

  Widget _buildWalletIdCard(String walletId) {
    return GestureDetector(
      onTap: () => _copyWalletId(walletId),
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

  Widget _buildActionButtons(String walletId, String userName) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _shareQrCode(walletId, userName),
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
            onPressed: _isDownloading ? null : _downloadQrCode,
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.backgroundDark,
                    ),
                  )
                : const Icon(Iconsax.document_download, size: 20),
            label: Text(_isDownloading ? 'Saving...' : AppStrings.downloadQrCode),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceMD),
            ),
          ),
        ),
      ],
    );
  }
}
