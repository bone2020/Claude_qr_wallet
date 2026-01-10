import 'package:flutter/material.dart';
import '../../../providers/auth_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;

import '../../../core/constants/constants.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/currency_provider.dart';

class RequestPaymentScreen extends ConsumerStatefulWidget {
  const RequestPaymentScreen({super.key});

  @override
  ConsumerState<RequestPaymentScreen> createState() => _RequestPaymentScreenState();
}

class _RequestPaymentScreenState extends ConsumerState<RequestPaymentScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _qrGenerated = false;
  String _qrData = '';
  final GlobalKey _qrKey = GlobalKey();

  String get _walletId => ref.watch(walletNotifierProvider).wallet?.walletId ?? '';
  String get _userName => ref.watch(currentUserProvider)?.fullName ?? 'User';
  String get _currencySymbol => ref.watch(currencyNotifierProvider).currency.symbol;
  String get _currencyCode => ref.watch(currencyNotifierProvider).currency.code;

  void _generateQR() {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Build QR data URL
    final note = _noteController.text.trim();
    final encodedName = Uri.encodeComponent(_userName);
    final encodedNote = Uri.encodeComponent(note);

    _qrData = 'qrwallet://pay?id=$_walletId&name=$encodedName&amount=${amount.toStringAsFixed(2)}&currency=$_currencyCode';
    if (note.isNotEmpty) {
      _qrData += '&note=$encodedNote';
    }

    setState(() {
      _qrGenerated = true;
    });
  }

  void _resetQR() {
    setState(() {
      _qrGenerated = false;
      _qrData = '';
      _amountController.clear();
      _noteController.clear();
    });
  }

  Future<void> _saveQRImage() async {
    try {
      // Create QR image
      final qrValidationResult = QrValidator.validate(
        data: _qrData,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      if (qrValidationResult.status != QrValidationStatus.valid) {
        throw Exception('Invalid QR data');
      }

      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter.withQr(
        qr: qrCode,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
        gapless: true,
      );

      final picData = await painter.toImageData(300, format: ui.ImageByteFormat.png);
      if (picData == null) throw Exception('Failed to generate image');

      final directory = await getTemporaryDirectory();
      final amount = _amountController.text;
      final fileName = 'payment_qr_${_currencyCode}_$amount.png';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(picData.buffer.asUint8List());

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Pay $_currencySymbol$amount to $_userName',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving QR: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(
          'Request Payment',
          style: AppTextStyles.headlineMedium(),
        ),
        actions: [
          if (_qrGenerated)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetQR,
              tooltip: 'New Request',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
        child: _qrGenerated ? _buildQRDisplay() : _buildInputForm(),
      ),
    );
  }

  Widget _buildInputForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppDimensions.spaceLG),

        // Header
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceLG),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.qr_code_2,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppDimensions.spaceMD),
              Text(
                'Create Payment Request',
                style: AppTextStyles.headlineSmall(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceXS),
              Text(
                'Enter the amount you want to receive. Customers can scan the QR code to pay you instantly.',
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spaceXL),

        // Amount Input
        Text(
          'Amount',
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceXS),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceLG,
            vertical: AppDimensions.spaceMD,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
            border: Border.all(color: AppColors.inputBorderDark),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _currencySymbol,
                style: AppTextStyles.displaySmall(color: AppColors.primary),
              ),
              const SizedBox(width: AppDimensions.spaceXS),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  style: AppTextStyles.displaySmall(),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '0.00',
                    hintStyle: AppTextStyles.displaySmall(color: AppColors.textTertiaryDark),
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spaceLG),

        // Note Input (Optional)
        Text(
          'Description (optional)',
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceXS),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
            border: Border.all(color: AppColors.inputBorderDark),
          ),
          child: TextField(
            controller: _noteController,
            maxLength: 50,
            style: AppTextStyles.bodyLarge(),
            decoration: InputDecoration(
              hintText: 'e.g., Bowl of Tomatoes, Lunch, Service',
              hintStyle: AppTextStyles.bodyMedium(color: AppColors.textTertiaryDark),
              prefixIcon: const Icon(Icons.note_alt_outlined, color: AppColors.textSecondaryDark),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(AppDimensions.spaceMD),
              counterStyle: AppTextStyles.caption(color: AppColors.textTertiaryDark),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spaceXXL),

        // Generate Button
        SizedBox(
          height: AppDimensions.buttonHeightLG,
          child: ElevatedButton(
            onPressed: _generateQR,
            child: Text(
              'Generate QR Code',
              style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQRDisplay() {
    final amount = _amountController.text;
    final note = _noteController.text.trim();

    return Column(
      children: [
        const SizedBox(height: AppDimensions.spaceLG),

        // Amount Display
        Text(
          '$_currencySymbol$amount',
          style: AppTextStyles.displayLarge(color: AppColors.primary),
        ),
        if (note.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spaceXS),
          Text(
            note,
            style: AppTextStyles.bodyLarge(color: AppColors.textSecondaryDark),
          ),
        ],
        const SizedBox(height: AppDimensions.spaceXL),

        // QR Code Container
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceLG),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: RepaintBoundary(
            key: _qrKey,
            child: QrImageView(
              data: _qrData,
              version: QrVersions.auto,
              size: 250,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spaceMD),

        // Receiver Info
        Text(
          'Pay to: $_userName',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceXL),

        // Action Buttons
        SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeightMD,
          child: OutlinedButton.icon(
            onPressed: _saveQRImage,
            icon: const Icon(Icons.share),
            label: const Text('Save / Share QR'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spaceLG),

        // Instructions
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceMD),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
          child: Column(
            children: [
              const Icon(Icons.info_outline, color: AppColors.primary),
              const SizedBox(height: AppDimensions.spaceXS),
              Text(
                'Show this QR code to the customer.\nThey scan it, confirm the amount, and pay instantly!',
                style: AppTextStyles.bodySmall(color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spaceXL),

        // New Request Button
        TextButton.icon(
          onPressed: _resetQR,
          icon: const Icon(Icons.add),
          label: const Text('Create New Request'),
        ),
      ],
    );
  }
}
