import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../auth/widgets/custom_text_field.dart';

/// Send money screen
class SendMoneyScreen extends ConsumerStatefulWidget {
  const SendMoneyScreen({super.key});

  @override
  ConsumerState<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends ConsumerState<SendMoneyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _walletIdController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isLoading = false;
  bool _isLookingUp = false;
  String? _recipientName;
  String? _recipientWalletId;
  String? _recipientCurrency;
  String? _recipientCurrencySymbol;
  String? _lookupError;

  @override
  void dispose() {
    _walletIdController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? _validateWalletId(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.errorFieldRequired;
    }
    if (value.length < 10) {
      return 'Please enter a valid wallet ID';
    }
    return null;
  }

  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.errorFieldRequired;
    }
    final amount = double.tryParse(value.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      return AppStrings.errorInvalidAmount;
    }
    return null;
  }

  Future<void> _lookupRecipient() async {
    final walletId = _walletIdController.text.trim();

    // Clear previous lookup if wallet ID is too short
    if (walletId.length < 10) {
      setState(() {
        _recipientName = null;
        _recipientWalletId = null;
        _recipientCurrency = null;
        _recipientCurrencySymbol = null;
        _lookupError = null;
      });
      return;
    }

    setState(() {
      _isLookingUp = true;
      _lookupError = null;
    });

    try {
      final result = await ref.read(walletNotifierProvider.notifier).lookupWallet(walletId);

      if (!mounted) return;

      if (result.found) {
        setState(() {
          _recipientName = result.fullName;
          _recipientWalletId = result.walletId;
          _recipientCurrency = result.currency;
          _recipientCurrencySymbol = result.currencySymbol;
          _isLookingUp = false;
        });
      } else {
        setState(() {
          _recipientName = null;
          _recipientWalletId = null;
          _recipientCurrency = null;
          _recipientCurrencySymbol = null;
          _lookupError = 'Wallet not found';
          _isLookingUp = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recipientName = null;
        _recipientWalletId = null;
        _recipientCurrency = null;
        _recipientCurrencySymbol = null;
        _lookupError = 'Error looking up wallet';
        _isLookingUp = false;
      });
    }
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;

    // Ensure recipient has been verified
    if (_recipientWalletId == null || _recipientName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid wallet ID'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (!mounted) return;

      final amount = double.parse(_amountController.text.replaceAll(',', ''));

      context.push(
        AppRoutes.confirmSend,
        extra: {
          'recipientWalletId': _recipientWalletId,
          'recipientName': _recipientName,
          'amount': amount,
          'note': _noteController.text.isNotEmpty ? _noteController.text : null,
          'recipientCurrency': _recipientCurrency,
          'recipientCurrencySymbol': _recipientCurrencySymbol,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
        title: Text(AppStrings.sendMoney, style: AppTextStyles.headlineMedium()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Scan QR Option
                      _buildScanQrOption()
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: -0.1, end: 0, duration: 400.ms),

                      const SizedBox(height: AppDimensions.spaceXL),

                      // OR Divider
                      Row(
                        children: [
                          const Expanded(child: Divider(color: AppColors.inputBorderDark)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMD),
                            child: Text(
                              'OR',
                              style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                            ),
                          ),
                          const Expanded(child: Divider(color: AppColors.inputBorderDark)),
                        ],
                      ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                      const SizedBox(height: AppDimensions.spaceXL),

                      // Wallet ID Input
                      CustomTextField(
                        label: AppStrings.walletId,
                        hintText: AppStrings.walletIdHint,
                        controller: _walletIdController,
                        validator: _validateWalletId,
                        onChanged: (_) => _lookupRecipient(),
                        textInputAction: TextInputAction.next,
                      ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                      // Loading indicator during lookup
                      if (_isLookingUp) ...[
                        const SizedBox(height: AppDimensions.spaceXS),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Looking up wallet...',
                              style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                            ),
                          ],
                        ),
                      ],

                      // Recipient Name (found)
                      if (_recipientName != null && !_isLookingUp) ...[
                        const SizedBox(height: AppDimensions.spaceXS),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spaceSM,
                            vertical: AppDimensions.spaceXS,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 14,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _recipientName!,
                                style: AppTextStyles.bodySmall(color: AppColors.success),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Lookup error
                      if (_lookupError != null && !_isLookingUp) ...[
                        const SizedBox(height: AppDimensions.spaceXS),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spaceSM,
                            vertical: AppDimensions.spaceXS,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 14,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _lookupError!,
                                style: AppTextStyles.bodySmall(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppDimensions.spaceLG),

                      // Amount Input
                      CustomTextField(
                        label: AppStrings.amount,
                        hintText: AppStrings.amountHint,
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        validator: _validateAmount,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
                        ],
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(AppDimensions.spaceMD),
                          child: Text(
                            ref.watch(currencyNotifierProvider).currency.symbol,
                            style: AppTextStyles.headlineMedium(color: AppColors.primary),
                          ),
                        ),
                      ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                      const SizedBox(height: AppDimensions.spaceLG),

                      // Note Input
                      CustomTextField(
                        label: AppStrings.note,
                        hintText: AppStrings.noteHint,
                        controller: _noteController,
                        maxLines: 3,
                        textInputAction: TextInputAction.done,
                      ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                    ],
                  ),
                ),
              ),
            ),

            // Continue Button
            _buildContinueButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildScanQrOption() {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.scanQr),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceLG),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          border: Border.all(color: AppColors.inputBorderDark),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              ),
              child: const Icon(
                Iconsax.scan_barcode,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: AppDimensions.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.scanQrCode,
                    style: AppTextStyles.bodyLarge(),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Scan recipient\'s QR code to send money',
                    style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondaryDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
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
            onPressed: _isLoading ? null : _handleContinue,
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
                    AppStrings.continueText,
                    style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
                  ),
          ),
        ),
      ),
    );
  }
}
