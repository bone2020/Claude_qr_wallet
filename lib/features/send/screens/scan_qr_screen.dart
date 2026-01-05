import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/wallet_provider.dart';

/// QR code scanner screen
class ScanQrScreen extends ConsumerStatefulWidget {
  const ScanQrScreen({super.key});

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends ConsumerState<ScanQrScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  bool _torchEnabled = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);

    // Parse QR code data
    _processQrCode(code);
  }

  Future<void> _processQrCode(String code) async {
    try {
      // Parse the QR code
      // Expected format: qrwallet://pay?id=WALLET_ID&name=NAME
      final uri = Uri.parse(code);

      String? walletId;
      String? name;

      if (uri.scheme == 'qrwallet' && uri.host == 'pay') {
        walletId = uri.queryParameters['id'];
        name = uri.queryParameters['name'];
      } else {
        // Fallback: treat the entire code as wallet ID
        walletId = code;
      }

      if (walletId != null && walletId.isNotEmpty) {
        // Look up wallet to get currency info
        String? recipientCurrency;
        String? recipientCurrencySymbol;

        try {
          final result = await ref.read(walletNotifierProvider.notifier).lookupWallet(walletId);
          if (result.found) {
            name = result.fullName ?? name;
            recipientCurrency = result.currency;
            recipientCurrencySymbol = result.currencySymbol;
          }
        } catch (_) {
          // Continue with navigation even if lookup fails
        }

        if (!mounted) return;

        // Navigate to confirm send screen
        context.pushReplacement(
          AppRoutes.confirmSend,
          extra: {
            'recipientWalletId': walletId,
            'recipientName': name ?? 'Unknown',
            'amount': 0.0,
            'note': null,
            'fromScan': true,
            'recipientCurrency': recipientCurrency,
            'recipientCurrencySymbol': recipientCurrencySymbol,
          },
        );
      } else {
        _showError('Invalid QR code');
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      _showError('Could not read QR code');
      setState(() => _isProcessing = false);
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

  void _toggleTorch() {
    _scannerController.toggleTorch();
    setState(() => _torchEnabled = !_torchEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera View
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Overlay
          _buildOverlay(),

          // Top Bar
          _buildTopBar(),

          // Bottom Instructions
          _buildBottomInstructions(),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withOpacity(0.5),
        BlendMode.srcOut,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Center(
            child: Container(
              width: AppDimensions.qrScanAreaSize,
              height: AppDimensions.qrScanAreaSize,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                ),
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            Text(
              AppStrings.scanQrCode,
              style: AppTextStyles.headlineMedium(color: Colors.white),
            ),
            GestureDetector(
              onTap: _toggleTorch,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _torchEnabled ? AppColors.primary : Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                ),
                child: Icon(
                  _torchEnabled ? Iconsax.flash_15 : Iconsax.flash_1,
                  color: _torchEnabled ? AppColors.backgroundDark : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInstructions() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceXXL),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spaceMD,
                  vertical: AppDimensions.spaceXS,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.scan, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Position QR code within the frame',
                      style: AppTextStyles.bodySmall(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              if (_isProcessing) ...[
                const SizedBox(height: AppDimensions.spaceLG),
                const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
