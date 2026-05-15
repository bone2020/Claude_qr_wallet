import 'package:flutter/material.dart';
import '../../../providers/auth_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'dart:io';
import 'dart:typed_data';

import '../../../core/constants/constants.dart';
import '../../../core/services/qr_signing_service.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/currency_provider.dart';

import '../../../generated/l10n/app_localizations.dart';
class RequestPaymentScreen extends ConsumerStatefulWidget {
  const RequestPaymentScreen({super.key});

  @override
  ConsumerState<RequestPaymentScreen> createState() => _RequestPaymentScreenState();
}

class _RequestPaymentScreenState extends ConsumerState<RequestPaymentScreen> {
  final _amountController = TextEditingController();
  final _itemController = TextEditingController();
  final List<String> _items = [];
  bool _qrGenerated = false;
  String _qrData = '';
  bool _isGenerating = false;
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isDownloading = false;

  String get _walletId => ref.watch(walletNotifierProvider).wallet?.walletId ?? '';
  String get _userName => ref.watch(currentUserProvider)?.displayName ?? AppLocalizations.of(context).defaultUserName;
  String? get _businessLogoUrl => ref.watch(currentUserProvider)?.businessLogoUrl;
  String get _currencySymbol => ref.watch(currencyNotifierProvider).currency.symbol;
  String get _currencyCode => ref.watch(currencyNotifierProvider).currency.code;

