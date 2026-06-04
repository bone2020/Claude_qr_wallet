import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/constants/constants.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/exchange_rate_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/biometric_localization_resolver.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/services/transaction_localization_resolver.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../core/utils/error_handler.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/wallet_provider.dart';

/// Confirm send screen showing transaction summary
class ConfirmSendScreen extends ConsumerStatefulWidget {
  final String recipientWalletId;
  final String recipientName;
  final int amount;
  final String? note;
  final List<String>? items;
  final bool fromScan;
  final bool amountLocked;
  final String? recipientCurrency;
  final String? recipientCurrencySymbol;

  const ConfirmSendScreen({
    super.key,
    required this.recipientWalletId,
    required this.recipientName,
    required this.amount,
    this.note,
    this.items,
    this.fromScan = false,
    this.amountLocked = false,
    this.recipientCurrency,
    this.recipientCurrencySymbol,
  });

  @override
  ConsumerState<ConfirmSendScreen> createState() => _ConfirmSendScreenState();
}

class _ConfirmSendScreenState extends ConsumerState<ConfirmSendScreen> {
  final _amountController = TextEditingController();
  bool _isLoading = false;
  bool _hasConvertedMerchantAmount = false;

  // Amount from user input (major units)
  double get _amountMajor => double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
  int get _amountMinor => (_amountMajor * 100).round();

  // Server preview results (null until loaded)
  int? _serverFee;
  int? _serverTotalDebit;
  int? _serverCreditAmount;
  double? _serverExchangeRate;
  bool _serverRateUnavailable = false;
  bool? _serverSufficient;
  bool _previewLoading = false;
  String? _previewError;

  // Merchant QR: server-authoritative conversion (buyer-pays computed server-side)
  double? _merchantExchangeRate;
  bool _merchantConvLoading = false;
  bool _merchantRateUnavailable = false;
  Timer? _previewDebounce;

   /// Format exchange rate with enough decimal places to be meaningful
  String _formatRate(double rate) {
    if (rate == 0) return '0.00';
    if (rate >= 1) return rate.toStringAsFixed(2);
    if (rate >= 0.01) return rate.toStringAsFixed(4);
    return rate.toStringAsFixed(6);
  }

  // Display values from server preview (fall back to estimate if not loaded)
  double get _feeMajor {
    if (_serverFee != null) return _serverFee! / 100.0;
    // Approximate fee using tiered structure (matches server calculateFee)
    final isCrossCountry = _currencyCode != (widget.recipientCurrency ?? _currencyCode);
    final majorAmount = _amountMinor / 100;
    double rate;
    int minFee;

    if (isCrossCountry) {
      if (majorAmount <= 500) { rate = 0.03; }
      else if (majorAmount <= 5000) { rate = 0.02; }
      else if (majorAmount <= 50000) { rate = 0.015; }
      else { rate = 0.01; }
      minFee = 100;
    } else {
      if (majorAmount <= 500) { rate = 0.015; }
      else if (majorAmount <= 5000) { rate = 0.01; }
      else if (majorAmount <= 50000) { rate = 0.0075; }
      else { rate = 0.005; }
      minFee = 50;
    }
    final fee = max((_amountMinor * rate).round(), minFee);
    return fee / 100.0;
  }
  double get _totalMajor => _serverTotalDebit != null ? _serverTotalDebit! / 100.0 : _amountMajor + _feeMajor;

  String get _currency => ref.watch(currencyNotifierProvider).currency.symbol;
  String get _currencyCode => ref.watch(currencyNotifierProvider).currency.code;

  // Currency conversion
  bool get _needsConversion {
    final recipientCurrency = widget.recipientCurrency;
    return recipientCurrency != null && recipientCurrency != _currencyCode;
  }

  double? get _convertedAmount {
    if (_serverCreditAmount != null) return _serverCreditAmount! / 100.0;
    // NEW-2: if the server reported the live rate unavailable, do NOT fall back to the
    // client's hardcoded table for the send flow — return null so the UI shows "unavailable".
    if (_serverRateUnavailable) return null;
    if (!_needsConversion || widget.recipientCurrency == null) return null;
    return ExchangeRateService.convert(
      amount: _amountMajor,
      fromCurrency: _currencyCode,
      toCurrency: widget.recipientCurrency!,
    );
  }

