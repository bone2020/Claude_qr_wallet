import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class LinkedAccountsScreen extends ConsumerStatefulWidget {
  const LinkedAccountsScreen({super.key});

  @override
  ConsumerState<LinkedAccountsScreen> createState() => _LinkedAccountsScreenState();
}

class _LinkedAccountsScreenState extends ConsumerState<LinkedAccountsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _bankAccounts = [];
  List<Map<String, dynamic>> _cards = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLinkedAccounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLinkedAccounts() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Load bank accounts
      final bankSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('linkedBankAccounts')
          .orderBy('createdAt', descending: true)
          .get();

      // Load cards
      final cardSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('linkedCards')
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _bankAccounts = bankSnapshot.docs
              .map((doc) => {...doc.data(), 'id': doc.id})
              .toList();
          _cards = cardSnapshot.docs
              .map((doc) => {...doc.data(), 'id': doc.id})
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading linked accounts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAccount(String type, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Account?', style: AppTextStyles.headlineSmall()),
        content: Text(
          'Are you sure you want to remove this ${type == 'bank' ? 'bank account' : 'card'}?',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTextStyles.labelMedium(color: AppColors.textSecondaryDark)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Remove', style: AppTextStyles.labelMedium(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final collection = type == 'bank' ? 'linkedBankAccounts' : 'linkedCards';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(collection)
          .doc(id)
          .delete();

      await _loadLinkedAccounts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account removed'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showAddAccountSheet(String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AddAccountSheet(
        type: type,
        onAdded: () {
          Navigator.pop(context);
          _loadLinkedAccounts();
        },
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
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textPrimaryDark),
          onPressed: () => context.pop(),
        ),
        title: Text('Linked Accounts', style: AppTextStyles.headlineMedium()),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryDark,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Bank Accounts'),
            Tab(text: 'Cards'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBankAccountsList(),
                _buildCardsList(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAccountSheet(
          _tabController.index == 0 ? 'bank' : 'card',
        ),
        backgroundColor: AppColors.primary,
        child: const Icon(Iconsax.add, color: Colors.black),
      ),
    );
  }

  Widget _buildBankAccountsList() {
    if (_bankAccounts.isEmpty) {
      return _buildEmptyState(
        icon: Iconsax.bank,
        title: 'No Bank Accounts',
        subtitle: 'Add a bank account to make withdrawals easier',
        buttonText: 'Add Bank Account',
        onPressed: () => _showAddAccountSheet('bank'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLinkedAccounts,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bankAccounts.length,
        itemBuilder: (context, index) {
          final account = _bankAccounts[index];
          return _buildBankAccountCard(account);
        },
      ),
    );
  }

  Widget _buildCardsList() {
    if (_cards.isEmpty) {
      return _buildEmptyState(
        icon: Iconsax.card,
        title: 'No Cards Linked',
        subtitle: 'Add a card for quick top-ups',
        buttonText: 'Add Card',
        onPressed: () => _showAddAccountSheet('card'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLinkedAccounts,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _cards.length,
        itemBuilder: (context, index) {
          final card = _cards[index];
          return _buildCardItem(card);
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.surfaceDark,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.textSecondaryDark),
            ),
            const SizedBox(height: 24),
            Text(title, style: AppTextStyles.headlineSmall()),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Iconsax.add, color: Colors.black),
              label: Text(buttonText, style: AppTextStyles.labelMedium(color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankAccountCard(Map<String, dynamic> account) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Iconsax.bank, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account['bankName'] ?? 'Bank Account',
                  style: AppTextStyles.bodyLarge(),
                ),
                const SizedBox(height: 4),
                Text(
                  _maskAccountNumber(account['accountNumber'] ?? ''),
                  style: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
                ),
                const SizedBox(height: 2),
                Text(
                  account['accountName'] ?? '',
                  style: AppTextStyles.bodySmall(color: AppColors.textSecondaryDark),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deleteAccount('bank', account['id']),
            icon: const Icon(Iconsax.trash, color: AppColors.error, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem(Map<String, dynamic> card) {
    final cardType = _getCardType(card['cardNumber'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cardType == 'Visa'
              ? [const Color(0xFF1A1F71), const Color(0xFF2E3B8C)]
              : [const Color(0xFFEB001B), const Color(0xFFF79E1B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                cardType,
                style: AppTextStyles.bodyLarge(color: Colors.white).copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => _deleteAccount('card', card['id']),
                icon: const Icon(Iconsax.trash, color: Colors.white70, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _maskCardNumber(card['cardNumber'] ?? ''),
            style: AppTextStyles.headlineSmall(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CARD HOLDER',
                    style: AppTextStyles.bodySmall(color: Colors.white60),
                  ),
                  Text(
                    card['cardHolder'] ?? '',
                    style: AppTextStyles.bodyMedium(color: Colors.white),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'EXPIRES',
                    style: AppTextStyles.bodySmall(color: Colors.white60),
                  ),
                  Text(
                    card['expiry'] ?? '',
                    style: AppTextStyles.bodyMedium(color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _maskAccountNumber(String number) {
    if (number.length < 4) return number;
    return '••••${number.substring(number.length - 4)}';
  }

  String _maskCardNumber(String number) {
    if (number.length < 4) return number;
    return '•••• •••• •••• ${number.substring(number.length - 4)}';
  }

  String _getCardType(String number) {
    if (number.startsWith('4')) return 'Visa';
    if (number.startsWith('5')) return 'Mastercard';
    return 'Card';
  }
}

class _AddAccountSheet extends StatefulWidget {
  final String type;
  final VoidCallback onAdded;

  const _AddAccountSheet({required this.type, required this.onAdded});

  @override
  State<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<_AddAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Bank account fields
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();

  // Card fields
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Not logged in');

      if (widget.type == 'bank') {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('linkedBankAccounts')
            .add({
          'bankName': _bankNameController.text,
          'accountNumber': _accountNumberController.text,
          'accountName': _accountNameController.text,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('linkedCards')
            .add({
          'cardNumber': _cardNumberController.text.replaceAll(' ', ''),
          'cardHolder': _cardHolderController.text,
          'expiry': _expiryController.text,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      widget.onAdded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondaryDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.type == 'bank' ? 'Add Bank Account' : 'Add Card',
                style: AppTextStyles.headlineSmall(),
              ),
              const SizedBox(height: 24),

              if (widget.type == 'bank') ...[
                _buildTextField(
                  controller: _bankNameController,
                  label: 'Bank Name',
                  hint: 'e.g. GCB Bank',
                  icon: Iconsax.bank,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _accountNumberController,
                  label: 'Account Number',
                  hint: 'Enter account number',
                  icon: Iconsax.card,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _accountNameController,
                  label: 'Account Name',
                  hint: 'Name on account',
                  icon: Iconsax.user,
                ),
              ] else ...[
                _buildTextField(
                  controller: _cardNumberController,
                  label: 'Card Number',
                  hint: '1234 5678 9012 3456',
                  icon: Iconsax.card,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _cardHolderController,
                  label: 'Card Holder Name',
                  hint: 'Name on card',
                  icon: Iconsax.user,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _expiryController,
                  label: 'Expiry Date',
                  hint: 'MM/YY',
                  icon: Iconsax.calendar,
                  keyboardType: TextInputType.datetime,
                ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : Text(
                          widget.type == 'bank' ? 'Add Bank Account' : 'Add Card',
                          style: AppTextStyles.labelLarge(color: Colors.black),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppTextStyles.bodyLarge(color: AppColors.textPrimaryDark),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        hintStyle: AppTextStyles.bodyMedium(color: AppColors.textSecondaryDark),
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.inputBackgroundDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'This field is required';
        }
        return null;
      },
    );
  }
}
