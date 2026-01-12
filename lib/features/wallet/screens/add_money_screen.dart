import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/constants.dart';
import '../../../core/services/payment_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/wallet_provider.dart';

/// Screen for adding money to wallet via multiple payment methods
class AddMoneyScreen extends ConsumerStatefulWidget {
  const AddMoneyScreen({super.key});

  @override
  ConsumerState<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends ConsumerState<AddMoneyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _paymentService = PaymentService();

  bool _isLoading = false;
  bool _isLoadingVirtualAccount = false;

  // Mobile Money
  List<MobileMoneyProvider> _momoProviders = [];
  MobileMoneyProvider? _selectedMomoProvider;

  // Virtual Account for Bank Transfer
  String? _virtualBankName;
  String? _virtualAccountNumber;
  String? _virtualAccountName;

  // Quick amount options
  final List<double> _quickAmounts = [1000, 2000, 5000, 10000, 20000, 50000];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMomoProviders();
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 2 && _virtualAccountNumber == null) {
      _loadVirtualAccount();
    }
  }

  String get _currencySymbol => ref.read(walletNotifierProvider).currencySymbol;
  String get _currency => ref.read(walletNotifierProvider).currency;

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

  Future<void> _loadVirtualAccount() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoadingVirtualAccount = true);

    try {
      final result = await _paymentService.getOrCreateVirtualAccount(
        email: user.email,
        name: user.fullName,
      );

      if (mounted) {
        setState(() {
          _isLoadingVirtualAccount = false;
          if (result.success) {
            _virtualBankName = result.bankName;
            _virtualAccountNumber = result.accountNumber;
            _virtualAccountName = result.accountName;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingVirtualAccount = false);
      }
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
      return 'Minimum amount is ${_currencySymbol}100';
    }
    if (amount > 5000000) {
      return 'Maximum amount is ${_currencySymbol}5,000,000';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter phone number';
    }
    if (value.length < 10) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  void _selectQuickAmount(double amount) {
    _amountController.text = amount.toInt().toString();
  }

  // Card Payment
  Future<void> _handleCardPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.replaceAll(',', ''));
    final user = ref.read(currentUserProvider);

    if (user == null) {
      _showError('User not found. Please log in again.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _paymentService.initializePayment(
        context: context,
        email: user.email,
        amount: amount,
        userId: user.id,
        currency: _currency,
      );

      if (!mounted) return;

      if (result.success) {
        ref.read(walletNotifierProvider.notifier).refreshWallet();
        _showSuccess('$_currencySymbol${amount.toStringAsFixed(2)} added to your wallet');
        context.pop();
      } else if (result.pending) {
        // Payment popup shown, waiting for completion
      } else if (result.error != null) {
        _showError(result.error!);
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

  // Mobile Money Payment
  Future<void> _handleMobileMoneyPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMomoProvider == null) {
      _showError('Please select a mobile money provider');
      return;
    }

    final amount = double.parse(_amountController.text.replaceAll(',', ''));
    final user = ref.read(currentUserProvider);

    if (user == null) {
      _showError('User not found. Please log in again.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _paymentService.initializeMobileMoneyPayment(
        email: user.email,
        amount: amount,
        currency: _currency,
        provider: _selectedMomoProvider!.code,
        phoneNumber: _phoneController.text.replaceAll(' ', ''),
        userId: user.id,
      );

      if (!mounted) return;

      if (result.success) {
        _showSuccess('Payment initiated! Please approve on your phone.');
        // Refresh wallet after a delay to check for payment
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            ref.read(walletNotifierProvider.notifier).refreshWallet();
          }
        });
      } else {
        _showError(result.error ?? 'Payment failed');
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

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
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
          AppStrings.addMoney,
          style: AppTextStyles.headlineSmall(),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryDark,
          tabs: const [
            Tab(text: 'Card'),
            Tab(text: 'Mobile Money'),
            Tab(text: 'Bank Transfer'),
          ],
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCardTab(),
              _buildMobileMoneyTab(),
              _buildBankTransferTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CARD TAB
  // ============================================================

  Widget _buildCardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.spaceLG),

          // Amount Input
          _buildAmountInput()
              .animate()
              .fadeIn(duration: 400.ms),

          const SizedBox(height: AppDimensions.spaceXL),

          // Quick Amounts
          _buildQuickAmounts()
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms),

          const SizedBox(height: AppDimensions.spaceXXL),

          // Payment Info
          _buildPaymentInfo()
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms),

          const SizedBox(height: AppDimensions.spaceXXL),

          // Continue Button
          _buildContinueButton(
            onPressed: _handleCardPayment,
            label: 'Continue to Payment',
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

          const SizedBox(height: AppDimensions.spaceLG),
        ],
      ),
    );
  }

  // ============================================================
  // MOBILE MONEY TAB
  // ============================================================

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
                'Mobile money payments are not available in your region. Please use Card or Bank Transfer.',
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

          // Amount Input
          _buildAmountInput()
              .animate()
              .fadeIn(duration: 400.ms),

          const SizedBox(height: AppDimensions.spaceXL),

          // Quick Amounts
          _buildQuickAmounts()
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

          const SizedBox(height: AppDimensions.spaceXXL),

          // Pay Button
          _buildContinueButton(
            onPressed: _handleMobileMoneyPayment,
            label: 'Pay with Mobile Money',
          ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

          const SizedBox(height: AppDimensions.spaceLG),
        ],
      ),
    );
  }

  // ============================================================
  // BANK TRANSFER TAB
  // ============================================================

  Widget _buildBankTransferTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.spaceLG),

          // Virtual Account Card
          _buildVirtualAccountCard()
              .animate()
              .fadeIn(duration: 400.ms),

          const SizedBox(height: AppDimensions.spaceXL),

          // How it works
          _buildHowItWorks()
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms),

          const SizedBox(height: AppDimensions.spaceLG),
        ],
      ),
    );
  }

  // ============================================================
  // SHARED WIDGETS
  // ============================================================

  Widget _buildAmountInput() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceLG),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
        border: Border.all(color: AppColors.inputBorderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter Amount',
            style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
          ),
          const SizedBox(height: AppDimensions.spaceMD),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _currencySymbol,
                style: AppTextStyles.displayMedium(color: AppColors.primary),
              ),
              const SizedBox(width: AppDimensions.spaceSM),
              Expanded(
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: AppTextStyles.displayMedium(),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _ThousandsSeparatorInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: AppTextStyles.displayMedium(color: AppColors.textTertiaryDark),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: _validateAmount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAmounts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Select',
          style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark),
        ),
        const SizedBox(height: AppDimensions.spaceMD),
        Wrap(
          spacing: AppDimensions.spaceSM,
          runSpacing: AppDimensions.spaceSM,
          children: _quickAmounts.map((amount) {
            return GestureDetector(
              onTap: () => _selectQuickAmount(amount),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spaceMD,
                  vertical: AppDimensions.spaceSM,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
                  border: Border.all(color: AppColors.inputBorderDark),
                ),
                child: Text(
                  '$_currencySymbol${_formatAmount(amount)}',
                  style: AppTextStyles.bodyMedium(),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPaymentInfo() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMD),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Row(
        children: [
          Icon(
            Iconsax.security_safe,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: AppDimensions.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Payment',
                  style: AppTextStyles.labelMedium(),
                ),
                const SizedBox(height: 2),
                Text(
                  'Powered by Paystack. Your payment details are secure.',
                  style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton({
    required VoidCallback onPressed,
    required String label,
  }) {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.buttonHeightLG,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
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
                label,
                style: AppTextStyles.labelLarge(color: AppColors.backgroundDark),
              ),
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

  Widget _buildVirtualAccountCard() {
    if (_isLoadingVirtualAccount) {
      return Container(
        padding: const EdgeInsets.all(AppDimensions.spaceXL),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          border: Border.all(color: AppColors.inputBorderDark),
        ),
        child: const Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppDimensions.spaceMD),
              Text('Loading account details...'),
            ],
          ),
        ),
      );
    }

    if (_virtualAccountNumber == null) {
      return Container(
        padding: const EdgeInsets.all(AppDimensions.spaceXL),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLG),
          border: Border.all(color: AppColors.inputBorderDark),
        ),
        child: Column(
          children: [
            Icon(
              Iconsax.bank,
              size: 48,
              color: AppColors.textTertiaryDark,
            ),
            const SizedBox(height: AppDimensions.spaceMD),
            Text(
              'Virtual Account',
              style: AppTextStyles.headlineSmall(),
            ),
            const SizedBox(height: AppDimensions.spaceSM),
            Text(
              'Tap to generate your dedicated account number',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spaceLG),
            ElevatedButton(
              onPressed: _loadVirtualAccount,
              child: const Text('Generate Account'),
            ),
          ],
        ),
      );
    }

    return Container(
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
          Row(
            children: [
              Icon(Iconsax.bank, color: Colors.white, size: 24),
              const SizedBox(width: AppDimensions.spaceSM),
              Text(
                'Your Virtual Account',
                style: AppTextStyles.labelLarge(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceLG),

          // Bank Name
          Text(
            'Bank Name',
            style: AppTextStyles.caption(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            _virtualBankName ?? 'Loading...',
            style: AppTextStyles.bodyLarge(color: Colors.white),
          ),

          const SizedBox(height: AppDimensions.spaceMD),

          // Account Number
          Text(
            'Account Number',
            style: AppTextStyles.caption(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _virtualAccountNumber ?? 'Loading...',
                style: AppTextStyles.headlineSmall(color: Colors.white),
              ),
              IconButton(
                onPressed: () => _copyToClipboard(
                  _virtualAccountNumber ?? '',
                  'Account number',
                ),
                icon: const Icon(Iconsax.copy, color: Colors.white, size: 20),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.spaceMD),

          // Account Name
          Text(
            'Account Name',
            style: AppTextStyles.caption(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _virtualAccountName ?? 'Loading...',
                  style: AppTextStyles.bodyLarge(color: Colors.white),
                ),
              ),
              IconButton(
                onPressed: () => _copyToClipboard(
                  _virtualAccountName ?? '',
                  'Account name',
                ),
                icon: const Icon(Iconsax.copy, color: Colors.white, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMD),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it works',
            style: AppTextStyles.labelLarge(),
          ),
          const SizedBox(height: AppDimensions.spaceMD),
          _buildHowItWorksStep(
            1,
            'Copy the account details above',
            Iconsax.copy,
          ),
          const SizedBox(height: AppDimensions.spaceSM),
          _buildHowItWorksStep(
            2,
            'Transfer any amount from your bank app',
            Iconsax.bank,
          ),
          const SizedBox(height: AppDimensions.spaceSM),
          _buildHowItWorksStep(
            3,
            'Your wallet will be credited instantly',
            Iconsax.tick_circle,
          ),
          const SizedBox(height: AppDimensions.spaceMD),
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceSM),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            ),
            child: Row(
              children: [
                const Icon(Iconsax.info_circle, color: AppColors.warning, size: 20),
                const SizedBox(width: AppDimensions.spaceSM),
                Expanded(
                  child: Text(
                    'This account is unique to you. Any transfer to this account credits your wallet automatically.',
                    style: AppTextStyles.caption(color: AppColors.textSecondaryDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksStep(int step, String text, IconData icon) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$step',
              style: AppTextStyles.caption(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spaceSM),
        Icon(icon, color: AppColors.textSecondaryDark, size: 20),
        const SizedBox(width: AppDimensions.spaceSM),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
          ),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
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