  double? get _exchangeRate {
    if (_serverExchangeRate != null) return _serverExchangeRate;
    // NEW-2: if the server reported the live rate unavailable, do NOT fall back to the
    // client's hardcoded table for the send flow — return null so the UI shows "unavailable".
    if (_serverRateUnavailable) return null;
    if (!_needsConversion || widget.recipientCurrency == null) return null;
    return ExchangeRateService.getExchangeRate(
      fromCurrency: _currencyCode,
      toCurrency: widget.recipientCurrency!,
    );
  }

  // Merchant QR specific getters
  bool get _isMerchantQR => widget.amountLocked && _needsConversion;

  // Original amount seller requested in their currency (major units)
  double get _sellerRequestedAmount => widget.amount / 100;

  // Local reverse-rate getters removed: merchant-QR conversion is now
  // server-authoritative via previewMerchantCharge / _fetchMerchantCharge.

  /// Fetch exact fee and conversion from server
  Future<void> _fetchPreview() async {
    final loc = AppLocalizations.of(context);
    if (_amountMinor <= 0) return;

    setState(() {
      _previewLoading = true;
      _previewError = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('previewTransfer');
      final result = await callable.call<Map<String, dynamic>>({
        'amount': _amountMinor,
        'recipientWalletId': widget.recipientWalletId,
      }).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception(loc.sendUiErrorPreviewTimedOut),
      );

      if (!mounted) return;

      final data = result.data;
      setState(() {
        _serverFee = data['fee'] as int?;
        _serverTotalDebit = data['totalDebit'] as int?;
        _serverCreditAmount = data['creditAmount'] as int?;
        _serverExchangeRate = (data['exchangeRate'] as num?)?.toDouble();
        _serverRateUnavailable = data['rateUnavailable'] as bool? ?? false;
        _serverSufficient = data['sufficient'] as bool?;
        _previewLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _previewLoading = false;
        _previewError = ErrorHandler.getUserFriendlyMessage(e);
      });
    }
  }

