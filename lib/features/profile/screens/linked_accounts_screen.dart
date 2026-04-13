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

class _LinkedAccountsScreenState extends ConsumerState<LinkedAccountsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _bankAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadLinkedAccounts();
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

      if (mounted) {
        setState(() {
          _bankAccounts = bankSnapshot.docs
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

  Future<void> _deleteAccount(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Account?', style: AppTextStyles.headlineSmall()),
        content: Text(
          'Are you sure you want to remove this bank account?',
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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('linkedBankAccounts')
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

  void _showAddAccountSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AddBankAccountSheet(
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
        title: Text('Linked Bank Accounts', style: AppTextStyles.headlineMedium()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _buildBankAccountsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAccountSheet,
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
        onPressed: _showAddAccountSheet,
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
            onPressed: () => _deleteAccount(account['id']),
            icon: const Icon(Iconsax.trash, color: AppColors.error, size: 20),
          ),
        ],
      ),
    );
  }

  String _maskAccountNumber(String number) {
    if (number.length < 4) return number;
    return '••••${number.substring(number.length - 4)}';
  }
}

class _AddBankAccountSheet extends StatefulWidget {
  final VoidCallback onAdded;

  const _AddBankAccountSheet({required this.onAdded});

  @override
  State<_AddBankAccountSheet> createState() => _AddBankAccountSheetState();
}

class _AddBankAccountSheetState extends State<_AddBankAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Not logged in');

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
                'Add Bank Account',
                style: AppTextStyles.headlineSmall(),
              ),
              const SizedBox(height: 24),
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
                          'Add Bank Account',
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
