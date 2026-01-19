import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/qr_signing_service.dart';
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
      String? walletId;
      String? name;
      double? amount;
      String? currency;
      String? note;
      bool isVerifiedQr = false;

      // First, try to parse as signed QR (v2 format)
      final parsed = QrSigningService.parseQrData(code);

      if (parsed != null) {
        // This is a signed QR code - verify signature
        final verification = await QrSigningService.verifySignature(
          payload: parsed['payload']!,
          signature: parsed['signature']!,
        );

        if (!verification.isValid) {
          if (!mounted) return;
          _showError(verification.errorReason ?? 'Invalid or expired QR code');
          setState(() => _isProcessing = false);
          return;
        }

        // Extract data from verified payload
        walletId = verification.walletId;
        amount = verification.amount;
        note = verification.note;
        isVerifiedQr = true;
      } else {
        // Try legacy format: qrwallet://pay?id=...
        final uri = Uri.tryParse(code);
        if (uri != null && uri.scheme == 'qrwallet' && uri.host == 'pay') {
          walletId = uri.queryParameters['id'];
          name = uri.queryParameters['name'];

          final amountStr = uri.queryParameters['amount'];
          if (amountStr != null) {
            amount = double.tryParse(amountStr);
          }

          currency = uri.queryParameters['currency'];
          note = uri.queryParameters['note'];

          // Decode URL-encoded values
          if (name != null) {
            name = Uri.decodeComponent(name);
          }
          if (note != null) {
            note = Uri.decodeComponent(note);
          }
        } else if (_isValidWalletIdFormat(code)) {
          // Plain wallet ID format
          walletId = code;
        } else {
          throw Exception('Unrecognized QR code format');
        }
      }

      if (walletId == null || walletId.isEmpty) {
        throw Exception('Invalid QR code');
      }

      // Look up wallet to verify and get details
      String? recipientCurrency = currency;
      String? recipientCurrencySymbol;

      try {
        final result = await ref.read(walletNotifierProvider.notifier).lookupWallet(walletId);
        if (result.found) {
          name = name ?? result.fullName ?? 'Unknown';
          recipientCurrency = recipientCurrency ?? result.currency;
          recipientCurrencySymbol = result.currencySymbol;
        }
      } catch (e) {
        // For unverified QR codes, require successful lookup
        if (!isVerifiedQr) {
          _showError('Could not verify recipient wallet');
          setState(() => _isProcessing = false);
          return;
        }
      }

      if (!mounted) return;

      // Navigate to confirm send screen with all data
      context.pushReplacement(
        AppRoutes.confirmSend,
        extra: {
          'recipientWalletId': walletId,
          'recipientName': name ?? 'Unknown',
          'amount': amount ?? 0.0,
          'note': note,
          'fromScan': true,
          'amountLocked': amount != null && amount > 0,
          'recipientCurrency': recipientCurrency,
          'recipientCurrencySymbol': recipientCurrencySymbol,
          'isVerifiedQr': isVerifiedQr,
        },
      );
    } catch (e) {
      _showError('Could not read QR code');
      setState(() => _isProcessing = false);
    }
  }

  /// Validate wallet ID format (QRW-XXXX-XXXX-XXXX or legacy QRW-XXXXX-XXXXX)
  bool _isValidWalletIdFormat(String id) {
    // New format: QRW-XXXX-XXXX-XXXX (alphanumeric)
    final newFormat = RegExp(r'^QRW-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$');
    // Legacy format: QRW-XXXXX-XXXXX (numeric)
    final legacyFormat = RegExp(r'^QRW-\d{5}-\d{5}$');
    return newFormat.hasMatch(id) || legacyFormat.hasMatch(id);
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
