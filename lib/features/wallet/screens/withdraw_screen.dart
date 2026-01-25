import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/services/momo_service.dart';
import '../../../providers/wallet_provider.dart';

/// Screen for withdrawing money from wallet to bank or mobile money
class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key});

  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _paymentService = PaymentService();

  bool _isLoading = false;
  bool _isVerifyingAccount = false;
  bool _isLoadingBanks = true;

  // Bank withdrawal fields
  List<Bank> _banks = [];
  Bank? _selectedBank;
  String? _verifiedAccountName;

  // Mobile money fields
  List<MobileMoneyProvider> _momoProviders = [];
  MobileMoneyProvider? _selectedMomoProvider;
  String _momoAccountName = '';

  // Debounce timer for bank verification
  Timer? _debounceTimer;

  // Configuration for bank account verification
  static const int _minDigitsToVerify = 10;
  static const int _maxAccountDigits = 20;
  static const Duration _debounceDuration = Duration(milliseconds: 1000);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBanks();
    _loadMomoProviders();
  }

  @override
  void dispose() {
    // Cancel debounce timer to prevent memory leaks and calls after dispose
    _debounceTimer?.cancel();
    _tabController.dispose();
    _amountController.dispose();
    _accountNumberController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String get _currencySymbol => ref.read(walletNotifierProvider).currencySymbol;
  double get _balance => ref.read(walletNotifierProvider).balance;

  Future<void> _loadBanks() async {
    setState(() => _isLoadingBanks = true);
    try {
      // Determine country from currency
      final currency = ref.read(walletNotifierProvider).currency;
      String country = 'nigeria';
      if (currency == 'GHS') country = 'ghana';
      if (currency == 'KES') country = 'kenya';
      if (currency == 'ZAR') country = 'south africa';

      final banks = await _paymentService.getBanks(country: country);
      if (mounted) {
        setState(() {
          _banks = [
            Bank(name: 'Test Bank (Development)', code: '001', type: 'nuban'),
            ...banks,
          ];
          _isLoadingBanks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBanks = false);
      }
    }
  }

  void _loadMomoProviders() {
    final currency = ref.read(walletNotifierProvider).currency;
    String country = 'nigeria';
    if (currency == 'GHS') country = 'ghana';
    if (currency == 'KES') country = 'kenya';
    if (currency == 'UGX') country = 'uganda';

    _momoProviders = MobileMoneyProvider.getProviders(country);
    if (_momoProviders.isNotEmpty) {
      _selectedMomoProvider = _momoProviders.first;
    }
  }

  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an amount';
    }
    final amount = double.tryParse(value.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      return 'Please enter a valid amount';
    }
    if (amount < 100) {
      return 'Minimum withdrawal is ${_currencySymbol}100';
    }
    if (amount > _balance) {
      return 'Insufficient balance';
    }
    return null;
  }

  String? _validateAccountNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter account number';
    }
    if (value.length < _minDigitsToVerify) {
      return 'Account number must be at least $_minDigitsToVerify digits';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter phone number';
    }
    if (value.length < 6) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  // ============================================================
  // DEBOUNCED BANK VERIFICATION
  // ============================================================

  /// Schedules a bank account verification with debouncing.
  /// This prevents multiple rapid API calls when user is typing.
  void _scheduleBankVerification() {
    // Cancel any existing timer
    _debounceTimer?.cancel();

    final accountNumber = _accountNumberController.text.replaceAll(' ', '');

    // Don't schedule if conditions aren't met
    if (accountNumber.length < _minDigitsToVerify) {
      return;
    }
    if (_selectedBank == null) {
      return;
    }
    if (_isVerifyingAccount) {
      return;
    }

    // Schedule verification after debounce delay
    _debounceTimer = Timer(_debounceDuration, () {
      _verifyBankAccount();
    });
  }

  /// Verifies bank account with Paystack API.
  /// Called either by debounce timer or manual verify button.
  Future<void> _verifyBankAccount() async {
    // Prevent duplicate calls
    if (_isVerifyingAccount) {
      return;
    }

    if (_selectedBank == null) {
      _showError('Please select a bank');
      return;
    }

    final accountNumber = _accountNumberController.text.replaceAll(' ', '');
    if (accountNumber.length < _minDigitsToVerify) {
      _showError('Account number must be at least $_minDigitsToVerify digits');
      return;
    }

    setState(() {
      _isVerifyingAccount = true;
      _verifiedAccountName = null;
    });

    try {
      final result = await _paymentService.verifyBankAccount(
        accountNumber: accountNumber,
        bankCode: _selectedBank!.code,
      );

      if (mounted) {
        setState(() {
          _isVerifyingAccount = false;
          if (result.success) {
            _verifiedAccountName = result.accountName;
          } else {
            _verifiedAccountName = null;
            _showError(result.error ?? 'Could not verify account');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifyingAccount = false);
        _showError(e.toString());
      }
    }
  }

  /// Clears the verified account name when account details change.
  void _clearVerification() {
    if (_verifiedAccountName != null) {
      setState(() {
        _verifiedAccountName = null;
      });
    }
  }

  Future<void> _handleWithdraw() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.replaceAll(',', ''));
    final isBankWithdrawal = _tabController.index == 0;

    // Validate based on withdrawal type
    if (isBankWithdrawal) {
      if (_selectedBank == null) {
        _showError('Please select a bank');
        return;
      }
      if (_verifiedAccountName == null && !kDebugMode) {
        _showError('Please verify your account first');
        return;
      }
    } else {
      if (_selectedMomoProvider == null) {
        _showError('Please select a mobile money provider');
        return;
      }
      if (_momoAccountName.isEmpty) {
        _showError('Please enter account name');
        return;
      }
    }

    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog(amount, isBankWithdrawal);
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      WithdrawalResult result;

      if (isBankWithdrawal) {
        result = await _paymentService.initiateWithdrawal(
          amount: amount,
          bankCode: _selectedBank!.code,
          accountNumber: _accountNumberController.text.replaceAll(' ', ''),
          accountName: _verifiedAccountName!,
        );
      } else {
        // Check if MTN provider - use direct MTN API
        if (MomoService.isMtnProvider(_selectedMomoProvider!.code)) {
          result = await _paymentService.initiateMtnMomoWithdrawal(
            amount: amount,
            phoneNumber: _phoneController.text.replaceAll(' ', ''),
            accountName: _momoAccountName,
            currency: ref.read(walletNotifierProvider).currency,
          );
        } else {
          // Use Paystack for non-MTN providers
          result = await _paymentService.initiateMobileMoneyWithdrawal(
            amount: amount,
            provider: _selectedMomoProvider!.code,
            phoneNumber: _phoneController.text.replaceAll(' ', ''),
            accountName: _momoAccountName,
          );
        }
      }

      if (!mounted) return;

      // Check if OTP is required
      if (result.requiresOtp && result.transferCode != null) {
        setState(() => _isLoading = false);
        final otpResult = await _showOtpDialog(result.transferCode!, amount);
        if (otpResult) {
          ref.read(walletNotifierProvider.notifier).refreshWallet();
          ref.read(transactionsNotifierProvider.notifier).refreshTransactions();
        }
      } else if (result.success) {
        ref.read(walletNotifierProvider.notifier).refreshWallet();
        ref.read(transactionsNotifierProvider.notifier).refreshTransactions();
        _showSuccessDialog(amount, result.reference ?? '');
      } else {
        _showError(result.error ?? 'Withdrawal failed');
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Shows OTP dialog for bank transfer verification
  Future<bool> _showOtpDialog(String transferCode, double amount) async {
    final otpController = TextEditingController();
    bool isVerifying = false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              backgroundColor: AppColors.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
              ),
              title: Text(
                'Enter OTP',
                style: AppTextStyles.headlineSmall(),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Please enter the OTP sent to your registered phone/email to complete the withdrawal of $_currencySymbol${_formatAmount(amount)}',
                    style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                  ),
                  const SizedBox(height: AppDimensions.spaceLG),
                  TextFormField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headlineSmall(),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: AppTextStyles.headlineSmall(color: AppColors.textTertiaryDark),
                      filled: true,
                      fillColor: AppColors.backgroundDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                        borderSide: const BorderSide(color: AppColors.inputBorderDark),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                        borderSide: const BorderSide(color: AppColors.inputBorderDark),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      counterText: '',
                    ),
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.labelMedium(
                      color: isVerifying ? AppColors.textTertiaryDark : AppColors.textSecondaryDark,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final otp = otpController.text.trim();
                          if (otp.length != 6) {
                            _showError('Please enter a valid 6-digit OTP');
                            return;
                          }

                          setDialogState(() => isVerifying = true);

                          try {
                            final result = await _paymentService.finalizeTransfer(
                              transferCode: transferCode,
                              otp: otp,
                            );

                            if (!mounted) return;

                            if (result.success) {
                              Navigator.of(context).pop(true);
                              _showSuccessDialog(amount, result.reference ?? '');
                            } else {
                              setDialogState(() => isVerifying = false);
                              _showError(result.error ?? 'OTP verification failed');
                            }
                          } catch (e) {
                            setDialogState(() => isVerifying = false);
                            _showError(e.toString());
                          }
                        },
                  child: isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.backgroundDark,
                          ),
                        )
                      : Text(
                          'Verify',
                          style: AppTextStyles.labelMedium(color: AppColors.backgroundDark),
                        ),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Future<bool> _showConfirmationDialog(double amount, bool isBankWithdrawal) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
            ),
            title: Text(
              'Confirm Withdrawal',
              style: AppTextStyles.headlineSmall(),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConfirmRow('Amount', '$_currencySymbol${_formatAmount(amount)}'),
                const SizedBox(height: AppDimensions.spaceSM),
                if (isBankWithdrawal) ...[
                  _buildConfirmRow('Bank', _selectedBank?.name ?? ''),
                  const SizedBox(height: AppDimensions.spaceSM),
                  _buildConfirmRow('Account', _accountNumberController.text),
                  const SizedBox(height: AppDimensions.spaceSM),
                  _buildConfirmRow('Name', _verifiedAccountName ?? ''),
                ] else ...[
                  _buildConfirmRow('Provider', _selectedMomoProvider?.name ?? ''),
                  const SizedBox(height: AppDimensions.spaceSM),
                  _buildConfirmRow('Phone', _phoneController.text),
                  const SizedBox(height: AppDimensions.spaceSM),
                  _buildConfirmRow('Name', _momoAccountName),
                ],
                const SizedBox(height: AppDimensions.spaceMD),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceSM),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.warning_2, color: AppColors.warning, size: 20),
                      const SizedBox(width: AppDimensions.spaceSM),
                      Expanded(
                        child: Text(
                          'Please verify the details are correct',
                          style: AppTextStyles.bodySmall(color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Confirm',
                  style: AppTextStyles.labelMedium(color: AppColors.backgroundDark),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildConfirmRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium(),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  void _showSuccessDialog(double amount, String reference) {
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
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.tick_circle5,
                  color: AppColors.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceLG),
              Text(
                'Withdrawal Initiated',
                style: AppTextStyles.headlineMedium(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceXS),
              Text(
                '$_currencySymbol${_formatAmount(amount)} is being processed',
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceSM),
              Text(
                'Ref: $reference',
                style: AppTextStyles.caption(color: AppColors.textTertiaryDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceXL),
              SizedBox(
                width: double.infinity,
                height: AppDimensions.buttonHeightMD,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.pop();
                  },
                  child: Text(
                    AppStrings.done,
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 16,
          right: 16,
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
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textPrimaryDark),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Withdraw',
          style: AppTextStyles.headlineSmall(),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryDark,
          tabs: const [
            Tab(text: 'Bank Transfer'),
            Tab(text: 'Mobile Money'),
          ],
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBankWithdrawalTab(),
              _buildMobileMoneyTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBankWithdrawalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.spaceLG),

          // Balance Card
          _buildBalanceCard()
              .animate()
              .fadeIn(duration: 400.ms),

          const SizedBox(height: AppDimensions.spaceXL),

          // Amount Input
          _buildAmountInput()
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms),

          const SizedBox(height: AppDimensions.spaceXL),

          // Bank Selection
          _buildBankDropdown()
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms),

          const SizedBox(height: AppDimensions.spaceLG),

          // Account Number
          _buildAccountNumberInput()
              .animate()
              .fadeIn(delay: 300.ms, duration: 400.ms),

          // Verified Account Name
          if (_verifiedAccountName != null) ...[
            const SizedBox(height: AppDimensions.spaceMD),
            _buildVerifiedAccountCard()
                .animate()
                .fadeIn(duration: 300.ms)
                .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
          ],

          const SizedBox(height: AppDimensions.spaceXXL),

          // Withdraw Button
          _buildWithdrawButton()
              .animate()
              .fadeIn(delay: 400.ms, duration: 400.ms),

          const SizedBox(height: AppDimensions.spaceLG),
        ],
      ),
    );
  }

  Widget _buildMobileMoneyTab() {
    if (_momoProviders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Iconsax.mobile,
                size: 64,
                color: AppColors.textTertiaryDark,
              ),
              const SizedBox(height: AppDimensions.spaceLG),
              Text(
                'Mobile Money Not Available',
                style: AppTextStyles.headlineSmall(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spaceSM),
              Text(
                'Mobile money withdrawals are not available in your region. Please use bank transfer.',
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.spaceLG),

          // Balance Card
          _buildBalanceCard()
              .animate()
              .fadeIn(duration: 400.ms),

          const SizedBox(height: AppDimensions.spaceXL),

          // Amount Input
          _buildAmountInput()
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms),

          const SizedBox(height: AppDimensions.spaceXL),

          // Provider Selection
          _buildMomoProviderDropdown()
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms),

          const SizedBox(height: AppDimensions.spaceLG),

          // Phone Number
          _buildPhoneInput()
              .animate()
              .fadeIn(delay: 300.ms, duration: 400.ms),

          const SizedBox(height: AppDimensions.spaceLG),

          // Account Name
          _buildMomoAccountNameInput()
              .animate()
              .fadeIn(delay: 350.ms, duration: 400.ms),

          const SizedBox(height: AppDimensions.spaceXXL),

          // Withdraw Button
          _buildWithdrawButton()
              .animate()
              .fadeIn(delay: 400.ms, duration: 400.ms),

          const SizedBox(height: AppDimensions.spaceLG),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    final walletState = ref.watch(walletNotifierProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spaceLG),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.8),
            AppColors.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Balance',
            style: AppTextStyles.bodyMedium(color: Colors.white70),
          ),
          const SizedBox(height: AppDimensions.spaceXS),
          Text(
            '${walletState.currencySymbol}${_formatAmount(walletState.balance)}',
            style: AppTextStyles.displaySmall(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount to Withdraw',
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceSM),
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceLG),
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
              const SizedBox(width: AppDimensions.spaceSM),
              Expanded(
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: AppTextStyles.displaySmall(),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _ThousandsSeparatorInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: AppTextStyles.displaySmall(color: AppColors.textTertiaryDark),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: _validateAmount,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBankDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Bank',
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceSM),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceMD,
            vertical: AppDimensions.spaceXS,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            border: Border.all(color: AppColors.inputBorderDark),
          ),
          child: _isLoadingBanks
              ? const Padding(
                  padding: EdgeInsets.all(AppDimensions.spaceMD),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : DropdownButtonFormField<Bank>(
                  isExpanded: true,
                  value: _selectedBank,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  dropdownColor: AppColors.surfaceDark,
                  hint: Text(
                    'Select a bank',
                    style: AppTextStyles.bodyMedium(color: AppColors.textTertiaryDark),
                  ),
                  items: _banks.map((bank) {
                    return DropdownMenuItem<Bank>(
                      value: bank,
                      child: Text(
                        bank.name,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium(),
                      ),
                    );
                  }).toList(),
                  onChanged: (bank) {
                    setState(() {
                      _selectedBank = bank;
                    });
                    // Clear previous verification and schedule new one
                    _clearVerification();
                    _scheduleBankVerification();
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAccountNumberInput() {
    final accountLength = _accountNumberController.text.replaceAll(' ', '').length;
    final canVerify = accountLength >= _minDigitsToVerify && _selectedBank != null;
    final showVerifyButton = canVerify && _verifiedAccountName == null && !_isVerifyingAccount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Number',
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceSM),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                style: AppTextStyles.bodyLarge(),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_maxAccountDigits),
                ],
                decoration: InputDecoration(
                  hintText: 'Enter account number',
                  hintStyle: AppTextStyles.bodyMedium(color: AppColors.textTertiaryDark),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                    borderSide: const BorderSide(color: AppColors.inputBorderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                    borderSide: const BorderSide(color: AppColors.inputBorderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  suffixIcon: _isVerifyingAccount
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                validator: _validateAccountNumber,
                onChanged: (value) {
                  // Clear previous verification when account number changes
                  _clearVerification();
                  // Schedule debounced verification
                  _scheduleBankVerification();
                },
              ),
            ),
            // Manual verify button - shows when conditions are met but not yet verified
            if (showVerifyButton) ...[
              const SizedBox(width: AppDimensions.spaceSM),
              SizedBox(
                height: 56, // Match text field height
                child: ElevatedButton(
                  onPressed: _verifyBankAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                    ),
                  ),
                  child: Text(
                    'Verify',
                    style: AppTextStyles.labelMedium(color: AppColors.backgroundDark),
                  ),
                ),
              ),
            ],
          ],
        ),
        // Helper text
        if (!canVerify && accountLength > 0) ...[
          const SizedBox(height: AppDimensions.spaceXS),
          Text(
            'Enter at least $_minDigitsToVerify digits to verify',
            style: AppTextStyles.caption(color: AppColors.textTertiaryDark),
          ),
        ],
      ],
    );
  }

  Widget _buildVerifiedAccountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spaceMD),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.tick_circle5, color: AppColors.success, size: 24),
          const SizedBox(width: AppDimensions.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Verified',
                  style: AppTextStyles.labelSmall(color: AppColors.success),
                ),
                Text(
                  _verifiedAccountName!,
                  style: AppTextStyles.bodyLarge(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMomoProviderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mobile Money Provider',
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceSM),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spaceMD,
            vertical: AppDimensions.spaceXS,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
            border: Border.all(color: AppColors.inputBorderDark),
          ),
          child: DropdownButtonFormField<MobileMoneyProvider>(
            value: _selectedMomoProvider,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            dropdownColor: AppColors.surfaceDark,
            items: _momoProviders.map((provider) {
              return DropdownMenuItem<MobileMoneyProvider>(
                value: provider,
                child: Text(
                  provider.name,
                  style: AppTextStyles.bodyMedium(),
                ),
              );
            }).toList(),
            onChanged: (provider) {
              setState(() => _selectedMomoProvider = provider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceSM),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: AppTextStyles.bodyLarge(),
          decoration: InputDecoration(
            hintText: 'Enter phone number',
            hintStyle: AppTextStyles.bodyMedium(color: AppColors.textTertiaryDark),
            filled: true,
            fillColor: AppColors.surfaceDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              borderSide: const BorderSide(color: AppColors.inputBorderDark),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              borderSide: const BorderSide(color: AppColors.inputBorderDark),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            prefixIcon: const Icon(Iconsax.call, color: AppColors.textSecondaryDark),
          ),
          validator: _validatePhone,
        ),
      ],
    );
  }

  Widget _buildMomoAccountNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Name',
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceSM),
        TextFormField(
          style: AppTextStyles.bodyLarge(),
          decoration: InputDecoration(
            hintText: 'Enter account holder name',
            hintStyle: AppTextStyles.bodyMedium(color: AppColors.textTertiaryDark),
            filled: true,
            fillColor: AppColors.surfaceDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              borderSide: const BorderSide(color: AppColors.inputBorderDark),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              borderSide: const BorderSide(color: AppColors.inputBorderDark),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            prefixIcon: const Icon(Iconsax.user, color: AppColors.textSecondaryDark),
          ),
          onChanged: (value) => _momoAccountName = value,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter account name';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildWithdrawButton() {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeightLG,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleWithdraw,
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
                'Withdraw',
                style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
              ),
      ),
    );
  }

  String _formatAmount(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$integerPart.${parts[1]}';
  }
}

/// Input formatter for thousands separator
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final value = int.tryParse(newValue.text.replaceAll(',', ''));
    if (value == null) {
      return oldValue;
    }

    final formatted = _formatNumber(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatNumber(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