  /// Fetch the authoritative buyer-pays amount for a merchant QR from the server
  /// (fresh rates). Never falls back to a local rate — blocks the send instead.
  Future<void> _fetchMerchantCharge() async {
    setState(() {
      _merchantConvLoading = true;
      _merchantRateUnavailable = false;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('previewMerchantCharge');
      final result = await callable.call<Map<String, dynamic>>({
        'recipientWalletId': widget.recipientWalletId,
        'requestedAmount': widget.amount,
      }).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final data = result.data;
      final rateUnavailable = data['rateUnavailable'] as bool? ?? false;
      final buyerPays = (data['buyerPaysAmount'] as num?)?.toInt();

      if (rateUnavailable || buyerPays == null) {
        setState(() {
          _merchantConvLoading = false;
          _merchantRateUnavailable = true;
        });
        return;
      }

      setState(() {
        _merchantConvLoading = false;
        _merchantExchangeRate = (data['exchangeRate'] as num?)?.toDouble();
        _amountController.text = (buyerPays / 100).toStringAsFixed(2);
      });

      // Fetch the fee/credit preview for the resolved amount.
      await _fetchPreview();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _merchantConvLoading = false;
        _merchantRateUnavailable = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // For non-merchant QR or same currency, set amount directly
    // Merchant QR with different currency needs conversion in didChangeDependencies
    if (widget.amount > 0 && !widget.amountLocked) {
      _amountController.text = (widget.amount / 100).toStringAsFixed(0);
    }

   // Debounced preview. Mark stale immediately so Send stays disabled until
    // fresh server values arrive — the button can never show a stale amount.
    _amountController.addListener(() {
      _previewDebounce?.cancel();
      if (!_previewLoading) {
        setState(() => _previewLoading = true);
      }
      _previewDebounce = Timer(const Duration(milliseconds: 800), () {
        if (mounted) _fetchPreview();
      });
    });

    // Fetch server preview for accurate fee display
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPreview();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Convert merchant QR amount from seller's currency to buyer's currency
    if (!_hasConvertedMerchantAmount && widget.amountLocked && widget.amount > 0) {
      _hasConvertedMerchantAmount = true;
      if (_isMerchantQR) {
        // Server-authoritative conversion: fetch the buyer-pays amount from the
        // server using fresh rates. Never convert locally — a stale phone rate
        // must not determine the charged amount.
        _fetchMerchantCharge();
      } else {
        // Same currency or no conversion needed
        _amountController.text = (widget.amount / 100).toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _formatAmount(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$integerPart.${parts[1]}';
  }

 String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<bool> _verifyTransactionPin() async {
    final storedPinHash = await SecureStorageService.getPinHash();

    // If no PIN is set, skip verification
    if (storedPinHash == null || storedPinHash.isEmpty) return true;

    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        String? error;
        bool isVerifying = false;
        final pinController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
              ),
              title: Row(
                children: [
                  const Icon(Iconsax.lock, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Text(AppLocalizations.of(context).transactionPin, style: AppTextStyles.headlineSmall()),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context).enterPinToConfirm,
                    style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                  ),
                  const SizedBox(height: 20),
                  if (isVerifying)
                    // TODO: wrap this dialog content in StatefulBuilder to
                    // actually toggle `isVerifying` during PIN verification.
                    // Currently `isVerifying` is always false statically, so
                    // the spinner branch never renders. The branch is preserved
                    // to document the intended verifying-state UI.
                    // ignore: dead_code
                    const CircularProgressIndicator(color: AppColors.primary)
                  else
                    TextField(
                      controller: pinController,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      style: AppTextStyles.headlineMedium(),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '●  ●  ●  ●  ●  ●',
                        hintStyle: AppTextStyles.headlineMedium(color: AppColors.textTertiaryDark),
                        filled: true,
                        fillColor: AppColors.inputBackgroundDark,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                          borderSide: BorderSide(color: error != null ? AppColors.error : AppColors.inputBorderDark),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                          borderSide: BorderSide(color: error != null ? AppColors.error : AppColors.inputBorderDark),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      autofocus: true,
                      onChanged: (value) {
                        if (value.length == 6) {
                          final enteredHash = _hashPin(value);
                          if (enteredHash == storedPinHash) {
                            Navigator.of(dialogContext).pop(true);
                          } else {
                            setDialogState(() {
                              error = 'Incorrect PIN';
                              pinController.clear();
                            });
                          }
                        } else if (error != null) {
                          setDialogState(() => error = null);
                        }
                      },
                    ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: AppTextStyles.bodySmall(color: AppColors.error),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    AppLocalizations.of(context).cancel,
                    style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    return result == true;
  }

  Future<void> _handleSend() async {
    final loc = AppLocalizations.of(context);
    if (_amountMajor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.pleaseEnterAmount),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Verify transaction PIN first
    final pinVerified = await _verifyTransactionPin();
    if (!pinVerified) return;

    setState(() => _isLoading = true);

    try {
      // Check if biometric is enabled and require authentication
      final biometricEnabled = await SecureStorageService.isBiometricEnabled();

      if (biometricEnabled) {
        final biometricService = BiometricService();
        final authResult = await biometricService.authenticate(
          reason: loc.biometricReasonConfirmPayment(
            _currency,
            _totalMajor.toStringAsFixed(2),
            widget.recipientName,
          ),
          biometricOnly: true,
        );

        if (!authResult.success) {
          if (!mounted) return;
          setState(() => _isLoading = false);

          if (!authResult.cancelled) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(resolveBiometricResultError(loc, authResult)),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }

      // Get wallet service and send money
      final walletService = ref.read(walletServiceProvider);
      final result = await walletService.sendMoney(
        recipientWalletId: widget.recipientWalletId,
        amount: _amountMinor,
        note: widget.note,
        items: widget.items,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception(loc.sendUiErrorRequestTimedOut),
      );

      if (!mounted) return;

      if (result.success) {
        // Refresh wallet and transactions
        ref.read(walletNotifierProvider.notifier).refreshWallet();
        ref.read(transactionsNotifierProvider.notifier).refreshTransactions();

        // Show success dialog
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resolveTransactionResultError(loc, result)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorHandler.getUserFriendlyMessage(e)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLG),
              Text(
                AppLocalizations.of(context).successMoneySent,
                style: AppTextStyles.headlineMedium(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceXS),
              Text(
                AppLocalizations.of(context).amountSentTo(_currency, _formatAmount(_amountMajor), widget.recipientName),
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceXL),
              SizedBox(
                width: double.infinity,
                height: AppDimensions.buttonHeightMD,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go(AppRoutes.main);
                  },
                  child: Text(
                    AppLocalizations.of(context).done,
                    style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
                  ),
                ),
              ),
            ],
          ),
        ),
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
        title: Text(AppLocalizations.of(context).confirmSend, style: AppTextStyles.headlineMedium()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
                child: Column(
                  children: [
                    // Payment Request Banner (if from merchant QR)
                    if (widget.amountLocked && ((widget.note != null && widget.note!.isNotEmpty) || (widget.items != null && widget.items!.isNotEmpty))) ...[
                      _buildPaymentRequestBanner()
                          .animate()
                          .fadeIn(duration: 400.ms),
                      const SizedBox(height: AppDimensions.spaceMD),
                    ],

                    // Recipient Card
                    _buildRecipientCard()
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: -0.1, end: 0, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXL),

                    // Amount Input
                    _buildAmountInput()
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 400.ms),

                    const SizedBox(height: AppDimensions.spaceXL),

                    // Transaction Summary
                    _buildTransactionSummary()
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 400.ms),
                  ],
                ),
              ),
            ),

            // Send Button
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLG),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            ),
            child: Center(
              child: Text(
                widget.recipientName.isNotEmpty
                    ? widget.recipientName[0].toUpperCase()
                    : '?',
                style: AppTextStyles.headlineLarge(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).sendingTo,
                  style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.recipientName,
                  style: AppTextStyles.bodyLarge(),
                ),
                Text(
                  widget.recipientWalletId,
                  style: AppTextStyles.caption(color: AppColors.textTertiaryDark),
                ),
              ],
            ),
          ),
          const Icon(
            Iconsax.verify5,
            color: AppColors.success,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRequestBanner() {
    final hasItems = widget.items != null && widget.items!.isNotEmpty;
    final hasNote = widget.note != null && widget.note!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spaceMD),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: AppColors.primary),
              const SizedBox(width: AppDimensions.spaceSM),
              Text(
                AppLocalizations.of(context).paymentRequestLabel,
                style: AppTextStyles.labelMedium(color: AppColors.primary),
              ),
            ],
          ),
          if (hasItems) ...[
            const SizedBox(height: AppDimensions.spaceSM),
            const Divider(color: AppColors.inputBorderDark),
            const SizedBox(height: AppDimensions.spaceXS),
            ...widget.items!.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: AppColors.textSecondaryDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                    ),
                  ),
                ],
              ),
            )),
          ],
          if (hasNote && !hasItems) ...[
            const SizedBox(height: AppDimensions.spaceXS),
            Text(
              widget.note!,
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppLocalizations.of(context).amount,
              style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
            ),
            if (widget.amountLocked) ...[
              const SizedBox(width: AppDimensions.spaceXS),
              const Icon(Icons.lock, size: 14, color: AppColors.textTertiaryDark),
            ],
          ],
        ),
        const SizedBox(height: AppDimensions.spaceSM),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceLG,
            vertical: AppDimensions.spaceMD,
          ),
          decoration: BoxDecoration(
            color: widget.amountLocked
                ? AppColors.surfaceDark.withValues(alpha: 0.5)
                : AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
            border: Border.all(
              color: widget.amountLocked
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.inputBorderDark,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _currency,
                style: AppTextStyles.displaySmall(color: AppColors.primary),
              ),
              const SizedBox(width: AppDimensions.spaceXS),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  readOnly: widget.amountLocked,
                  enabled: !widget.amountLocked,
                  style: AppTextStyles.displaySmall(),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: AppTextStyles.displaySmall(color: AppColors.textTertiaryDark),
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (widget.amountLocked)
                const Icon(Icons.lock, color: AppColors.textTertiaryDark, size: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionSummary() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLG),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
      ),
      child: Column(
        children: [
          _buildSummaryRow(AppLocalizations.of(context).amount, '$_currency${_formatAmount(_amountMajor)}'),
          const SizedBox(height: AppDimensions.spaceMD),
          _buildSummaryRow(
            AppLocalizations.of(context).transactionFee,
            _previewLoading
                ? '...'
                : '${_serverFee == null ? "~" : ""}$_currency${_formatAmount(_feeMajor)}',
            trailing: _previewLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondaryDark),
                  )
                : null,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimensions.spaceMD),
            child: Divider(color: AppColors.inputBorderDark),
          ),
          _buildSummaryRow(
            AppLocalizations.of(context).totalAmount,
            _previewLoading
                ? '...'
                : '${_serverTotalDebit == null ? "~" : ""}$_currency${_formatAmount(_totalMajor)}',
            isTotal: true,
          ),
          if (_serverRateUnavailable || _merchantRateUnavailable) ...[
            const SizedBox(height: AppDimensions.spaceXS),
            Text(
              AppLocalizations.of(context).exchangeRateUnavailable,
              style: AppTextStyles.caption(color: AppColors.error),
            ),
          ],
          if (_previewError != null) ...[
            const SizedBox(height: AppDimensions.spaceXS),
            Text(
              AppLocalizations.of(context).feeApproximateError(_previewError ?? ''),
              style: AppTextStyles.caption(color: AppColors.warning),
            ),
          ],
          if (_serverSufficient == false) ...[
            const SizedBox(height: AppDimensions.spaceXS),
            Text(
              AppLocalizations.of(context).insufficientBalance,
              style: AppTextStyles.caption(color: AppColors.error),
            ),
          ],
          // Show conversion info if currencies are different
          if (_needsConversion && (_isMerchantQR || _convertedAmount != null)) ...[
            const SizedBox(height: AppDimensions.spaceMD),
            _buildConversionInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildConversionInfo() {
    final recipientSymbol = widget.recipientCurrencySymbol ?? widget.recipientCurrency ?? '';

    // For merchant QR: show "Seller requested X" in seller's currency
    // For regular send: show "Recipient receives X" in recipient's currency
    if (_isMerchantQR) {
      final reverseRate = _merchantExchangeRate ?? 0;
      return Container(
        padding: const EdgeInsets.all(AppDimensions.spaceMD),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context).sellerRequestedLabel,
                  style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                ),
                Text(
                  AppLocalizations.of(context).symbolAmount(recipientSymbol, _formatAmount(_sellerRequestedAmount)),
                  style: AppTextStyles.bodyLarge(color: AppColors.info),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceXS),
            Text(
               AppLocalizations.of(context).exchangeRateLine(_currencyCode, _formatRate(reverseRate > 0 ? 1 / reverseRate : 0), widget.recipientCurrency ?? ''),
              style: AppTextStyles.caption(color: AppColors.textSecondaryDark),
            ),
          ],
        ),
      );
    }

    // Regular send: show what recipient receives
    final rate = _exchangeRate ?? 0;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMD),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).recipientReceivesLabel,
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
              ),
              Text(
                AppLocalizations.of(context).symbolAmount(recipientSymbol, _formatAmount(_convertedAmount!)),
                style: AppTextStyles.bodyLarge(color: AppColors.info),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceXS),
          Text(
           AppLocalizations.of(context).exchangeRateLine(_currencyCode, _formatRate(rate), widget.recipientCurrency ?? ''),
            style: AppTextStyles.caption(color: AppColors.textSecondaryDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false, Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? AppTextStyles.bodyLarge()
              : AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: isTotal
                  ? AppTextStyles.headlineSmall(color: AppColors.primary)
                  : AppTextStyles.bodyMedium(),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              trailing,
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSendButton() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        border: Border(
          top: BorderSide(color: AppColors.inputBorderDark, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeightLG,
          child: ElevatedButton(
            onPressed: _isLoading || _previewLoading || _amountMajor <= 0 || _serverRateUnavailable || _merchantConvLoading || _merchantRateUnavailable ? null : _handleSend,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.backgroundDark,
                    ),
                  )
                : Text(
                    AppLocalizations.of(context).sendButtonAmount(_currency, _formatAmount(_totalMajor)),
                    style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
                  ),
          ),
        ),
      ),
    );
  }
}