  void _addItem() {
    final item = _itemController.text.trim();
    if (item.isEmpty) return;
    if (_items.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).maximum20ItemsAllowed),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    setState(() {
      _items.add(item);
      _itemController.clear();
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _generateQR() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).pleaseEnterAmount),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).pleaseEnterValidAmount),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // Build note from items if items exist, otherwise empty
      final note = _items.isNotEmpty ? _items.join(', ') : '';

      // Generate signed QR for security
      final signedPayload = await QrSigningService.signQrPayload(
        walletId: _walletId,
        amount: amount,
        note: note,
        items: _items.isNotEmpty ? _items : null,
      );

      if (signedPayload == null) {
        throw Exception('Failed to generate secure QR code');
      }

      _qrData = QrSigningService.generateSignedQrData(signedPayload);

      setState(() {
        _qrGenerated = true;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorGeneratingQr(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _resetQR() {
    setState(() {
      _qrGenerated = false;
      _qrData = '';
      _amountController.clear();
      _itemController.clear();
      _items.clear();
    });
  }

  Future<void> _shareQRCode() async {
    try {
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 10),
      );

      if (imageBytes == null) throw Exception('Failed to capture QR');

      final directory = await getTemporaryDirectory();
      final amount = _amountController.text;
      final fileName = 'payment_qr_${_currencyCode}_$amount.png';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: AppLocalizations.of(context).payRequestShareText(_currencySymbol, amount, _userName),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorSharingQr(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadQRCode() async {
    if (_isDownloading) return;

    setState(() => _isDownloading = true);

    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context).storagePermissionRequired),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }

      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 10),
      );

      if (imageBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final amount = _amountController.text;
        final fileName = 'payment_qr_${_currencyCode}_${amount}_${DateTime.now().millisecondsSinceEpoch}.png';
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(imageBytes);

        await Gal.putImage(tempFile.path);
        await tempFile.delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).qrCodeSavedToGallery),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorSavingQrCode(e.toString())),
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
  void dispose() {
    _amountController.dispose();
    _itemController.dispose();
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
          AppLocalizations.of(context).requestPaymentTitle,
          style: AppTextStyles.headlineMedium(),
        ),
        actions: [
          if (_qrGenerated)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetQR,
              tooltip: AppLocalizations.of(context).newRequestTooltip,
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
            color: AppColors.primary.withValues(alpha: 0.1),
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
                AppLocalizations.of(context).createPaymentRequestTitle,
                style: AppTextStyles.headlineSmall(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceXS),
              Text(
                AppLocalizations.of(context).createPaymentRequestDescription,
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spaceXL),

        // Amount Input
        Text(
          AppLocalizations.of(context).amountLabel,
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

        // Items Section
        Text(
          AppLocalizations.of(context).itemsOptional,
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceXS),

        // Add Item Input
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
            border: Border.all(color: AppColors.inputBorderDark),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _itemController,
                  maxLength: 100,
                  style: AppTextStyles.bodyLarge(),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addItem(),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).itemsHint,
                    hintStyle: AppTextStyles.bodyMedium(color: AppColors.textTertiaryDark),
                    prefixIcon: const Icon(Icons.add_shopping_cart, color: AppColors.textSecondaryDark),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(AppDimensions.spaceMD),
                    counterText: '',
                  ),
                ),
              ),
              GestureDetector(
                onTap: _addItem,
                child: Container(
                  margin: const EdgeInsets.only(right: AppDimensions.spaceSM),
                  padding: const EdgeInsets.all(AppDimensions.spaceXS),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                  ),
                  child: const Icon(Icons.add, color: AppColors.backgroundDark, size: 20),
                ),
              ),
            ],
          ),
        ),

        // Items List
        if (_items.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spaceSM),
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceSM),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              border: Border.all(color: AppColors.inputBorderDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppDimensions.spaceXS,
                    bottom: AppDimensions.spaceXS,
                  ),
                  child: Text(
                    AppLocalizations.of(context).itemCount(_items.length),
                    style: AppTextStyles.caption(color: AppColors.textTertiaryDark),
                  ),
                ),
                ..._items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spaceSM,
                      vertical: AppDimensions.spaceXS,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 6, color: AppColors.primary.withValues(alpha: 0.5)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: AppTextStyles.bodyMedium(),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _removeItem(index),
                          child: const Icon(Icons.close, size: 16, color: AppColors.textTertiaryDark),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppDimensions.spaceXXL),

        // Generate Button
        SizedBox(
          height: AppDimensions.buttonHeightLG,
          child: ElevatedButton(
            onPressed: _isGenerating ? null : _generateQR,
            child: _isGenerating
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.backgroundDark,
                    ),
                  )
                : Text(
                    AppLocalizations.of(context).generateQrCode,
                    style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildQRDisplay() {
    final amount = _amountController.text;

    return Column(
      children: [
        const SizedBox(height: AppDimensions.spaceLG),

        // Amount Display
        Text(
          AppLocalizations.of(context).symbolAmount(_currencySymbol, amount),
          style: AppTextStyles.displayLarge(color: AppColors.primary),
        ),

        // Items summary
        if (_items.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spaceXS),
          Text(
            AppLocalizations.of(context).itemCount(_items.length),
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
          ),
        ],

        const SizedBox(height: AppDimensions.spaceXL),

        // QR Code Container
        Screenshot(
          controller: _screenshotController,
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.spaceLG),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                QrImageView(
                  data: _qrData,
                  version: QrVersions.auto,
                  size: 250,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                  embeddedImage: _businessLogoUrl != null && _businessLogoUrl!.isNotEmpty
                      ? NetworkImage(_businessLogoUrl!) as ImageProvider
                      : const AssetImage('assets/images/app_logo.png'),
                  embeddedImageStyle: const QrEmbeddedImageStyle(
                    size: Size(60, 60),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _userName,
                  style: AppTextStyles.bodyLarge(color: AppColors.backgroundDark),
                ),
                Text(
                  AppLocalizations.of(context).symbolAmount(_currencySymbol, amount),
                  style: AppTextStyles.headlineMedium(color: AppColors.primary),
                ),
                // Show items in the QR card
                if (_items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 4),
                  ..._items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  )),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spaceMD),

        // Receiver Info
        Text(
          AppLocalizations.of(context).payToUser(_userName),
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceXL),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _shareQRCode,
                icon: const Icon(Icons.share, size: 20),
                label: Text(AppLocalizations.of(context).shareButton),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimaryDark,
                  side: const BorderSide(color: AppColors.inputBorderDark),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isDownloading ? null : _downloadQRCode,
                icon: _isDownloading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.backgroundDark,
                        ),
                      )
                    : const Icon(Icons.download, size: 20),
                label: Text(_isDownloading ? AppLocalizations.of(context).saving : AppLocalizations.of(context).downloadButton),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceLG),

        // Instructions
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceMD),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          ),
          child: Column(
            children: [
              const Icon(Icons.info_outline, color: AppColors.primary),
              const SizedBox(height: AppDimensions.spaceXS),
              Text(
                AppLocalizations.of(context).qrCodeInfoForCustomer,
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
          label: Text(AppLocalizations.of(context).createNewRequest),
        ),
      ],
    );
  }
}
